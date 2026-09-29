{
  lib,
  steam,
  writeShellScriptBin,
  makeDesktopItem,
  symlinkJoin,
  engineRoot ? "/media/Unreal/UE_5.8",
}:
let
  # Keep Epic's unpacked engine writable and outside the Nix store.
  runtime =
    (steam.override {
      extraPkgs = pkgs: [
        pkgs.nss
        pkgs.nspr
      ];
      privateTmp = false;
      # UBA's HTTP client looks up the TCP protocol by name.
      extraBwrapArgs = [
        "--ro-bind /etc/protocols /etc/protocols"
        "--ro-bind /etc/services /etc/services"
      ];
    }).run-free;

  environment = writeShellScriptBin "unreal-env" ''
    if [ "$#" -eq 0 ]; then
      set -- bash
    fi
    exec ${lib.getExe runtime} "$@"
  '';

  editor = writeShellScriptBin "unreal-editor" ''
    engine_root=${lib.escapeShellArg engineRoot}
    if [ ! -x "$engine_root/Engine/Binaries/Linux/UnrealEditor" ]; then
      echo "Unreal Editor not found in $engine_root; unpack Epic's Linux archive there first." >&2
      exit 1
    fi
    cd "$engine_root" || exit 1
    exec ${lib.getExe environment} "$engine_root/Engine/Binaries/Linux/UnrealEditor" "$@"
  '';

  desktop = makeDesktopItem {
    name = "unreal-editor";
    desktopName = "Unreal Editor";
    comment = "Unreal Engine development environment";
    exec = "${lib.getExe editor} %f";
    icon = "${engineRoot}/Engine/Content/Slate/Starship/Common/UELogo.png";
    categories = [
      "Development"
      "Graphics"
    ];
  };
in
symlinkJoin {
  name = "unreal-engine-launcher";
  paths = [
    environment
    editor
    desktop
  ];
  meta = {
    description = "Launch a locally unpacked Unreal Engine in an FHS environment";
    mainProgram = "unreal-editor";
    platforms = [ "x86_64-linux" ];
  };
}
