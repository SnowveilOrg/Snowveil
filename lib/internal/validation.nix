# 验证 flake 输出声明（disabledOutputs、expectedOutputs、evalOutputs）
{ lib }:

let
  sortNames = lib.sort (a: b: a < b);
in

{
  # 解析和验证 disabledOutputs 配置
  parseDisabledOutputs =
    {
      disabledOutputs,
      errors,
    }:
    if builtins.isList disabledOutputs then
      lib.genAttrs disabledOutputs (_: true)
    else if builtins.isAttrs disabledOutputs then
      lib.mapAttrs (_: names: lib.genAttrs names (_: true)) disabledOutputs
    else
      errors.invalidDisabledOutputs (builtins.typeOf disabledOutputs);

  # 检查是否禁用了特定输出
  isDisabledByName =
    {
      lib,
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
      lib,
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
    {
      lib,
      expectedOutputs,
      errors,
    }:
    let
      checkedExpectedOutputs =
        if builtins.isAttrs expectedOutputs then
          expectedOutputs
        else
          errors.invalidExpectedOutputs;

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
          errors.invalidExpectedOutputsMode
        else if unknownExpectedFields != [ ] then
          errors.unsupportedExpectedOutputsFields unknownExpectedFields
        else
          expectedFields;
    in
    {
      inherit expectedMode checkedExpectedFields supportedExpectedFields;
    };

  # 验证 outputs.eval 配置
  validateEvalOutputs =
    {
      lib,
      evalOutputs,
      errors,
    }:
    let
      checkedEvalOutputs =
        if builtins.isAttrs evalOutputs then evalOutputs else errors.invalidDiagnosticsOutputs;

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
      errors.unexpectedEvalOutputsFields invalidEvalKeys
    else
      checkedEvalOutputs;

  # 验证和解析字符串列表或布尔值
  stringListOrBool =
    {
      label,
      value,
      available,
      errors,
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
        errors.unknownEvalTargets {
          kind = label;
          targets = unknown;
        }
    else
      errors.invalidEvalExpression {
        kind = label;
        type = builtins.typeOf value;
      };

  # 验证 outputs.diagnostics 配置
  validateDiagnostics =
    {
      lib,
      diagnosticsOutputs,
      errors,
    }:
    let
      checkedDiagnosticsOutputs =
        if builtins.isAttrs diagnosticsOutputs then
          diagnosticsOutputs
        else
          errors.invalidDiagnosticsOutputs;

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
      errors.invalidDiagnosticsField {
        fields = invalidDiagnosticKeys;
        supported = supportedDiagnosticKeys;
      }
    else if invalidDiagnosticValues != [ ] then
      errors.invalidDiagnosticsValue {
        fields = invalidDiagnosticValues;
      }
    else
      diagnostics;
}
