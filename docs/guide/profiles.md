# Profiles

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
