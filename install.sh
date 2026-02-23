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
INSTALL_NERD_FONT=${INSTALL_NERD_FONT:-true}
SYSTEM_UPGRADE=${SYSTEM_UPGRADE:-false}
INSTALL_WEAK_DEPS=${INSTALL_WEAK_DEPS:-false}
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
DNF_INSTALL_FLAGS="-y"

if [[ "${INSTALL_WEAK_DEPS}" == "false" ]]; then
  DNF_INSTALL_FLAGS="${DNF_INSTALL_FLAGS} --setopt=install_weak_deps=False"
fi

if [[ "${DRY_RUN}" == "true" ]]; then
  info() { printf '\n[DRY RUN] %s\n' "$*"; }
  RSYNC_FLAGS="${RSYNC_FLAGS} --dry-run --itemize-changes"
else
  info() { printf '\n[+] %s\n' "$*"; }
fi

info "Ensuring sudo session is active"
sudo -v

info "Detected Fedora ${FEDORA_VERSION}"

# Clean up stale COPR repos that may not exist for newer Fedora releases.
sudo dnf -y copr disable erikreider/swww >/dev/null 2>&1 || true
sudo find /etc/yum.repos.d -maxdepth 1 -type f -name '*erikreider*swww*.repo' -delete 2>/dev/null || true

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
if [[ "${SYSTEM_UPGRADE}" == "true" ]]; then
  sudo dnf -y upgrade --refresh
else
  info "Skipping full system upgrade (set SYSTEM_UPGRADE=true to enable)"
fi
sudo dnf ${DNF_INSTALL_FLAGS} install dnf-plugins-core curl wget unzip rsync git \
  wl-clipboard brightnessctl playerctl pavucontrol \
  grim slurp swappy mate-polkit xdg-desktop-portal-hyprland xdg-desktop-portal-gtk \
  kitty waybar rofi nautilus \
  network-manager-applet blueman bluez mako hypridle hyprlock xdg-user-dirs xdg-user-dirs-gtk

info "Enabling COPR repos for Hyprland and swww"
if ! sudo dnf -y copr enable solopasha/hyprland; then
  info "Copr solopasha/hyprland not available for this Fedora release; continuing with default repos"
fi
if ! sudo dnf -y copr enable erikreider/swww; then
  info "Copr erikreider/swww not available for this Fedora release; continuing with default repos"
  sudo dnf -y copr disable erikreider/swww >/dev/null 2>&1 || true
fi

info "Installing Hyprland stack"
sudo dnf ${DNF_INSTALL_FLAGS} install hyprland swww

case "${GPU_VENDOR}" in
  nvidia)
    info "Installing NVIDIA drivers via RPM Fusion"
    sudo dnf ${DNF_INSTALL_FLAGS} install "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
      "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
    sudo dnf ${DNF_INSTALL_FLAGS} install akmod-nvidia xorg-x11-drv-nvidia-cuda

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

    info "Enabling NVIDIA dynamic power management"
    sudo tee /etc/modprobe.d/nvidia-power.conf >/dev/null <<'EOF'
options nvidia NVreg_DynamicPowerManagement=0x02
EOF

    if systemctl list-unit-files | grep -q '^nvidia-powerd.service'; then
      sudo systemctl enable --now nvidia-powerd.service
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
  sudo dnf ${DNF_INSTALL_FLAGS} install google-chrome-stable
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
  sudo dnf ${DNF_INSTALL_FLAGS} install code
else
  info "Skipping VS Code (set INSTALL_VSCODE=true to enable)"
fi

case "${INSTALL_MATUGEN_METHOD}" in
  cargo)
    info "Installing matugen via cargo"
    sudo dnf ${DNF_INSTALL_FLAGS} install rust cargo gcc-c++ make pkg-config
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

if [[ "${INSTALL_NERD_FONT}" == "true" ]]; then
  if compgen -G "$HOME/.local/share/fonts/JetBrainsMonoNerd/*.ttf" >/dev/null 2>&1; then
    info "JetBrains Mono Nerd Font already present; skipping download"
  else
    info "Installing JetBrains Mono Nerd Font"
    tmpdir=$(mktemp -d)
    mkdir -p "$HOME/.local/share/fonts"
    curl -fL "${FONT_URL}" -o "$tmpdir/font.zip"
    unzip -o "$tmpdir/font.zip" -d "$HOME/.local/share/fonts/JetBrainsMonoNerd" >/dev/null
    fc-cache -f
    rm -rf "$tmpdir"
  fi
else
  info "Skipping Nerd Font install (set INSTALL_NERD_FONT=true to enable)"
fi

append_once() {
  local line="$1"
  local file="$2"

  grep -qxF "$line" "$file" 2>/dev/null || echo "$line" >> "$file"
}

if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
  info "Adding ~/.local/bin to PATH via ~/.bashrc"
  append_once 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.bashrc"
fi

if [[ ":$PATH:" != *":$HOME/.cargo/bin:"* ]] && [[ "${INSTALL_MATUGEN_METHOD}" == "cargo" ]]; then
  info "Adding ~/.cargo/bin to PATH via ~/.bashrc"
  append_once 'export PATH="$HOME/.cargo/bin:$PATH"' "$HOME/.bashrc"
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
for dir in hypr kitty matugen rofi waybar mako swappy; do
  backup_and_copy "$dir"
done

info "Installing wallgen helper"
mkdir -p "$HOME/.local/bin"
cat > "$HOME/.local/bin/wallgen" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "wallgen: failed - $1"
  exit 1
}

if [[ $# -lt 1 ]]; then
  fail "missing wallpaper path"
fi

if [[ ! -f "$1" ]]; then
  fail "wallpaper not found"
fi

MATUGEN_BIN="${MATUGEN_BIN:-}"
if [[ -z "$MATUGEN_BIN" ]]; then
  if [[ -x "$HOME/.cargo/bin/matugen" ]]; then
    MATUGEN_BIN="$HOME/.cargo/bin/matugen"
  elif [[ -x "$HOME/.local/bin/matugen" ]]; then
    MATUGEN_BIN="$HOME/.local/bin/matugen"
  elif command -v matugen >/dev/null 2>&1; then
    MATUGEN_BIN="$(command -v matugen)"
  else
    fail "matugen not found (expected in PATH or ~/.cargo/bin/matugen)"
  fi
fi

if ! pgrep -x swww-daemon >/dev/null 2>&1; then
  swww init >/dev/null 2>&1 || fail "could not start swww"
fi

swww img "$1" --transition-type grow --transition-pos center >/dev/null 2>&1 || fail "swww failed"
"$MATUGEN_BIN" image "$1" --source-color-index 0 >/dev/null 2>&1 || fail "matugen failed"

ESCAPED=$(printf '%s\n' "$1" | sed 's/[&|]/\\&/g')
NEW_TEXT="    background-image:            url(\"$ESCAPED\", height);"
FILE="$HOME/.config/rofi/launchers/type-7/style-7.rasi"

if [[ -f "$FILE" ]]; then
  sed -i -E "s|^[[:space:]]*background-image:.*|${NEW_TEXT}|" "$FILE" >/dev/null 2>&1 || fail "rofi theme update failed"
else
  fail "rofi theme not found"
fi

echo "wallgen: success"
EOF
chmod +x "$HOME/.local/bin/wallgen"
chmod +x "$HOME/.config/rofi/launchers/type-7/launcher.sh"
chmod +x "$HOME/.config/rofi/powermenu.sh"
chmod +x "$HOME/.config/rofi/wallgen-menu.sh"
chmod +x "$HOME/.config/hypr/scripts/battery-mode.sh"

info "Creating wallpaper directory"
mkdir -p "$HOME/Pictures/Wallpapers"

if [[ -d "$WALLPAPER_SRC" ]]; then
  info "Copying bundled wallpapers to ~/Pictures/Wallpapers"
  rsync ${RSYNC_FLAGS} "$WALLPAPER_SRC/" "$HOME/Pictures/Wallpapers/"
fi

if [[ "${ENABLE_BATTERY_TUNING}" == "true" ]]; then
  info "Applying battery optimizations (target user: ${TARGET_USER})"

  sudo dnf ${DNF_INSTALL_FLAGS} install tlp tlp-rdw brightnessctl

  sudo systemctl stop power-profiles-daemon.service 2>/dev/null || true
  sudo systemctl mask power-profiles-daemon.service 2>/dev/null || true
  sudo systemctl disable tuned.service 2>/dev/null || true

  sudo systemctl enable --now tlp.service

  sudo tee /etc/tlp.conf >/dev/null <<'EOF'
TLP_ENABLE=1

# CPU
# Keep governors at distro defaults for broad CPU compatibility.
# CPU_SCALING_GOVERNOR_ON_AC=performance
# CPU_SCALING_GOVERNOR_ON_BAT=powersave

CPU_BOOST_ON_AC=1
CPU_BOOST_ON_BAT=0

CPU_ENERGY_PERF_POLICY_ON_AC=performance
CPU_ENERGY_PERF_POLICY_ON_BAT=power

# Wi-Fi
WIFI_PWR_ON_AC=off
WIFI_PWR_ON_BAT=on

# Audio
SOUND_POWER_SAVE_ON_AC=0
SOUND_POWER_SAVE_ON_BAT=1
SOUND_POWER_SAVE_CONTROLLER=Y

# Platform
PCIE_ASPM_ON_BAT=powersupersave
RUNTIME_PM_ON_BAT=auto
USB_AUTOSUSPEND=1

# Storage
SATA_LINKPWR_ON_AC=med_power
SATA_LINKPWR_ON_BAT=min_power
AHCI_RUNTIME_PM_ON_BAT=auto
EOF

  sudo mkdir -p /etc/NetworkManager/conf.d
  sudo tee /etc/NetworkManager/conf.d/wifi-powersave.conf >/dev/null <<'EOF'
[connection]
wifi.powersave = 3
EOF

  sudo systemctl restart NetworkManager

  if command -v hyprctl >/dev/null 2>&1; then
    sudo tee /usr/local/bin/hypr-refresh.sh >/dev/null <<EOF
#!/usr/bin/env bash

MONITOR="${MONITOR_NAME}"
RESOLUTION="${MONITOR_RESOLUTION}"
BAT_REFRESH="${MONITOR_REFRESH_BAT}"
AC_REFRESH="${MONITOR_REFRESH_AC}"

RUNTIME_DIR="/run/user/$(id -u)"
SIG_DIR=$(ls -1d "$RUNTIME_DIR"/hypr/* 2>/dev/null | head -n1)
if [[ -z "$SIG_DIR" ]]; then
  exit 0
fi
export HYPRLAND_INSTANCE_SIGNATURE="$(basename "$SIG_DIR")"

POWER=\$(for ps in /sys/class/power_supply/*; do
  [[ -f "\$ps/type" ]] || continue
  if grep -qi "mains" "\$ps/type"; then
    cat "\$ps/online" 2>/dev/null
    break
  fi
done)

if [ "\$POWER" = "1" ]; then
  hyprctl keyword monitor "\$MONITOR,\$RESOLUTION@\$AC_REFRESH,0x0,1"
else
  hyprctl keyword monitor "\$MONITOR,\$RESOLUTION@\$BAT_REFRESH,0x0,1"
fi
EOF

    sudo chmod 755 /usr/local/bin/hypr-refresh.sh

    sudo tee /etc/systemd/system/hypr-refresh.service >/dev/null <<EOF
[Unit]
Description=Hyprland Auto Refresh Rate Switch
After=systemd-logind.service

[Service]
Type=oneshot
User=${TARGET_USER}
Environment=XDG_RUNTIME_DIR=/run/user/${TARGET_UID}
Environment=DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${TARGET_UID}/bus
ExecStart=/usr/local/bin/hypr-refresh.sh

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable hypr-refresh.service

    sudo tee /etc/udev/rules.d/90-hypr-refresh.rules >/dev/null <<'EOF'
  SUBSYSTEM=="power_supply", ENV{POWER_SUPPLY_TYPE}=="Mains", ACTION=="change", RUN+="/usr/bin/systemctl restart hypr-refresh.service"
  EOF

    sudo tee /usr/local/bin/battery-bluetooth.sh >/dev/null <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if ! command -v rfkill >/dev/null 2>&1; then
  exit 0
fi

POWER=$(for ps in /sys/class/power_supply/*; do
  [[ -f "$ps/type" ]] || continue
  if grep -qi "mains" "$ps/type"; then
    cat "$ps/online" 2>/dev/null
    break
  fi
done)

if [ "$POWER" = "1" ]; then
  rfkill unblock bluetooth
else
  rfkill block bluetooth
fi
EOF
    sudo chmod 755 /usr/local/bin/battery-bluetooth.sh

    sudo tee /etc/udev/rules.d/91-battery-bluetooth.rules >/dev/null <<'EOF'
SUBSYSTEM=="power_supply", ENV{POWER_SUPPLY_TYPE}=="Mains", ACTION=="change", RUN+="/usr/local/bin/battery-bluetooth.sh"
EOF

    sudo tee /usr/local/bin/battery-mode-auto.sh >/dev/null <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

TARGET_USER="${TARGET_USER:-}"
TARGET_UID="${TARGET_UID:-}"
TARGET_HOME="${TARGET_HOME:-}"

if [[ -z "$TARGET_USER" || -z "$TARGET_UID" || -z "$TARGET_HOME" ]]; then
  exit 0
fi

POWER=$(for ps in /sys/class/power_supply/*; do
  [[ -f "\$ps/type" ]] || continue
  if grep -qi "mains" "\$ps/type"; then
    cat "\$ps/online" 2>/dev/null
    break
  fi
done)

if [ "\$POWER" = "1" ]; then
  runuser -u "$TARGET_USER" -- \
    env XDG_RUNTIME_DIR="/run/user/${TARGET_UID}" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${TARGET_UID}/bus" \
    "$TARGET_HOME/.config/hypr/scripts/battery-mode.sh" off
else
  runuser -u "$TARGET_USER" -- \
    env XDG_RUNTIME_DIR="/run/user/${TARGET_UID}" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${TARGET_UID}/bus" \
    "$TARGET_HOME/.config/hypr/scripts/battery-mode.sh" on
fi
EOF
    sudo chmod 755 /usr/local/bin/battery-mode-auto.sh

    sudo tee /etc/systemd/system/battery-mode.service >/dev/null <<EOF
[Unit]
Description=Battery Mode Toggle
After=systemd-logind.service

[Service]
Type=oneshot
  Environment=TARGET_USER=${TARGET_USER}
  Environment=TARGET_UID=${TARGET_UID}
  Environment=TARGET_HOME=${TARGET_HOME}
ExecStart=/usr/local/bin/battery-mode-auto.sh

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable battery-mode.service

    sudo tee /etc/udev/rules.d/92-battery-mode.rules >/dev/null <<'EOF'
SUBSYSTEM=="power_supply", ENV{POWER_SUPPLY_TYPE}=="Mains", ACTION=="change", RUN+="/usr/bin/systemctl restart battery-mode.service"
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

info "Enabling Bluetooth service"
sudo systemctl enable --now bluetooth.service

info "Done. Log out and pick the Hyprland session."
echo "Set your wallpaper and recolor the desktop with: wallgen ~/Pictures/Wallpapers/your-image.jpg"
