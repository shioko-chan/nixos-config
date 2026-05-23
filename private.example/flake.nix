{
  description = "Example private NixOS wrapper";

  inputs = {
    # Replace this with the absolute path to your public config checkout.
    nixos-config.url = "path:/home/example/nixos-config/public";
  };

  outputs =
    {
      self,
      nixos-config,
      ...
    }:
    let
      settings = import ./settings.nix;
    in
    {
      nixosConfigurations.${settings.hostName} = nixos-config.lib.mkNixosConfiguration {
        inherit settings;
        hardwareModules = [
          ./hardware.nix
        ];
      };
    };
}
