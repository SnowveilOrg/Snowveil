{
  description = "Snowveil: A Nix Flakes-based configuration framework";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
    }:
    let
      inherit (nixpkgs) lib;
      snowveil = import ./lib { inherit lib; };
      schema = import ./lib/schema.nix { };
      frameworkInputs = {
        inherit self nixpkgs home-manager;
      };
      bound = snowveil.mkLib { inputs = frameworkInputs; };
      selfChecks = import ./tests/flake-checks {
        inherit
          lib
          nixpkgs
          home-manager
          self
          snowveil
          ;
        repoRoot = ./.;
      };
      checks = selfChecks.checks;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      templates = {
        default = {
          path = ./templates/default;
          description = "Snowveil minimal working template";
        };
      };
      devShells = lib.genAttrs systems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.nix
              pkgs.nixfmt
              pkgs.deadnix
              pkgs.statix
              pkgs.nodejs
              pkgs.treefmt
              pkgs.mdformat
            ];
          };
        }
      );
      formatter = lib.genAttrs systems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          tools = [
            pkgs.treefmt
            pkgs.nixfmt
            pkgs.mdformat
            pkgs.statix
            pkgs.deadnix
          ];
          config = pkgs.writeText "treefmt.toml" (builtins.readFile ./treefmt.toml);
        in
        pkgs.writeShellScriptBin "fmt" ''
          export PATH=${pkgs.lib.makeBinPath tools}:$PATH
          exec ${pkgs.treefmt}/bin/treefmt --config-file ${config} "$@"
        ''
      );
      options = lib.genAttrs systems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          snowveilOpts = selfChecks.exampleFlake.nixosConfigurations.nixos-desktop.options.snowveil;
        in
        pkgs.writeText "snowveil-options.json" (builtins.toJSON (snowveil.renderOptions snowveilOpts))
      );
    in
    {
      lib = snowveil // {
        snowveil = bound;
        inherit templates checks options;
      };
      inherit
        templates
        checks
        devShells
        formatter
        options
        ;

      flakeOutputsSchema = schema.metaFlakeOutputs // {
        userFlakeOutputsNote = "User flakes will also include: nixosConfigurations, homeConfigurations, packages, apps, nixosModules, homeModules, overlays, images, deploy";
      };
    };
}
