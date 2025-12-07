# NixOS Toolkit ISO

Multi-purpose bootable ISO for NixOS installation and Yubikey management.

https://nixos.wiki/wiki/Creating_a_NixOS_live_CD

## Features

- ✅ NixOS installation assistant with LUKS encryption
- ✅ Complete Yubikey configuration suite
- ✅ Hardware diagnostic tools
- ✅ Network configuration utilities
- ✅ Interactive menu system

## Build

## Build

```bash
# Enable flakes
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf

# Build ISO
nix build .#nixosConfigurations.toolkit-iso.config.system.build.isoImage

# Flash to USB
sudo dd if=result/iso/*.iso of=/dev/sdX bs=4M status=progress conv=fsync
```

## Usage

Boot from USB
Login: nixos / nixos
Run toolkit-menu (auto-starts)
Follow interactive menus

Available Commands

toolkit-menu - Main interactive menu
nixos-install-helper - Guided NixOS installation
yubikey-setup - Configure Yubikey (FIDO2/PIV/OTP)
ykman info - Display Yubikey information
pcsc_scan - Test smartcard reader

Scripts
All scripts use writeShellApplication with:

✅ Automatic shellcheck validation
✅ Explicit runtime dependencies
✅ Error handling (set -euo pipefail)

## License

MIT

## Build & usage

```bash
# 1. Create project
mkdir nixos-toolkit && cd nixos-toolkit
mkdir scripts

# 2. Copy files
# - flake.nix
# - scripts/menu.sh
# - scripts/yubikey-setup.sh
# - scripts/install-helper.sh
# - README.md

# 3. Make scripts executable (optional, writeShellApplication handles this)
chmod +x scripts/*.sh

# 4. Build
nix build .#nixosConfigurations.toolkit-iso.config.system.build.isoImage

# 5. Flash
sudo dd if=result/iso/*.iso of=/dev/sdX bs=4M status=progress conv=fsync
```
