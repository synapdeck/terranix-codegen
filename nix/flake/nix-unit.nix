{
  inputs,
  lib,
  ...
}: let
  # Autodiscover all .test.nix files in the lib directory
  testFiles = builtins.filter (name: lib.hasSuffix ".test.nix" name) (
    builtins.attrNames (builtins.readDir ../lib)
  );

  # Import and merge all test files
  importTests = file: import (../lib + "/${file}") {inherit lib;};
  allTests = lib.foldl' (acc: file: acc // importTests file) {} testFiles;
in {
  imports = [
    inputs.nix-unit.modules.flake.default
  ];

  perSystem = {
    nix-unit.inputs = let
      sanitizeInput = input:
        if builtins.isAttrs input && input ? outPath
        then input.outPath
        else input;
    in
      builtins.mapAttrs (_: sanitizeInput) (builtins.removeAttrs inputs ["self"]);
  };

  # System-agnostic tests at the flake level
  flake.tests = allTests;
}
