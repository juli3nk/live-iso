# This module defines a small NixOS installation CD.  It does not
# contain any graphical stuff.
{ config, pkgs, ... }:
{
  imports = [
    <nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix>

    # Provide an initial copy of the NixOS channel so that the user
    # doesn't need to run "nix-channel --update" first.
    <nixpkgs/nixos/modules/installer/cd-dvd/channel.nix>
  ];

  isoImage.squashfsCompression = "lz4";

  # packages to support install scripts and dotfile programs
  environment.systemPackages = with pkgs; [
    curl
    git
    gnupg
    htop
    tree
    vim
    wget
  ];

  # tar files are copied to the nix store implicitly!
  # they have built in prefixes.
  systemd.services.populate-home = with pkgs; {
    serviceConfig.Type = "oneshot";
    path = [
      bash
      gnutar
      gnupg
    ];
    script = ''
      cd /root
      tar xf ${./scripts.tar}
      chown -R root:root bin
    '';
    wantedBy = [ "multi-user.target" ];
  };
}
