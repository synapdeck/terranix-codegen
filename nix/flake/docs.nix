{
  perSystem = {
    self',
    pkgs,
    ...
  }: {
    packages.docs = pkgs.stdenv.mkDerivation {
      name = "terranix-codegen-docs";
      src = ../../docs;
      buildInputs = [pkgs.mdbook];
      buildPhase = ''
        mdbook build
      '';
      installPhase = ''
        mkdir -p $out
        cp -r book/* $out/
      '';
    };

    devshells.default = {
      packages = with pkgs; [
        mdbook
      ];
    };

    apps.serve-docs = {
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
}
