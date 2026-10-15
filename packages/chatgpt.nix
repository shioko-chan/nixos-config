{
  lib,
  chatgpt,
  codex,
  openssl,
  tpm2-tss,
}:
(chatgpt.override { inherit codex; }).overrideAttrs (old: {
  # Pin the official Linux release while retaining the PR's NixOS packaging.
  passthru = old.passthru // {
    sources = old.passthru.sources // {
      x86_64-linux = rec {
        version = "26.1007.71326";
        src = {
          url = "https://persistent.oaistatic.com/codex-app-prod/linux/deb/pool/main/c/chatgpt/chatgpt_${version}_amd64.deb";
          hash = "sha256-DgBrSTFxL1qQ1M0ElyxuC1M87c39srUZRtW5NnRx9VY=";
        };
      };
    };
  };

  # The remote-control device-key addon links against OpenSSL and TPM libraries.
  buildInputs = old.buildInputs ++ [
    openssl
    tpm2-tss
  ];

  # Tectonic is now an application resource rather than part of the LaTeX plugin.
  installPhase =
    lib.replaceStrings
      [ "resources/plugins/openai-bundled/plugins/latex/bin/tectonic" ]
      [ "resources/tectonic/tectonic" ]
      old.installPhase;

  # Use the package's existing launcher wrapper for both desktop and CLI launches.
  preFixup = (old.preFixup or "") + ''
    gappsWrapperArgs+=(--set RUST_LOG warn)
  '';
})
