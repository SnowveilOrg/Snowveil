# 模块过滤和覆盖逻辑
{ lib }:

{
  # 验证 modules 覆盖结构
  # overrides: { "desktop.gaming" = false; "development.rust" = true; }
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
}
