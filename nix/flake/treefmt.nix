{inputs, ...}: {
  imports = [
    inputs.flake-root.flakeModule
    inputs.fourmolu-nix.flakeModule
    inputs.treefmt-nix.flakeModule
  ];

  perSystem = {
    config,
    pkgs,
    lib,
    ...
  }: {
    treefmt = {
      inherit (config.flake-root) projectRootFile;
      package = pkgs.treefmt;

      programs = {
        alejandra.enable = true;
        deadnix.enable = true;
        statix.enable = true;

        cabal-gild.enable = true;
        fourmolu.enable = true;
        hlint.enable = true;

        mdformat.enable = true;
      };

      settings = {
        global.excludes = ["vendor/**/*"];

        formatter = {
          hlint.options = ["-XQuasiQuotes"];
        };
      };
    };

    devshells.default = {
      devshell.startup.treefmt-config.text = ''
        FLAKE_ROOT=$(${lib.getExe config.flake-root.package})
        SYMLINK_SOURCE_PATH="${config.treefmt.build.configFile}"
        SYMLINK_TARGET_PATH="$FLAKE_ROOT/.treefmt.toml"

        if [[ -e "$SYMLINK_TARGET_PATH" && ! -L "$SYMLINK_TARGET_PATH" ]]; then
          echo "treefmt-nix: Error: Target exists but is not a symlink."
          exit 1
        fi

        if [[ -L "$SYMLINK_TARGET_PATH" ]]; then
          if [[ "$(readlink "$SYMLINK_TARGET_PATH")" != "$SYMLINK_SOURCE_PATH" ]]; then
            echo "treefmt-nix: Removing existing symlink"
            unlink "$SYMLINK_TARGET_PATH"
          else
            exit 0
          fi
        fi

        nix-store --add-root "$SYMLINK_TARGET_PATH" --indirect --realise "$SYMLINK_SOURCE_PATH"
        echo "treefmt-nix: Created symlink successfully"
      '';

      packages = with pkgs; [
        config.fourmolu.wrapper
        treefmt
      ];
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
      extensions = [
        "ImportQualifiedPost"
        "TemplateHaskellQuotes"
      ];
    };
  };
}
