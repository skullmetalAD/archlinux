#!/usr/bin/env bash

# =============================================================================
# Arch Linux Post-Installation Setup Script
# =============================================================================
# Target  : Arch Linux
# Usage   : Run as your regular user
# Version : 1.0
# =============================================================================

set -euo pipefail

# -- Output helpers -----------------------------------------------------------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

section() {
    echo -e "\n${BLUE}${BOLD}══════════════════════════════════════════════${NC}"
    echo -e "${BLUE}${BOLD}  $1${NC}"
    echo -e "${BLUE}${BOLD}══════════════════════════════════════════════${NC}\n"
}
ok()   { echo -e "${GREEN}  ✓  $1${NC}"; }
warn() { echo -e "${YELLOW}  ⚠  $1${NC}"; }
info() { echo -e "${CYAN}  →  $1${NC}"; }
fail() { echo -e "${RED}  ✗  $1${NC}"; }

# =============================================================================
# PRE-FLIGHT CHECKS
# =============================================================================
section "Pre-flight Checks"

# Must not be run as root
if [[ "$EUID" -eq 0 ]]; then
    fail "Do not run this script as root. Run as your regular user."
    exit 1
fi

# Must be Arch Linux
if [[ ! -f /etc/arch-release ]]; then
    fail "This script is intended for Arch Linux only."
    exit 1
fi

USERNAME=$(whoami)
ok "Running setup for user: ${BOLD}$USERNAME${NC}"

# =============================================================================
# SECTION 1: PACMAN CONFIGURATION
# =============================================================================
section "Section 1 — Pacman Configuration"

info "Setting parallel downloads to 25..."
# Handles both commented (#ParallelDownloads) and uncommented versions
sudo sed -i 's/^#*\s*ParallelDownloads\s*=.*/ParallelDownloads = 25/' /etc/pacman.conf
ok "Parallel downloads set to 25"

# Refresh package databases with new settings
info "Refreshing package databases..."
sudo pacman -Sy --noconfirm
ok "Package databases refreshed"

# =============================================================================
# SECTION 2: FSTAB — SWITCH TO noatime FOR BTRFS VOLUMES
# =============================================================================
section "Section 2 — fstab: relatime → noatime"

info "Creating backup at /etc/fstab.bak..."
sudo cp /etc/fstab /etc/fstab.bak

info "Replacing relatime with noatime on btrfs entries..."
sudo sed -i '/btrfs/s/\brelatime\b/noatime/g' /etc/fstab
ok "fstab updated"

info "Verifying fstab syntax..."
if sudo findmnt --verify --tab-file /etc/fstab; then
    ok "fstab syntax is valid"
else
    warn "findmnt reported issues — please review /etc/fstab before rebooting"
fi

# =============================================================================
# SECTION 3: BASE BUILD TOOLS & YAY (AUR HELPER)
# =============================================================================
section "Section 3 — Base Build Tools & Yay"

info "Installing base-devel, git, wget, curl..."
sudo pacman -S --needed --noconfirm base-devel git wget curl
ok "Base build tools installed"

if command -v yay &>/dev/null; then
    ok "yay is already installed — skipping"
else
    info "Cloning and installing yay from AUR..."
    rm -rf /tmp/yay-bin
    git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin
    cd /tmp/yay-bin
    makepkg -si --noconfirm
    cd ~
    rm -rf /tmp/yay-bin
    ok "yay installed"
fi

# =============================================================================
# SECTION 4: OFFICIAL REPOSITORY PACKAGES
# =============================================================================
section "Section 4 — Official Repository Packages"

OFFICIAL_PACKAGES=(

    # -- Desktop Environment --
    plasma-meta 		        # plasma environement

    # -- Terminal & Shell --
    alacritty                   # GPU-accelerated terminal emulator (OpenGL)
    fish                        # Friendly Interactive Shell — user-friendly CLI

    # -- Text Editor --
    neovim                      # Modern, extensible Vim-based text editor

    # -- System Monitoring --
    btop                        # Interactive resource monitor (CPU/RAM/disk/net)
    fastfetch                   # Fast system information display (neofetch alternative)

    # -- File Management --
    dolphin                     # KDE default graphical file manager

    # -- Browser --
    vivaldi                     # Chromium-based browser with heavy UI customisation

    # -- Office Suite --
    libreoffice-still           # LibreOffice LTS/stable branch (recommended for reliability)

    # -- Printing --
    cups                        # Common Unix Printing System — printing daemon
    cups-pdf                    # Virtual PDF printer backend for CUPS

    # -- Fonts --
    ttf-jetbrains-mono-nerd     # JetBrains Mono patched with Nerd Font icon glyphs

    # -- CLI Utilities --
    tealdeer                    # Fast tldr client — simplified, community-sourced man pages
    bat                         # Drop-in cat replacement with syntax highlighting and git diff
    p7zip                       # 7-Zip support — required by Ark to handle .7z archives
    pacman-contrib              # Extra pacman tools: paccache, rankmirrors, checkupdates

    # -- Security / Firewall --
    ufw                         # Uncomplicated Firewall — simplified iptables frontend

    # -- OCR Engine --
    tesseract                   # Open-source OCR engine
    tesseract-data-por          # Tesseract language data — Portuguese
    tesseract-data-eng          # Tesseract language data — English

    # -- BTRFS Snapshot Toolchain --
    snapper                      # BTRFS snapshot manager — create/list/delete snapshots
    #grub-btrfs                  # Adds BTRFS snapshots as bootable GRUB entries (recovery)

)

info "Installing ${#OFFICIAL_PACKAGES[@]} official packages..."
sudo pacman -S --needed --noconfirm "${OFFICIAL_PACKAGES[@]}"
ok "Official packages installed"

# =============================================================================
# SECTION 5: AUR PACKAGES
# =============================================================================
section "Section 5 — AUR Packages"

AUR_PACKAGES=(

    # -- Game / Desktop Streaming --
    #sunshine                                # Self-hosted game streaming server (Moonlight-compatible)

    # -- Banking Security Module --
    warsaw-bin                              # Warsaw security plugin (required by Brazilian banking apps)

    # -- Printer Driver --
    epson-inkjet-printer-escpr2             # Epson inkjet driver — ESC/P-R 2 protocol

    # -- KWin Scripts --
    kwin-karousel                           # KWin script: carousel-style window switcher/taskbar

    # -- BTRFS Snapshot Toolchain --
    limine-mkinitcpio-hook                  # Install kernels for the Limine bootloader
    limine-snapper-sync                     # Integrates Limine boot entries with Snapper snapshots.

    # -- System utils --
    qdirstat-bin                            # Qt-based directory statistics
    
)

info "Installing ${#AUR_PACKAGES[@]} AUR packages via yay..."
yay -S --needed --noconfirm "${AUR_PACKAGES[@]}"
ok "AUR packages installed"

# =============================================================================
# SECTION 6: FISH AS DEFAULT SHELL (USER & ROOT)
# =============================================================================
section "Section 6 — Fish as Default Shell"

FISH_PATH="$(command -v fish)"

# Register fish in /etc/shells (required for chsh)
if ! grep -qF "$FISH_PATH" /etc/shells; then
    echo "$FISH_PATH" | sudo tee -a /etc/shells > /dev/null
    ok "Fish registered in /etc/shells"
else
    ok "Fish already in /etc/shells"
fi

# Set for current user
chsh -s "$FISH_PATH" "$USERNAME"
ok "Default shell set to fish for: $USERNAME"

# Set for root
sudo chsh -s "$FISH_PATH" root
ok "Default shell set to fish for: root"

#info "Setting Fish to use VI keybindings"
#fish_vi_key_bindings
#ok "VI keybindings set"


# =============================================================================
# SECTION 7: ALACRITTY AS DEFAULT KDE TERMINAL
# =============================================================================
section "Section 7 — Alacritty as Default KDE Terminal"

# KDE global terminal (used by Run Command, keyboard shortcuts, etc.)
kwriteconfig6 --file kdeglobals --group General \
    --key TerminalApplication "alacritty"
kwriteconfig6 --file kdeglobals --group General \
    --key TerminalService "Alacritty.desktop"

# KIO setting — controls "Open Terminal Here" in Dolphin
kwriteconfig6 --file kiorc --group "Favorite Services" \
    --key "TerminalApplication" "alacritty"

ok "Alacritty set as default terminal in KDE"

# =============================================================================
# SECTION 8: ENABLE SYSTEM SERVICES
# =============================================================================
section "Section 8 — System Services"

# -- CUPS: printing daemon ----------------------------------------------------
sudo systemctl enable --now cups.service
ok "CUPS service enabled and started"

# -- UFW: firewall ------------------------------------------------------------
sudo systemctl enable --now ufw.service
sudo ufw --force enable
sudo ufw default deny incoming
sudo ufw default allow outgoing
ok "UFW enabled — default: deny incoming / allow outgoing"

# -- grub-btrfsd: watches for new snapshots and updates GRUB entries ----------
#sudo systemctl enable grub-btrfsd.service
#ok "grub-btrfsd service enabled (starts on next boot)"

# -- limine-snapper: watches for new snapshots and updates Limine entries ----------
sudo systemctl enable --now limine-snapper-sync.service
#ok "limine-snapper service enabled"

# -- Plasma Login Manager -----------------------------------------------------
sudo systemctl enable plasmalogin
ok "plasmalogin enabled (starts on next boot)"

# -- Pacman Cache Timer -----------------------------------------------------
sudo systemctl enable --now paccache.timer
ok "paccache.timer enabled"

# =============================================================================
# SECTION 9: SNAPPER CONFIGURATION
# =============================================================================
section "Section 9 — Snapper (BTRFS Snapshots)"

# Create root config — fails silently if it already exists
if sudo snapper -c root create-config / 2>/dev/null; then
    ok "Snapper root config created"
else
    warn "Snapper root config may already exist — skipping creation"
fi

# Enable automatic snapshot creation and cleanup timers
sudo systemctl enable --now snapper-timeline.timer
sudo systemctl enable --now snapper-cleanup.timer
ok "Snapper timeline and cleanup timers enabled"


# =============================================================================
# SECTION 10: TEALDEER — REFRESH CACHE
# =============================================================================
section "Section 10 — Tealdeer Cache"

tldr --update \
    && ok "tealdeer cache updated" \
    || warn "tealdeer update failed — run 'tldr --update' manually when online"


# =============================================================================
# SECTION 11: SNAP-PAC — INSTALLATION
# =============================================================================
section "Section 11 — Snap-Pac"


info "Installing Snap-Pac..."
# Pacman hook: auto-creates snapshots before/after package ops
# Install after everything so it won't create snapshots during the setup proc.
sudo pacman -S --needed --noconfirm snap-pac
ok "Snap-Pac installed"        


ok "Script finished for user: ${BOLD}$USERNAME${NC}. System will reboot"

sleep 20s

sudo reboot now