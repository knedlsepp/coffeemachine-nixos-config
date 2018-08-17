{ config, pkgs, lib, ... }:
{
  nixpkgs.config.packageOverrides = super: let self = super.pkgs; in {
  };

  security.polkit.enable = true;
  services.udisks2.enable = false;

  programs.command-not-found.enable = false;

  programs.vim.defaultEditor = true;

  system.boot.loader.kernelFile = lib.mkForce "Image";

  # installation-device.nix forces this on. But it currently won't
  # cross build due to w3m
  services.nixosManual.enable = lib.mkOverride 0 false;

  services.sshd.enable = true;

  nix.checkConfig = false;
  networking.wireless.enable = true;

  hardware.enableRedistributableFirmware = true;
  hardware.firmware = [
    (pkgs.stdenv.mkDerivation {
     name = "broadcom-rpi3-extra";
     src = pkgs.fetchurl {
     url = "https://raw.githubusercontent.com/RPi-Distro/firmware-nonfree/54bab3d/brcm80211/brcm/brcmfmac43430-sdio.txt";
     sha256 = "19bmdd7w0xzybfassn7x4rb30l70vynnw3c80nlapna2k57xwbw7";
     };
     phases = [ "installPhase" ];
     installPhase = ''
     mkdir -p $out/lib/firmware/brcm
     cp $src $out/lib/firmware/brcm/brcmfmac43430-sdio.txt
     '';
     })
  ];

  imports = [
    ./sd-image-aarch64.nix
    ./hardware-configuration.nix
  ];

  environment.systemPackages = with pkgs; [
    vim
    gitMinimal
    htop
  ];

  swapDevices = [
    { device = "/var/swapfile"; size = 1024; }
  ];

  services.hostapd = {
    enable = true;
    ssid = "coffeemachine";
    wpa = false;
  };


  system.stateVersion = "18.03";
}
