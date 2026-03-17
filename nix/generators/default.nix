{
  pkgs,
  terranix-codegen,
}: {
  generateFromSchema = {
    schema,
    outputDir ? "providers",
  }:
    pkgs.stdenv.mkDerivation {
      name = "terranix-generated-modules";
      dontUnpack = true;
      dontInstall = true;
      nativeBuildInputs = [terranix-codegen];
      buildPhase = ''
        mkdir -p $out/${outputDir}
        terranix-codegen generate -i ${schema} -o $out/${outputDir}
      '';
    };

  generateProvider = {
    provider,
    pluginDrv ? null,
    terraform ? null,
    tofu ? pkgs.opentofu,
    outputDir ? "providers",
  }: let
    usePlugin = pluginDrv != null;
    terraformWithPlugin = assert pkgs.lib.assertMsg (terraform != null)
    "generateProvider: terraform must be provided when pluginDrv is set";
      terraform.withPlugins (_: [pluginDrv]);
    tfExecutable =
      if usePlugin
      then terraformWithPlugin
      else tofu;
    tfName =
      if usePlugin
      then "terraform"
      else builtins.baseNameOf (pkgs.lib.getExe tfExecutable);
  in
    pkgs.stdenv.mkDerivation {
      name = "terranix-generated-modules";
      dontUnpack = true;
      dontInstall = true;
      nativeBuildInputs = [terranix-codegen tfExecutable];
      buildPhase = ''
        export HOME=$(mktemp -d)
        mkdir -p $out/${outputDir}
        terranix-codegen generate -p ${provider} -t ${tfName} -o $out/${outputDir}
      '';
    };
}
