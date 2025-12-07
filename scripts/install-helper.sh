#!/usr/bin/env bash

set -euo pipefail

#═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION
#═══════════════════════════════════════════════════════════════════════════════

readonly ROOT_SIZE_MINIMUM_GB="50"
readonly VG_NAME="vg0"
readonly LUKS_DEVICE_NAME="cryptroot"

#═══════════════════════════════════════════════════════════════════════════════
# FUNCTIONS
#═══════════════════════════════════════════════════════════════════════════════

show_banner() {
    echo "╔════════════════════════════════════════╗"
    echo "║   NixOS Installation Assistant         ║"
    echo "╚════════════════════════════════════════╝"
    echo ""
    echo "This script will help you install NixOS with:"
    echo "  - UEFI boot"
    echo "  - LUKS encryption"
    echo "  - LVM (Logical Volume Manager)"
    echo "  - Separate swap and root volumes"
    echo "  - ext4 filesystem"
    echo ""
    echo "Usage: $0 [profile]"
    echo "  Profiles:"
    echo "    desktop (default) - Swap >= RAM for hibernation"
    echo "    server            - No swap partition, minimum root size"
    echo ""
}

validate_profile() {
    local profile=$1
    if [ "$profile" != "desktop" ] && [ "$profile" != "server" ]; then
        echo "❌ Invalid profile: $profile"
        echo "   Valid profiles: desktop, server"
        exit 1
    fi
}

confirm_disk_wipe() {
    local disk=$1

    echo ""
    echo "⚠️  WARNING: All data on ${disk} will be ERASED!"
    echo ""
    lsblk "$disk"
    echo ""
    parted "$disk" print
    echo ""
    read -r -p "Continue? (type 'YES'): " confirm

    if [ "$confirm" != "YES" ]; then
        echo "Installation cancelled"
        exit 0
    fi
}

partition_disk() {
    local disk=$1

    echo ""
    echo "=== Partitioning ==="

    # Remove existing partitions if any exist
    if parted "$disk" print >/dev/null 2>&1; then
        echo "Removing existing partitions..."
        # Get partition numbers and delete them in reverse order
        local parts
        parts=$(parted "$disk" print 2>/dev/null | awk '/^[[:space:]]*[0-9]+/ { print $1 }' | sort -rn)
        if [ -n "$parts" ]; then
            for part in $parts; do
                echo "  Deleting partition $part..."
                parted "$disk" -- rm "$part" 2>/dev/null || true
            done
        fi
    fi

    # Create new partition table (mklabel will also clear any existing partitions)
    echo "Creating new GPT partition table..."
    parted "$disk" -- mklabel gpt

    # Create partitions
    echo "Creating partitions..."
    parted "$disk" -- mkpart ESP fat32 1MiB 512MiB
    parted "$disk" -- set 1 esp on
    parted "$disk" -- mkpart primary 512MiB 100%

    # Wait for partition detection
    sleep 2

    echo "Partitions created successfully"
    echo ""
    parted "$disk" print
    echo ""
    read -r -p "Continue? (type 'YES'): " confirm

    if [ "$confirm" != "YES" ]; then
        echo "Installation cancelled"
        exit 0
    fi
}

get_partition_names() {
    local disk=$1

    if [[ "$disk" == *"nvme"* ]] || [[ "$disk" == *"mmcblk"* ]]; then
        echo "${disk}p1 ${disk}p2"
    else
        echo "${disk}1 ${disk}2"
    fi
}

setup_luks() {
    local part2=$1

    echo ""
    echo "=== LUKS Encryption ==="
    echo "Choose a strong passphrase!"
    echo ""
    cryptsetup luksFormat "$part2"
    echo ""
}

get_luks_uuid() {
    local part2=$1

    local luks_uuid
    luks_uuid=$(blkid -s UUID -o value "$part2")
    cryptsetup luksOpen "$part2" "$LUKS_DEVICE_NAME"

    echo "$luks_uuid"
}

setup_lvm() {
    echo ""
    echo "=== LVM Setup ==="

    pvcreate "/dev/mapper/${LUKS_DEVICE_NAME}"

    vgcreate "$VG_NAME" "/dev/mapper/${LUKS_DEVICE_NAME}"
}

get_total_size() {
    vgdisplay "$VG_NAME" --units m | awk '/VG Size/ { print $3 }' | sed 's/\..*//'
}

calculate_swap_size() {
    local profile=$1
    local total_size=$2

    if [ "$profile" != "desktop" ]; then
        echo "0"
        return 0
    fi

    # Get memory size in MB
    local memory_size
    memory_size=$(free -m | awk '/Mem/ { print $2 }')

    # For hibernation, swap must be at least equal to memory size
    # Add 10% overhead for safety
    local swap_size
    swap_size=$((memory_size + (memory_size / 10)))

    local swap_root_size root_size_mb
    root_size_mb=$((ROOT_SIZE_MINIMUM_GB * 1024))
    swap_root_size=$((swap_size + root_size_mb))

    if [ "$swap_root_size" -gt "$total_size" ]; then
        echo "❌ Error: Not enough space for swap ($swap_size MB) and root ($root_size_mb MB)"
        echo "   Required: $swap_root_size MB, Available: $total_size MB"
        exit 1
    fi

    echo "$swap_size"
}

calculate_root_size_server() {
    local total_size=$1
    local root_size_gb=$2

    local root_size_mb
    local root_size remaining_size

    if [ -z "$root_size_gb" ]; then
        root_size_mb=$((ROOT_SIZE_MINIMUM_GB * 1024))
        root_size="${root_size_mb}M"
        remaining_size=$((total_size - root_size_mb))
    elif [ "$root_size_gb" = "max" ]; then
        root_size="100%FREE"
        remaining_size=0
    else
        root_size_mb=$((root_size_gb * 1024))
        if [ "$root_size_mb" -gt "$total_size" ]; then
            echo "⚠️  Warning: Requested size (${root_size_mb}MB) exceeds available space (${total_size}MB)"
            echo "   Using all available space instead"
            exit 1
        else
            root_size="${root_size_mb}M"
            remaining_size=$((total_size - root_size_mb))
        fi
    fi

    echo "$root_size $remaining_size"
}

create_logical_volumes() {
    local profile=$1
    local swap_size=$2
    local root_size=$3
    local remaining_size=$4

    echo ""
    echo "Creating logical volumes:"
    if [ "$swap_size" -gt 0 ]; then
        echo "  - swap: ${swap_size}M"
    fi
    echo "  - root: ${root_size}"
    if [ "$profile" = "server" ] && [ "$remaining_size" -gt 0 ]; then
        echo "  - unallocated: ${remaining_size}M (available for future LVs)"
    fi

    # Create logical volumes
    if [ "$swap_size" -gt 0 ]; then
        lvcreate -L "${swap_size}M" -n swap "$VG_NAME"
    fi
    # Use -l (extents) for percentage-based sizes, -L (size) for absolute sizes
    if [[ "$root_size" == *"%"* ]]; then
        lvcreate -l "$root_size" -n root "$VG_NAME"
    else
        lvcreate -L "$root_size" -n root "$VG_NAME"
    fi
}

format_partitions() {
    local part1=$1
    local swap_size=$2

    echo ""
    echo "=== Formatting ==="
    mkfs.fat -F 32 -n boot "$part1"
    mkfs.ext4 -L nixos "/dev/mapper/${VG_NAME}-root"
    if [ "$swap_size" -gt 0 ]; then
        mkswap -L swap "/dev/mapper/${VG_NAME}-swap"
    fi
}

mount_filesystems() {
    local part1=$1
    local swap_size=$2

    echo ""
    echo "=== Mounting ==="

    if mountpoint -q /mnt 2>/dev/null; then
        echo "❌ Error: /mnt is already mounted"
        exit 1
    fi

    mount "/dev/mapper/${VG_NAME}-root" /mnt
    mkdir -p /mnt/boot
    mount "$part1" /mnt/boot

    if [ "$swap_size" -gt 0 ]; then
        swapon "/dev/mapper/${VG_NAME}-swap"
    fi
}

generate_hardware_config() {
    echo ""
    echo "=== Generating hardware configuration ==="

    mkdir -p /mnt/etc/nixos
    nixos-generate-config \
        --root /mnt \
        --show-hardware-config \
            2>/dev/null \
            > /tmp/hardware-configuration.nix
}

show_next_steps() {
    local profile=$1
    local luks_uuid=$2

    echo ""
    echo "✅ System ready for installation!"
    echo ""
    echo "Next steps:"
    echo "  1. Edit files in /mnt/etc/nixos/"
    echo "  2. Add this for LUKS in configuration.nix:"
    echo ""
    echo "     boot.initrd.luks.devices.cryptroot = {"
    echo "       device = \"/dev/disk/by-uuid/${luks_uuid}\";"
    echo "     };"
    echo ""

    if [ "$profile" = "desktop" ]; then
        echo "  3. For hibernation support, also add:"
        echo ""
        echo "     boot.resumeDevice = \"/dev/mapper/${VG_NAME}-swap\";"
        echo ""
        echo "  4. Run: nixos-install"
        echo "  5. Set root password when prompted"
        echo "  6. Reboot"
    else
        echo "  3. Run: nixos-install"
        echo "  4. Set root password when prompted"
        echo "  5. Reboot"
    fi
    echo ""
}

#═══════════════════════════════════════════════════════════════════════════════
# MAIN
#═══════════════════════════════════════════════════════════════════════════════

main() {
    local profile="${1:-}"

    show_banner

    if [ -z "$profile" ]; then
    read -r -p "Which profile do you want to use? (desktop or server): " profile
    fi
    validate_profile "$profile"

    local disk

    echo "=== Available disks ==="
    lsblk -d -o NAME,SIZE,TYPE | grep disk
    echo ""

    read -r -p "Disk to use (e.g., sda, nvme0n1): " disk_name
    disk="/dev/${disk_name}"

    if [ ! -b "$disk" ]; then
        echo "❌ Disk ${disk} not found"
        exit 1
    fi

    confirm_disk_wipe "$disk"

    partition_disk "$disk"

    local part1 part2
    read -r part1 part2 <<< "$(get_partition_names "$disk")"

    setup_luks "$part2"

    local luks_uuid
    luks_uuid=$(get_luks_uuid "$part2")

    setup_lvm

    echo ""
    echo "=== Sizing ==="

    local total_size
    total_size=$(get_total_size)

    local swap_size
    swap_size=$(calculate_swap_size "$profile" "$total_size")

    echo ""
    echo "=== Root Partition Size ==="
    echo "Available space: ${total_size}MB"
    echo ""

    local root_size_gb
    read -r -p "Root partition size in GB (default: $ROOT_SIZE_MINIMUM_GB, or 'max' for all available): " root_size_gb

    local root_size remaining_size
    if [ "$profile" = "server" ]; then
        read -r root_size remaining_size <<< "$(calculate_root_size_server "$total_size" "$root_size_gb")"
    else
        local root_size_mb=$((total_size - swap_size))
        root_size="${root_size_mb}M"
        remaining_size=0
    fi

    create_logical_volumes "$profile" "$swap_size" "$root_size" "$remaining_size"

    format_partitions "$part1" "$swap_size"

    mount_filesystems "$part1" "$swap_size"

    generate_hardware_config

    show_next_steps "$profile" "$luks_uuid"
}

main "$@"
