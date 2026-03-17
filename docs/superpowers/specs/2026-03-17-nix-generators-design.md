# Nix Generator Wrapper

## Goal

Expose terranix-codegen's code generation as Nix derivation-producing functions so consumers can generate type-safe NixOS modules for Terraform providers at Nix build time, similar to how nixidy exposes its generators under `packages.${system}.generators`.

## File Structure

```
nix/
  generators/
    default.nix          # { pkgs, terranix-codegen } -> { generateFromSchema, generateProvider }
  flake/
    generators.nix       # flake-parts perSystem module wiring generators into packages
    default.nix          # Updated to import generators.nix
```

`nix/generators/default.nix` is a standalone file (no flake-parts dependency) that takes `{ pkgs, terranix-codegen }` and returns the two generator functions. It is independent of the flake so it can be used from a non-flake `default.nix` entry point as well.

`nix/flake/generators.nix` is a flake-parts module that wires the generators into `packages.${system}.generators` by passing the per-system `pkgs` and `self'.packages.terranix-codegen`.

## API

### `generateFromSchema`

```nix
generateFromSchema {
  schema,                  # path to provider schema JSON file
  outputDir ? "providers", # output directory name in the derivation
}
```

Runs `terranix-codegen generate -i ${schema} -o $out/${outputDir}` inside a derivation. Fully pure, no network access needed.

### `generateProvider`

```nix
generateProvider {
  provider,                # provider spec string, e.g. "hashicorp/aws:5.0.0"
  pluginDrv ? null,        # optional: provider plugin derivation (e.g. from nixpkgs-terraform-providers-bin)
  terraform ? null,        # terraform package (required when pluginDrv is set)
  tofu ? pkgs.opentofu,    # tofu package (used when pluginDrv is null)
  outputDir ? "providers",
}
```

Note: `pkgs` is not a per-call argument — it is captured from the outer scope when the generators are constructed.

Two modes based on whether `pluginDrv` is provided:

**Without `pluginDrv` (tofu path):**

Uses the CLI's built-in provider spec handling:

```bash
terranix-codegen generate -p ${provider} -o $out/${outputDir}
```

The `-p` flag internally runs `tofu init` and `tofu providers schema -json`. The `tofu` parameter controls which binary is used via `-t`.

Requires network access at build time — the Nix sandbox must be disabled for this path.

**With `pluginDrv` (terraform path):**

1. Wrap terraform with the plugin: `terraform.withPlugins (_: [ pluginDrv ])`
1. Run via CLI with the wrapped terraform:

```bash
terranix-codegen generate -p ${provider} -t terraform -o $out/${outputDir}
```

The wrapped terraform is placed on `PATH` in the derivation's `nativeBuildInputs`, so `-t terraform` resolves to it. The `-p` flag internally runs `terraform providers schema -json` using that binary.

Fully sandboxed — the plugin binary is already in the Nix store via `withPlugins`. Uses `terraform` (not `tofu`) because opentofu is incompatible with binary providers.

**`pluginDrv` requirements:** Must be a derivation compatible with `terraform.withPlugins`, meaning it has the standard nixpkgs terraform provider structure (e.g. `libexec/terraform-providers/...`). Derivations from nixpkgs-terraform-providers-bin satisfy this.

## Assertions

- If `pluginDrv` is set but `terraform` is null, fail at evaluation time with: `"generateProvider: terraform must be provided when pluginDrv is set"`

## Build Inputs

- `generateFromSchema`: `nativeBuildInputs = [ terranix-codegen ]`
- `generateProvider` (tofu path): `nativeBuildInputs = [ terranix-codegen tofu ]`
- `generateProvider` (terraform path): `nativeBuildInputs = [ terranix-codegen terraformWithPlugin ]`

## Consumer Usage

```nix
{
  inputs.terranix-codegen.url = "github:synapdeck/terranix-codegen";
  inputs.nixpkgs-terraform-providers-bin.url = "github:nix-community/nixpkgs-terraform-providers-bin";

  outputs = { nixpkgs, terranix-codegen, nixpkgs-terraform-providers-bin, ... }:
  let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
    providers-bin = nixpkgs-terraform-providers-bin.packages.${system};
    gen = terranix-codegen.packages.${system}.generators;
  in {
    # From pre-existing schema JSON (fully pure)
    awsModules = gen.generateFromSchema {
      schema = ./aws-schema.json;
    };

    # From tofu (requires sandbox disabled)
    awsModules' = gen.generateProvider {
      provider = "hashicorp/aws:5.0.0";
    };

    # From plugin derivation (fully sandboxed)
    awsModules'' = gen.generateProvider {
      provider = "hashicorp/aws:5.0.0";
      pluginDrv = providers-bin.aws;
      terraform = pkgs.terraform;
    };
  };
}
```

## Wiring

`nix/flake/generators.nix` (new file):

```nix
{ ... }: {
  perSystem = { pkgs, self', ... }: {
    packages.generators = import ../generators {
      inherit pkgs;
      terranix-codegen = self'.packages.terranix-codegen;
    };
  };
}
```

The existing `nix/flake/lib.nix` is unchanged — `flake.lib.types.tupleOf` remains as-is. Generators are per-system because they close over a per-system executable.
