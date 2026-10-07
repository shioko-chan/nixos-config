# nixos-config

[English](README.md) | [简体中文](README.zh-CN.md)

A reusable public NixOS configuration that uses Flakes, Home Manager, and Plasma Manager to manage the system and user environment. The repository separates shared configuration from machine-specific private configuration and exports `lib.mkNixosConfiguration` for reuse by other Flakes.

## Main Components

- NixOS 26.05
- `nixpkgs-unstable` for selectively using newer packages
- Home Manager
- Plasma Manager
- sops-nix + age
- A reusable NixOS configuration constructor

## File Structure

```text
nixos-config/
├── flake.nix
├── flake.lock
├── settings.nix
├── configuration.nix
├── sops.nix
├── hardware-configuration.nix
├── packages/
│   ├── chatgpt.nix
│   ├── claude-code.nix
│   ├── claude-desktop.nix
│   ├── codex.nix
│   ├── deepseek-harness.nix
│   ├── p2pool.nix
│   └── unreal-engine.nix
└── home.nix
```

## Using sops-nix + age

The configuration currently uses user-level sops-nix through Home Manager. On first use,
bootstrap an age private key for the user. This file stays out of the Nix store and must
never be committed to Git:

```bash
install -d -m 0700 ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt
age-keygen -y ~/.config/sops/age/keys.txt
```

`age-keygen -o` creates the private key with `0600` permissions. If the target file already
exists, it refuses to overwrite it, preventing accidental loss of an existing key.

Add the resulting `age1...` public key to `.sops.yaml` in your private configuration repository:

```yaml
keys:
  - &desktop age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
creation_rules:
  - path_regex: secrets/[^/]+[.](yaml|json|env|ini)$
    key_groups:
      - age:
          - *desktop
```

Then create an encrypted file in the private configuration repository:

```bash
mkdir -p secrets
sops secrets/secrets.yaml
```

Declare the keys to decrypt for the Home Manager user in the private Flake's `extraModules`. For example:

```nix
extraModules = [
  {
    home-manager.users.${settings.username} = {
      sops.defaultSopsFile = ./secrets/secrets.yaml;
      sops.secrets.example = { };
    };
  }
];
```

Home Manager modules or user services reference the file decrypted at runtime through
`config.sops.secrets.example.path`. Do not read secrets with `builtins.readFile`, as this
copies plaintext into the Nix store. Back up the age private key separately; existing
encrypted data cannot be decrypted if the private key is lost. System services cannot depend
on user-level secrets. Secrets needed before login should use system-level sops-nix in NixOS instead.

## Configuration Before Use

Edit `settings.nix` and replace the example values:

```nix
{
  username = "your-user";
  fullName = "Your Name";
  hostName = "your-host";

  sshAuthorizedKeys = [ ];

  git = {
    name = "Your Name";
    email = "you@example.com";
  };

  paths = {
    mountDir = "/media";
    wallpaper = "/path/to/wallpaper.jpg";
    fastfetchLogo = "/path/to/logo.png";
  };

  flakePath = "~/nixos-config/public";
  flakeHost = "your-host";
}
```

When setting up a new machine for the first time, also generate or copy the hardware
configuration for that machine:

```bash
sudo nixos-generate-config
```

Before rebuilding the system, confirm that the disks, filesystems, and device settings in
`hardware-configuration.nix` are correct.

## Local Packages

Local package definitions, version pins, and overrides of upstream packages are kept in
`packages/<package-name>.nix` and exported by the public Flake as `packages.x86_64-linux`.
`home.nix` and the private Flake reference these packages; consumers still supply settings
such as which packages to install, engine paths, and the machine's DPI.

| Package | Packaging Source and Local Customizations |
| --- | --- |
| `chatgpt` | The `nixpkgs-chatgpt` PR package, using the public Codex package and a lower launcher log level |
| `claude-code` | The `nixpkgs-unstable` package, with an override for the official version manifest |
| `claude-desktop` | The `nixpkgs-claude` PR package, with overrides for the official version and checksum; `deviceScaleFactor` sets scaling for the local machine |
| `codex` | The full official Linux release bundle with runtime library adaptations for NixOS |
| `deepseek-harness` | The `nixpkgs-harness` PR package, with a corrected Bash path and a complete launcher runtime environment |
| `p2pool` | The `nixpkgs-unstable` package, with the source version and checksum pinned |
| `unreal-engine` | A launcher and FHS runtime environment for a locally extracted Unreal Engine |

Package sources from PRs and their pinned commits are declared centrally in the public
`flake.nix`. To update a PR input, run `nix flake update <input-name>` in the public
repository. To update only an application version, edit the corresponding package file.
The private configuration uses a local public input; after making changes, run
`nix flake update nixos-config` in the private repository.

You can build any exported package individually, for example:

```bash
nix build path:/home/kurage/nixos-config/public#claude-code --no-link --print-out-paths
```

## Checking the Configuration

Codex uses the full official Linux release bundle, with its version and SHA-256 pinned in
`packages/codex.nix`. The bundle includes the CLI, code-mode host, and voice runtime.
Home Manager installs the same package, and the ChatGPT desktop package in the private
layer also references it through `override { codex = ...; }`.

To update it, change the version and the checksum of the official release asset, then
build it independently to verify:

```bash
nix build path:/home/kurage/nixos-config/public#codex --no-link --print-out-paths
```

```bash
nix flake check
```

To view the available outputs:

```bash
nix flake show
```

## Unreal Engine

Extract Epic's official Linux binary package to `Unreal/UE_5.8` under
`settings.paths.mountDir`. Nix manages the launch environment and runtime libraries such
as NSS/NSPR. The engine stays in its original directory and uses its bundled .NET SDK
and Clang toolchain.

The launcher sets `SDL_VIDEO_WAYLAND_SCALE_TO_DISPLAY=1` for the editor to avoid
blurry text caused by Wayland enlarging a low-resolution window on high-DPI displays.
This has been verified at 4K with 200% scaling. When moving windows between displays
with different scale factors, check window sizes and popup menu positions.

After applying the Home Manager configuration, launch **Unreal Editor** from the
application menu or run `unreal-editor /absolute/path/Game.uproject`. You can also launch
it directly before applying the configuration:

```bash
nix run path:/home/kurage/nixos-config/public#unreal-engine
```

`unreal-env` lets build scripts or a terminal use the same FHS environment:

```bash
unreal-env /media/Unreal/UE_5.8/Engine/Build/BatchFiles/Linux/Build.sh \
  GameEditor Linux Development -Project=/absolute/path/Game.uproject -NoHotReloadFromIDE
unreal-env /media/Unreal/UE_5.8/Engine/Build/BatchFiles/Linux/GenerateProjectFiles.sh \
  -project=/absolute/path/Game.uproject -game -vscode
unreal-env bash
```

Use `-NoHotReloadFromIDE` for full command-line builds to prevent an editor running in
another FHS environment from triggering UE 5.8's process-path detection error. This does
not perform an editor hot reload.

To build the launcher separately:

```bash
nix build path:/home/kurage/nixos-config/public#unreal-engine --no-link --print-out-paths
```

## Applying the Configuration

Run from the repository root:

```bash
sudo nixos-rebuild switch --flake .#your-host
```

`your-host` must match `hostName` in `settings.nix`.

To build without switching:

```bash
sudo nixos-rebuild build --flake .#your-host
```

## Reusing as a Public Module

`flake.nix` exports:

```nix
lib.mkNixosConfiguration
```

A private repository can reference this function and pass its own `settings`,
`hardwareModules`, and additional modules, keeping usernames, host information, hardware
configuration, and secrets in the private layer.

## Notes

- Check disk mounts, the bootloader, username, and hostname before running `switch`.
- Do not commit passwords, private keys, wireless network credentials, or other secrets to a public repository.
- `settings.nix` is currently an example configuration and cannot be used directly on a real machine.
- It is recommended to test with `build` or a virtual machine before applying the configuration to your main system.
