{
  username = "example";
  fullName = "Example User";
  hostName = "workstation";

  sshAuthorizedKeys = [ ];

  git = {
    name = "Example User";
    email = "user@example.com";
  };

  paths = {
    mountDir = "/media";
    wallpaper = "/media/Pictures/wallpaper.jpg";
    fastfetchLogo = "/media/Pictures/logo.png";
  };

  configDir = "~/nixos-config";
  generateConfigDir = "~/nixos-config";
  rebuildFlake = "~/nixos-config#workstation";
}
