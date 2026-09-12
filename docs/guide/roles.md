# 角色系统

角色（role）是框架的**模块过滤机制**：通过在主机元数据中声明角色，自动决定哪些目录下的模块会被注入该主机。

## Role 与 Profile

| | Role | Profile |
| --- | --- | --- |
| 声明位置 | Host `meta.nix` | Host `meta.nix` |
| 核心作用 | 过滤模块目录 | 启用指定模块集合 |
| 控制范围 | `modules/<role>/` | Profile 中列出的模块 |
| 是否自动启用模块 | 否 | 是 |
| 典型用途 | `desktop`、`server` | `workstation`、`gaming` |

**Role 决定主机加载哪些目录；Profile 列出需要启用的模块。**

Role 不用于声明模块依赖。模块依赖见[模块图](/guide/module-dependencies)，Profile 的写法见[Profiles](/guide/profiles)。

## 声明角色

在 `meta.nix` 中声明：

```nix
# hosts/nixos-desktop/meta.nix
{
  roles = [
    "desktop"
    "development"
  ];
}
```

`role`（单值）是 `roles`（列表）的别名，两者等价。

## 模块目录结构

```
modules/
├── _common/          # 始终注入（特殊前缀）
│   ├── base/
│   │   ├── nixos.nix
│   │   └── home.nix
│   └── security/
│       └── nixos.nix
├── desktop/          # 仅注入包含 "desktop" 角色的主机
│   ├── hyprland/
│   │   ├── nixos.nix
│   │   └── home.nix
│   └── fonts/
│       └── nixos.nix
├── server/           # 仅注入包含 "server" 角色的主机
│   └── nginx/
│       └── nixos.nix
└── development/      # 仅注入包含 "development" 角色的主机
    └── tools/
        ├── nixos.nix
        └── home.nix
```

## 过滤规则

| 模块路径 | 加载条件 |
| -------- | -------- |
| `modules/_common/**` | 始终注入 |
| `modules/<role>/**` | 主机 `roles` 包含 `<role>` |
| `modules/<role>/**/default.nix` | 始终注入（共享 option） |
| 未声明 `roles` 的主机 | 全量注入 |

注意：`default.nix` 永远注入，保证各角色的 option 声明在所有主机可见（`lib.mkEnableOption` 等不会因角色过滤而缺失）。

## 组合角色

多角色组合：

```nix
{
  roles = [
    "desktop"
    "development"
  ];
}
```

等价于同时注入 `_common`、`desktop`、`development` 三个目录下的模块。

## 角色与 option 的关系

角色只控制 **import**，不等同于 option 开关。推荐在模块内部仍使用 option 做细粒度控制：

```nix
# modules/desktop/hyprland/nixos.nix
{ config, lib, ... }:
{
  config = lib.mkIf config.snowveil.hyprland.enable {
    # ...
  };
}
```

这样即使同属 `desktop` 角色，用户也可以通过 `snowveil.hyprland.enable = false` 禁用单个功能。

## 调试模块加载

查看框架发现了哪些模块：

```bash
nix run .#snowveil-discovery
```

需要完整 JSON 报告时加 `--json`，其中 `nixosModules` / `homeModules` 字段列出所有已发现模块及其角色归属。
