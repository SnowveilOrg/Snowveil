# Roles、Profiles 与 Modules

这四个概念解决不同问题。先按你的意图选择，再考虑实现细节。

| 我想做什么 | 应该使用 | 例子 |
| --- | --- | --- |
| 创建一个可复用功能 | Module | Docker、Neovim、桌面字体 |
| 表示机器属于什么类型 | Role | `desktop`、`server`、`development` |
| 一次启用一组功能 | Profile | workstation、gaming |
| 表明功能 A 依赖功能 B | Module dependency | editor 依赖 fonts |
| 为特殊情况手动加入模块 | `nixos.modules` / `home.modules` | 外部 module |

## Module：功能的实现

每个功能放在 `modules/` 下的一个目录。例如 `modules/desktop/fonts/default.nix` 是一个可复用的桌面字体功能。Snowveil 按文件名将它分拣给 NixOS、Home Manager 或两边；详细规则见[第一个 Module](/guide/modules)。

## Role：主机的类型

Role 是主机选择模块的标签：

```nix
# hosts/desktop/meta.nix
{
  system = "x86_64-linux";
  roles = [ "desktop" "development" ];
}
```

- `modules/_common/**` 始终选择。
- `modules/desktop/**` 只选择给带有 `desktop` role 的主机。
- `modules/development/**` 只选择给带有 `development` role 的主机。

Role 只控制导入；模块内部仍可使用 option 来启用或关闭细粒度功能。

## Profile：功能组合

Profile 是主机声明的一组已启用模块，而不是目录过滤器。将 Profile 写在 `profiles/`：

```nix
# profiles/workstation.nix
{
  nixos = [ "workstation.podman" ];
  home = [ "development.helix" ];
}
```

再在主机元数据引用它：

```nix
# hosts/desktop/meta.nix
{
  system = "x86_64-linux";
  profiles = [ "workstation" ];
}
```

当一台机器始终需要同一组功能时使用 Profile；当功能只属于某类机器时使用 Role。

## Dependency：功能前提

Module dependency 用来表达模块之间的硬前提，并产生稳定的加载顺序。不要用 Role 或 Profile 模拟依赖关系。配置格式见[模块依赖](/guide/module-dependencies)。
