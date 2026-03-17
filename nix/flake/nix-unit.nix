{
  inputs,
  lib,
  ...
}: let
  # Autodiscover all .test.nix files in the lib directory
  libTestFiles = builtins.filter (name: lib.hasSuffix ".test.nix" name) (
    builtins.attrNames (builtins.readDir ../lib)
  );

  # Import and merge all lib test files (system-agnostic, take {lib})
  importLibTests = file: import (../lib + "/${file}") {inherit lib;};
  libTests = lib.foldl' (acc: file: acc // importLibTests file) {} libTestFiles;

  # Autodiscover all .test.nix files in the generators directory
  generatorTestFiles = builtins.filter (name: lib.hasSuffix ".test.nix" name) (
    builtins.attrNames (builtins.readDir ../generators)
  );
in {
  imports = [
    inputs.nix-unit.modules.flake.default
  ];

  perSystem = {
    pkgs,
    self',
    system,
    ...
  }: {
    nix-unit.inputs = let
      sanitizeInput = input:
        if builtins.isAttrs input && input ? outPath
        then input.outPath
        else input;
    in
      builtins.mapAttrs (_: sanitizeInput) (builtins.removeAttrs inputs ["self"]);

    # All tests live under perSystem.nix-unit.tests so they appear at
    # tests.systems.<system> (managed by the nix-unit flake module).
    # Lib tests are pure Nix and evaluate identically under any system.
    nix-unit.tests = let
      importGenTests =
        lib.foldl' (
          acc: file:
            acc
            // import (../generators + "/${file}") {
              inherit pkgs;
              inherit (self'.packages) terranix-codegen;
            }
        ) {}
        generatorTestFiles;
    in
      libTests // importGenTests;

    devshells.default = {
      commands = [
        {
          name = "nix-test";
          help = "Run `nix-unit` tests";
          command = "nix-unit --flake .#tests.systems.${system}";
        }
      ];

      packages = with pkgs; [
        nix-unit
      ];
    };
  };
}
