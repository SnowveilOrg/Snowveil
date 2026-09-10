# 示例配置

下面是一份可运行的 Snowveil 配置。它包含一个 NixOS 主机、一个关联用户、一个 Home Manager 配置、两个模块和一个 Profile；实际目录可从仓库中的 [`examples/basic`](https://github.com/SnowveilOrg/Snowveil/tree/main/examples/basic) 查看。

```text
snowveil-example/
├── flake.nix
├── hosts/
│   └── desktop/
│       ├── default.nix
│       ├── hardware.nix
│       ├── network.nix
│       └── meta.nix
├── homes/
│   └── rhen/
│       └── desktop.nix
├── users/
│   └── rhen/
│       ├── default.nix
│       └── meta.nix
├── modules/
│   ├── desktop/
│   │   └── default.nix
│   └── development/
│       └── default.nix
└── profiles/
    └── workstation.nix
```

## 运行它

```bash
git clone https://github.com/SnowveilOrg/Snowveil.git
cd Snowveil/examples/basic

# 在真正的 NixOS 主机上，把 nixos-desktop 替换为你的主机名。
sudo nixos-rebuild switch --flake .#nixos-desktop

# 查看 Snowveil 生成的 outputs。
nix flake show
```

你会看到类似的结构：

```text
nixosConfigurations
└── nixos-desktop

homeConfigurations
└── rhencloud@nixos-desktop
```

`examples/basic` 还包含 packages、overlays、apps、checks 和 shell 等可选目录。示例使用本地 Snowveil input 以便仓库自检；自己的配置应使用 GitHub input，见[快速开始](/guide/getting-started)。

## 最小文件

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    snowveil.url = "github:SnowveilOrg/Snowveil";
  };

  outputs = inputs: inputs.snowveil.lib.mkFlake { inherit inputs; };
}
```

```nix
# hosts/desktop/meta.nix
{
  system = "x86_64-linux";
  roles = [ "desktop" "development" ];
}
```

```nix
# hosts/desktop/default.nix
{ ... }:
{
  system.stateVersion = "25.05";
}
```

```nix
# users/rhen/meta.nix
{
  hosts = [ "desktop" ];
  uid = 1000;
  extraGroups = [ "wheel" ];
}
```

```nix
# homes/rhen/desktop.nix
{ ... }:
{
  home.stateVersion = "25.05";
}
```

下一步：阅读[第一个 Host](/guide/first-host)，理解每个文件为什么存在。
