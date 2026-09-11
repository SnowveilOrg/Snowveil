# 示例项目

仓库中的 [`examples/basic`](https://github.com/SnowveilOrg/Snowveil/tree/main/examples/basic) 可以直接运行。下面按目录说明其结构；它还包含 packages、overlays、apps、checks 和 shell。

```text
snowveil-example/
├── flake.nix
├── hosts/
│   ├── desktop/
│   └── server/
├── users/
│   └── alice/
├── homes/
│   └── alice/
├── modules/
│   ├── _common/
│   ├── desktop/
│   ├── server/
│   └── development/
└── profiles/
    ├── workstation.nix
    └── server.nix
```

## 1. 定义 Flake 入口

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    snowveil.url = "github:SnowveilOrg/Snowveil";
  };

  outputs = inputs: inputs.snowveil.lib.mkFlake { inherit inputs; };
}
```

此处不列出主机和模块。`mkFlake` 在项目根目录发现约定目录。

## 2. 添加 Hosts

```nix
# hosts/desktop/meta.nix
{
  system = "x86_64-linux";
  roles = [ "desktop" "development" ];
  profiles = [ "workstation" ];
}
```

```nix
# hosts/desktop/default.nix
{ ... }:
{
  networking.hostName = "desktop";
  system.stateVersion = "25.05";
}
```

为服务器创建同样的目录，并用 `roles = [ "server" ];` 和 `profiles = [ "server" ];` 区分配置。每个目录生成一个 `nixosConfigurations.<name>`。

## 3. 添加 User 和 Home

```nix
# users/alice/meta.nix
{
  hosts = [ "desktop" "server" ];
  uid = 1000;
  extraGroups = [ "wheel" ];
}
```

```nix
# homes/alice/desktop.nix
{ ... }:
{
  home.stateVersion = "25.05";
}
```

`users/alice/meta.nix` 将系统用户安装到列出的主机。`homes/alice/desktop.nix` 生成 `homeConfigurations."alice@desktop"`，并可嵌入 desktop 的 NixOS 配置。

## 4. 添加 Modules

```text
modules/
├── _common/base/nixos.nix
├── desktop/firefox/home.nix
├── development/tools/home.nix
└── server/nginx/nixos.nix
```

`_common` 始终加载；`desktop`、`development` 和 `server` 目录由 Host 的 roles 过滤。模块内容和 magic 文件说明见[Modules](/guide/modules)。

## 5. 添加 Profiles

```nix
# profiles/workstation.nix
{
  nixos = [ "desktop.firefox" ];
  home = [ "development.tools" ];
}
```

Profile 启用列出的模块。Role 决定模块目录是否加载；具体区别见[Roles](/guide/roles)和[Profiles](/guide/profiles)。

## 6. 检查结果

```bash
git clone https://github.com/SnowveilOrg/Snowveil.git
cd Snowveil/examples/basic
nix flake show
```

输出大致如下：

```text
nixosConfigurations
├── desktop
└── server

homeConfigurations
└── alice@desktop
```

构建或切换某个主机：

```bash
sudo nixos-rebuild switch --flake .#desktop
```

需要查看框架发现的对象时，构建 discovery report：

```bash
nix build .#checks.x86_64-linux.snowveil-discovery
cat result | python3 -m json.tool
```

该 report 是当前提供的 discovery 调试入口；命令行输出形式的 `snowveil-discovery` app 尚未提供。
