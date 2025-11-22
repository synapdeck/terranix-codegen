{inputs, ...}: {
  imports = [
    inputs.files.flakeModules.default
    inputs.github-actions-nix.flakeModules.default
  ];

  perSystem = {
    config,
    lib,
    ...
  }: {
    files.files = let
      go = name: drv: {
        path_ = ".github/workflows/${name}";
        inherit drv;
      };
    in
      lib.mapAttrsToList go config.githubActions.workflowFiles;

    apps.write-files = {
      type = "app";
      program = config.files.writer.drv;
    };

    githubActions = {
      enable = true;

      workflows = {
        check = {
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
          };
        };

        pages = {
          name = "GitHub Pages";

          on = {
            push.branches = ["master"];
            workflowDispatch = {};
          };

          permissions = {
            contents = "read";
            pages = "write";
            id-token = "write";
          };

          defaults.job = {
            runsOn = "ubuntu-latest";
          };

          jobs = {
            build = {
              name = "Build documentation";
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
                  name = "Build book";
                  run = "nix build .#docs";
                }
                {
                  name = "Setup Pages";
                  uses = "actions/configure-pages@v5";
                }
                {
                  name = "Upload artifact";
                  uses = "actions/upload-pages-artifact@v3";
                  with_ = {
                    path = "./result";
                  };
                }
              ];
            };

            deploy = {
              name = "Deploy to GitHub Pages";
              needs = ["build"];

              permissions = {
                pages = "write";
                id-token = "write";
              };

              environment = {
                name = "github-pages";
                url = "\${{ steps.deployment.outputs.page_url }}";
              };

              steps = [
                {
                  name = "Deploy to GitHub Pages";
                  id = "deployment";
                  uses = "actions/deploy-pages@v4";
                }
              ];
            };
          };
        };
      };
    };
  };
}
