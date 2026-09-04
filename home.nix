{
  config,
  lib,
  pkgs,
  pkgs-unstable,
  settings,
  ...
}:
let
  username = settings.username;
  mount_dir = settings.paths.mountDir;
  xmrigEnabled = settings.xmrig.enable or false;

  p2poolPackage = pkgs-unstable.p2pool.overrideAttrs (_: rec {
    version = "4.18";
    src = pkgs-unstable.fetchFromGitHub {
      owner = "SChernykh";
      repo = "p2pool";
      rev = "v${version}";
      hash = "sha256-nmh6XY7fP/qddzVyb1yiJ5dcOxZctCjodi5uf3M3NfM=";
      fetchSubmodules = true;
    };
  });

  xmrigConfig = pkgs.writeText "xmrig-config.json" (
    builtins.toJSON {
      autosave = false;
      background = false;
      colors = true;
      randomx = {
        init = -1;
        "init-avx2" = -1;
        mode = "auto";
        "1gb-pages" = false;
        # A root-only system service applies and restores the Intel MSR. The
        # networked miner deliberately has no CAP_SYS_RAWIO.
        rdmsr = false;
        wrmsr = false;
        numa = true;
      };
      cpu = {
        enabled = true;
        "huge-pages" = true;
        "huge-pages-jit" = false;
        priority = 2;
        yield = true;
        "max-threads-hint" = 100;
      };
      opencl.enabled = false;
      cuda.enabled = false;
      pools = [
        {
          url = "127.0.0.1:3333";
          user = "x";
          pass = "x";
          coin = "monero";
          keepalive = true;
        }
      ];
    }
  );

  p2poolStart = pkgs.writeShellScript "p2pool-mini-start" ''
    set -eu

    : "''${P2POOL_WALLET_ADDRESS:?Set P2POOL_WALLET_ADDRESS in the p2pool_env SOPS secret}"

    if [ "$P2POOL_WALLET_ADDRESS" = "REPLACE_WITH_MONERO_PRIMARY_WALLET_ADDRESS" ]; then
      echo "Replace P2POOL_WALLET_ADDRESS in the p2pool_env SOPS secret." >&2
      exit 78
    fi

    data_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/p2pool"
    ${pkgs.coreutils}/bin/install -d -m 0700 "$data_dir"

    exec ${lib.getExe p2poolPackage} \
      --wallet "$P2POOL_WALLET_ADDRESS" \
      --host 127.0.0.1 \
      --rpc-port 18081 \
      --zmq-port 18083 \
      --mini \
      --light-mode \
      --stratum 127.0.0.1:3333 \
      --p2p 127.0.0.1:37888 \
      --socks5 127.0.0.1:7891 \
      --socks5-proxy-type plain \
      --no-upnp \
      --no-log-file \
      --data-dir "$data_dir"
  '';

  stable_packages = with pkgs; [
    crow-translate

    monero-gui
    xmrig

    openssl

    iperf3
    input-leap
    ydotool
    mpi
    pdfgrep
    poppler-utils
    texliveFull
    mathpix-snipping-tool
    vlc
    playwright
    zip
    jq
    ripgrep
    bat
    btop
    tmux
    helix
    yazi
    peazip
    unzip
    lsof
    ffmpeg
    libclang
    gcc
    binutils
    gnumake
    pkg-config
    jdk25_headless
    nil
    nixd
    nixfmt
    python3
    uv
    xmake
    cmake
    cargo
    rustfmt
    nodejs_24

    bubblewrap

    gemini-cli

    firefox-devedition
    wechat
    discord
    feishu
    obs-studio
    haruna
    libreoffice-qt-fresh
    chromium
    prismlauncher
    vipsdisp
    kdePackages.qtstyleplugin-kvantum

    fortune
    cowsay
    lolcat
    figlet
    libnotify
  ];
  unstable_packages = [ p2poolPackage ] ++ (with pkgs-unstable; [
    antigravity-ide
    vscode
    zoom-us
    codex
  ]);
in
{
  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "25.11";

  home.sessionPath = [
    "$HOME/.cargo/bin"
    "$HOME/.npm-global/bin"
    "$HOME/.local/bin"
  ];

  home.sessionVariables = {
    GTK_IM_MODULE = "fcitx";
    QT_IM_MODULE = "fcitx";
    XMODIFIERS = "@im=fcitx";
    SDL_IM_MODULE = "fcitx";
    GLFW_IM_MODULE = "ibus";
  };

  xdg.userDirs = {
    enable = true;
    createDirectories = true;
    setSessionVariables = true;
  };
  home.file."Documents" = {
    source = config.lib.file.mkOutOfStoreSymlink "${mount_dir}/Documents";
  };
  home.file."Downloads" = {
    source = config.lib.file.mkOutOfStoreSymlink "${mount_dir}/Downloads";
  };
  home.file."Pictures" = {
    source = config.lib.file.mkOutOfStoreSymlink "${mount_dir}/Pictures";
  };
  home.file."Videos" = {
    source = config.lib.file.mkOutOfStoreSymlink "${mount_dir}/Videos";
  };
  home.file."Music" = {
    source = config.lib.file.mkOutOfStoreSymlink "${mount_dir}/Music";
  };

  home.packages = stable_packages ++ unstable_packages;

  xdg.configFile."xmrig/config.json" = lib.mkIf xmrigEnabled {
    source = xmrigConfig;
  };

  systemd.user.services.p2pool = lib.mkIf xmrigEnabled {
    Unit = {
      Description = "Monero P2Pool mini node via Mihomo";
      After = [
        "network-online.target"
        "sops-nix.service"
      ];
      Wants = [ "network-online.target" ];
      Requires = [ "sops-nix.service" ];
    };
    Service = {
      EnvironmentFile = config.sops.secrets.p2pool_env.path;
      ExecStart = p2poolStart;
      Restart = "on-failure";
      RestartPreventExitStatus = 78;
      RestartSec = 10;
    };
  };

  # Deliberately not enabled at login: first create a dedicated P2Pool wallet,
  # replace the encrypted placeholder, and let this unit start P2Pool on demand.
  systemd.user.services.xmrig = lib.mkIf xmrigEnabled {
    Unit = {
      Description = "XMRig Monero miner for local P2Pool mini";
      After = [ "p2pool.service" ];
      Requires = [ "p2pool.service" ];
    };
    Service = {
      ExecCondition = "${pkgs.systemd}/bin/systemctl is-active --quiet xmrig-msr.service";
      ExecStart = "${lib.getExe pkgs.xmrig} --config=${xmrigConfig}";
      Restart = "on-failure";
      RestartSec = 10;
      LimitMEMLOCK = "infinity";
      Nice = 10;
    };
  };

  programs.zed-editor = {
    enable = true;
    extensions = [
      "nix"
      "toml"
    ];
    userSettings = {
      features = {
        direnv = "auto";
      };
      buffer_line_height = "comfortable";
      terminal = {
        alternate_scroll = "off";
        blinking = "off";
        copy_on_select = true;
        dock = "bottom";
        detect_venv = {
          on = {
            directories = [
              ".env"
              "env"
              ".venv"
              "venv"
            ];
            activate_script = "default";
          };
        };
        env = {
          TERM = "kitty";
        };
        font_family = "JetBrainsMono Nerd Font";
        font_features = null;
        font_size = 14;
        line_height = "standard";
        option_as_meta = false;
        button = false;
        shell = "system";
        toolbar = {
          title = true;
        };
        working_directory = "current_project_directory";
      };
      ui_font_size = 16;
      buffer_font_size = 15;
    };
  };

  programs.kitty = {
    enable = true;
    font = {
      name = "JetBrainsMono Nerd Font";
      size = 10;
    };
    settings = {
      cursor_shape = "underline";
      window_padding_width = 5;
      background_opacity = "0.85";
      hide_window_decorations = "no";
      font_family = "JetBrainsMonoNF-SemiBold";
      bold_font = "JetBrainsMonoNF-ExtraBold";
      italic_font = "JetBrainsMonoNF-Italic";
      bold_italic_font = "JetBrainsMonoNF-ExtraBoldItalic";
      font_size = "10.0";
      update_check_interval = 0;
      confirm_os_window_close = 0;
    };
  };
  xdg.desktopEntries."kitty" = {
    name = "Kitty";
    icon = "kitty";
    exec = "kitty";
    genericName = "Terminal Emulator";
    terminal = false;
    categories = [
      "System"
      "TerminalEmulator"
    ];
    settings = {
      "X-KDE-Shortcuts" = "Ctrl+Alt+T";
    };
  };

  programs.starship = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.zsh = {
    enable = true;
    history = {
      size = 10000;
      save = 1000000;
      ignoreDups = true;
      share = true;
    };
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    shellAliases = {
      update = ''
        (
           set -e
           cd ${settings.configDir}/public
           nix flake update
           cd ${settings.configDir}/private
           nix flake update
           sudo nixos-rebuild switch --flake .#${settings.flakeHost}
           git add flake.lock
           if ! git diff --cached --quiet; then
             git commit -m "flake update"
           else
             echo "No flake.lock changes to commit."
           fi
         )
      '';
      ll = "ls -l";
      v = "nvim";
      gen = "sudo nixos-generate-config --dir ${settings.generateConfigDir}";
      editcfg = "zeditor ${settings.configDir}";
    };
    oh-my-zsh = {
      enable = true;
      plugins = [
        "git"
        "sudo"
        "extract"
        "bgnotify"
        "z"
      ];
    };
    initContent = ''
      fortune | cowsay | lolcat
      echo "--------------------------------------"
      figlet "Caelestis Musica Mundana!" | lolcat
    '';
  };

  programs.plasma = {
    enable = true;
    overrideConfig = true;
    configFile = {
      kwinrc.Wayland.InputMethod = "/run/current-system/sw/share/applications/org.fcitx.Fcitx5.desktop";
      kdeglobals = {
        General = {
          TerminalApplication = "kitty";
          TerminalService = "kitty.desktop";
        };
      };
    };
    desktop = {
      icons = {
        arrangement = "leftToRight";
        folderPreviewPopups = true;
      };
    };
    kwin = {
      effects = {
        blur.enable = true;
        translucency.enable = true;
      };
    };
    shortcuts = {
      "org.kde.konsole.desktop" = {
        "_launch" = [ ];
      };
    };
    workspace = {
      lookAndFeel = "org.kde.breezedark.desktop";
      wallpaper = settings.paths.wallpaper;
      wallpaperFillMode = "preserveAspectFit";
    };
    kscreenlocker = {
      autoLock = false;
      appearance = {
        alwaysShowClock = true;
        showMediaControls = true;
        wallpaper = settings.paths.wallpaper;
      };
    };
    powerdevil.AC = {
      autoSuspend.action = "nothing";
      displayBrightness = 100;
      dimDisplay = {
        enable = true;
        idleTimeout = 300;
      };
    };
    panels = [
      {
        location = "top";
        height = 22;
        opacity = "translucent";
        widgets = [
          {
            name = "org.kde.plasma.kickoff";
            config = {
              General = {
                icon = "/run/current-system/sw/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
              };
            };
          }
          "org.kde.plasma.appmenu"
          "org.kde.plasma.panelspacer"
          "org.kde.plasma.windowlist"
          "org.kde.plasma.systemtray"
          "org.kde.plasma.digitalclock"
          "org.kde.plasma.showdesktop"
        ];
      }
      {
        location = "left";
        height = 45;
        lengthMode = "fit";
        alignment = "center";
        hiding = "dodgewindows";
        opacity = "translucent";
        widgets = [
          "org.kde.plasma.kickoff"
          "org.kde.plasma.icontasks"
          "org.kde.plasma.trash"
        ];
      }
    ];
  };

  programs.git = {
    enable = true;
    settings = {
      user = {
        name = settings.git.name;
        email = settings.git.email;
      };
      core = {
        editor = "vim";
        autocrlf = "input";
      };
      pull = {
        rebase = true;
      };
      push = {
        default = "simple";
        autoSetupRemote = true;
      };
      init = {
        defaultBranch = "main";
      };
      merge = {
        conflictstyle = "diff3";
      };
      rebase = {
        autoStash = true;
      };
    };
  };

  programs.fastfetch = {
    enable = true;
    settings = {
      logo = {
        source = settings.paths.fastfetchLogo;
        type = "kitty";
        width = 45;
      };
      display = {
        size = {
          maxPrefix = "MB";
          ndigits = 0;
          spaceBeforeUnit = "never";
        };
        freq = {
          ndigits = 3;
          spaceBeforeUnit = "never";
        };
      };
      modules = [
        "title"
        "separator"
        "os"
        "host"
        {
          type = "kernel";
          format = "{release}";
        }
        "uptime"
        {
          type = "packages";
          combined = true;
        }
        "shell"
        {
          type = "display";
          compactType = "original";
          key = "Resolution";
        }
        "de"
        "wm"
        "wmtheme"
        "theme"
        "icons"
        "terminal"
        {
          type = "terminalfont";
          format = "{/name}{-}{/}{name}{?size} {size}{?}";
        }
        "cpu"
        {
          type = "gpu";
          key = "GPU";
          format = "{name}";
        }
        {
          type = "memory";
          format = "{used} / {total}";
        }
        "break"
        "colors"
      ];
    };
  };
}
