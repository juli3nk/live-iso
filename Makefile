.DEFAULT_GOAL := help

# Get the latest ISO file (most recent by modification time)
ISO_FILE := $(shell ls -t result/iso/*.iso 2>/dev/null | head -1)

.PHONY: help
help:
	@echo "NixOS Toolkit ISO - Build & Management"
	@echo ""
	@echo "Build:"
	@echo "  build                - Build the NixOS ISO image"
	@echo "  iso-name             - Show the latest ISO filename"
	@echo ""
	@echo "Testing:"
	@echo "  test                 - Test the ISO by mounting it"
	@echo "  run                  - Run the ISO in QEMU"
	@echo ""
	@echo "USB:"
	@echo "  list-usb             - List connected USB storage devices"
	@echo "  usb                  - Flash ISO to USB device (device=/dev/sdX)"
	@echo ""
	@echo "Examples:"
	@echo "  make build"
	@echo "  make iso-name"
	@echo "  make test"
	@echo "  make run"
	@echo "  make list-usb"
	@echo "  make usb device=/dev/sdb"

.PHONY: build
build:
	@nix flake update
	@nix build .#nixosConfigurations.toolkit.config.system.build.isoImage

.PHONY: iso-name
iso-name:
	@if [ -z "$(ISO_FILE)" ]; then \
		echo "No ISO file found in result/iso/"; \
		echo "Run 'make build' first"; \
		exit 1; \
	fi
	@echo "$(ISO_FILE)"

.PHONY: test
test:
	@if [ -z "$(ISO_FILE)" ]; then \
		echo "Error: No ISO file found. Run 'make build' first"; \
		exit 1; \
	fi
	@mkdir -p mnt
	@sudo mount -o loop "$(ISO_FILE)" mnt
	@ls mnt
	@umount mnt
	@rmdir mnt

.PHONY: run
run:
	@if [ -z "$(ISO_FILE)" ]; then \
		echo "Error: No ISO file found. Run 'make build' first"; \
		exit 1; \
	fi
	@qemu-system-x86_64 -enable-kvm -m 2048 -cdrom "$(ISO_FILE)"

.PHONY: list-usb
list-usb:
	@./scripts/list-usb.sh

.PHONY: usb
usb:
	@if [ -z "$(device)" ]; then \
        echo "Error: device parameter is required"; \
        echo "Usage: make usb device=/dev/sdb"; \
        exit 1; \
    fi
	@if [ -z "$(ISO_FILE)" ]; then \
		echo "Error: No ISO file found. Run 'make build' first"; \
		exit 1; \
	fi
	@if [ ! -b "$(device)" ]; then \
		echo "Error: $(device) is not a block device"; \
		exit 1; \
	fi
	@if findmnt "$(device)" >/dev/null 2>&1 || findmnt -D "$(device)" >/dev/null 2>&1; then \
		echo "Error: $(device) or one of its partitions is currently mounted"; \
		echo "Please unmount it first using: sudo umount $(device)*"; \
		echo "Or check mounted partitions with: findmnt | grep $(device)"; \
		exit 1; \
	fi
	@for part in $(device)[0-9]*; do \
		if [ -b "$$part" ] && findmnt "$$part" >/dev/null 2>&1; then \
			echo "Error: Partition $$part is currently mounted"; \
			echo "Please unmount it first using: sudo umount $$part"; \
			exit 1; \
		fi; \
	done
	@echo "Flashing $(ISO_FILE) to $(device)..."
	@sudo dd if="$(ISO_FILE)" of=$(device) bs=4M status=progress conv=fsync
