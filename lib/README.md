# Snowveil - Library Structure

本目录包含框架的所有库代码。

## 当前结构

### 核心模块（已稳定）

- **default.nix** - 主入口点，导出 `mkFlake`, `mkLib`, `forAllSystems`, `renderOptions`, `version`, `patches`, `source`, `sops` 等公共 API（通过 `mkLib` 或绑定实例暴露 `mkSystem`, `mkHome`）
- **discover.nix** - 目录自动发现系统（hosts, users, homes, packages, overlays 等）
- **host.nix** - 主机元数据处理和角色过滤
- **user.nix** - 用户元数据归一化与 `users.users` / `users.groups` 生成
- **sops.nix** - SOPS 密钥管理帮助函数
- **patches.nix** - 补丁应用工具函数（`local`, `fromCommit`, `fromPR`）
- **fs.nix** - 文件系统树遍历工具

### 内部模块（框架开发用）

- **internal/options.nix** - 框架内置的 NixOS/Home Manager 选项定义
- **internal/utils.nix** - 通用工具函数（选项渲染等）
- **internal/modules.nix** - 模块分析与合并逻辑
- **internal/depgraph.nix** - 模块依赖图与拓扑排序
- **internal/outputs.nix** - 输出构造与规范化
- **internal/validation.nix** - 输出与元数据校验

## 重构演进

代码库持续进行模块化拆分与解耦：

- 当前版本（`0.5.0-dev`）
- 重构保持**渐进式**，保障公共 API 稳定与向下兼容
- 所有公共函数（`mkFlake`, `mkLib`, `mkSystem`, `mkHome` 等）保持兼容性
