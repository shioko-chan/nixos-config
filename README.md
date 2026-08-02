# nixos-config

可复用的公开 NixOS 配置，使用 Flakes、Home Manager 和 Plasma Manager 管理系统与用户环境。仓库将通用配置与机器私有配置分离，并导出 `lib.mkNixosConfiguration` 供其他 Flake 复用。

## 主要组件

- NixOS 26.05
- `nixpkgs-unstable`，用于按需引入较新的软件包
- Home Manager
- Plasma Manager
- 可复用的 NixOS configuration 构造函数

## 文件结构

```text
nixos-config/
├── flake.nix
├── flake.lock
├── settings.nix
├── configuration.nix
├── hardware-configuration.nix
└── home.nix
```

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

## 检查配置

```bash
nix flake check
```

查看可用输出：

```bash
nix flake show
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
