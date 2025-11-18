{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    haskell-flake.url = "github:srid/haskell-flake";
  };
  outputs = inputs @ {
    nixpkgs,
    flake-parts,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = nixpkgs.lib.systems.flakeExposed;
      imports = [inputs.haskell-flake.flakeModule];

      perSystem = {
        self',
        pkgs,
        ...
      }: {
        haskellProjects.default = {
          devShell = {
            tools = hp: {
              inherit (hp) cabal-gild;
            };
          };
        };

        packages = {
          default = self'.packages.terranix-codegen;

          docs = pkgs.stdenv.mkDerivation {
            name = "terranix-codegen-docs";
            src = ./docs;
            buildInputs = [pkgs.mdbook];
            buildPhase = ''
              mdbook build
            '';
            installPhase = ''
              mkdir -p $out
              cp -r book/* $out/
            '';
          };
        };

        apps = {
          default = self'.apps.terranix-codegen;
          serve-docs = {
            type = "app";
            program = "${pkgs.writeShellScript "serve-docs" ''
              set -e
              PORT=8000
              URL="http://localhost:$PORT"

              echo "Serving docs at $URL"
              echo "Press Ctrl+C to stop"

              # Open browser in background
              (
                if [[ "$OSTYPE" == "darwin"* ]]; then
                  open "$URL"
                else
                  ${pkgs.xdg-utils}/bin/xdg-open "$URL"
                fi
              ) &

              # Start server in foreground
              ${pkgs.python3}/bin/python -m http.server $PORT -d ${self'.packages.docs}
            ''}";
          };
        };
      };
    };
}
