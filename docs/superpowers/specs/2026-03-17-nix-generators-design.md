# Nix Generator Wrapper

## Goal

Expose terranix-codegen's code generation as Nix library functions so consumers can generate type-safe NixOS modules for Terraform providers at Nix build time, similar to how nixidy exposes its generators.

## File Structure

```
nix/
  generators/
    default.nix          # Pure Nix functions: { generateFromSchema, generateProvider }
  flake/
    lib.nix              # Extended to wire generators into flake.lib
```

`nix/generators/default.nix` is a standalone file (no flake-parts dependency) that takes `{ terranix-codegen }` (the executable derivation) and returns the two generator functions. Both functions accept `pkgs` from the consumer.

The existing `nix/flake/lib.nix` is extended to expose these functions under `flake.lib.generators`.

## API

### `generateFromSchema`

```nix
generateFromSchema {
  pkgs,                    # nixpkgs package set
  schema,                  # path to provider schema JSON file
  outputDir ? "providers", # output directory name in the derivation
}
```

Runs `terranix-codegen generate -i ${schema} -o $out/${outputDir}` inside a derivation. Fully pure, no network access needed.

### `generateProvider`

```nix
generateProvider {
  pkgs,                    # nixpkgs package set
  provider,                # provider spec string, e.g. "hashicorp/aws:5.0.0"
  pluginDrv ? null,        # optional: provider plugin derivation (e.g. from nixpkgs-terraform-providers-bin)
  terraform ? null,        # terraform package (required when pluginDrv is set)
  tofu ? pkgs.opentofu,    # tofu package (used when pluginDrv is null)
  outputDir ? "providers",
}
```

Two modes based on whether `pluginDrv` is provided:

**Without `pluginDrv` (tofu path):**

1. Create a minimal `.tf.json` requiring the provider
1. Run `tofu init && tofu providers schema -json`
1. Pipe schema JSON to `terranix-codegen generate -o $out/${outputDir}`

Requires network access at build time (sandbox must be disabled, or provider must be available via `withPlugins`).

**With `pluginDrv` (terraform path):**

1. Wrap terraform with the plugin: `terraform.withPlugins (p: [ pluginDrv ])`
1. Create a minimal `.tf.json` requiring the provider
1. Run `terraformWithPlugin providers schema -json`
1. Pipe schema JSON to `terranix-codegen generate -o $out/${outputDir}`

Fully sandboxed — the plugin binary is already in the Nix store. Uses `terraform` (not `tofu`) because opentofu is incompatible with the binary providers.

## Assertions

- If `pluginDrv` is set but `terraform` is null, fail at evaluation time with a clear error message.

## Consumer Usage

```nix
{
  inputs.terranix-codegen.url = "github:synapdeck/terranix-codegen";
  inputs.nixpkgs-terraform-providers-bin.url = "github:nix-community/nixpkgs-terraform-providers-bin";

  outputs = { nixpkgs, terranix-codegen, nixpkgs-terraform-providers-bin, ... }:
  let
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
    providers-bin = nixpkgs-terraform-providers-bin.packages.x86_64-linux;
    gen = terranix-codegen.lib.generators;
  in {
    # From pre-existing schema JSON (fully pure)
    awsModules = gen.generateFromSchema {
      inherit pkgs;
      schema = ./aws-schema.json;
    };

    # From tofu (requires sandbox disabled)
    awsModules' = gen.generateProvider {
      inherit pkgs;
      provider = "hashicorp/aws:5.0.0";
    };

    # From plugin derivation (fully sandboxed)
    awsModules'' = gen.generateProvider {
      inherit pkgs;
      provider = "hashicorp/aws:5.0.0";
      pluginDrv = providers-bin.aws;
      terraform = pkgs.terraform;
    };
  };
}
```

## Wiring

`nix/flake/lib.nix` currently exposes:

```nix
flake.lib = lib.makeExtensible (_: {
  types = { inherit (import ../lib/tuple.nix { inherit lib; }) tupleOf; };
});
```

This will be extended to include:

```nix
flake.lib = lib.makeExtensible (_: {
  types = { ... };
  generators = import ../generators { inherit terranix-codegen; };
});
```

Where `terranix-codegen` is the built executable package. Since `lib.nix` is a flake-parts module with access to `perSystem`, the executable will come from `self'.packages.terranix-codegen`. The generators functions themselves are system-independent — they take `pkgs` from the consumer — but the executable they invoke is system-specific, so the wiring must account for this (either making `generators` per-system, or deferring the executable resolution to the consumer's `pkgs`).

**Resolution:** The generators will be per-system, exposed under `perSystem.lib.generators` or passed as `flake.lib.generators.${system}`. Alternatively, `nix/generators/default.nix` takes the executable as an argument and each function closes over it, so the flake wiring passes the per-system executable once.
