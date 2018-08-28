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
          pandas = python-super.pandas.overrideAttrs(o: rec {
            doCheck = false;
            doInstallCheck = false;
          });
          smbus2 = python-super.buildPythonPackage rec {
            name = "smbus2-${version}";
            version = "0.2.1";
            src = pkgs.fetchurl {
              url = "mirror://pypi/s/smbus2/${name}.tar.gz";
              sha256 = "0axzrb1b20vjsp02ppz0x28pwn8gvx3rzrsvkfbbww26wzzl7ndq";
            };
          };
          pyscard = python-super.pyscard.overrideAttrs(o: rec {
            preBuild = ''
              substituteInPlace smartcard/CardMonitoring.py --replace "traceback.print_exc()" "print('Not bailing on you!'); continue"
            '';
          });
          coffeemachine = python-super.buildPythonPackage rec {
            name = "coffeemachine-${version}";
            version = "1.0.0";
            src = fetchGit {
              url = "https://github.com/knedlsepp/coffeemachine.git";
              rev = "9be481028984ce94851fa3a70ff9d98b35920565";
            };
            propagatedBuildInputs = with python-self; [
              django
              pandas
              pyscard
              smbus2
            ];
            prePatch = with python-self; ''
              cp ${coffeemachine-settings} coffeemachine/settings.py
            '';
            doCheck = false;
          };
          coffeemachine-settings = writeTextFile rec {
            name = "coffeemachine-settings.py";
            text = ''
              import os
              BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
              SECRET_KEY = 'pbm4ad1*2k^j69_b2ro-nhcm-uh^n8&take5bhbdm@)5+35v&e'
              DEBUG = True
              ALLOWED_HOSTS = [ 'www.coffeemachine.com', '10.0.0.1' ]
              INSTALLED_APPS = [
                  'coffeelist.apps.CoffeelistConfig',
                  'django.contrib.admin',
                  'django.contrib.auth',
                  'django.contrib.contenttypes',
                  'django.contrib.sessions',
                  'django.contrib.messages',
                  'django.contrib.staticfiles',
              ]
              MIDDLEWARE = [
                  'django.middleware.security.SecurityMiddleware',
                  'django.contrib.sessions.middleware.SessionMiddleware',
                  'django.middleware.common.CommonMiddleware',
                  'django.middleware.csrf.CsrfViewMiddleware',
                  'django.middleware.locale.LocaleMiddleware',
                  'django.contrib.auth.middleware.AuthenticationMiddleware',
                  'django.contrib.messages.middleware.MessageMiddleware',
                  'django.middleware.clickjacking.XFrameOptionsMiddleware',
              ]
              ROOT_URLCONF = 'coffeemachine.urls'
              TEMPLATES = [
                  {
                      'BACKEND': 'django.template.backends.django.DjangoTemplates',
                      'DIRS': [],
                      'APP_DIRS': True,
                      'OPTIONS': {
                          'context_processors': [
                              'django.template.context_processors.debug',
                              'django.template.context_processors.request',
                              'django.contrib.auth.context_processors.auth',
                              'django.contrib.messages.context_processors.messages',
                          ],
                      },
                  },
              ]
              WSGI_APPLICATION = 'coffeemachine.wsgi.application'
              DATABASES = {
                  'default': {
                      'ENGINE': 'django.db.backends.sqlite3',
                      'NAME': '/tmp/coffeemachine/db.sqlite3',
                  }
              }
              AUTH_PASSWORD_VALIDATORS = [
                  {
                      'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator',
                  },
                  {
                      'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator',
                  },
                  {
                      'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator',
                  },
                  {
                      'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator',
                  },
              ]
              LANGUAGE_CODE = 'en-us'
              TIME_ZONE = 'UTC'
              USE_I18N = True
              USE_L10N = True
              USE_TZ = True
              STATIC_ROOT = '/tmp/coffeemachine/static/'
              STATIC_URL = '/static/'
            '';
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
 
  services.pcscd = {
    enable = true;
    plugins = with pkgs; [ ccid ]; # acsccid
    readerConfig = ''
      # Empty
    '';
  };

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
    (python3.withPackages(ps: with ps; [ coffeemachine ]))
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
      locations."/static/" = {
        extraConfig = ''
          alias             /tmp/coffeemachine/static/;
        '';
      };
      locations."/" = {
        extraConfig = ''
          uwsgi_pass unix://${config.services.uwsgi.instance.vassals.coffeemachine.socket};
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
        coffeemachine = {
          type = "normal";
          pythonPackages = self: with self; [ coffeemachine ];
          socket = "${config.services.uwsgi.runDir}/coffeemachine.sock";
          wsgi-file = "${pkgs.python3Packages.coffeemachine}/${pkgs.python3.sitePackages}/coffeemachine/wsgi.py";
        };
      };
    };
    plugins = [ "python3" ];
  };

  systemd.services.coffeemachine_nfc_reader = {
    description = "Coffeemachine NFC reader";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.lib.getBin pkgs.python3Packages.coffeemachine}/bin/write_nfc_purchases_to_db.py";
      User = "root"; # There's a privilege issue otherwise: PermissionError: [Errno 13] Permission denied: '/dev/i2c-1'
      Restart = "always";
      RestartSec = "5s";

      #User = "nginx";
    };
    preStart = let baseDir = "/tmp/coffeemachine/"; in ''
      mkdir -p ${baseDir}
      #chown nginx.nginx ${baseDir}
      chmod 0750 ${baseDir}
      if ! [ -e ${baseDir}/.db-created ]; then
        ${pkgs.lib.getBin pkgs.python3Packages.coffeemachine}/bin/manage.py migrate
        ${pkgs.lib.getBin pkgs.python3Packages.coffeemachine}/bin/manage.py collectstatic --clear --no-input
        echo "from django.contrib.auth import get_user_model; User = get_user_model(); User.objects.create_superuser('admin', 'admin@myproject.com', 'password')" | ${pkgs.lib.getBin pkgs.python3Packages.coffeemachine}/bin/manage.py shell
        touch ${baseDir}/.db-created
      fi
    '';
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
