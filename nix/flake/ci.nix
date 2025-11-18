{inputs, ...}: {
  imports = [
    inputs.actions-nix.flakeModules.default
  ];

  flake = {
    actions-nix.workflows = {
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
            runs-on = "ubuntu-latest";
            steps = [
              {
                name = "Checkout";
                uses = "actions/checkout@v4";
              }
              {
                name = "Install Nix";
                uses = "DeterminateSystems/nix-installer-action@v9";
              }
              {
                name = "Build book";
                run = "nix build .#docs";
              }
              {
                name = "Setup Pages";
                uses = "actions/configure-pages@v4";
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
            runs-on = "ubuntu-latest";
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
}
