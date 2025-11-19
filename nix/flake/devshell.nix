{
  perSystem = {
    pkgs,
    config,
    ...
  }: {
    devShells.default = pkgs.mkShell {
      inputsFrom = [
        config.haskellProjects.default.outputs.devShell
        config.pre-commit.devShell
      ];

      packages = with pkgs; [
        mdbook
        nix-unit
        prek
      ];
    };
  };
}
