# Snowveil

Snowveil 是一个基于 Nix Flakes 的约定式配置框架。它按目录自动发现 NixOS 主机、Home Manager 配置、模块、packages 和 overlays，减少多主机配置中的 import 与 output 样板。

- NixOS 与 Home Manager 共享单一模块树
- 使用角色组合主机配置
- 纯 `nixpkgs.lib` 实现，无 `flake-utils` 或 `flake.parts` 运行时依赖

## 快速开始

```bash
nix flake init --template github:SnowveilOrg/Snowveil
cd <your-config>
```

最小 `flake.nix`：

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    snowveil.url = "github:SnowveilOrg/Snowveil";
    snowveil.inputs.nixpkgs.follows = "nixpkgs";
    snowveil.inputs.home-manager.follows = "home-manager";
  };

  outputs = inputs: inputs.snowveil.lib.mkFlake { inherit inputs; };
}
```

模板中的 `myhost` 和 `myuser` 是占位符，应先重命名对应目录与文件，并更新 Nix 用户名。模板默认使用容器模式以便通过求值；部署实体主机前，请移除 `boot.isContainer = true`，运行 `nixos-generate-config --show-hardware-config` 并将输出保存为 `hosts/<host>/hardware.nix`。最后运行 `nix flake check`，再使用 `sudo nixos-rebuild switch --flake .#<host>`。

`homes/<user>/<host>.nix` 会自动关联该用户与主机；关联用户仍需在 `users/<user>/meta.nix` 中声明 UID 等系统用户元数据。完整示例见 [`examples/basic/`](./examples/basic)。

## 文档

文档站位于 [`docs/`](./docs)，本地预览可运行 `cd docs && npm run docs:dev`。

- [快速开始](./docs/guide/getting-started.md)
- [目录结构](./docs/guide/directory-structure.md)
- [多主机与 Home Manager](./docs/guide/multiple-hosts.md)
- [模块、角色与元数据](./docs/guide/modules.md)
- [Packages、overlays 与扩展 outputs](./docs/guide/packages.md)
- [核心 API](./docs/api/core.md)
- [迁移指南](./docs/migration/from-plain-flake.md)

## 开发

开发约定见 [AGENTS.md](./AGENTS.md)。提交前运行：

```bash
nix fmt
deadnix -l -L -_
statix check
nix flake check
```

## 许可证

MIT
