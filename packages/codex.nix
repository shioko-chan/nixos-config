{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  makeBinaryWrapper,
  zstd,
  bubblewrap,
  ripgrep,
  ncurses,
  versionCheckHook,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "codex";
  version = "0.156.1";

  src = fetchurl {
    url = "https://github.com/openai/codex/releases/download/rust-v${finalAttrs.version}/codex-package-x86_64-unknown-linux-musl.tar.zst";
    hash = "sha256-mphgcveiX4iYnUIWgl0ZeGc9Uzg+CkWsqEntgrHqICA=";
  };

  sourceRoot = ".";
  nativeBuildInputs = [ autoPatchelfHook makeBinaryWrapper zstd ];
  buildInputs = [ ncurses ];
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -a bin codex-package.json codex-path codex-resources "$out/"
    runHook postInstall
  '';

  postFixup = ''
    wrapProgram "$out/bin/codex" --prefix PATH : ${lib.makeBinPath [ ripgrep bubblewrap ]}
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  meta = {
    description = "Codex CLI and matching code-mode and voice runtimes";
    homepage = "https://github.com/openai/codex";
    license = lib.licenses.asl20;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "codex";
  };
})
