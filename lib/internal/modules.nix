# 模块过滤和覆盖逻辑
{ lib }:

let
  # 将路径转换为模块名称
  # modules/desktop/gaming/nixos.nix → "desktop.gaming"
  # modules/_common/base/default.nix → "_common.base"
  pathToModuleName =
    path:
    let
      # 将 /path/to/modules/desktop/gaming/nixos.nix 转换为 desktop/gaming
      pathString = builtins.toString path;
      # 查找 /modules/ 后面的部分
      splitParts = lib.splitString "/modules/" pathString;
    in
    if lib.length splitParts >= 2 then
      let
        afterModulesDirectory = lib.last splitParts;
        # 移除最后的文件名（nixos.nix, home.nix, default.nix）
        directoryPath = builtins.dirOf afterModulesDirectory;
        # 用点替换斜杠
        dotSeparatedName = lib.replaceStrings [ "/" ] [ "." ] directoryPath;
      in
      if dotSeparatedName == "" || dotSeparatedName == "." then null else dotSeparatedName
    else
      null;

  # 应用 meta.nix 中的模块覆盖
  # overrides: { "desktop.gaming" = false; "development.rust" = true; }
  # modules: 发现的模块路径列表
  applyModuleOverrides =
    { overrides, modules }:
    let
      isModuleEnabled =
        modulePath:
        let
          resolvedModuleName = pathToModuleName modulePath;
        in
        if resolvedModuleName == null then
          true
        else
          let
            overrideValue = overrides.${resolvedModuleName} or null;
          in
          if overrideValue == null then true else overrideValue;
    in
    lib.filter isModuleEnabled modules;

  # 验证 modules 覆盖结构
  validateModuleOverrides =
    overrides:
    if !builtins.isAttrs overrides then
      throw "modules in meta.nix must be an attrset, got ${builtins.typeOf overrides}"
    else
      lib.mapAttrs (
        name: value:
        if builtins.isBool value || value == null then
          value
        else
          throw "modules.${name} must be a boolean or null, got ${builtins.typeOf value}"
      ) overrides;
in

{
  inherit pathToModuleName applyModuleOverrides validateModuleOverrides;
}
