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
        statix = {
          enable = true;
          settings.ignore = [
            "vendor/**/*"
          ];
        };

        cabal-gild.enable = true;
        fourmolu = {
          enable = true;
          package = config.fourmolu.wrapper;
        };
        hlint = {
          enable = true;
          args = ["-XQuasiQuotes"];
        };

        mdformat.enable = true;
      };

      excludes = [
        "vendor/.*"
      ];

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

    apps.update-pre-commit = {
      type = "app";
      program = ''${pkgs.writeShellScript "update-pre-commit" config.pre-commit.installationScript}'';
    };
  };
}
