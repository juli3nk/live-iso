{ pkgs, ... }:

{
    environment.systemPackages = with pkgs; [
        # Main menu
        (writeShellApplication {
            name = "toolkit-menu";
            runtimeInputs = [
                coreutils        # read (built-in bash mais besoin de coreutils pour autres)
                yubikey-manager  # ykman
                pcsctools        # pcsc_scan
                util-linux       # lscpu, lsblk
                procps           # free
                usbutils         # lsusb
                iproute2         # ip
            ];
            text = builtins.readFile ../../scripts/menu.sh;
        })

        # WiFi connection helper
        (writeShellApplication {
            name = "wifi-connect";
            runtimeInputs = [
                
            ];
            text = builtins.readFile ../../scripts/wifi-connect.sh;
        })

        # NixOS installation helper
        (writeShellApplication {
            name = "nixos-install-helper";
            runtimeInputs = [
                coreutils
                procps           # free
                gnused
                gawk             # awk
                util-linux       # lsblk, blkid, mount, mountpoint
                parted           # parted
                cryptsetup       # cryptsetup
                lvm2             # pvcreate, vgcreate
                dosfstools       # mkfs.fat
                e2fsprogs        # mkfs.ext4
            ];
            text = builtins.readFile ../../scripts/install-helper.sh;
        })

        # Yubikey setup
        (writeShellApplication {
            name = "yubikey-setup";
            runtimeInputs = [
                yubikey-manager  # ykman
                gnupg            # Si manipulation GPG
                pcsctools        # Si tests de carte
            ];
            text = builtins.readFile ../../scripts/yubikey-setup.sh;
        })

        # GPG key generation
        (writeShellApplication {
            name = "gpg-keygen";
            runtimeInputs = [
                coreutils        # stty
                gnupg            # gpg
            ];
            text = builtins.readFile ../../scripts/gpg-keygen.sh;
        })
    ];
}
