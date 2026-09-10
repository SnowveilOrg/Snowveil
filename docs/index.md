---
layout: home

hero:
  name: Snowveil
  text: 基于目录约定的 NixOS 配置框架
  tagline: 按约定扫描 hosts/、homes/ 和 modules/，生成对应的 Flake outputs。
  actions:
    - theme: brand
      text: 快速开始
      link: /guide/getting-started
    - theme: alt
      text: 从普通 flake 迁移
      link: /migration/from-plain-flake
    - theme: alt
      text: 在 GitHub 查看
      link: https://github.com/SnowveilOrg/Snowveil

features:
  - title: 目录约定
    details: hosts/、homes/、modules/ 按固定规则发现，无需维护 import 列表或手写 nixosConfigurations。
  - title: NixOS 与 Home Manager
    details: 同一模块目录按目标分拣，分别写入 nixosConfigurations 和 homeConfigurations。
  - title: 主机组合
    details: Roles 用于主机分类，Profiles 用于启用模块集合，Modules 用于实现具体配置。
  - title: 无额外运行时依赖
    details: 基于 nixpkgs.lib 实现，不依赖 flake-utils 或 flake-parts。

---

## 手写装配与目录约定

<table>
<tr><th>手写配置</th><th>Snowveil 配置</th></tr>
<tr><td>

```nix
nixosConfigurations.desktop =
  nixpkgs.lib.nixosSystem {
    modules = [
      ./hosts/desktop
      ./modules/common.nix
      ./modules/desktop.nix
    ];
  };
```

</td><td>

```text
hosts/
└── desktop/
    ├── default.nix
    └── meta.nix
modules/
├── _common/
└── desktop/
homes/
└── rhen/
    └── desktop.nix
```

</td></tr>
</table>

Snowveil 负责目录扫描和模块装配；NixOS 与 Home Manager 仍负责模块求值。

## 目录与 outputs 的对应关系

```text
                              Snowveil
                                 │
                         文件系统扫描
                                 │
              ┌──────────────────┼──────────────────┐
              ▼                  ▼                  ▼
           hosts/             modules/            homes/
              │                  │                  │
              ▼                  ▼                  ▼
           NixOS              模块集合         Home Manager
              │                  │                  │
              └──────────────────┼──────────────────┘
                                 ▼
                            Flake outputs
                         ┌───────┴────────┐
                         ▼                ▼
              nixosConfigurations  homeConfigurations
```

可参考仓库中的[示例配置](/guide/example-repository)，或从[普通 flake 迁移](/migration/from-plain-flake)。
