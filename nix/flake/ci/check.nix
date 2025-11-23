_: {
  perSystem = _: {
    githubActions.workflows.check = {
      name = "Check";

      on = {
        push = {};
        pullRequest = {};
      };

      permissions = {
        contents = "read";
        id-token = "write";
      };

      defaults.job = {
        runsOn = "ubuntu-latest";
      };

      jobs = {
        check = {
          name = "Run flake check";
          steps = [
            {
              name = "Checkout";
              uses = "actions/checkout@v4";
            }
            {
              name = "Install Nix";
              uses = "DeterminateSystems/nix-installer-action@v21";
            }
            {
              name = "Run flake check";
              run = "nix flake check";
            }
          ];
        };

        build = {
          name = "Build package";
          steps = [
            {
              name = "Checkout";
              uses = "actions/checkout@v4";
            }
            {
              name = "Install Nix";
              uses = "DeterminateSystems/nix-installer-action@v21";
            }
            {
              name = "Build package";
              run = "nix build";
            }
          ];
        };

        coverage = {
          name = "Test coverage";
          steps = [
            {
              name = "Checkout";
              uses = "actions/checkout@v4";
            }
            {
              name = "Install Nix";
              uses = "DeterminateSystems/nix-installer-action@v21";
            }
            {
              name = "Run tests with coverage";
              run = ''
                nix develop -c cabal test --enable-coverage
                TIX_FILE=$(find dist-newstyle -name "terranix-codegen-tests.tix" -type f | head -1)
                MIX_DIRS=$(find dist-newstyle -type d -name "mix" -path "*/hpc/vanilla/mix" | sed "s/^/--hpcdir=/")
                mkdir -p coverage
                nix develop -c hpc report $MIX_DIRS "$TIX_FILE" | tee coverage/coverage.txt
                nix develop -c hpc markup $MIX_DIRS --destdir=coverage "$TIX_FILE"
              '';
            }
            {
              name = "Upload coverage report";
              uses = "actions/upload-artifact@v4";
              with_ = {
                name = "coverage-report";
                path = "coverage/";
              };
            }
          ];
        };
      };
    };
  };
}
