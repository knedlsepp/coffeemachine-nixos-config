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

  services.openssh = { enable = true; permitRootLogin = "yes"; };

  nix.checkConfig = false;

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

  services.hostapd = {
    enable = true;
    ssid = "coffeemachine";
    interface = "wlan0";
    wpa = false;
  };


  networking.enableIPv6 = false;
  networking.interfaces = {
    wlan0 = {
      ipv4.addresses = [ { address = "10.0.3.1"; prefixLength = 24; } ];
    };
    eth0 = {
      useDHCP = true;
    };
  };

  services.resolved.enable = false;
  services.dnsmasq = {
    enable = true;
    alwaysKeepRunning = false;
    resolveLocalQueries = false; # Otherwise config messes with: dnsmasq-resolv.conf
    extraConfig = ''
        ###
        no-resolv
        #### DHCP - config
        interface=wlan0
        listen-address=10.0.3.1,127.0.0.1
        dhcp-range=10.0.3.16,10.0.3.254,24h
        dhcp-host=b4:9d:0b:78:2e:2f,10.0.3.17
   #     #### DNS - config
   #     address=/#/127.0.0.1 # forward everything to localhost
    '';
  };

  services.nginx = {
    enable = true;
  };

  networking.firewall.enable = false;
  networking.firewall.allowedTCPPorts = [
    22 # SSH
    53 # DNS
    67 68 # DHCP
    80 443 # HTTP/S
  ];

  system.stateVersion = "18.03";
}
