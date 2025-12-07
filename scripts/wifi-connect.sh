#!/usr/bin/env bash

SSID="$1"

# Check if SSID argument is provided
if [ -z "$SSID" ]; then
    nmcli device wifi list

    read -r -p "Enter SSID: " SSID
    if [ -z "$SSID" ]; then
        echo "Error: No SSID provided."
        exit 1
    fi
fi

# Connect to Wi-Fi using nmcli
if ! nmcli --ask device wifi connect "$SSID"; then
    echo "Error: Failed to connect to Wi-Fi network '$SSID'."
    exit 1
fi
