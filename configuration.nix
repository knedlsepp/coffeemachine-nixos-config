{ config, pkgs, lib, ... }:
{

  nixpkgs.overlays = [
    (self: super: with self; {

      python27 = super.python27.override pythonOverrides;
      python27Packages = super.recurseIntoAttrs (python27.pkgs);
      python36 = super.python36.override pythonOverrides;
      python36Packages = super.recurseIntoAttrs (python36.pkgs);
      python = python27;
      pythonPackages = python27Packages;

      pythonOverrides = {
        packageOverrides = python-self: python-super: {
          flask-helloworld = python-super.pythonPackages.buildPythonPackage rec {
            name = "flask-hello-world-${version}";
            version = "0.1.0";
            src = fetchgit {
              url = "https://github.com/knedlsepp/flask-hello-world.git";
              rev = "dff5896234ce2bd7afa66134206f3403f2d94e38";
              sha256 = "0g350ikvnz1kzyb31z6363nvjgyfj5f75a2c1p008s18sv0blqr3";
            };
            propagatedBuildInputs = with pythonPackages; [
              flask
            ];
          };
        };
      };
    })
  ];
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
     locations."@to_home".extraConfig = ''
       return 301 /$is_args$args;
     '';
      root = builtins.fetchGit {
        url = "https://github.com/knedlsepp/knedlsepp.at-landing-page.git";
        rev = "6bb09bcca1bd39344d4e568c70b2ad31fd29f1bf";
      };
      locations."/" = {
        tryFiles = "$uri $uri/ @to_home";
        extraConfig = ''
          uwsgi_pass unix://${config.services.uwsgi.instance.vassals.flask-helloworld.socket};
          include ${pkgs.nginx}/conf/uwsgi_params;
        '';
      };
    };
  };
  services.uwsgi = {
    enable = true;
    user = "nginx";
    group = "nginx";
    instance = {
      type = "emperor";
      vassals = {
        flask-helloworld = {
          type = "normal";
          pythonPackages = self: with self; [ flask-helloworld ];
          socket = "${config.services.uwsgi.runDir}/flask-helloworld.sock";
          wsgi-file = "${pkgs.pythonPackages.flask-helloworld}/${pkgs.python.sitePackages}/helloworld/share/flask-helloworld.wsgi";
        };
      };
    };
    plugins = [ "python2" ];
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
