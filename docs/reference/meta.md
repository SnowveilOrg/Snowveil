# meta.nix Reference

`meta.nix` 是 Snowveil 的发现阶段接口。它必须直接返回属性集，不能是 NixOS 或 Home Manager module，因此不能依赖 `config`、`pkgs` 或其他运行时模块参数。

## Host：`hosts/<name>/meta.nix`

```nix
{
  system = "x86_64-linux";
  roles = [ "desktop" "development" ];

  home = {
    embed = true;
    useGlobalPkgs = true;
  };

  profiles = [ "workstation" ];
}
```

| 字段 | 类型 | 默认值 | 作用 |
| --- | --- | --- | --- |
| `system` | string | 必填 | 主机系统架构，例如 `x86_64-linux`。 |
| `roles` | list of string | `null` | 决定角色目录中的哪些模块注入主机。 |
| `role` | string | `null` | `roles` 的单值兼容别名。 |
| `profiles` | list of string | `[]` | 启用 `profiles/` 中定义的功能集合。 |
| `home.embed` | bool | 继承全局设置 | 是否把关联 Home Manager 配置嵌入 NixOS。 |
| `home.useGlobalPkgs` | bool | 继承全局设置 | 嵌入式 HM 是否复用 NixOS 的 `pkgs`。 |
| `images.formats` | list of string | `null` | 在发现阶段声明镜像格式。 |
| `snowveil.modules.<role>.<module>.enable` | bool | `true` | 覆盖某个发现模块的选择状态。 |
| `snowveil.overlays.<name>.enable` | bool | `true` | 覆盖发现 overlay 是否应用到该主机。 |
| `snowveil.packages.<name>` | attrset | 未选择 | 选择自动安装的 package；可设 `enable` 与 `scope`。 |

`scope = "system"` 安装到 `environment.systemPackages`；`scope = "home"` 安装到关联用户的 `home.packages`。

## User：`users/<name>/meta.nix`

```nix
{
  hosts = [ "desktop" ];
  uid = 1000;
  extraGroups = [ "wheel" ];
  hashedPasswordSecret = "rhen-password";
}
```

| 字段 | 类型 | 默认值 | 作用 |
| --- | --- | --- | --- |
| `hosts` | list of string | 必填 | 用户关联的主机，是系统用户生成的来源。 |
| `uid` | integer | 自动处理 | 用户 UID。 |
| `extraGroups` | list of string | `[]` | 额外 Unix groups。 |
| `hashedPasswordSecret` | string | `null` | sops 密钥名，或以 `/` 开头的密码文件路径。 |

框架为关联主机生成默认的 `users.users.<name>` 和 `users.groups.<name>` 配置；可在 `users/<name>/default.nix` 覆盖或补充。

## Package、App 与 Check：`meta.nix`

`packages/<name>/meta.nix`、`apps/<name>/meta.nix` 和 `checks/<name>/meta.nix` 可使用：

| 字段 | 类型 | 默认值 | 作用 |
| --- | --- | --- | --- |
| `enable` | bool | `true` | 设为 `false` 时不生成该 output。 |
| `systems` | list of string | 所有支持系统 | 限制生成 output 的系统。 |

## Module、Profile 与 Home

- module 目录的 `meta.nix` 用于模块依赖和顺序，见[模块依赖](/guide/module-dependencies)。
- profile 文件是 `profiles/<name>.nix`，不是 `meta.nix`；见[Roles、Profiles 与 Modules](/guide/composition)。
- 当前 `homes/` 不读取 `meta.nix`。配置放在 `homes/<user>/default.nix` 或 `homes/<user>/<host>.nix`。

字段的完整、实现级约束和兼容字段请阅读[Discovery Specification](/reference/discovery)。
