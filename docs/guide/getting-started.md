# 快速开始

Snowveil 用「约定代替样板」，让多主机、多用户的 NixOS + home-manager 配置仓库结构清晰、可复用。只需 5 分钟即可建立一个完整的可运行仓库。

## 5 分钟上手

### 1. 使用模板初始化

在空目录中运行：

```bash
nix flake init --template github:SnowveilOrg/Snowveil
```

### 2. 最小目录骨架

一个最基础的 Snowveil 配置仅需包含一台主机与 `flake.nix`：

```text
.
├── flake.nix
└── hosts/
    └── my-host/
        ├── meta.nix        # 必须：声明 system 架构
        └── default.nix     # 必须：主机核心配置
```

其中文件内容极简：

::: code-group
```nix [hosts/my-host/meta.nix]
{
  system = "x86_64-linux";
}
```

```nix [hosts/my-host/default.nix]
{ pkgs, ... }:
{
  boot.loader.systemd-boot.enable = true;
  environment.systemPackages = [ pkgs.git pkgs.neovim ];
  system.stateVersion = "24.11";
}
```
:::

### 3. flake.nix 入口

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    snowveil = {
      url = "github:SnowveilOrg/Snowveil";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
  };

  outputs = inputs: inputs.snowveil.lib.mkFlake { inherit inputs; };
}
```

> **注意**：入口位于框架 flake 的 `lib` output 下，因此应使用 `inputs.snowveil.lib.mkFlake`。
> 框架会自动扫描 `hosts/` 发现 `my-host`，并自动装配出 `nixosConfigurations.my-host`。

---

## 查看 outputs

创建目录后，运行：

```bash
nix flake show
```

输出将自动包含发现的各配置与模块：

```text
nixosConfigurations
└── my-host

nixosModules
homeModules
packages
apps
devShells
checks
```

更详细的完整目录层级与规范，请参考[项目结构](/guide/directory-structure)。

---

## 常用全局配置

```nix
outputs = inputs:
  inputs.snowveil.lib.mkFlake {
    inherit inputs;

    nixpkgs = {
      config = {
        allowUnfree = true;
        permittedInsecurePackages = [ ];
      };
      overlays = [ ];
    };

    nixos.specialArgs = { };
    home.specialArgs = { };

    # 默认嵌入，仅为指定主机关闭。
    home.embed = {
      default = true;
      hosts.yc-hk-1 = false;
    };

    # 可按主机关闭 useGlobalPkgs，兼容需要自行添加 HM overlay 的模块。
    home.useGlobalPkgs = {
      default = true;
      hosts.nixos-desktop = false;
    };

    outputs.disabled = [ "checks.expensive" ];
  };
```

自动发现的 overlays、`nixpkgs.overlays` 与 `nixpkgs.config` 会统一作用于 NixOS、独立/嵌入式 home-manager 以及所有 per-system outputs。关闭 `home.useGlobalPkgs` 时，这些配置会注入 HM 自己的 nixpkgs，同时允许 HM 模块追加 overlay。

推荐在每台主机的 `meta.nix` 声明角色和主机级策略：

```nix
# hosts/nixos-desktop/meta.nix
{
  system = "x86_64-linux";

  roles = [
    "desktop"
    "development"
  ];

  home.useGlobalPkgs = false;
}
```

## 常见用法

```bash
# 构建并切换主机
sudo nixos-rebuild switch --flake .#nixos-desktop

# 切换用户环境（全局 home）
home-manager switch --flake .#rhencloud

# 切换某主机专属 home
home-manager switch --flake .#rhencloud@nixos-desktop

# 运行 app
nix run .#hello

# 构建隔离检查（CI）
nix flake check path:. --show-trace
```
