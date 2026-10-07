# nixos-config

[English](README.md) | [简体中文](README.zh-CN.md)

可复用的公开 NixOS 配置，使用 Flakes、Home Manager 和 Plasma Manager 管理系统与用户环境。仓库将通用配置与机器私有配置分离，并导出 `lib.mkNixosConfiguration` 供其他 Flake 复用。

## 主要组件

- NixOS 26.05
- `nixpkgs-unstable`，用于按需引入较新的软件包
- Home Manager
- Plasma Manager
- sops-nix + age
- 可复用的 NixOS configuration 构造函数

## 文件结构

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

## 使用 sops-nix + age

当前使用 Home Manager 用户级 sops-nix。首次使用时需要为用户引导 age
私钥；该文件不会进入 Nix store，也绝不能提交到 Git：

```bash
install -d -m 0700 ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt
age-keygen -y ~/.config/sops/age/keys.txt
```

`age-keygen -o` 会以 `0600` 权限创建私钥。如果目标文件已经存在，它会拒绝
覆盖，以免误删已有密钥。

把输出的 `age1...` 公钥写入私有配置仓库的 `.sops.yaml`：

```yaml
keys:
  - &desktop age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
creation_rules:
  - path_regex: secrets/[^/]+[.](yaml|json|env|ini)$
    key_groups:
      - age:
          - *desktop
```

随后在私有配置仓库中创建密文文件：

```bash
mkdir -p secrets
sops secrets/secrets.yaml
```

在私有 Flake 的 `extraModules` 中为 Home Manager 用户声明要解密的键。例如：

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

Home Manager 模块或用户服务通过 `config.sops.secrets.example.path` 引用运行时
解密文件。不要用 `builtins.readFile` 读取秘密，否则明文会被复制进 Nix
store。请单独备份 age 私钥；私钥遗失后无法恢复已有密文。系统服务无法依赖
用户级秘密；需要在登录前使用的秘密应改用 NixOS 系统级 sops-nix。

## 使用前配置

编辑 `settings.nix`，替换示例值：

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

首次用于新机器时，还应生成或复制与该机器匹配的硬件配置：

```bash
sudo nixos-generate-config
```

确认 `hardware-configuration.nix` 中的磁盘、文件系统和设备设置正确后再重建系统。

## 本地软件包

本地包定义、版本固定及上游包的覆盖统一放在 `packages/<包名>.nix`，
由公共 Flake 的 `packages.x86_64-linux` 导出。`home.nix` 和私有 Flake
引用这些包；安装选择、引擎路径和本机 DPI 等设置仍由使用方传入。

| 包 | 打包来源及本地定制 |
| --- | --- |
| `chatgpt` | `nixpkgs-chatgpt` PR 包，使用公共 Codex 包并降低启动器日志级别 |
| `claude-code` | `nixpkgs-unstable` 包，覆盖官方版本清单 |
| `claude-desktop` | `nixpkgs-claude` PR 包，覆盖官方版本与校验值；可通过 `deviceScaleFactor` 设置本机缩放 |
| `codex` | 官方 Linux 完整发布包及 NixOS 运行库适配 |
| `deepseek-harness` | `nixpkgs-harness` PR 包，修正 Bash 路径并补全启动器运行环境 |
| `p2pool` | `nixpkgs-unstable` 包，固定源码版本与校验值 |
| `unreal-engine` | 本地解压的 Unreal Engine 的启动器和 FHS 运行环境 |

PR 的软件源及固定提交统一声明在公共 `flake.nix` 中。更新 PR 时在公共
仓库运行 `nix flake update <输入名>`；只更新应用版本时修改对应包文件。
私有配置使用本地公共输入，修改后在私有仓库运行 `nix flake update nixos-config`。

可单独构建任一导出的包，例如：

```bash
nix build path:/home/kurage/nixos-config/public#claude-code --no-link --print-out-paths
```

## 检查配置

Codex 使用 `packages/codex.nix` 中固定版本及 SHA-256 的官方 Linux 完整发布包，
包含 CLI、code-mode host 与语音运行时。Home Manager 安装同一个包，私有层的
ChatGPT 桌面包也通过 `override { codex = ...; }` 引用它。

更新时修改版本与官方发布资产的校验值，然后单独构建验证：

```bash
nix build path:/home/kurage/nixos-config/public#codex --no-link --print-out-paths
```

```bash
nix flake check
```

查看可用输出：

```bash
nix flake show
```

## Unreal Engine

将 Epic 官方 Linux 二进制包解压到 `settings.paths.mountDir` 下的
`Unreal/UE_5.8`。Nix 管理启动环境和 NSS/NSPR 等运行库；引擎保持在原目录，
使用随包附带的 .NET SDK 与 Clang 工具链。

启动器为编辑器设置 `SDL_VIDEO_WAYLAND_SCALE_TO_DISPLAY=1`，避免 Wayland
在高 DPI 屏幕上放大低分辨率窗口而导致文字模糊。已在 4K、200% 缩放下验证；
不同缩放比例的屏幕之间移动窗口时，仍需留意窗口大小和弹出菜单的位置。

应用 Home Manager 配置后，可从应用菜单启动 **Unreal Editor**，或运行
`unreal-editor /absolute/path/Game.uproject`。未应用配置时可直接启动：

```bash
nix run path:/home/kurage/nixos-config/public#unreal-engine
```

`unreal-env` 可让构建脚本或终端使用相同的 FHS 环境：

```bash
unreal-env /media/Unreal/UE_5.8/Engine/Build/BatchFiles/Linux/Build.sh \
  GameEditor Linux Development -Project=/absolute/path/Game.uproject -NoHotReloadFromIDE
unreal-env /media/Unreal/UE_5.8/Engine/Build/BatchFiles/Linux/GenerateProjectFiles.sh \
  -project=/absolute/path/Game.uproject -game -vscode
unreal-env bash
```

命令行完整构建使用 `-NoHotReloadFromIDE`，避免另一个 FHS 环境中正在运行的编辑器
触发 UE 5.8 的进程路径检测异常；它不会执行编辑器热重载。

单独构建启动器：

```bash
nix build path:/home/kurage/nixos-config/public#unreal-engine --no-link --print-out-paths
```

## 应用配置

在仓库根目录运行：

```bash
sudo nixos-rebuild switch --flake .#your-host
```

其中 `your-host` 必须与 `settings.nix` 中的 `hostName` 一致。

仅构建但不切换：

```bash
sudo nixos-rebuild build --flake .#your-host
```

## 作为公共模块复用

`flake.nix` 导出了：

```nix
lib.mkNixosConfiguration
```

私有仓库可以引用该函数，并传入自己的 `settings`、`hardwareModules` 和额外模块，从而把用户名、主机信息、硬件配置与秘密留在私有层。

## 注意事项

- 在执行 `switch` 前检查磁盘挂载、引导器、用户名和主机名。
- 不要在公开仓库提交密码、私钥、无线网络凭据或其他秘密。
- `settings.nix` 当前是示例配置，不能直接用于真实机器。
- 建议先使用 `build` 或虚拟机测试，再应用到主系统。
