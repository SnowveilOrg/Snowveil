# 设计理念

## 核心原则

**约定优于配置**（Convention over Configuration）。

框架的核心命题是：一个合理的目录结构比任何手写 import 列表都更可读、更稳定。用户不应该需要知道 `nixosConfigurations` 的内部构造，只需按约定放置文件。

## 独立性是结果，不是目的

框架自身**零 `flake-utils` / `flake.parts` 运行时依赖**，完全基于纯 `nixpkgs.lib` 实现。这个选择的动机是：

- **降低认知负荷**：无需为了组织几台主机而学习复杂抽象的第三方 Flake 模块系统 DSL。
- **保持发现确定性**：目录文件树直接一对一映射到输出 outputs，中间无隐式黑盒机制���
- **避免依赖传染**：配置仓库引入 Snowveil 不会拉入冗长的 flake.lock 依赖链，保持 lock 文件的极致精简。

### 为什么不采用 Snowfall 或 Flake-parts？

| 方案 | 优势 | 为什么 Snowveil 重新设计 |
| ---- | ---- | ----------------------- |
| **flake.parts** | 提供了通用的模块化 Flake 系统 | 它是 Flake 级别的通用模块系统，更适合编写复杂库或通用工具；但对于配置系统来说，仍需手写大量 glue 代码来映射主机与配置。 |
| **snowfallorg/lib** | 同样基于目录约定生成 outputs | 依赖深度绑定的上游生态（如 flake-utils-plus），且模块分类与多目标分拣逻辑偏向特定 opinionated 结构；Snowveil 采用轻量单树扫描与原生 options/nixos/home 三 magic 分拣。 |

如果你正从其他框架迁移，可参考对应的平滑迁移方案：
- [从普通 Flake 迁移](/migration/from-plain-flake)
- [从 Snowfall 迁移](/migration/from-snowfall)
- [从 flake-parts 迁移](/migration/from-flake-parts)
- [从 nixos-unified 迁移](/migration/from-nixos-unified)

> 与实践指南的对应关系：
> - 目录扫描对应 [Discovery 规范](/reference/discovery) 与 [项目结构](/guide/directory-structure)。
> - 主机与配置装配对应 [Hosts 指南](/guide/hosts) 与 [Core API 参考](/reference/core)。

## 两类用户

框架区分两类用户：

| 类型 | 接触的概念 |
| ---- | ---------- |
| 普通用户 | 目录约定、`meta.nix`、角色、模块魔法文件 |
| 高级用户 | `mkFlake` 分组参数、`mkSystem`/`mkHome` 逃生舱、`outputs.extra` |

绝大多数场景不需要碰 `mkSystem`。

## 发现 vs 模块系统

框架的职责分为两层：

- **发现层**：纯文件系统扫描，不求值任何 Nix 配置。产出发现清单（主机、模块、包等），这是框架真正有价值的核心。
- **组合层**：将发现清单传给 NixOS / home-manager 模块系统，模块系统完成真正的配置合并。

框架不替代模块系统，也不在模块系统之外实现一套配置继承机制。

## meta.nix vs default.nix 分离

框架元数据（角色、嵌入策略等）放 `meta.nix`，NixOS 配置放 `default.nix`。这个分离的意义：

- `meta.nix` 在发现阶段静态求值（纯属性集），不需要 `config`
- `default.nix` 只交给 NixOS module system，可以安全使用真实 `config`
- 两个文件的职责互不干扰

旧版本支持在 `default.nix` 顶层声明角色等元数据（兼容路径），但需要额外的探测调用，已弃用。

## 框架边界

Snowveil 的核心是发现引擎（`lib/discover.nix`）。周边的 patches helper、sops helper 是**可选扩展**，不是核心承诺。随着生态演进，这些扩展可能独立化或移到用户仓库。

框架不内置部署工具、镜像构建逻辑或 CI 流水线——这些通过约定目录（`deploy/`、`images/`）和 `outputs.extra` 交给用户工具链处理。
