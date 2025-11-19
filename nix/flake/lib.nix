{lib, ...}: {
  flake.lib = lib.makeExtensible (_: {
    types = {
      inherit (import ../lib/tuple.nix {inherit lib;}) tupleOf;
    };
  });
}
