{
  description = "Public NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-unstable,
      home-manager,
      plasma-manager,
      ...
    }@inputs:
    let
      defaultSettings = import ./settings.nix;

      mkNixosConfiguration =
        {
          settings,
          hardwareModules ? [ ./hardware-configuration.nix ],
          extraModules ? [ ],
        }:
        let
          system = "x86_64-linux";

          pkgs-unstable = import nixpkgs-unstable {
            inherit system;
            config.allowUnfree = true;
          };
        in
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
                ];
                home-manager.users.${settings.username} = {
                  imports = [
                    ./home.nix
                  ];
                };
              }
            ]
            ++ extraModules;
        };
    in
    {
      lib.mkNixosConfiguration = mkNixosConfiguration;

      nixosConfigurations.${defaultSettings.hostName} = mkNixosConfiguration {
        settings = defaultSettings;
      };
    };
}
