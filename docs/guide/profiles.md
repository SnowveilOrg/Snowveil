# Profiles

## Role 与 Profile

| | Role | Profile |
| --- | --- | --- |
| 声明位置 | Host `meta.nix` | Host `meta.nix` |
| 核心作用 | 过滤模块目录 | 启用指定模块集合 |
| 控制范围 | `modules/<role>/` | Profile 中列出的模块 |
| 是否自动启用模块 | 否 | 是 |
| 典型用途 | `desktop`、`server` | `workstation`、`gaming` |

**Role 决定哪些模块有资格进入主机；Profile 决定哪些模块应该被启用。**

Profile 是一组模块启用项。它适合复用固定的主机功能组合，例如 workstation、gaming 或 CI runner。

Profile 文件位于 `profiles/<name>.nix`：

```nix
# profiles/workstation.nix
{
  nixos = [
    "workstation.podman"
  ];

  home = [
    "development.helix"
  ];
}
```

在主机 metadata 中引用：

```nix
# hosts/desktop/meta.nix
{
  system = "x86_64-linux";
  profiles = [ "workstation" ];
}
```

Profile 不决定模块是否能被发现，也不替代模块依赖：

- 用 [Roles](/guide/roles) 按主机类型选择目录中的模块。
- 用 Profile 启用一组已发现的模块。
- 用[模块依赖](/guide/module-dependencies)表示模块之间的前提和顺序。

当功能本身需要实现时，创建 [Module](/guide/modules)，而不是 Profile。
