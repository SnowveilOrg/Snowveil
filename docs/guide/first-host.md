# 第一个 Host

一个 Host 就是一台 NixOS 机器。创建 `hosts/<name>/`，其中 `meta.nix` 声明框架在发现阶段需要的信息，`default.nix` 则是普通 NixOS module。

```text
hosts/
└── desktop/
    ├── meta.nix
    ├── default.nix
    ├── hardware.nix  # 可选
    └── network.nix   # 可选
```

## 1. 声明主机元数据

`system` 是唯一必填字段。不要从目录名猜测架构。

```nix
# hosts/desktop/meta.nix
{
  system = "x86_64-linux";
  roles = [ "desktop" "development" ];
}
```

Roles 决定哪些模块目录会被选中；它们不等于 NixOS option 开关。稍后可在[Roles、Profiles 与 Modules](/guide/composition)了解选择方式。

## 2. 写 NixOS 配置

```nix
# hosts/desktop/default.nix
{ pkgs, ... }:
{
  networking.hostName = "desktop";
  environment.systemPackages = [ pkgs.git ];
  system.stateVersion = "25.05";
}
```

它和传给 `nixosSystem` 的任意 NixOS module 完全一样，因此能正常接收 `config`、`pkgs`、`lib` 等参数。

## 3. 添加硬件或网络配置

Snowveil 仅自动加载主机目录的 magic 文件，顺序固定为 `default.nix`、`hardware.nix`、`disk.nix`、`network.nix`。非 magic 的 Nix 文件不会自动导入。

```nix
# hosts/desktop/hardware.nix
{ ... }:
{
  boot.initrd.availableKernelModules = [ "ahci" ];
}
```

## 4. 构建或切换

```bash
nix build .#nixosConfigurations.desktop.config.system.build.toplevel
sudo nixos-rebuild switch --flake .#desktop
```

若看到 `hosts/desktop/meta.nix must define system`，请添加第一步中的 `system` 字段。更多可复制的修复方法见[调试与问题排查](/advanced/debugging)。
