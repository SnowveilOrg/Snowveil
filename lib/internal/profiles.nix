# profiles.nix — profile 定义的解析与校验（纯函数，可单测）
#
# profile 与 moduleGroups 的区别：
#   - moduleGroups 是模块侧声明的 all-of 硬依赖，不会自动启用成员；
#   - profiles 是主机侧声明的启用包，成员会被启用（仍走 override 与冲突校验）。
#
# 定义形状与 moduleGroups 一致：
#   - 字符串列表：成员在 NixOS 与 home 两侧同时生效
#   - { extends; common; nixos; home; }：可继承其他 profile，并分侧声明成员
{ lib }:

let
  utils = import ./utils.nix { inherit lib; };
  inherit (utils) readStringList;

  readProfile =
    {
      name,
      value,
      source,
    }:
    if name == "" then
      throw "profile name must be a non-empty string"
    else if builtins.isList value then
      let
        members = readStringList {
          field = name;
          inherit source value;
        };
      in
      if members == [ ] then
        throw "profile '${name}' (${source}) must not be empty"
      else
        {
          extends = [ ];
          nixos = members;
          home = members;
        }
    else if builtins.isAttrs value then
      let
        supportedFieldsSet = {
          extends = true;
          common = true;
          nixos = true;
          home = true;
        };
        unknownFields = lib.filter (field: !builtins.hasAttr field supportedFieldsSet) (
          builtins.attrNames value
        );
        common = readStringList {
          field = "${name}.common";
          inherit source;
          value = value.common or [ ];
        };
        nixos = readStringList {
          field = "${name}.nixos";
          inherit source;
          value = value.nixos or [ ];
        };
        home = readStringList {
          field = "${name}.home";
          inherit source;
          value = value.home or [ ];
        };
        extends = readStringList {
          field = "${name}.extends";
          inherit source;
          value = value.extends or [ ];
        };
      in
      if unknownFields != [ ] then
        throw "profile '${name}' (${source}) contains unsupported fields: ${lib.concatStringsSep ", " unknownFields}"
      else if extends ++ common ++ nixos ++ home == [ ] then
        throw "profile '${name}' (${source}) must not be empty"
      else
        {
          inherit extends;
          nixos = lib.unique (common ++ nixos);
          home = lib.unique (common ++ home);
        }
    else
      throw ''
        invalid profile definition

        profile '${name}' (${source}) must be either a list of strings or an attrset with extends/common/nixos/home fields
      '';

  # 从路径中截取到目标为止的后缀，用于拼接继承环的错误信息。
  dropUntil =
    target: values:
    if values == [ ] || lib.head values == target then values else dropUntil target (lib.tail values);

  resolveProfiles =
    definitions:
    let
      names = builtins.attrNames definitions;
      knownSet = lib.genAttrs names (_: true);

      # 先做一遍 DFS 校验（环优先于未知父级），错误信息与原先一致。
      visit =
        done: trail: name:
        if builtins.hasAttr name done then
          done
        else if builtins.elem name trail then
          throw "profile inheritance cycle: ${lib.concatStringsSep " -> " (dropUntil name trail ++ [ name ])}"
        else
          let
            definition = definitions.${name};
            unknown = lib.filter (parent: !builtins.hasAttr parent knownSet) definition.extends;
          in
          if unknown != [ ] then
            throw "profile '${name}' (${definition.source}) extends unknown profile(s): ${lib.concatStringsSep ", " unknown}"
          else
            lib.foldl' (acc: parent: visit acc (trail ++ [ name ]) parent) done definition.extends;
      check = lib.foldl' (done: name: visit done [ ] name) { } names;

      # 递归绑定配合 Nix 的惰性求值，使每个 profile 只解析一次（原先菱形继承会指数级重复求值）。
      resolved = lib.genAttrs names (
        name:
        let
          definition = definitions.${name};
        in
        {
          inherit (definition) source extends;
          nixos = lib.unique (
            lib.concatMap (parent: resolved.${parent}.nixos) definition.extends ++ definition.nixos
          );
          home = lib.unique (
            lib.concatMap (parent: resolved.${parent}.home) definition.extends ++ definition.home
          );
        }
      );
    in
    builtins.seq check resolved;

  checkMembers =
    {
      profile,
      source,
      side,
      members,
      knownNames,
    }:
    let
      knownSet = lib.genAttrs knownNames (_: true);
    in
    if lib.all (member: builtins.hasAttr member knownSet) members then
      members
    else
      let
        unknown = lib.filter (member: !builtins.hasAttr member knownSet) members;
      in
      throw ''
        profile references unknown module(s) (${side} side)

        profile '${profile}' (${source}) references: ${lib.concatStringsSep ", " unknown}

        hint: module names are derived from directory paths (e.g. desktop.hyprland).
        For side-specific modules, use the split form { nixos = [...]; home = [...]; }
      '';

  checkHostProfiles =
    {
      host,
      declared,
      knownProfiles,
    }:
    if lib.all (profile: builtins.hasAttr profile knownProfiles) declared then
      declared
    else
      let
        unknown = lib.filter (profile: !builtins.hasAttr profile knownProfiles) declared;
        available = builtins.attrNames knownProfiles;
      in
      throw ''
        host '${host}' declares unknown profile(s)

        unknown profiles: ${lib.concatStringsSep ", " unknown}
        ${
          if available == [ ] then
            "no profiles are defined in this project (create profiles/<name>.nix or pass mkFlake.profiles)"
          else
            "available profiles: ${lib.concatStringsSep ", " available}"
        }
      '';
in
{
  inherit
    readProfile
    resolveProfiles
    checkMembers
    checkHostProfiles
    ;
}
