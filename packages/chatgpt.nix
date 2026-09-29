{ chatgpt, codex }:
(chatgpt.override { inherit codex; }).overrideAttrs (old: {
  # Use the package's existing launcher wrapper for both desktop and CLI launches.
  preFixup = (old.preFixup or "") + ''
    gappsWrapperArgs+=(--set RUST_LOG warn)
  '';
})
