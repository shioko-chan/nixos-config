{
  lib,
  claude-desktop,
  stdenvNoCC,
  fetchurl,
  deviceScaleFactor ? null,
}:

# The PR closes over its unwrapped package in the FHS launcher. Override the
# inner derivation at construction time so all launcher references use it too.
claude-desktop.override {
  stdenvNoCC = stdenvNoCC // {
    mkDerivation =
      args:
      let
        package = stdenvNoCC.mkDerivation args;
      in
      if package ? src && package.pname == "claude-desktop" then
        package.overrideAttrs (
          finalAttrs: old: {
            version = "2.9939.4";
            src = fetchurl {
              url = "https://downloads.claude.ai/claude-desktop/apt/stable/pool/main/c/claude-desktop/claude-desktop_${finalAttrs.version}_amd64.deb";
              hash = "sha256-PP3bI78pEeBeJ7TtOFa455XflGQ7LDW1nesxfPmVvKA=";
            };
            postFixup =
              old.postFixup
              + lib.optionalString (deviceScaleFactor != null) ''
                wrapProgram "$out/bin/claude-desktop" \
                  --add-flags "--force-device-scale-factor=${toString deviceScaleFactor}"
              '';
          }
        )
      else
        package;
  };
}
