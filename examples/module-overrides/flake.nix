{
  description = "Snowveil - Module Overrides Example";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    snowveil.url = "path:../..";
    snowveil.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      snowveil,
    }:
    snowveil.lib.mkFlake {
      inputs = { inherit self nixpkgs; };
      systems = [ "x86_64-linux" ];
      root = ./.;
    };
}
