{ lib, pkgs, nixos-modules, ... }:

{
  imports = [
    ./scripts.nix

    nixos-modules.nixosModules.core.locale
    nixos-modules.nixosModules.core.nix
    nixos-modules.nixosModules.features.security.sudo-nopasswd
    nixos-modules.nixosModules.features.security.yubikey
    nixos-modules.nixosModules.features.security.gpg
    nixos-modules.nixosModules.features.system.filesystem
    nixos-modules.nixosModules.features.system.iso-builder
    nixos-modules.nixosModules.services.openssh.server
    nixos-modules.nixosModules.features.console
    nixos-modules.nixosModules.features.networking
    nixos-modules.nixosModules.features.packages.all
  ];

  myModules.nixos.features.system.iso-builder = {
    enable = true;
    profile = "balanced";
    customName = "nixos-toolkit";
    volumeID = "NIXOS_TOOLKIT";
  };

  # Support firmware (WiFi, etc.)
  hardware.enableRedistributableFirmware = true;

  # ==========================================
  # BOOT & SYSTEM
  # ==========================================

  # Message de boot personnalisé
  boot.kernelParams = [
    "quiet"
    "splash"
    "vt.global_cursor_default=0"  # Cache le curseur clignotant
  ];

  # Optimisation pour ISO live
  # boot.initrd.systemd.enable = true;

  # Compression memoire
  zramSwap.enable = true;

  myModules.nixos.features.system.filesystemSupport.enable = true;

  # ==========================================
  # LOCALE & CONSOLE
  # ==========================================

  # Timezone
  time.timeZone = "UTC";

  # Console keyboard layout
  myModules.nixos.features.console = {
    enable = true;
    profile = "standard";
  };

  # ==========================================
  # NETWORK
  # ==========================================

  networking.hostName = "nixos-toolkit";

  myModules.nixos.features.networking = {
    backend = "networkmanager";
    wifi = {
      enable = true;
      useIwd = true;
    };
    dns = {
      mode = "dhcp";
    };
  };

  # ==========================================
  # USER
  # ==========================================

  users.users.nixos = {
    isNormalUser = true;
    password = "nixos";
    initialHashedPassword = lib.mkForce null;
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
    ];
    shell = pkgs.bash;
    description = "ISO User";
  };

  services.getty.autologinUser = "nixos";

  # ==========================================
  # SERVICES
  # ==========================================

  # SSH
  myModules.nixos.services.openssh.server = {
    enable = true;
    passwordAuthentication = true;
    rootLogin = "no";
  };

  # Smartcard/Yubikey
  myModules.nixos.features.security.yubikey.enable = true;

  # GPG
  myModules.nixos.features.security.gpg = {
    enable = true;
    enableSmartCard = true;
    pinentryFlavor = "curses";
  };

  # Désactiver services inutiles sur ISO
  systemd.services = {
    # Accélère le boot
    NetworkManager-wait-online.enable = false;
  };

  # ==========================================
  # LOGIN
  # ==========================================

  # Launch menu at login
  environment.loginShellInit = ''
    if [ "$(tty)" = "/dev/tty1" ]; then
      toolkit-menu
    fi
  '';

  # Welcome message
  users.motd = ''

    ╔════════════════════════════════════════════════╗
    ║                                                ║
    ║       NixOS Toolkit - Multi-purpose ISO        ║
    ║                                                ║
    ╚════════════════════════════════════════════════╝

    📦 Available commands:
        • toolkit-menu          - Main menu
        • nixos-install-helper  - Installation assistant
        • yubikey-setup         - Configure Yubikey
        • gpg-keygen            - Generate GPG keys
        • wifi-connect          - Connect to WiFi
        • ykman info            - Yubikey information

    🔐 Login: nixos / nixos

  '';

  # ==========================================
  # ENVIRONMENT VARIABLES
  # ==========================================

  environment.variables = {
    EDITOR = "vim";
    VISUAL = "vim";
    PAGER = "less";
    LESS = "-R";    # Couleurs dans less
  };

  # ==========================================
  # BASE PACKAGES
  # ==========================================

  myModules.nixos.features.packages = {
    systemInfo.enable = true;

    hardware.enable = true;
    hardware.includeStorage = true;

    shell.enable = true;

    utilities.enable = true;
    utilities.modernAlternatives = true;
    utilities.includeContainers = true;

    monitoring.enable = true;
    monitoring.level = "full";

    networking.enable = true;
    networking.includeDownloaders = true;
    networking.includeDiagnostics = true;
    networking.includeMonitoring = true;

    textProcessing.enable = true;
    textProcessing.modernTools = true;

    compression.enable = true;
    editors.vim.enable = true;
    editors.neovim.enable = true;

    development.enable = true;
    development.includeGitExtras = true;

    nixTools.enable = true;
  };
}
