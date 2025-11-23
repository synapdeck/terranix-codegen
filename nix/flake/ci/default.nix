{inputs, ...}: {
  imports = let
    # Auto-discover all workflow files in this directory
    workflowFiles = builtins.filter (name: name != "default.nix") (
      builtins.attrNames (builtins.readDir ./.)
    );
  in
    [
      inputs.files.flakeModules.default
      inputs.github-actions-nix.flakeModules.default
    ]
    ++ map (name: ./${name}) workflowFiles;

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

    githubActions.enable = true;
  };
}
