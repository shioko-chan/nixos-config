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

  configDir = "~/nixos-config/public";
  generateConfigDir = "~/nixos-config/public";
  rebuildFlake = "~/nixos-config/public#workstation";
}
