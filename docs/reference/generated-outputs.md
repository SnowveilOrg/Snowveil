# Generated Outputs

Snowveil 把约定目录转成标准 Flake outputs。它先发现文件，再把 NixOS 与 Home Manager 配置交给各自的模块系统求值。

```text
hosts/laptop/
        │
        ▼
nixosConfigurations.laptop

homes/rhen/laptop.nix
        │
        ▼
homeConfigurations."rhen@laptop"

modules/desktop/fonts/
        │
        ▼
nixosModules."desktop.fonts"
homeModules."desktop.fonts"
```

## 目录映射

| 目录或文件 | 生成的 output |
| --- | --- |
| `hosts/<name>/default.nix` | `nixosConfigurations.<name>` |
| `homes/<user>/default.nix` | `homeConfigurations.<user>` |
| `homes/<user>/<host>.nix` | `homeConfigurations."<user>@<host>"` |
| `modules/<path>/{options,default,nixos,home}.nix` | `nixosModules."<path>"` 与/或 `homeModules."<path>"` |
| `packages/<name>/default.nix` | `packages.<system>.<name>` |
| `apps/<name>/default.nix` | `apps.<system>.<name>` |
| `overlays/<name>/default.nix` | `overlays.<name>` |
| `shells/<name>/default.nix` | `devShells.<system>.<name>` |
| `checks/<name>/default.nix` | `checks.<system>.<name>` |
| `formatter/default.nix` | `formatter.<system>` |
| `deploy/default.nix` | `deploy` |
| `lib/<name>.nix` | `lib.<name>` |

`hardware.nix`、`disk.nix` 与 `network.nix` 是 `hosts/<name>/` 内的附加 magic 文件：它们被导入 `nixosConfigurations.<name>`，但不会单独生成 output。

## 查看生成结果

```bash
nix flake show
```

检查发现清单而不构建主机：

```bash
nix build .#checks.x86_64-linux.snowveil-discovery
cat result | python3 -m json.tool
```

若一个目录未生成预期 output，先确认文件名和路径符合上表，再查看[调试与问题排查](/advanced/debugging)。完整的目录扫描和排序契约属于[Discovery Specification](/reference/discovery)。
