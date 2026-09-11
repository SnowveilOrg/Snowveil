# Metadata

`meta.nix` 供 Snowveil 在扫描阶段读取。它说明目录对应的主机、用户或 output 应如何处理；NixOS 和 Home Manager 配置仍写在 `default.nix` 等模块文件中。

| 文件 | 作用 | 求值阶段 |
| ---- | ---- | -------- |
| `meta.nix` | Snowveil 读取的目录信息 | 扫描阶段，纯属性集 |
| `default.nix` | NixOS 模块配置 | NixOS module system |

`meta.nix` 不是 NixOS 模块，不接受 `config`、`pkgs`、`lib` 等模块参数。

## Host Metadata

```nix
# hosts/<name>/meta.nix
{
  system = "x86_64-linux";

  # 角色：过滤 modules/ 下哪些目录被注入该主机
  roles = [ "desktop" "development" ];
  # role = "desktop";  # 单值别名

  # HM 嵌入策略（null 表示继承 mkFlake 全局值）
  home.embed = true;
  home.useGlobalPkgs = true;

  # 镜像格式（在发现阶段读取，避免强制求值整个 config）
  images.formats = [ "iso" ];
}
```

## Compatibility

兼容字段和旧式主机目录命名仅用于迁移，详见[Discovery Specification](/reference/discovery)与迁移页面；新配置只应使用 `roles`、`home.embed` 和 `home.useGlobalPkgs`。

## 优先级

```
主机 meta.nix 字段  >  mkFlake 全局参数  >  框架硬编码默认值
```

## Output Metadata

```nix
# packages/<name>/meta.nix 或 checks/<name>/meta.nix
{
  enable = true;          # false 时不生成该 output
  systems = [ "x86_64-linux" ];  # 限制架构（null 表示所有 systems）
}
```

## Module Metadata

`hosts/<name>/meta.nix` 还可以选择模块、overlay 和自动安装的 package。未选中的模块不会导入，未选中的 overlay 不会进入该主机的 `pkgs`。

```nix
{
  snowveil = {
    modules.desktop.gaming.enable = false;
    overlays.unstable.enable = false;
    packages = {
      helix = {
        enable = true;
        scope = "system";
      };
      devenv = {
        enable = true;
        scope = "home";
      };
    };
  };
}
```

- `snowveil.modules.<role>.<module>.enable`：控制模块是否导入；旧字段 `modules."<role>.<module>" = false` 仅为迁移保留。
- `snowveil.overlays.<name>.enable`：控制自动发现 overlay 是否应用到该主机，以及其关联 home-manager 的包集合。
- `snowveil.packages.<name>`：选择自动安装的 `packages/<name>`；`scope` 为 `"system"` 时写入 `environment.systemPackages`，为 `"home"` 时写入关联用户的 `home.packages`。默认 scope 为 `"system"`。

## Home Metadata

homes 目录当前不读取 `meta.nix`；位置保留供未来使用（如多架构全局 home 的 system 声明）。

## 限制

- `meta.nix` 必须直接返回属性集，不能是函数。
- 违反此约定在发现阶段 `throw` 报错。
- `meta.nix` 中不能引用 `pkgs`、`config` 等运行时值。
