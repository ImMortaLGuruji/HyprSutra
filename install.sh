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

FEDORA_VERSION=$(grep -i '^VERSION_ID=' /etc/os-release | cut -d'=' -f2 | tr -d '"')
if [[ ${FEDORA_VERSION%%.*} -lt 39 ]]; then
  echo "This script expects Fedora 39 or newer. Detected ${FEDORA_VERSION}. Aborting." >&2
  exit 1
fi

LOG_FILE=${LOG_FILE:-$(mktemp /tmp/fedora-hyprland-XXXX.log)}
echo "Logging to ${LOG_FILE}"
exec > >(tee -a "${LOG_FILE}") 2>&1

sudo -v

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SRC="${SCRIPT_DIR}/.config"
WALLPAPER_SRC="${SCRIPT_DIR}/Wallpapers"
BACKUP_ROOT="$HOME/.config.backup-$(date +%Y%m%d%H%M%S)"
INSTALL_CHROME=${INSTALL_CHROME:-true}
INSTALL_VSCODE=${INSTALL_VSCODE:-true}
INSTALL_MATUGEN_METHOD=${INSTALL_MATUGEN_METHOD:-cargo}
FONT_URL=${FONT_URL:-"https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/JetBrainsMono.zip"}
ENABLE_BATTERY_TUNING=${ENABLE_BATTERY_TUNING:-true}
MONITOR_NAME=${MONITOR_NAME:-"eDP-1"}
MONITOR_RESOLUTION=${MONITOR_RESOLUTION:-"1920x1080"}
MONITOR_REFRESH_BAT=${MONITOR_REFRESH_BAT:-"60.01900"}
MONITOR_REFRESH_AC=${MONITOR_REFRESH_AC:-"144.00000"}
GPU_VENDOR=${GPU_VENDOR:-auto}
ENABLE_NVIDIA_ENV=${ENABLE_NVIDIA_ENV:-true}
DRY_RUN=${DRY_RUN:-false}
TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME=$(eval echo "~${TARGET_USER}")
TARGET_UID=$(id -u "${TARGET_USER}")
RSYNC_FLAGS="-a --checksum"

if [[ "${DRY_RUN}" == "true" ]]; then
  info() { printf '\n[DRY RUN] %s\n' "$*"; }
  RSYNC_FLAGS="${RSYNC_FLAGS} --dry-run --itemize-changes"
else
  info() { printf '\n[+] %s\n' "$*"; }
fi

info "Ensuring sudo session is active"
sudo -v

info "Detected Fedora ${FEDORA_VERSION}"

if [[ "${GPU_VENDOR}" == "auto" ]]; then
  if command -v lspci >/dev/null 2>&1; then
    if lspci | grep -qi nvidia; then
      GPU_VENDOR="nvidia"
    elif lspci | grep -qi 'AMD/ATI'; then
      GPU_VENDOR="amd"
    elif lspci | grep -qi 'Intel Corporation'; then
      GPU_VENDOR="intel"
    else
      GPU_VENDOR="unknown"
    fi
  else
    GPU_VENDOR="unknown"
  fi
fi

info "GPU vendor set to ${GPU_VENDOR}"

user_systemctl() {
  sudo -u "$TARGET_USER" \
    XDG_RUNTIME_DIR="/run/user/${TARGET_UID}" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${TARGET_UID}/bus" \
    systemctl --user "$@"
}

has_user_systemd() {
  user_systemctl list-units --type=service >/dev/null 2>&1
}

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

case "${GPU_VENDOR}" in
  nvidia)
    info "Installing NVIDIA drivers via RPM Fusion"
    sudo dnf -y install "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
      "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
    sudo dnf -y install akmod-nvidia xorg-x11-drv-nvidia-cuda

    if [[ "${ENABLE_NVIDIA_ENV}" == "true" ]]; then
      info "Writing NVIDIA Wayland environment overrides"
      sudo mkdir -p /etc/environment.d
      sudo tee /etc/environment.d/90-hypr-nvidia.conf >/dev/null <<'EOF'
WLR_NO_HARDWARE_CURSORS=1
LIBVA_DRIVER_NAME=nvidia
GBM_BACKEND=nvidia-drm
__GLX_VENDOR_LIBRARY_NAME=nvidia
EOF
    fi
    ;;
  amd|intel)
    info "GPU vendor ${GPU_VENDOR} detected; no vendor-specific packages needed"
    ;;
  *)
    info "GPU vendor ${GPU_VENDOR} not recognized; skipping GPU-specific setup"
    ;;
esac

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
    rsync ${RSYNC_FLAGS} "$target" "$BACKUP_ROOT/"
  fi

  mkdir -p "$target"
  rsync ${RSYNC_FLAGS} "$CONFIG_SRC/$name/" "$target/"
}

info "Deploying configuration files (backups go to $BACKUP_ROOT if needed)"
mkdir -p "$HOME/.config"
for dir in hypr kitty matugen rofi waybar; do
  backup_and_copy "$dir"
done

info "Installing wallgen helper"
mkdir -p "$HOME/.local/bin"
cat > "$HOME/.local/bin/wallgen" <<'EOF'
#!/usr/bin/env bash
swww img "$1" --transition-type grow --transition-pos center
matugen image "$1"

LINE_NUM=75
ESCAPED=$(printf '%s\n' "$1" | sed 's/[&|]/\\&/g')
NEW_TEXT="    background-image:            url(\"$ESCAPED\", height);"
FILE="$HOME/.config/rofi/launchers/type-7/style-7.rasi"

sed -i "${LINE_NUM}s|.*|${NEW_TEXT}|" "$FILE"
EOF
chmod +x "$HOME/.local/bin/wallgen"
chmod +x "$HOME/.config/rofi/launchers/type-7/launcher.sh"

info "Creating wallpaper directory"
mkdir -p "$HOME/Pictures/Wallpapers"

if [[ -d "$WALLPAPER_SRC" ]]; then
  info "Copying bundled wallpapers to ~/Pictures/Wallpapers"
  rsync ${RSYNC_FLAGS} "$WALLPAPER_SRC/" "$HOME/Pictures/Wallpapers/"
fi

if [[ "${ENABLE_BATTERY_TUNING}" == "true" ]]; then
  info "Applying battery optimizations (target user: ${TARGET_USER})"

  sudo dnf install -y tlp tlp-rdw brightnessctl mesa-demos

  sudo systemctl stop power-profiles-daemon.service 2>/dev/null || true
  sudo systemctl mask power-profiles-daemon.service 2>/dev/null || true
  sudo systemctl disable tuned.service 2>/dev/null || true

  sudo systemctl enable --now tlp.service

  sudo tee /etc/tlp.conf >/dev/null <<'EOF'
TLP_ENABLE=1

# CPU
CPU_SCALING_GOVERNOR_ON_AC=schedutil
CPU_SCALING_GOVERNOR_ON_BAT=powersave

CPU_BOOST_ON_AC=1
CPU_BOOST_ON_BAT=0

CPU_ENERGY_PERF_POLICY_ON_AC=performance
CPU_ENERGY_PERF_POLICY_ON_BAT=power

# Platform
PCIE_ASPM_ON_BAT=powersupersave
RUNTIME_PM_ON_BAT=auto
USB_AUTOSUSPEND=1
EOF

  sudo mkdir -p /etc/NetworkManager/conf.d
  sudo tee /etc/NetworkManager/conf.d/wifi-powersave.conf >/dev/null <<'EOF'
[connection]
wifi.powersave = 3
EOF

  sudo systemctl restart NetworkManager

  if command -v hyprctl >/dev/null 2>&1; then
    sudo -u "$TARGET_USER" mkdir -p "$TARGET_HOME/.local/bin"
    sudo tee "$TARGET_HOME/.local/bin/hypr-refresh.sh" >/dev/null <<EOF
#!/usr/bin/env bash

MONITOR="${MONITOR_NAME}"
RESOLUTION="${MONITOR_RESOLUTION}"
BAT_REFRESH="${MONITOR_REFRESH_BAT}"
AC_REFRESH="${MONITOR_REFRESH_AC}"

POWER=$(cat /sys/class/power_supply/AC*/online 2>/dev/null | head -n1)

if [ "$POWER" = "1" ]; then
    hyprctl keyword monitor "$MONITOR,$RESOLUTION@$AC_REFRESH,0x0,1"
else
    hyprctl keyword monitor "$MONITOR,$RESOLUTION@$BAT_REFRESH,0x0,1"
fi
EOF

    sudo chmod +x "$TARGET_HOME/.local/bin/hypr-refresh.sh"
    sudo chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.local"

    sudo -u "$TARGET_USER" mkdir -p "$TARGET_HOME/.config/systemd/user"
    sudo tee "$TARGET_HOME/.config/systemd/user/hypr-refresh.service" >/dev/null <<'EOF'
[Unit]
Description=Hyprland Auto Refresh Rate Switch

[Service]
Type=oneshot
ExecStart=%h/.local/bin/hypr-refresh.sh

[Install]
WantedBy=default.target
EOF

    if command -v loginctl >/dev/null 2>&1; then
      sudo loginctl enable-linger "$TARGET_USER" || true
    fi

    if has_user_systemd; then
      user_systemctl daemon-reload
      user_systemctl enable hypr-refresh.service
    else
      info "User systemd not detected; enable hypr-refresh.service after login with: systemctl --user enable hypr-refresh.service"
    fi

    sudo tee /etc/udev/rules.d/90-hypr-refresh.rules >/dev/null <<'EOF'
SUBSYSTEM=="power_supply", ACTION=="change", RUN+="/usr/bin/systemctl --user restart hypr-refresh.service"
EOF

    sudo udevadm control --reload-rules
  else
    info "hyprctl not found; skipping Hyprland refresh auto-switch"
  fi

  sudo tlp start
  info "Battery setup complete. Reboot recommended."
else
  info "Skipping battery optimizations (set ENABLE_BATTERY_TUNING=true to enable)"
fi

info "Done. Log out and pick the Hyprland session."
echo "Set your wallpaper and recolor the desktop with: wallgen ~/Pictures/Wallpapers/your-image.jpg"
