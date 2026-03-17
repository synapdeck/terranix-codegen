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

  generateProvider = throw "not yet implemented";
}
