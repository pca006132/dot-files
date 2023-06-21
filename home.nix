{ pkgs
, config
, inputs
, ...
}:
let
  development-packages = with pkgs; [
    gnumake
    clang-tools
    cmake
    gdb
    pkg-config
    flamegraph
    linuxPackages.perf
    hyperfine

    gcc
    nodejs
    metals
    sbt
    scalafmt

    nixpkgs-fmt

    texlab
    (texlive.combine { inherit (texlive) scheme-full minted; })

    vale

    powertop
    nodePackages.pyright
    nodePackages.typescript
    nodePackages_latest.grammarly-languageserver
    (symlinkJoin {
      name = "typescript-language-server";
      paths = [ nodePackages.typescript-language-server ];
      buildInputs = [ makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/typescript-language-server \
          --add-flags --tsserver-path=${nodePackages.typescript}/lib/node_modules/typescript/lib/
      '';
    })
    nil
    adoptopenjdk-openj9-bin-16
    (python3.withPackages (ps:
      with ps; [
        numpy
        matplotlib
        scipy
        autopep8
        pandas
        requests
        grequests
        setuptools
      ]))
  ];
  tools = with pkgs; [
    tealdeer
    fd
    sd
    bat
    aria2
    ripgrep
    ranger
    xclip
    (neovide.overrideAttrs (old: rec {
      src = inputs.neovide-src;
      cargoDeps = pkgs.rustPlatform.importCargoLock {
        lockFile = src + "/Cargo.lock";
        outputHashes = {
          "winit-0.28.6" =
            "sha256-6YK4hmogBZ3Nchrz8aE865UyvOIa5Ul969T4R0GG8xA=";
          "xkbcommon-dl-0.1.0" =
            "sha256-ojokJF7ivN8JpXo+JAfX3kUOeXneNek7pzIy8D1n4oU=";
        };
      };
    }))
    fzf
    sioyek
    imagemagick
    vimv
    pandoc
    pdftk
    nix-du
    nix-prefetch-git
    xdot
    graphviz
    yt-dlp
    rsync
    unar
    zip
    xournalpp
    wl-clipboard
  ];
  desktop-apps = with pkgs; [
    rime-data
    firefox-bin
    zoom-us
    gnome.gnome-tweaks
    gnome.adwaita-icon-theme
    gnomeExtensions.dash-to-dock
    qemu_kvm
    nvtop
    intel-gpu-tools
    kcachegrind
    steam
    pinentry-gnome
  ];
in
{
  nixpkgs.config.allowUnfree = true;
  home.stateVersion = "22.11";
  programs.home-manager = { enable = true; };

  home.packages = with pkgs; [
    (callPackage ./osu.nix { })
    (callPackage ./prusa-slicer.nix { })
    (callPackage ./super-slicer.nix { })
  ] ++ development-packages ++ tools ++ desktop-apps;

  xdg.desktopEntries = {
    prusa-slicer = {
      name = "Prusa Slicer";
      exec = "prusa-slicer";
      icon = "prusa-slicer";
      comment = "Prusa Slicer";
      genericName = "3D printer tool";
      categories = [ "Development" ];
    };
    super-slicer = {
      name = "Super Slicer";
      exec = "super-slicer";
      icon = "super-slicer";
      comment = "Super Slicer";
      genericName = "3D printer tool";
      categories = [ "Development" ];
    };
  };

  home.sessionVariables = {
    EDITOR = "nvim";
    LD_LIBRARY_PATH = "$LD_LIBRARY_PATH:/run/opengl-driver/lib";
  };
  home.sessionPath = [ "$HOME/.npm-packages/bin/" "$HOME/.local/bin" ];

  xdg.mimeApps.defaultApplications = {
    "application/pdf" = "sioyek.desktop";
  };

  programs.kitty = {
    enable = true;
    font = {
      name = "DejaVuSansMono";
      size = 12;
    };
    settings = {
      scrollback_lines = 100000;
      enable_audio_bell = false;
      update_check_interval = 0;
    };
  };

  programs.htop = {
    enable = true;
    settings = {
      show_cpu_usage = 1;
      show_cpu_frequency = 1;
      show_cpu_temperature = 1;
    } // (with config.lib.htop; leftMeters [
      (bar "LeftCPUs2")
      (bar "Memory")
      (bar "Swap")
      (text "DiskIO")
      (text "NetworkIO")
    ]) // (with config.lib.htop; rightMeters [
      (bar "RightCPUs2")
      (text "Tasks")
      (text "LoadAverage")
      (text "Uptime")
      (text "Systemd")
    ]);
  };

  fonts.fontconfig.enable = true;

  nixpkgs.overlays = [
    inputs.neovim-nightly-overlay.overlay
    (self: super: {
      neovim-unwrapped = super.neovim-unwrapped.overrideAttrs (oa: {
        patches = builtins.filter
          (p:
            let
              patch =
                if builtins.typeOf p == "set"
                then baseNameOf p.name
                else baseNameOf p;
            in
            patch != "neovim-build-make-generated-source-files-reproducible.patch")
          oa.patches;
      });
    })
  ];

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableZshIntegration = true;
  };

  programs.git = {
    enable = true;
    extraConfig = {
      core = {
        editor = "nvim";
        autocrlf = "input";
      };
      pull = { ff = "only"; };
    };
    lfs.enable = true;
    userEmail = "john.lck40@gmail.com";
    userName = "pca006132";
    ignores = [ ".envrc" ".direnv/" ".venv" ];
    signing = {
      key = "E9D2B552F9801C5D";
      signByDefault = false;
    };
  };

  programs.gpg = {
    enable = true;
    publicKeys = [{
      source = ./public.key;
      trust = 5;
    }];
  };

  services.easyeffects = {
    enable = true;
  };

  services.gpg-agent = {
    defaultCacheTtlSsh = 60;
    enable = true;
    enableSshSupport = true;
    enableExtraSocket = true;
    sshKeys = [ "996D13DF48B5A21F57298DD1B542F46ABECF3015" ];
    pinentryFlavor = "gnome3";
  };

  programs.ssh = {
    enable = true;
    matchBlocks = {
      pca-pc = {
        hostname = "pca006132.duckdns.org";
        forwardAgent = true;
        compression = true;
      };
    };
  };

  programs.zsh = {
    enable = true;
    enableAutosuggestions = true;
    oh-my-zsh = {
      enable = true;
      plugins = [ "git" "z" "vi-mode" "history-substring-search" ];
      theme = "avit";
    };
    autocd = true;
    shellAliases = {
      ll = "ls -l";
      v = "nvim";
      r = ''
        ranger --choosedir=$HOME/.rangerdir; LASTDIR=`cat $HOME/.rangerdir`; cd "$LASTDIR"'';
    };
    initExtra = ''
      if [[ "$SSH_AUTH_SOCK" == "/run/user/1000/keyring/ssh" ]]
      then
        SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket) 
      fi
    '';
  };

  programs.tmux = {
    enable = true;
    escapeTime = 0;
    extraConfig = ''
      set -g mouse on
      set -g default-terminal "tmux-256color"
      bind | split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"
      bind t new
    '';
    keyMode = "vi";
    plugins = [ pkgs.tmuxPlugins.vim-tmux-navigator ];
    shortcut = "a";
    terminal = "xterm";
  };

  programs.neovim = inputs.my-nvim.nvim;
}
