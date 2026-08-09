{ config, pkgs, ... }:

{
  # This user-owned key never enters the Nix store.
  # Back it up separately: encrypted files cannot be recovered without it.
  sops.age = {
    keyFile = "${config.xdg.configHome}/sops/age/keys.txt";
    generateKey = true;
  };

  home.packages = with pkgs; [
    age
    sops
  ];
}
