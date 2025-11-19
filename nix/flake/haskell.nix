{inputs, ...}: {
  imports = [
    inputs.haskell-flake.flakeModule
  ];

  perSystem = {self', ...}: {
    haskellProjects.default = {
      devShell = {
        tools = hp: {
          inherit
            (hp)
            cabal-gild
            hspec-discover
            ;
        };
      };

      autoWire = ["packages" "apps" "checks"];
    };

    packages.default = self'.packages.terranix-codegen;
    apps.default = self'.apps.terranix-codegen;
  };
}
