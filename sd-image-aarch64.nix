{ config, lib, pkgs, ... }:
# Copied and modified from
# nixpkgs/nixos/modules/installer/cd-dvd/sd-image-aarch64.nix

let
  extlinux-conf-builder =
    import <nixpkgs/nixos/modules/system/boot/loader/generic-extlinux-compatible/extlinux-conf-builder.nix> {
      pkgs = pkgs.buildPackages;
    };
in
{
  imports = [
  ];

  # Needed by RPi firmware
  nixpkgs.config.allowUnfree = true;

  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;

  boot.consoleLogLevel = lib.mkDefault 7;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # The serial ports listed here are:
  # - ttyS0: for Tegra (Jetson TX1)
  # - ttyAMA0: for QEMU's -machine virt
  # Also increase the amount of CMA to ensure the virtual console on the RPi3 works.
  boot.kernelParams = ["cma=32M" "console=ttyS0,115200n8" "console=ttyAMA0,115200n8" "console=tty0"];
  boot.blacklistedKernelModules = [
    "pn533_usb" "pn533" "nfc"
  ];

  users.extraUsers.root.initialPassword = "beans4life";

}
