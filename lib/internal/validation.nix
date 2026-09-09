# 验证 flake 输出声明（disabledOutputs、expectedOutputs、evalOutputs）
{ lib }:

{
  # 解析和验证 disabledOutputs 配置
  parseDisabledOutputs =
    { disabledOutputs }:
    if builtins.isList disabledOutputs then
      lib.genAttrs disabledOutputs (_: true)
    else if builtins.isAttrs disabledOutputs then
      lib.mapAttrs (_: names: lib.genAttrs names (_: true)) disabledOutputs
    else
      throw ''
        disabledOutputs must be a list of strings or an attrset mapping output names to lists of names
        got: ${builtins.typeOf disabledOutputs}'';

  # 检查是否禁用了特定输出
  isDisabledByName =
    {
      kind,
      name,
      disabledOutputs,
      disabledSet,
    }:
    if builtins.isList disabledOutputs then
      builtins.hasAttr "${kind}.${name}" disabledSet
      || (kind == "formatter" && name == "default" && builtins.hasAttr "formatter" disabledSet)
      || (kind == "deploy" && name == "default" && builtins.hasAttr "deploy" disabledSet)
    else
      builtins.hasAttr name (disabledSet.${kind} or { });

  # 检查特定系统的输出是否被禁用
  isDisabledForSystem =
    {
      kind,
      name,
      system,
      disabledOutputs,
      disabledSet,
      disabledByName,
    }:
    disabledByName kind name
    || (
      if builtins.isList disabledOutputs then
        builtins.hasAttr "${kind}.${system}.${name}" disabledSet
        || (kind == "formatter" && name == "default" && builtins.hasAttr "formatter.${system}" disabledSet)
      else
        builtins.hasAttr "${system}.${name}" (disabledSet.${kind} or { })
    );

  # 验证 outputs.expected 配置
  validateExpectedOutputs =
    { expectedOutputs }:
    let
      checkedExpectedOutputs =
        if builtins.isAttrs expectedOutputs then
          expectedOutputs
        else
          throw "outputs.expected must be an attribute set";

      expectedMode = checkedExpectedOutputs.mode or "subset";
      supportedExpectedFields = [
        "hosts"
        "homes"
        "packages"
        "apps"
        "checks"
        "devShells"
        "overlays"
        "nixosModules"
        "homeModules"
        "formatter"
        "deploy"
        "images"
      ];
      supportedExpectedFieldsSet = lib.genAttrs supportedExpectedFields (_: true);
      expectedFields = builtins.removeAttrs checkedExpectedOutputs [ "mode" ];
      unknownExpectedFields = lib.filter (name: !builtins.hasAttr name supportedExpectedFieldsSet) (
        builtins.attrNames expectedFields
      );
      checkedExpectedFields =
        if
          !builtins.hasAttr expectedMode {
            subset = true;
            exact = true;
          }
        then
          throw ''outputs.expected.mode must be "subset" or "exact"''
        else if unknownExpectedFields != [ ] then
          throw "outputs.expected contains unsupported fields: ${lib.concatStringsSep ", " unknownExpectedFields}"
        else
          expectedFields;
    in
    {
      inherit expectedMode checkedExpectedFields supportedExpectedFields;
    };

  # 验证 outputs.eval 配置
  validateEvalOutputs =
    { evalOutputs }:
    let
      checkedEvalOutputs =
        if builtins.isAttrs evalOutputs then evalOutputs else throw "outputs.eval must be an attribute set";

      evalKeys = builtins.attrNames checkedEvalOutputs;
      invalidEvalKeys = lib.filter (
        name:
        !builtins.hasAttr name {
          hosts = true;
          homes = true;
        }
      ) evalKeys;
    in
    if invalidEvalKeys != [ ] then
      throw "outputs.eval contains unsupported fields: ${lib.concatStringsSep ", " invalidEvalKeys}"
    else
      checkedEvalOutputs;

  # 验证和解析字符串列表或布尔值（用于 eval 选择）
  stringListOrBool =
    {
      label,
      value,
      available,
    }:
    if builtins.isBool value then
      if value then available else [ ]
    else if builtins.isList value && lib.all builtins.isString value then
      let
        selected = lib.unique value;
        availableSet = lib.genAttrs available (_: true);
        unknown = lib.filter (name: !builtins.hasAttr name availableSet) selected;
      in
      if unknown == [ ] then
        selected
      else
        throw "outputs.eval.${label} references undiscovered targets: ${lib.concatStringsSep ", " unknown}"
    else
      throw "outputs.eval.${label} must be a boolean or a list of strings";

  # 验证 outputs.diagnostics 配置
  validateDiagnostics =
    { diagnosticsOutputs }:
    let
      checkedDiagnosticsOutputs =
        if builtins.isAttrs diagnosticsOutputs then
          diagnosticsOutputs
        else
          throw "outputs.diagnostics must be an attribute set";

      diagnosticKeys = builtins.attrNames checkedDiagnosticsOutputs;
      supportedDiagnosticKeys = [
        "discovery"
        "moduleGraph"
        "perHostModuleGraph"
        "doctor"
        "expectedScaffold"
        "moduleCoverage"
      ];
      supportedDiagnosticKeysSet = {
        discovery = true;
        moduleGraph = true;
        perHostModuleGraph = true;
        doctor = true;
        expectedScaffold = true;
        moduleCoverage = true;
      };
      invalidDiagnosticKeys = lib.filter (
        name: !builtins.hasAttr name supportedDiagnosticKeysSet
      ) diagnosticKeys;
      diagnostics = {
        discovery = checkedDiagnosticsOutputs.discovery or true;
        moduleGraph = checkedDiagnosticsOutputs.moduleGraph or true;
        perHostModuleGraph = checkedDiagnosticsOutputs.perHostModuleGraph or false;
        doctor = checkedDiagnosticsOutputs.doctor or true;
        expectedScaffold = checkedDiagnosticsOutputs.expectedScaffold or true;
        moduleCoverage = checkedDiagnosticsOutputs.moduleCoverage or true;
      };
      invalidDiagnosticValues = lib.filter (
        name: !builtins.isBool diagnostics.${name}
      ) supportedDiagnosticKeys;
    in
    if invalidDiagnosticKeys != [ ] then
      throw "outputs.diagnostics contains unsupported fields: ${lib.concatStringsSep ", " invalidDiagnosticKeys}"
    else if invalidDiagnosticValues != [ ] then
      throw "outputs.diagnostics fields must be booleans: ${lib.concatStringsSep ", " invalidDiagnosticValues}"
    else
      diagnostics;
}
