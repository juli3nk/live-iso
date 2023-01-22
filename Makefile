
.PHONY: build
build:
	tar -cf scripts.tar bin/
	nix-build '<nixpkgs/nixos>' -A config.system.build.isoImage -I nixos-config=iso.nix

.PHONY: run
run:
	qemu-system-x86_64 -enable-kvm -m 256 -cdrom result/iso/nixos-*.iso

.PHONY: usb
usb:
	@echo "sudo dd if=nixos-*.iso of=/dev/sdb bs=1024k status=progress"
