# Hosts

每个 `hosts/<name>/` 目录对应一个 NixOS 主机，并生成 `nixosConfigurations.<name>`。

```text
hosts/
└── desktop/
    ├── meta.nix
    ├── default.nix
    ├── hardware.nix  # 可选
    ├── disk.nix      # 可选
    └── network.nix   # 可选
```

`meta.nix` 是发现阶段读取的属性集，必须声明系统架构：

```nix
# hosts/desktop/meta.nix
{
  system = "x86_64-linux";
  roles = [ "desktop" "development" ];
}
```

`default.nix` 是普通 NixOS module：

```nix
# hosts/desktop/default.nix
{ pkgs, ... }:
{
  networking.hostName = "desktop";
  environment.systemPackages = [ pkgs.git ];
  system.stateVersion = "25.05";
}
```

`default.nix`、`hardware.nix`、`disk.nix`、`network.nix` 会按此顺序导入。其他 `.nix` 文件需要由这些文件显式导入。

```bash
sudo nixos-rebuild switch --flake .#desktop
```

字段说明见 [`meta.nix` Reference](/reference/meta)；多个主机的共享方式见[多主机配置](/guide/multiple-hosts)。
