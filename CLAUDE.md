# CLAUDE.md

This file provides guidance to Claude Code when working with code in this repository.

## Project Overview

terranix-codegen transforms Terraform provider schemas (go-cty type system) into type-safe NixOS modules for Terranix. It parses provider specs, runs `tofu providers schema`, then generates Nix code through a linear pipeline of AST transformations.

## Build and Development

```bash
nix develop                    # Enter dev shell (provides GHC, cabal, formatters, linters)
cabal build                    # Build the project
cabal test --enable-tests      # Run all tests
cabal test --enable-coverage   # Run tests with HPC coverage
nix build                      # Full Nix build
nix flake check                # Run all checks (build, format, lint)
```

GHC 9.10.3 with GHC2024 edition. The flake uses flake-parts.

## Testing

Hspec with hspec-discover. Tests are in `test/TerranixCodegen/` with `*Spec.hs` suffix.

Key testing patterns:

- **`shouldMapTo` custom matcher** in `test/TestUtils.hs` — compares `NExpr` ASTs via pretty-printed output
- **QuasiQuotes** — tests use `[nix| ... |]` syntax for inline Nix AST literals
- HLint is configured (`.hlint.yaml`) to ignore parse errors from QuasiQuotes in test files

## Formatting and Linting

Treefmt-based with pre-commit hooks via hk. Hooks install automatically on dev shell entry.

| Tool | Purpose |
| -------------------------- | ----------------------------------------------------------------------- |
| fourmolu | Haskell formatting (2-space indent, leading commas, record brace space) |
| hlint | Haskell linting |
| cabal-gild | .cabal file formatting |
| alejandra, deadnix, statix | Nix formatting and linting |

## Architecture

### Pipeline

```
ProviderSpec (text) → TerraformGenerator (runs tofu CLI)
  → ProviderSchema (JSON via aeson) → TypeMapper (CtyType → NExpr)
  → OptionBuilder (SchemaAttribute → mkOption) → ModuleGenerator (NixOS module assembly)
  → FileOrganizer (directory tree output)
```

### Source Layout

- `app/` — CLI entry point using optparse-applicative (`CLI/Types.hs`, `CLI/Parser.hs`, `CLI/Commands.hs`)
- `lib/TerranixCodegen/` — Library code (pipeline stages)
  - `ProviderSchema/` — Aeson-based JSON parsing into ADTs (`CtyType.hs`, `Attribute.hs`, `Block.hs`, `Schema.hs`, `Provider.hs`, `Function.hs`, `Identity.hs`, `Types.hs`)
  - `ProviderSpec.hs` — Megaparsec parser for provider specs (e.g. `hashicorp/aws:5.0.0`)
  - `TypeMapper.hs` — Maps go-cty types to Nix types via hnix AST
  - `OptionBuilder.hs` — Builds `mkOption` expressions from schema attributes
  - `ModuleGenerator.hs` — Assembles complete NixOS module expressions
  - `FileOrganizer.hs` — Writes organized directory tree with auto-generated `default.nix` imports
  - `PrettyPrint.hs` — Colorized terminal output
- `test/` — Hspec test suite
- `nix/` — Flake modules (haskell build, devshell, treefmt, docs, CI workflow generation)
- `vendor/` — Vendored terraform-json schema library

### Critical Design Decisions

- **AST-based code generation, not string templates.** All Nix output goes through hnix's `NExpr` AST and `prettyNix`. This guarantees syntactic validity. Never generate Nix as raw strings.
- **`types.nullOr` for optional attributes** — preserves Terraform's null semantics (unset ≠ default value).
- **Custom `types.tupleOf`** — implemented in `nix/lib/tuple.nix` for fixed-length, per-position type validation matching Terraform tuples.
- **`StrictData` extension** — used in all `ProviderSchema/` modules for strict-by-default record fields.

### Key Types

| Type | Module | Role |
| ----------------- | -------------------------- | --------------------------------------------------------------------------------- |
| `CtyType` | `ProviderSchema.CtyType` | go-cty type system (Bool, Number, String, Dynamic, List, Set, Map, Object, Tuple) |
| `SchemaAttribute` | `ProviderSchema.Attribute` | Attribute metadata (type, required/optional, computed, deprecated, sensitive) |
| `SchemaBlock` | `ProviderSchema.Block` | Block with attributes, nested blocks, and nesting mode |
| `ProviderSpec` | `ProviderSpec` | Parsed provider specification (namespace/name:version) |
| `NExpr` | hnix | Nix expression AST — the core intermediate representation |

## CI

GitHub Actions workflow auto-generated from Nix (`nix/flake/ci/`). Three jobs: `check` (flake check), `build` (nix build), `coverage` (HPC report).
