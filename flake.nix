{
  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1";

    flake-parts = {
      url = "https://flakehub.com/f/hercules-ci/flake-parts/0.1";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    flake-root.url = "https://flakehub.com/f/srid/flake-root/0.1";

    files.url = "github:mightyiam/files";

    devshell = {
      url = "github:numtide/devshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    fourmolu-nix.url = "github:jedimahdi/fourmolu-nix";

    github-actions-nix = {
      url = "https://flakehub.com/f/synapdeck/github-actions-nix/0.1";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-parts.follows = "flake-parts";
      };
    };

    haskell-flake.url = "github:srid/haskell-flake";

    hk = {
      url = "git+https://github.com/jdx/hk?submodules=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-unit = {
      url = "github:nix-community/nix-unit";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-parts.follows = "flake-parts";
        treefmt-nix.follows = "treefmt-nix";
      };
    };

    treefmt-nix = {
      url = "https://flakehub.com/f/numtide/treefmt-nix/0.1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = inputs @ {
    nixpkgs,
    flake-parts,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = nixpkgs.lib.systems.flakeExposed;
      imports = [
        ./nix/flake
      ];
    };
}
