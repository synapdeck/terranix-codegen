# Architecture

terranix-codegen is a Haskell pipeline that transforms Terraform provider schemas into NixOS module files.

## Pipeline

```
Provider spec       e.g. "hashicorp/aws:5.0.0"
      │
      ▼
TerraformGenerator  generates minimal .tf, runs tofu init + providers schema -json
      │
      ▼
ProviderSchema      parses JSON into Haskell ADTs (CtyType, SchemaAttribute, SchemaBlock, etc.)
      │
      ▼
TypeMapper          CtyType → hnix NExpr (e.g. CtyString → types.str)
      │
      ▼
OptionBuilder       SchemaAttribute → mkOption { type = ...; default = ...; description = ...; }
      │
      ▼
ModuleGenerator     assembles options into { lib, ... }: with lib; { options.resource.X = ...; }
      │
      ▼
FileOrganizer       writes one .nix file per resource/data source + default.nix imports
```

Each stage is independent and tested separately.

## Key modules

| Module | File | What it does |
|--------|------|-------------|
| ProviderSpec | `lib/TerranixCodegen/ProviderSpec.hs` | Parses provider spec strings (`aws`, `hashicorp/aws:5.0.0`) |
| TerraformGenerator | `lib/TerranixCodegen/TerraformGenerator.hs` | Runs tofu/terraform to extract schema JSON |
| ProviderSchema | `lib/TerranixCodegen/ProviderSchema/` | JSON parsing into Haskell types (aeson) |
| TypeMapper | `lib/TerranixCodegen/TypeMapper.hs` | go-cty type → NixOS module type |
| OptionBuilder | `lib/TerranixCodegen/OptionBuilder.hs` | Schema attribute → `mkOption` expression |
| ModuleGenerator | `lib/TerranixCodegen/ModuleGenerator.hs` | Assembles complete NixOS modules |
| FileOrganizer | `lib/TerranixCodegen/FileOrganizer.hs` | Directory structure and file writing |
| PrettyPrint | `lib/TerranixCodegen/PrettyPrint.hs` | Colorized terminal output for `show` command |

## Schema types

The Terraform provider schema is parsed into these Haskell types:

- **`ProviderSchemas`** -- top-level container mapping registry paths to providers
- **`ProviderSchema`** -- one provider's config schema, resource schemas, and data source schemas
- **`Schema`** -- a single resource/data source, containing a `SchemaBlock`
- **`SchemaBlock`** -- has `blockAttributes` (a map of `SchemaAttribute`) and `blockNestedBlocks` (a map of `SchemaBlockType`)
- **`SchemaAttribute`** -- type, description, required/optional/computed flags, deprecation, sensitivity
- **`SchemaBlockType`** -- a nested block with a nesting mode (single/group/list/set/map) and an inner `SchemaBlock`
- **`CtyType`** -- Terraform's type system: `Bool`, `Number`, `String`, `Dynamic`, `List T`, `Set T`, `Map T`, `Object fields optionals`, `Tuple elems`

## Code generation approach

All Nix code is generated through [hnix](https://github.com/haskell-nix/hnix)'s `NExpr` AST and pretty-printer. No string templates. This means:

- The generated code is always syntactically valid
- Type mappings are compositional (you can nest them freely)
- The pretty-printer handles formatting

The final step uses `nixExprToText` (which calls hnix's `prettyNix`) to render the AST to text.

## Design decisions

**NixOS modules with no `config` block.** The generated modules only declare `options`. Because the option paths (`resource.<type>.<name>.<attr>`) exactly match the attrset structure Terranix already consumes, no transformation is needed. The module system validates the values and passes them through as-is.

**One file per resource.** Large providers like AWS have 1000+ resources. A single file would be unmanageable. Individual files also make git diffs clean and allow selective imports.

**hnix AST instead of string templates.** More verbose to write, but impossible to generate malformed Nix. Also makes testing easier -- tests compare ASTs directly using hnix's quasiquoter.

**`types.nullOr` for optional attributes.** Matches Terraform's semantics where omitted optional attributes are treated as null/unset. Using `null` as the default lets optional+computed attributes fall through to provider-computed values.

**Custom `types.tupleOf`.** Terraform has typed fixed-length tuples. Nix doesn't have a built-in equivalent, so we provide one in `nix/lib/tuple.nix` that validates both length and per-position types.
