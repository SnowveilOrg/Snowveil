{ lib }:

# Snowveil v1 namespace — thin wrapper around the canonical lib/default.nix
# All logic lives in the parent; this file only re-exports under the
# { snowveil = { ... }; } shape expected by the v1 public API.

let
  core = import ../default.nix { inherit lib; };
in
{
  snowveil = {
    inherit (core)
      mkLib
      mkFlake
      forAllSystems
      renderOptions
      version
      importModules
      flattenTree
      groupModules
      patches
      source
      ;
  };
}
