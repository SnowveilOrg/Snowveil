# 处理 flake 输出的通用逻辑（packages、apps、checks 等）
# 这个模块处理系统特定的输出生成和元数据验证
{ lib }:

{
  # 验证具有元数据 enable 和 systems 字段的定义
  metadataEnabled =
    {
      kind,
      name,
      meta,
      system,
      disabledForSystem,
    }:
    let
      enabled = meta.enable or true;
      supportedSystems = meta.systems or null;
    in
    if !builtins.isBool enabled then
      throw "error: invalid meta value

  ${kind}.${name} meta.enable must be a boolean
  got: ${builtins.typeOf enabled}"
    else if
      supportedSystems != null
      && !(builtins.isList supportedSystems && lib.all builtins.isString supportedSystems)
    then
      throw "error: invalid meta value

  ${kind}.${name} meta.systems must be a list of strings
  got: ${builtins.typeOf supportedSystems}"
    else
      enabled
      && (supportedSystems == null || builtins.elem system supportedSystems)
      && !disabledForSystem kind name system;

  # 检查定义中的重复名称
  uniqueDefinitions =
    kind: system: definitions:
    let
      grouped = lib.groupBy (definition: definition.name) definitions;
      duplicates = builtins.attrNames (lib.filterAttrs (_: values: builtins.length values > 1) grouped);
    in
    if duplicates == [ ] then
      definitions
    else
      throw "error: duplicate names detected

  ${kind}.${system} contains duplicate definitions:
  ${lib.concatStringsSep ", " duplicates}";

  # 为给定系统构建命名输出的属性集（packages、apps、checks 等）
  # 返回格式: { sys1 = { name1 = ...; name2 = ...; }; sys2 = { ... }; }
  namedSystemOutputs =
    {
      lib,
      kind,
      systems,
      definitions,
      metadataEnabled,
      uniqueDefinitions,
      callPackage,
      pkgsBySystem,
    }:
    lib.genAttrs systems (
      sys:
      let
        pkgs = pkgsBySystem.${sys};
        enabled = lib.filter (
          d:
          metadataEnabled {
            inherit kind;
            inherit (d) name meta;
            system = sys;
          }
        ) definitions;
        unique = uniqueDefinitions kind sys enabled;
      in
      lib.listToAttrs (map (d: lib.nameValuePair d.name (callPackage pkgs d.path)) unique)
    );
}
