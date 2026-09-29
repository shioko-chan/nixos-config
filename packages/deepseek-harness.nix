{
  lib,
  deepseek-harness,
  makeWrapper,
  bashInteractive,
  pnpm_11,
  nodejs_24,
}:
deepseek-harness.overrideAttrs (old: {
  nativeBuildInputs = old.nativeBuildInputs ++ [ makeWrapper ];
  postPatch = (old.postPatch or "") + ''
    substituteInPlace packages/terminal/terminal-bash/src/config.ts \
      --replace-fail "DEFAULT_BASH_SHELL = '/bin/bash'" "DEFAULT_BASH_SHELL = '${lib.getExe bashInteractive}'"
  '';
  postFixup = (old.postFixup or "") + ''
    wrapProgram "$out/bin/dsh" \
      --prefix PATH : ${
        lib.makeBinPath [
          pnpm_11
          nodejs_24
          bashInteractive
        ]
      }
  '';
})
