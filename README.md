# nixos-config

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
