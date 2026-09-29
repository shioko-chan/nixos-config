{
  description = "Public NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    # Official Linux desktop packaging from NixOS/nixpkgs#551713.
    nixpkgs-chatgpt.url = "github:Moraxyc/nixpkgs/6f5904350edee5bb794f854ab51b1cb20b2da215";
    # Official Linux desktop packaging from NixOS/nixpkgs#537215.
    nixpkgs-claude.url = "github:minegameYTB/nixpkgs/c6fdb764a39b26dae69aa468427985a0ea4d4c7b";
    # NixOS/nixpkgs#554081 with its linked Node profile-loading fix.
    nixpkgs-harness.url = "github:tlvince/nixpkgs/bb92a908f642b89de7f190aa0183a15510331aac";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    hardware-monitor = {
      url = "github:shioko-chan/hardware-monitor-nixos-kde";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-unstable,
      nixpkgs-chatgpt,
      nixpkgs-claude,
      nixpkgs-harness,
      home-manager,
      sops-nix,
      plasma-manager,
      hardware-monitor,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      pkgs-unstable = import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };
      chatgptPkgs = import nixpkgs-chatgpt {
        inherit system;
        config.allowUnfree = true;
      };
      claudePkgs = import nixpkgs-claude {
        inherit system;
        config.allowUnfree = true;
      };
      harnessPkgs = import nixpkgs-harness { inherit system; };

      packages = {
        chatgpt = chatgptPkgs.callPackage ./packages/chatgpt.nix { inherit (packages) codex; };
        claude-code = pkgs-unstable.callPackage ./packages/claude-code.nix { };
        claude-desktop = claudePkgs.callPackage ./packages/claude-desktop.nix { };
        codex = pkgs.callPackage ./packages/codex.nix { };
        deepseek-harness = harnessPkgs.callPackage ./packages/deepseek-harness.nix { };
        p2pool = pkgs-unstable.callPackage ./packages/p2pool.nix { };
        unreal-engine = pkgs.callPackage ./packages/unreal-engine.nix { };
      };

      defaultSettings = import ./settings.nix;

      mkNixosConfiguration =
        {
          settings,
          hardwareModules ? [ ./hardware-configuration.nix ],
          extraModules ? [ ],
        }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs pkgs-unstable settings;
          };
          modules =
            hardwareModules
            ++ [
              ./configuration.nix

              home-manager.nixosModules.home-manager
              {
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.extraSpecialArgs = {
                  inherit inputs pkgs-unstable settings;
                };
                home-manager.sharedModules = [
                  plasma-manager.homeModules.plasma-manager
                  sops-nix.homeManagerModules.sops
                ];
                home-manager.users.${settings.username} = {
                  imports = [
                    ./home.nix
                    ./sops.nix
                  ];
                };
              }

              hardware-monitor.nixosModules.default
              {
                services.hardware-monitor = {
                  enable = true;
                  pollInterval = 1;
                  smartInterval = 300;
                };
              }
            ]
            ++ extraModules;
        };
    in
    {
      lib.mkNixosConfiguration = mkNixosConfiguration;

      packages.${system} = packages;

      nixosConfigurations.${defaultSettings.hostName} = mkNixosConfiguration {
        settings = defaultSettings;
      };
    };
}
