{inputs, ...}: {
  imports = [
    inputs.actions-nix.flakeModules.default
  ];

  flake = {
    actions-nix = {
      pre-commit.enable = true;
      defaultValues.jobs.runs-on = "ubuntu-latest";

      workflows = {
        ".github/workflows/check.yaml" = {
          on = {
            push = {};
            pull_request = {};
          };
          permissions = {
            contents = "read";
            id-token = "write";
          };
          jobs = {
            check = {
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
        ".github/workflows/pages.yaml" = {
          on = {
            push = {
              branches = ["master"];
            };
            workflow_dispatch = {};
          };
          permissions = {
            contents = "read";
            pages = "write";
            id-token = "write";
          };
          jobs = {
            build = {
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
                  "with" = {
                    path = "./result";
                  };
                }
              ];
            };
            deploy = {
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
