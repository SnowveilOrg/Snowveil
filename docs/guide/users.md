# Users

`users/<name>/` 用于声明 NixOS 用户。用户与主机的关联由 `users/<name>/meta.nix` 中的 `hosts` 定义。

```text
users/
└── rhen/
    ├── meta.nix
    └── default.nix  # 可选
```

```nix
# users/rhen/meta.nix
{
  hosts = [ "desktop" ];
  uid = 1000;
  extraGroups = [ "wheel" ];
}
```

对于 `hosts` 中的每台主机，Snowveil 会写入默认的 `users.users.rhen` 和 `users.groups.rhen` 配置。`users/rhen/default.nix` 可用于覆盖默认字段或补充其他用户选项。

```nix
# users/rhen/default.nix
{ ... }:
{
  users.users.rhen.shell = "/run/current-system/sw/bin/fish";
}
```

若使用 sops，`hashedPasswordSecret` 可指定密钥名或绝对密码文件路径：

```nix
{
  hosts = [ "desktop" ];
  hashedPasswordSecret = "rhen-password";
}
```

关联主机的 Home Manager 配置位于 `homes/rhen/<host>.nix`。用法见[Home Manager](/guide/home-manager)，全部字段见 [`meta.nix` Reference](/reference/meta)。
