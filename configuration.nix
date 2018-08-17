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
    lsof
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
      ipv4.addresses = [ { address = "10.0.0.1"; prefixLength = 24; } ];
    };
    eth0 = {
      useDHCP = true;
    };
  };
  networking.hosts = {
    "127.0.0.1" = [ "coffeemachine.localnet" ];
    "10.0.0.1" = [ "coffeemachine.localnet" ];
  };

  services.resolved.enable = false;
  services.dnsmasq = {
    enable = true;
    alwaysKeepRunning = false;
    resolveLocalQueries = false; # Otherwise config messes with: dnsmasq-resolv.conf
    extraConfig = ''
        #### DHCP - config
        bogus-priv
        server=/localnet/10.0.0.1
        local=/localnet/
        address=/#/10.0.0.1
        interface=wlan0
        domain=localnet
        listen-address=10.0.0.1,127.0.0.1
        # Specify the range of IP addresses the DHCP server will lease out to devices, and the duration of the lease
        dhcp-range=10.0.0.16,10.0.0.254,24h
        # Specify the default route
        dhcp-option=3,10.0.0.1
        # Specify the DNS server address
        dhcp-option=6,10.0.0.1
        # Set the DHCP server to authoritative mode.
        dhcp-authoritative
    '';
  };

  services.nginx = {
    enable = true;
    virtualHosts."www.coffeemachine.com" = {
     locations."/".tryFiles = "$uri $uri/ @to_home";
     locations."@to_home".extraConfig = ''
	return 301 /$is_args$args;
     '';
      root = builtins.fetchGit {
        url = "https://github.com/knedlsepp/knedlsepp.at-landing-page.git";
        rev = "6bb09bcca1bd39344d4e568c70b2ad31fd29f1bf";
      };
    };
    virtualHosts."coffeemachine.all" = {
      globalRedirect = "www.coffeemachine.com";
    };

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
