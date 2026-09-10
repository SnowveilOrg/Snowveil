# Performance

Snowveil 将目录扫描与 NixOS、Home Manager 和 per-system output 的求值分开处理。

- Discovery 只读取目录结构和 `meta.nix`，不会求值主机 module。
- `nixosConfigurations`、`homeConfigurations`、packages、checks、apps 和 formatter 都是惰性属性；访问一个 output 不会构建其他 output。
- 同一 `mkFlake` 调用内，同一 system 的 NixOS、Home Manager 和 per-system outputs 复用 package set。
- Discovery 结果、模块选择和依赖解析按主机缓存。

因此，排查慢求值或构建时应先缩小到单个 output：

```bash
nix eval .#nixosConfigurations.desktop.config.system.stateVersion
nix build .#nixosConfigurations.desktop.config.system.build.toplevel
nix build .#checks.x86_64-linux.snowveil-discovery
```

`nix flake show` 适合检查输出结构，但不应当用它替代目标主机的求值或构建测试。

## 降低检查成本

将昂贵或暂时无法通过的自动发现 output 加入 `outputs.disabled`：

```nix
inputs.snowveil.lib.mkFlake {
  inherit inputs;
  outputs.disabled = [ "checks.expensive" ];
}
```

这只会禁用框架发现的 output，不影响 `outputs.extra`。更多禁用规则见[自定义 Outputs](/guide/extensions)。

完整求值流程见[Evaluation Model](/concepts/architecture)。
