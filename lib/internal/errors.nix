# 统一的错误消息定义
# 避免整个代码库中错误消息格式不一致
{ lib }:

{
  missingFlakeInput =
    name:
    throw ''
      error: missing required flake input

      Snowveil requires inputs.${name}
      make sure '${name}' is included in your flake inputs'';

  missingHostSystem =
    host:
    throw ''
      error: host system not declared

      hosts/${host}/meta.nix must declare system (e.g. system = "x86_64-linux")
      see documentation: https://github.com/SnowveilOrg/Snowveil/docs/guide'';

  unknownHost =
    host:
    throw ''
      error: host not discovered

      host '${host}' was not discovered
      create hosts/${host}/ with the following structure:
        hosts/${host}/
          ├── default.nix     (required)
          ├── meta.nix        (required, must declare system)
          ├── hardware.nix    (optional)
          ├── disk.nix        (optional)
          └── network.nix     (optional)'';

  missingHomeManager =
    hosts:
    throw ''
      error: home-manager not available

      host(s) ${lib.concatStringsSep ", " hosts} have associated homes but no home-manager input
      solution: add home-manager to your flake inputs
      example:
        inputs.home-manager = {
          url = "github:nix-community/home-manager";
          inputs.nixpkgs.follows = "nixpkgs";
        };'';

  invalidRoleType =
    type:
    throw ''
      error: invalid role type

      host role/roles must be a string or list of strings
      got: ${type}'';

  invalidProfileType =
    type:
    throw ''
      error: invalid profile type

      host profiles must be a string or list of strings
      got: ${type}'';

  invalidMetadataType =
    {
      file,
      expected,
      got,
    }:
    throw ''
      error: invalid metadata in ${file}

      expected: ${expected}
      got: ${got}'';

  unknownProfile =
    {
      host,
      profile,
      knownProfiles,
    }:
    throw ''
      error: unknown profile '${profile}' in host '${host}'

      known profiles:
      ${lib.concatStringsSep "\n" (map (p: "  - ${p}") knownProfiles)}'';

  duplicateProfiles =
    duplicates:
    throw ''
      error: profile name conflict

      the following profiles are defined in both profiles/ and mkFlake.profiles:
      ${lib.concatStringsSep "\n" (map (p: "  - ${p}") duplicates)}
      keep only one definition per profile'';

  invalidModuleOverride =
    {
      moduleName,
      value,
    }:
    throw ''
      error: invalid module override

      modules.${moduleName} must be a boolean or null
      got: ${builtins.typeOf value}'';

  unknownModule =
    {
      kind,
      names,
    }:
    throw ''
      error: unknown ${kind}

      the following names do not match discovered ${kind}:
      ${lib.concatStringsSep "\n" (map (n: "  - ${n}") names)}
      check your meta.nix configuration'';

  invalidPackageScope =
    {
      packageName,
      scope,
    }:
    throw ''
      error: invalid package scope for '${packageName}'

      snowveil.packages.${packageName}.scope must be either "system" or "home"
      got: ${scope}'';

  duplicateDefinitions =
    {
      kind,
      system,
      names,
    }:
    throw ''
      error: duplicate definitions in ${kind}.${system}

      the following names are defined multiple times:
      ${lib.concatStringsSep "\n" (map (n: "  - ${n}") names)}'';

  invalidDisabledOutputs =
    type:
    throw ''
      error: invalid disabledOutputs type

      disabledOutputs must be a list of strings or an attrset mapping output names to lists
      got: ${type}'';

  invalidExpectedOutputs =
    throw ''
      error: invalid outputs.expected type

      outputs.expected must be an attribute set'';

  invalidExpectedOutputsMode =
    throw ''
      error: invalid outputs.expected.mode

      outputs.expected.mode must be "subset" or "exact"'';

  unsupportedExpectedOutputsFields =
    fields:
    throw ''
      error: unsupported fields in outputs.expected

      supported fields: hosts, homes, packages, apps, checks, devShells, overlays, nixosModules, homeModules, formatter, deploy, images
      unsupported: ${lib.concatStringsSep ", " fields}'';

  unexpectedEvalOutputsFields =
    fields:
    throw ''
      error: unsupported fields in outputs.eval

      supported fields: hosts, homes
      unsupported: ${lib.concatStringsSep ", " fields}'';

  unknownEvalTargets =
    {
      kind,
      targets,
    }:
    throw ''
      error: outputs.eval.${kind} references undiscovered targets

      ${lib.concatStringsSep "\n" (map (t: "  - ${t}") targets)}'';

  invalidEvalExpression =
    {
      kind,
      type,
    }:
    throw ''
      error: invalid outputs.eval.${kind} expression

      must be a boolean or a list of strings
      got: ${type}'';

  invalidDiagnosticsOutputs =
    throw ''
      error: invalid outputs.diagnostics type

      outputs.diagnostics must be an attribute set'';

  invalidDiagnosticsField =
    {
      fields,
      supported,
    }:
    throw ''
      error: unsupported fields in outputs.diagnostics

      supported: ${lib.concatStringsSep ", " supported}
      unsupported: ${lib.concatStringsSep ", " fields}'';

  invalidDiagnosticsValue =
    {
      fields,
    }:
    throw ''
      error: invalid outputs.diagnostics field values

      the following fields must be booleans:
      ${lib.concatStringsSep "\n" (map (f: "  - ${f}") fields)}'';

  metadataFileMustReturnAttrSet =
    {
      path,
      type,
    }:
    throw ''
      error: metadata file must return an attribute set

      file: ${toString path}
      got: ${type}
      remove function wrappers or null returns'';

  missingUserHosts =
    user:
    throw ''
      error: user hosts not declared

      users/${user}/meta.nix must declare hosts
      example:
        hosts = [ "nixos-desktop" "nixos-laptop" ]'';

  invalidUserHosts =
    user:
    throw ''
      error: invalid user hosts

      users/${user}/meta.nix hosts must be a list of strings
      example:
        hosts = [ "nixos-desktop" "nixos-laptop" ]'';

  invalidHostRolesType =
    {
      host,
      type,
    }:
    throw ''
      error: invalid host roles type

      hosts/${host}/meta.nix roles must be a string or list of strings
      got: ${type}
      example:
        roles = "workstation";
        # or
        roles = [ "workstation" "development" ];'';
}
