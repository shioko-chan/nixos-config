{
  config,
  pkgs,
  pkgs-unstable,
  settings,
  ...
}:
let
  username = settings.username;
  mount_dir = settings.paths.mountDir;

  stable_packages = with pkgs; [
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
    codex

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
  unstable_packages = with pkgs-unstable; [
    antigravity-ide
    vscode
    zoom-us
  ];
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
