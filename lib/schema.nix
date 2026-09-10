# Snowveil flake output schemas
# ===============================
# 遵循 Determinate Systems flake-schemas 的 schema 约定
# （version / doc / inventory），用于生成 flake 的 `schemas` output，
# 让 nix flake show、IDE 与第三方工具识别 Snowveil 生成的非标准 outputs
# （images、deploy）。标准 outputs（packages、checks、nixosModules、
# homeModules 等）的 schema 来自 inputs.flake-schemas.exportedSchemas，
# 本文件只补充 Snowveil 专属部分，调用方负责 `//` 合并。

let
  mkChildren = children: { inherit children; };
in
{
  snowveilSchemas = {
    images = {
      version = 1;
      doc = ''
        The `images` flake output contains NixOS system images (ISO, VM, OCI,
        ...) built per host and image format via `system.build.images`.
      '';
      inventory =
        output:
        mkChildren (
          builtins.mapAttrs (host: formats: {
            what = "NixOS image set";
            children = builtins.mapAttrs (format: image: {
              forSystems = [ image.system ];
              shortDescription = image.meta.description or "";
              derivationAttrPath = [ ];
              what = "NixOS image";
            }) formats;
          }) output
        );
    };

    deploy = {
      version = 1;
      doc = ''
        The `deploy` flake output contains deploy-rs compatible deployment
        configuration, with one entry per target node.
      '';
      inventory =
        output:
        let
          nodes = output.nodes or { };
        in
        mkChildren (
          builtins.mapAttrs (name: _node: {
            what = "deploy node";
          }) nodes
        );
    };
  };
}
