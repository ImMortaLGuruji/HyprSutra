#!/usr/bin/env bash
set -euo pipefail

if [[ ${EUID} -eq 0 ]]; then
  echo "Run this script as a regular user. It will elevate with sudo when needed." >&2
  exit 1
fi

if ! grep -qi '^ID=fedora' /etc/os-release; then
  echo "This script targets Fedora. Aborting." >&2
  exit 1
fi

sudo -v

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SRC="${SCRIPT_DIR}/.config"
WALLPAPER_SRC="${SCRIPT_DIR}/Wallpapers"
BACKUP_ROOT="$HOME/.config.backup-$(date +%Y%m%d%H%M%S)"
INSTALL_CHROME=${INSTALL_CHROME:-true}
INSTALL_VSCODE=${INSTALL_VSCODE:-true}
INSTALL_MATUGEN_METHOD=${INSTALL_MATUGEN_METHOD:-cargo}
FONT_URL=${FONT_URL:-"https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/JetBrainsMono.zip"}

info() { printf '\n[+] %s\n' "$*"; }

info "Updating system and base tooling"
sudo dnf -y upgrade
sudo dnf -y install dnf-plugins-core curl wget unzip rsync git \
  wl-clipboard brightnessctl playerctl pavucontrol \
  grim slurp swappy polkit-gnome xdg-desktop-portal-hyprland xdg-desktop-portal-gtk \
  kitty waybar rofi nautilus

info "Enabling COPR repos for Hyprland and swww"
sudo dnf -y copr enable solopasha/hyprland
sudo dnf -y copr enable erikreider/swww

info "Installing Hyprland stack"
sudo dnf -y install hyprland swww

if [[ "${INSTALL_CHROME}" == "true" ]]; then
  info "Configuring Google Chrome repo"
  sudo tee /etc/yum.repos.d/google-chrome.repo >/dev/null <<'EOF'
[google-chrome]
name=google-chrome
baseurl=https://dl.google.com/linux/chrome/rpm/stable/x86_64
enabled=1
gpgcheck=1
gpgkey=https://dl.google.com/linux/linux_signing_key.pub
EOF
  info "Installing Google Chrome"
  sudo dnf -y install google-chrome-stable
else
  info "Skipping Chrome (set INSTALL_CHROME=true to enable)"
fi

if [[ "${INSTALL_VSCODE}" == "true" ]]; then
  info "Configuring Visual Studio Code repo"
  sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
  sudo tee /etc/yum.repos.d/vscode.repo >/dev/null <<'EOF'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF
  info "Installing VS Code"
  sudo dnf -y install code
else
  info "Skipping VS Code (set INSTALL_VSCODE=true to enable)"
fi

case "${INSTALL_MATUGEN_METHOD}" in
  cargo)
    info "Installing matugen via cargo"
    sudo dnf -y install rust cargo gcc-c++ make pkg-config
    cargo install --locked matugen
    ;;
  skip)
    info "Skipping matugen install (set INSTALL_MATUGEN_METHOD=cargo to build)"
    ;;
  *)
    echo "Unknown INSTALL_MATUGEN_METHOD: ${INSTALL_MATUGEN_METHOD}" >&2
    exit 1
    ;;
esac

info "Installing JetBrains Mono Nerd Font"
tmpdir=$(mktemp -d)
mkdir -p "$HOME/.local/share/fonts"
curl -L "${FONT_URL}" -o "$tmpdir/font.zip"
unzip -o "$tmpdir/font.zip" -d "$HOME/.local/share/fonts/JetBrainsMonoNerd" >/dev/null
fc-cache -f
rm -rf "$tmpdir"

if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
  info "Adding ~/.local/bin to PATH via ~/.bashrc"
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
fi

if [[ ":$PATH:" != *":$HOME/.cargo/bin:"* ]] && [[ "${INSTALL_MATUGEN_METHOD}" == "cargo" ]]; then
  info "Adding ~/.cargo/bin to PATH via ~/.bashrc"
  echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> "$HOME/.bashrc"
fi

backup_and_copy() {
  local name="$1"
  local target="$HOME/.config/$name"

  [[ -d "$CONFIG_SRC/$name" ]] || return

  if [[ -e "$target" ]]; then
    mkdir -p "$BACKUP_ROOT"
    rsync -a "$target" "$BACKUP_ROOT/"
  fi

  mkdir -p "$target"
  rsync -a "$CONFIG_SRC/$name/" "$target/"
}

info "Deploying configuration files (backups go to $BACKUP_ROOT if needed)"
mkdir -p "$HOME/.config"
for dir in hypr kitty matugen rofi waybar; do
  backup_and_copy "$dir"
done

info "Installing wallgen helper"
mkdir -p "$HOME/.local/bin"
install -m 755 "$SCRIPT_DIR/wallgen" "$HOME/.local/bin/wallgen"
chmod +x "$HOME/.config/rofi/launchers/type-7/launcher.sh"

info "Creating wallpaper directory"
mkdir -p "$HOME/Pictures/Wallpapers"

if [[ -d "$WALLPAPER_SRC" ]]; then
  info "Copying bundled wallpapers to ~/Pictures/Wallpapers"
  rsync -a "$WALLPAPER_SRC/" "$HOME/Pictures/Wallpapers/"
fi

info "Done. Log out and pick the Hyprland session."
echo "Set your wallpaper and recolor the desktop with: wallgen ~/Pictures/Wallpapers/your-image.jpg"
