#!/usr/bin/env bash

while true; do
    clear
    echo "╔════════════════════════════════════════╗"
    echo "║   NixOS Toolkit - Main Menu            ║"
    echo "╚════════════════════════════════════════╝"
    echo ""
    echo "1) Install NixOS"
    echo "2) Configure Yubikey"
    echo "3) Test Yubikey"
    echo "4) Hardware info"
    echo "5) Network configuration"
    echo "6) Open shell"
    echo "0) Exit"
    echo ""
    read -r -p "Choice: " choice

    case $choice in
    1)
        echo ""
        echo "=== NixOS Installation Assistant ==="
        echo ""
        nixos-install-helper
        read -r -p "Press Enter to continue..."
        ;;
    2)
        echo ""
        echo "=== Yubikey Configuration ==="
        echo ""
        yubikey-setup
        read -r -p "Press Enter to continue..."
        ;;
    3)
        echo ""
        echo "=== Yubikey Test ==="
        echo ""
        echo "--- Yubikey Info ---"
        ykman info || echo "⚠️  No Yubikey detected"
        echo ""
        echo "--- PCSC Scan (Ctrl+C to stop) ---"
        timeout 5 pcsc_scan || true
        read -r -p "Press Enter to continue..."
        ;;
    4)
        echo ""
        echo "=== Hardware Information ==="
        echo ""
        echo "--- CPU ---"
        lscpu | head -n 20
        echo ""
        echo "--- Memory ---"
        free -h
        echo ""
        echo "--- Disks ---"
        lsblk
        echo ""
        echo "--- USB Devices ---"
        lsusb
        read -r -p "Press Enter to continue..."
        ;;
    5)
        echo ""
        echo "=== Network Configuration ==="
        echo ""
        echo "--- Interfaces ---"
        ip addr
        echo ""
        echo "--- Routes ---"
        ip route
        echo ""
        echo "--- DNS ---"
        cat /etc/resolv.conf
        echo ""
        read -r -p "Press Enter to continue..."
        ;;
    6)
        echo ""
        echo "Launching shell... (type 'exit' to return to menu)"
        bash
        ;;
    0)
        echo "Goodbye!"
        exit 0
        ;;
    *)
        echo "Invalid choice"
        sleep 1
        ;;
    esac
done
