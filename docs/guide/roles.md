# 角色系统

角色（role）是框架的**模块过滤机制**：通过在主机元数据中声明角色，自动决定哪些目录下的模块会被注入该主机。

## Role 与 Profile

在规划多主机系统时，Role 与 Profile 承担不同维度的职责：

| 维度 | Role（角色） | Profile（配置集） |
| --- | --- | --- |
| **心智模型** | **主机分类（环境归属）** | **功能打包（开箱即用套件）** |
| **声明位置** | `hosts/<name>/meta.nix` 中的 `roles` | `hosts/<name>/meta.nix` 中的 `profiles` |
| **定义位置** | 模块目录名（如 `modules/<role>/`） | `profiles/<name>.nix` 单独文件 |
| **核心机制** | 决定哪些模块目录被 `import` 进主机 | 将一组模块的 enable 开关批量设为 true |
| **控制粒度** | 粗粒度（目录级过滤） | 细粒度（具体模块列表） |
| **是否自动启用模块** | 否（仅注入定义，仍由 option 决定） | 是（直接激活预设） |
| **典型示例** | `desktop`、`server`、`laptop` | `workstation`、`gaming`、`minimal-server` |

> **一句话总结**：
> - **Role 决定主机能用什么**：一台 `server` 主机甚至不需要编译和扫描桌面组件。
> - **Profile 决定主机直接开启什么**：一台 `desktop` 可以直接套用 `gaming` 配置集开启 Steam 与驱动配置。

Role 不用于声明模块依赖。模块依赖见[模块图与依赖系统](/guide/module-dependencies)，Profile 的具体写法见下一节 [Profiles](/guide/profiles)。

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
| `modules/<role>/**/options.nix` | 始终注入（接口声明） |
| `modules/<role>/**/default.nix` | 始终注入（中性共享实现） |
| 未声明 `roles` 的主机 | 全量注入 |

注意：`options.nix` 与 `default.nix` 永远注入。将接口声明放在 `options.nix`，不要在 `default.nix` 中使用仅属于 NixOS 或 Home Manager 的选项。

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
