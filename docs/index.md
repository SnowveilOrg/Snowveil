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

Snowveil 扫描目录并组装模块；NixOS 和 Home Manager 继续处理模块求值。

## 文件扫描与模块求值

```text
                         Snowveil
                            │
                ┌───────────┴───────────┐
                │                       │
            Discovery               Composition
                │                       │
        ┌───────┼────────┐              │
        ▼       ▼        ▼              ▼
      hosts/  users/  modules/    Nix module system
        │       │        │              │
        ▼       ▼        ▼              │
      Host    User    Feature            │
        │       │        │              │
        └───────┴────────┴──────────────┘
                            │
                            ▼
             nixosConfigurations / homeConfigurations
             packages / apps / devShells / checks
```

文件扫描读取目录和 `meta.nix`；随后 Snowveil 按规则选择模块，并交给 NixOS 和 Home Manager。它不改变 option merge、`mkIf`、`mkDefault` 或系统配置的求值方式。

## Snowveil 与 Nix 模块系统

| Snowveil | Nix 模块系统 |
| --- | --- |
| 扫描目录 | 求值模块 |
| 读取 magic 文件和 `meta.nix` | 合并 options |
| 生成 outputs | 处理 `mkIf`、`mkDefault` |
| 区分 NixOS 与 Home Manager 模块 | 解析模块依赖 |
| 传入模块 | 求值最终配置 |

## 目录和 outputs

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

可查看仓库中的[示例项目](/guide/example-repository)，也可以直接阅读[从普通 flake 迁移](/migration/from-plain-flake)。
