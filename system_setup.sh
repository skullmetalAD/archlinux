#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "======================================================="
echo " Starting Post-Install Configuration Script"
echo "======================================================="

# ---------------------------------------------------------
# SECTION 1: Pacman System Configuration
# ---------------------------------------------------------
echo "Configuring pacman parallel downloads..."
# Updates the ParallelDownloads limit to 25 for blazing-fast package updates
sudo sed -i 's/^#\s*ParallelDownloads.*/ParallelDownloads = 25/' /etc/pacman.conf
sudo sed -i 's/^ParallelDownloads = .*/ParallelDownloads = 25/' /etc/pacman.conf

# Force system database refresh
sudo pacman -Sy --noconfirm

# ---------------------------------------------------------
# SECTION 2: Official Repo Packages Installation
# ---------------------------------------------------------
echo "Installing official packages..."

PACMAN_PKGS=(
    "plasma-meta"		  # plasma environement
    "alacritty"                   # Blazing fast, GPU-accelerated terminal emulator
    "btop"                        # Sleek, modern interactive system resource monitor
    "fish"                        # Smart, interactive shell featuring autosuggestions out of the box
    "neovim"                      # Highly extensible terminal text editor fork of Vim
    "dolphin"                     # Feature-rich file manager native to KDE Plasma
    "libreoffice-fresh"           # Cutting-edge stable branch of the LibreOffice productivity suite
    "fastfetch"                   # Lightweight system information rendering tool
    "cups"                        # Common Unix Printing System core backend
    "cups-pdf"                    # Virtual print-to-PDF utility extension for CUPS
    "vivaldi"                     # Feature-packed, customizable Chromium-based web browser
    "tealdeer"                    # Ultra-fast rust implementation of simplified 'tldr' manual sheets
    "bat"                         # A cat alternative enhanced with syntax highlighting and Git tracking
    "pacman-contrib"              # Auxiliary utilities for pacman (e.g., managing logs, paccache)
    "ufw"                         # Uncomplicated Firewall frontend interface for iptables/nftables
    "tesseract"                   # Advanced open-source optical character recognition (OCR) engine
    "tesseract-data-por"          # Language training datasets for Portuguese OCR indexing
    "tesseract-data-eng"          # Language training datasets for English OCR indexing
    "kvantum"                     # Scalable SVG-based style sheet engine for Qt interface ricing
    "snapper"                     # Command line snapshot management utility natively matching BTRFS
    "snap-pac"                    # Automation hooks triggering pre/post Snapper snapshots during Pacman actions
    "wl-clipboard"                # Command-line copy/paste utilities for native Wayland environments
    "base-devel"                  # Basic development headers required for building native AUR components
)

sudo pacman -S --needed --noconfirm "${PACMAN_PKGS[@]}"

# ---------------------------------------------------------
# SECTION 3: Bootstrapping AUR & Helpers
# ---------------------------------------------------------
echo "Bootstrapping yay (AUR Helper)..."
if ! command -v yay &> /dev/null; then
    mkdir -p /tmp/yay-build
    git clone https://aur.archlinux.org/yay.git /tmp/yay-build/yay
    cd /tmp/yay-build/yay
    makepkg -si --noconfirm
    cd -
    rm -rf /tmp/yay-build
fi

# ---------------------------------------------------------
# SECTION 4: AUR Package Installation
# ---------------------------------------------------------
echo "Installing packages from the Arch User Repository..."

AUR_PKGS=(
    "sunshine"                                  # Ultra-low latency game streaming host server
    "warsaw-bin"                                # Mandatory security tool demanded by Brazilian banks
    "kwin-karousel"                             # Dynamic tiling window layout management script with scrolling
    "catppuccin-plasma-colorscheme-macchiato"   # Pastel-inspired warm dark desktop theme palette profile
    "catppuccin-plasma-colorscheme-mocha"       # Pastel-inspired deep dark desktop theme palette profile
    "kvantum-theme-catppuccin-git"              # Standard Catppuccin styles matched for the Kvantum engine
    "epson-inkjet-printer-escpr2" # Official driver extension for newer Epson printer profiles
)

yay -S --needed --noconfirm "${AUR_PKGS[@]}"

# ---------------------------------------------------------
# SECTION 5: Core System Modifications (fstab & Shells)
# ---------------------------------------------------------
echo "Modifying /etc/fstab for optimal BTRFS performance..."
# Replaces 'relatime' variables with the high-performance 'noatime' to limit SSD write overheads on BTRFS
sudo sed -i '/btrfs/s/relatime/noatime/g' /etc/fstab

echo "Setting up Fish as default shell environment..."
# Adds fish to legitimate shells list and binds it to both target accounts
if ! grep -q "/usr/bin/fish" /etc/shells; then
    echo "/usr/bin/fish" | sudo tee -a /etc/shells
fi
chsh -s /usr/bin/fish
sudo chsh -s /usr/bin/fish

echo "Activating Core System Daemons (UFW & CUPS)..."
sudo systemctl enable --now ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw enable

sudo systemctl enable --now cups
sudo systemctl enable --now plasmalogin

# ---------------------------------------------------------
# SECTION 6: Snapper Initialization
# ---------------------------------------------------------
echo "Setting up Snapper configs for user execution..."
if [ ! -f /etc/snapper/configs/root ]; then
    sudo snapper -c root create-config /
fi
# Grants user root-less viewing rights over local snapshot timelines
sudo chmod a+rx /.snapshots
sudo chown :wheel /.snapshots

# ---------------------------------------------------------
# SECTION 7: KDE Plasma Customizations
# ---------------------------------------------------------
echo "Applying explicit Plasma configuration defaults..."

# Define Alacritty as default shell terminal environment handler inside Plasma
kwriteconfig6 --file kdeglobals --group General --key TerminalApplication "alacritty"
kwriteconfig6 --file kdeglobals --group General --key TerminalService "Alacritty.desktop"

# Set Color Scheme profile to Catppuccin Mocha Blue
kwriteconfig6 --file kdeglobals --group General --key ColorScheme "CatppuccinMochaBlue"

# Direct Qt apps to look at the Kvantum theme framework engine
kwriteconfig6 --file kdeglobals --group General --key widgetStyle "kvantum-dark"

# Point cursor profile targeting WhiteSur Cursors
kwriteconfig6 --file kcminputrc --group Mouse --key cursorTheme "WhiteSur Cursors"

echo "======================================================="
echo " System Configured! Please reboot to finalize details."
echo "======================================================="