# Profiles

## Role 与 Profile 对比

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
> - **Role 决定哪些模块有资格进入主机**（编译范围���。
> - **Profile 决定哪些模块应该被默认启用**（运行时激活）。

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
