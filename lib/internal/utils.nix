# 通用工具函数
{ lib }:

{
  # Validate and normalize a list of non-empty strings
  readStringList =
    {
      field,
      source,
      value,
    }:
    if builtins.isList value && lib.all (item: builtins.isString item && item != "") value then
      lib.unique value
    else
      throw ''
        invalid definition

        '${field}' in ${source} must be a list of non-empty strings
        current type: ${builtins.typeOf value}
      '';
  renderOptions =
    opts:
    let
      isOpt =
        o:
        builtins.isAttrs o
        && (
          (o._type or "") == "option"
          || (o ? type && builtins.isAttrs o.type && (o.type._type or "") == "option-type")
        );
      leaf = o: {
        type =
          let
            t = o.type or null;
          in
          if t == null then null else t.name or t.description or "unknown";
        description = o.description or null;
        default =
          let
            d = builtins.tryEval (o.default or null);
          in
          if d.success then (builtins.tryEval (builtins.toJSON d.value)).value else null;
      };
      go =
        o:
        if isOpt o then
          leaf o
        else if builtins.isAttrs o then
          lib.mapAttrs (_: go) o
        else
          o;
    in
    lib.mapAttrs (_: go) opts;
}
