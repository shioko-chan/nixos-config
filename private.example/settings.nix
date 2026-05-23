{
  username = "example";
  fullName = "Example User";
  hostName = "workstation";

  sshAuthorizedKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEXAMPLEPUBLICKEYREPLACEWITHYOURS user@example.com"
  ];

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
  generateConfigDir = "~/nixos-config/private";
  rebuildFlake = "path:$HOME/nixos-config/private#workstation";
}
