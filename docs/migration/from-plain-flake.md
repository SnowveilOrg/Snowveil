# 从普通 NixOS flake 迁移

Snowveil 最适合的迁移方式是：保留已有的 NixOS 与 Home Manager module 内容，只把手写的 output 装配和 import 列表换成目录约定。

## 迁移前：手写装配

```nix
# flake.nix
outputs = { self, nixpkgs, home-manager, ... }@inputs: {
  nixosConfigurations.desktop = nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = { inherit inputs; };
    modules = [
      ./hosts/desktop/configuration.nix
      ./modules/common.nix
      ./modules/desktop.nix
      home-manager.nixosModules.home-manager
    ];
  };
};
```

## 迁移后：目录约定

```text
hosts/
└── desktop/
    ├── default.nix
    └── meta.nix
modules/
├── _common/
│   └── default.nix
└── desktop/
    └── nixos.nix
homes/
└── rhen/
    └── desktop.nix
users/
└── rhen/
    └── meta.nix
```

```nix
# flake.nix
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

Snowveil 自动产生 `nixosConfigurations.desktop`，并为 `homes/rhen/desktop.nix` 产生 `homeConfigurations."rhen@desktop"`。

## 迁移步骤

### 1. 添加 Snowveil input，并替换 `outputs`

采用上面的 `flake.nix`。入口是 `inputs.snowveil.lib.mkFlake`，不是 `inputs.snowveil.mkFlake`。

### 2. 移动主机配置

```text
# 从
hosts/desktop/configuration.nix

# 到
hosts/desktop/default.nix
```

添加强制的主机元数据：

```nix
# hosts/desktop/meta.nix
{
  system = "x86_64-linux";
  roles = [ "desktop" ];
}
```

`system` 不再编码在目录名中；裸名称 `hosts/desktop/` 是唯一支持的主机目录形式。

### 3. 移动共享模块

```text
# 从
modules/common.nix
modules/desktop.nix

# 到
modules/_common/default.nix
modules/desktop/nixos.nix
```

`_common` 始终注入。`modules/desktop/` 由主机的 `roles = [ "desktop" ];` 选中。若一个模块同时给 NixOS 与 Home Manager 使用，可采用 `options.nix`、`default.nix`、`nixos.nix`、`home.nix` 的单树布局。

### 4. 提取 Home Manager 配置

```text
# 从：通过 home-manager NixOS module 手写挂接
hosts/desktop/home.nix

# 到：Snowveil 自动建立关联
homes/rhen/desktop.nix
```

同时声明系统用户：

```nix
# users/rhen/meta.nix
{
  hosts = [ "desktop" ];
  uid = 1000;
  extraGroups = [ "wheel" ];
}
```

### 5. 验证生成结果

```bash
nix flake show
nix flake check
sudo nixos-rebuild switch --flake .#desktop
```

查看目录如何映射到 output，请阅读[Generated Outputs](/reference/generated-outputs)。

## 过渡期的特殊主机

无法立即按约定重组的主机可以通过 `mkSystem` 与自动发现并存：

```nix
outputs = inputs:
  let
    snowveil = inputs.snowveil.lib.mkLib { inherit inputs; };
  in
  inputs.snowveil.lib.mkFlake {
    inherit inputs;
    outputs.extra.nixosConfigurations.special = snowveil.mkSystem {
      host = "special";
      system = "x86_64-linux";
      modules = [ ./special/configuration.nix ];
    };
  };
```

## 常见迁移问题

### `hosts/foo/meta.nix must define system`

每个 `hosts/<name>/meta.nix` 都必须包含：

```nix
{ system = "x86_64-linux"; }
```

### 原先的模块文件没有被加载

Snowveil 不会导入任意 `.nix` 文件。将模块重命名为目录中的 `options.nix`、`default.nix`、`nixos.nix` 或 `home.nix`，或从 magic 文件显式 import 它。

### 何时使用 Roles、Profiles 或 Module dependencies？

请阅读[Roles、Profiles 与 Modules](/guide/composition)的决策表。更多排错场景见[调试与问题排查](/advanced/debugging)。
