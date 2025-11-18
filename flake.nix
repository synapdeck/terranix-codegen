{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    haskell-flake.url = "github:srid/haskell-flake";
  };
  outputs = inputs @ {
    nixpkgs,
    flake-parts,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = nixpkgs.lib.systems.flakeExposed;
      imports = [inputs.haskell-flake.flakeModule];

      perSystem = {self', ...}: {
        haskellProjects.default = {
          devShell = {
            tools = hp: {
              inherit (hp) cabal-gild;
            };
          };
        };

        apps.default = self'.apps.terranix-codegen;
        packages.default = self'.packages.terranix-codegen;
      };
    };
}
