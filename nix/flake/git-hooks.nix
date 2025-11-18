{inputs, ...}: {
  imports = [
    inputs.fourmolu-nix.flakeModule
    inputs.git-hooks.flakeModule
  ];

  perSystem = {
    config,
    pkgs,
    ...
  }: {
    pre-commit.settings = {
      hooks = {
        alejandra.enable = true;
        deadnix.enable = true;
        statix.enable = true;

        cabal-fmt.enable = true;
        cabal-gild.enable = true;
        fourmolu = {
          enable = true;
          package = config.fourmolu.wrapper;
        };
        hlint.enable = true;

        mdformat.enable = true;
      };

      package = pkgs.prek;
    };

    fourmolu.settings = {
      indentation = 2;
      comma-style = "leading";
      record-brace-space = true;
      indent-wheres = true;
      import-export-style = "diff-friendly";
      respectful = true;
      haddock-style = "multi-line";
      newlines-between-decls = 1;
      extensions = ["ImportQualifiedPost"];
    };
  };
}
