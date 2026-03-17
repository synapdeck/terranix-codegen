{
  pkgs,
  terranix-codegen,
}: let
  generators = import ./default.nix {inherit pkgs terranix-codegen;};
  dummySchema = builtins.toFile "empty-schema.json" "{}";
in {
  generators = {
    generateFromSchema = {
      testProducesDerivation = {
        expr = (generators.generateFromSchema {schema = dummySchema;}).type or null;
        expected = "derivation";
      };

      testDerivationName = {
        expr = (generators.generateFromSchema {schema = dummySchema;}).name;
        expected = "terranix-generated-modules";
      };

      testCustomOutputDir = {
        expr =
          (generators.generateFromSchema {
            schema = dummySchema;
            outputDir = "custom";
          })
          .name;
        expected = "terranix-generated-modules";
      };
    };

    generateProvider = {
      testProducesDerivation = {
        expr =
          (generators.generateProvider {
            provider = "hashicorp/null:3.2.0";
          })
          .type or null;
        expected = "derivation";
      };

      testDerivationName = {
        expr =
          (generators.generateProvider {
            provider = "hashicorp/null:3.2.0";
          })
          .name;
        expected = "terranix-generated-modules";
      };

      testRequiresTerraformWithPlugin = {
        expr =
          !(builtins.tryEval (
            builtins.deepSeq
            (generators.generateProvider {
              provider = "hashicorp/null:3.2.0";
              pluginDrv = builtins.toFile "fake-plugin" "";
            })
            true
          ))
          .success;
        expected = true;
      };
    };
  };
}
