# 调试与问题排查

## snowveil-discovery 报告

查看框架发现了哪些主机、模块和包：

```bash
# 人类可读概览
nix run .#snowveil-discovery

# JSON 输出（适合脚本 / 管道）
nix run .#snowveil-discovery -- --json

# 原始 JSON check（CI / 调试）
nix build .#checks.x86_64-linux.snowveil-discovery
```

输出字段：

- `hosts`：发现的主机列表
- `homes`：发现的 home 列表（含 `user@host` 格式）
- `packages`：各架构的包列表
- `modules.nixosModules`：发现的 NixOS 模块组
- `modules.homeModules`：发现的 HM 模块组

## 常见问题

### 主机未被发现

原因：

1. 缺少 `meta.nix` 或 `default.nix`
2. `meta.nix` 未声明 `system`

检查：

```bash
# 查看 flake check 输出
nix flake check path:. --show-trace 2>&1 | grep -i "skip\|trace\|warn"
```

### 模块被意外注入或未注入

原因：角色配置不正确，或 `_common` 前缀使用错误。

检查 `snowveil-discovery` 报告中 `modules` 字段的角色归属。

### 嵌入式 HM 报"option not found"

模块在 `_common/nixos.nix` 中引用了 `home-manager.*` 选项，但该主机关闭了 HM 嵌入。

解决：

1. 使用 `snowveil.homeManager.backupFileExtension` 代替 `home-manager.backupFileExtension`
2. 或将该配置移到按角色过滤的模块

### VitePress 构建错误：`Element is missing end tag`

原因：Markdown 中有未转义的 `<` 或 `>`，VitePress 将其解析为 HTML 标签。

修复：将 `<name>` 等占位符改为代码块中使用，或在行内使用 `&lt;name&gt;`。

### `nix flake check` 报 `unknown flake output`

这是 Nix 对非标准 output（如 `deploy`、`options`、`homeModules`）的警告，不影响构建。预期行为。

## trace 调试

框架会在使用已弃用元数据字段或发现未导入的主机文件时输出 `builtins.trace` 警告：

```bash
nix flake check path:. --show-trace 2>&1 | grep "warning:"
```

常见 trace：

- `warning: meta.nix field 'embedHomeManager' is deprecated` → 使用了旧字段
- `warning: files ... under hosts/foo/ are not host magic files` → 该文件需由主机模块显式导入

## 隔离求值

仅求值一台主机，避免所有主机同时触发：

```bash
nix eval .#nixosConfigurations.nixos-desktop.config.system.stateVersion
nix build .#nixosConfigurations.nixos-desktop.config.system.build.toplevel
```
