_: {
  perSystem = {
    pkgs,
    self',
    ...
  }: {
    legacyPackages.generators = import ../generators {
      inherit pkgs;
      inherit (self'.packages) terranix-codegen;
    };
  };
}
