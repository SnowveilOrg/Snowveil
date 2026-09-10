# 从 nixos-unified 迁移

nixos-unified 与 Snowveil 都可以组织 NixOS、Home Manager 和 Flake outputs，但目录约定与激活入口不同。迁移时可先保留现有 NixOS 与 Home Manager modules，再替换 output 装配。

## 对应关系

| nixos-unified | Snowveil |
| --- | --- |
| 主机配置与 autowiring 目录 | `hosts/<name>/` |
| Home Manager 配置 | `homes/<user>/<host>.nix` |
| 用户声明 | `users/<user>/meta.nix` |
| Flake module / autowiring | `modules/` 与各 output 目录 |
| `.#activate` | `nixos-rebuild switch --flake .#<host>` 或 `home-manager switch --flake .#<user>@<host>` |

## 迁移步骤

1. 添加 Snowveil input，并将 `outputs` 改为 `inputs.snowveil.lib.mkFlake { inherit inputs; }`。
2. 将每台 NixOS 主机放到 `hosts/<name>/default.nix`，并添加包含 `system` 的 `meta.nix`。
3. 将主机关联的 Home Manager 配置移到 `homes/<user>/<host>.nix`。
4. 添加 `users/<user>/meta.nix`，用 `hosts` 声明该用户安装到哪些系统。
5. 将自动挂接的公共模块整理为 `modules/` 下的 magic 文件。
6. 用 `nix flake show` 和 `nix flake check` 检查输出，再按主机执行 `nixos-rebuild switch`。

```nix
# hosts/desktop/meta.nix
{
  system = "x86_64-linux";
}
```

```bash
nix flake show
sudo nixos-rebuild switch --flake .#desktop
```

Snowveil 不提供 nixos-unified 的统一激活 app、远程部署或 Darwin 处理。保留这些需求时，可通过 `outputs.extra` 或现有部署工具继续定义相应 output。

目录映射见[Outputs](/reference/generated-outputs)，普通 Flake 的完整迁移示例见[普通 Flake → Snowveil](/migration/from-plain-flake)。
