{
  description = "Generic ISO toolkit";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";

    nixos-modules = {
      url = "tarball+https://github.com/juli3nk/nixos-modules/archive/refs/heads/main.tar.gz";
      flake = true;
    };
  };

  outputs = { self, nixpkgs, nixos-modules, ... } @ inputs:
  {
    nixosConfigurations = {
      toolkit = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        specialArgs = {
          inherit inputs nixos-modules;
        };

        modules = [
            "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
            ./isos/toolkit
        ];
      };
    };
  };
}
