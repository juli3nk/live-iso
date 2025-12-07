#!/usr/bin/env bash
# List USB storage devices

set -euo pipefail

echo "╔════════════════════════════════════════╗"
echo "║   USB Storage Devices                  ║"
echo "╚════════════════════════════════════════╝"
echo ""

echo "--- Block Devices (lsblk) ---"
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE,LABEL,UUID | grep -E "^(NAME|sd|nvme)" || true
echo ""

echo "--- USB Devices (lsusb) ---"
lsusb
echo ""

echo "--- Disk Information (fdisk) ---"
if command -v fdisk &> /dev/null; then
    sudo fdisk -l 2>/dev/null | grep -E "^Disk /dev/(sd|nvme)" || true
fi
echo ""

echo "💡 Tip: Look for devices like /dev/sdb, /dev/sdc, etc."
echo "   Make sure to identify the correct device before using 'make usb device=/dev/sdX'"
