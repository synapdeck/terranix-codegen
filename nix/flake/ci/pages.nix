_: {
  perSystem = _: {
    githubActions.workflows.pages = {
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
        runsOn = "warp-ubuntu-latest-arm64-2x";
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
}
