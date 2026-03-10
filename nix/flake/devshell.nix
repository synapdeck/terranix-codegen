{inputs, ...}: {
  imports = [
    inputs.devshell.flakeModule
  ];

  perSystem = {
    config,
    inputs',
    pkgs,
    lib,
    ...
  }: {
    devshells.default = {
      packages = with pkgs; [
        alejandra
        deadnix
        inputs'.hk.packages.hk
        mdformat
        pkl
        statix
      ];

      packagesFrom = [
        config.haskellProjects.default.outputs.devShell
      ];

      devshell.startup.hk = {
        text = ''
          # Ensure git hooks are installed (skip in worktrees)
          if [ -d .git ]; then
            if ! output=$(hk install 2>&1); then
              exit_code=$?
              echo "$output" >&2
              exit $exit_code
            fi
          fi
        '';
      };

      env = [
        {
          name = "FLAKE_ROOT";
          value = "\${${lib.getExe config.flake-root.package}}";
        }
      ];
    };
  };
}
