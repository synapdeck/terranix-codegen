# terranix-codegen

> Automatically generate [Terranix](https://terranix.org/) modules from Terraform provider schemas

[![License: MPL 2.0](https://img.shields.io/badge/License-MPL_2.0-brightgreen.svg)](https://opensource.org/licenses/MPL-2.0)

**terranix-codegen** bridges the gap between Terraform's vast provider ecosystem and Terranix's type-safe, Nix-based infrastructure configuration by automatically generating NixOS modules from Terraform provider schemas.

## Project Status

**Ready for Use** - Complete end-to-end generation pipeline!

- ✅ **Schema parsing**: Complete and tested
- ✅ **Type Mapper**: Complete (CtyType → Nix type conversion) - 25 tests passing
- ✅ **Option Builder**: Complete (SchemaAttribute → mkOption conversion) - 31 tests passing
- ✅ **Module Generator**: Complete (assembles complete NixOS modules) - 11 tests passing
- ✅ **File Organizer**: Complete (creates directory structure and files) - 20 tests passing
- ✅ **CLI**: Complete (optparse-applicative with --input/-i, --output/-o, and --print-schema/-p flags)
- ✅ **Design documentation**: Architecture defined and documented
- 🔨 **Documentation generation**: Not yet implemented (future enhancement)

## What It Does

terranix-codegen reads Terraform provider schemas and generates:

1. **Type-safe NixOS modules** for all resources and data sources
1. **Comprehensive documentation** in mdBook format
1. **Changelogs** tracking provider updates

```
Terraform Provider → Schema JSON → terranix-codegen → Nix Modules + Docs
```

### Example Output

After running terranix-codegen on the AWS provider:

```
providers/
├── aws/
│   ├── default.nix           # Entry point
│   ├── provider.nix          # Provider configuration
│   ├── resources/
│   │   ├── instance.nix      # aws_instance
│   │   ├── vpc.nix           # aws_vpc
│   │   └── ... (1000+ resources)
│   └── data-sources/
│       ├── ami.nix           # aws_ami data source
│       └── ... (100+ data sources)
└── docs/
    └── book/                 # Generated mdBook documentation
```

## Why?

**The Problem**: Manually creating Terranix modules for Terraform providers is tedious:

- AWS alone has 1000+ resources
- Providers update constantly
- Type definitions are already in the schema

**The Solution**: Generate modules automatically from schemas, ensuring:

- Type safety through NixOS module system
- Always up-to-date with provider versions
- Complete documentation from schema metadata
- No manual maintenance burden

## Quick Start

```bash
# 1. Get provider schema
terraform providers schema -json > schema.json

# 2. Generate Terranix modules
cabal run terranix-codegen -- --input schema.json --output ./terranix-modules

# Or from stdin:
terraform providers schema -json | cabal run terranix-codegen -- -o ./terranix-modules

# 3. Use in your Terranix config
cat > config.nix <<EOF
{
  imports = [ ./terranix-modules/registry.terraform.io/hashicorp/aws ];

  resource.aws_instance.web = {
    ami = "ami-123456";
    instance_type = "t2.micro";
  };
}
EOF

# 4. Generate Terraform JSON and apply
terranix config.nix > config.tf.json
terraform init && terraform apply
```

### Inspecting Schemas

To inspect and pretty-print a provider schema without generating modules:

```bash
# Pretty-print schema from stdin
terraform providers schema -json | cabal run terranix-codegen -- --print-schema

# Pretty-print schema from file
cabal run terranix-codegen -- -i schema.json -p

# Or with Nix:
terraform providers schema -json | nix run . -- --print-schema
```

This is useful for understanding provider schemas and debugging generation issues.

## How It Works

terranix-codegen is written in Haskell and uses a multi-phase approach:

### 1. Schema Parsing (Complete)

Parses Terraform's JSON schema into strongly-typed Haskell data structures:

```haskell
-- See app/TerranixCodegen/ProviderSchema/
data ProviderSchema = ProviderSchema
  { configSchema :: Maybe Schema
  , resourceSchemas :: Maybe (Map Text Schema)
  , dataSourceSchemas :: Maybe (Map Text Schema)
  -- ...
  }
```

### 2. Type Mapping (Complete)

Maps Terraform's type system (go-cty) to Nix:

| Terraform CtyType | Nix Type |
|-------------------|----------|
| `CtyString` | `types.str` |
| `CtyNumber` | `types.number` |
| `CtyBool` | `types.bool` |
| `CtyList T` | `types.listOf (mapType T)` |
| `CtyMap T` | `types.attrsOf (mapType T)` |
| `CtyObject {...}` | `types.submodule { options = {...}; }` |
| `CtyTuple [...]` | [`types.tupleOf [...]`](./nix/lib/tuple.nix) |

See [`lib/TerranixCodegen/TypeMapper.hs`](./lib/TerranixCodegen/TypeMapper.hs) and [Type Mapper documentation](./docs/src/type-mapper.md).

### 3. Option Building (Complete)

Converts schema attributes to NixOS `mkOption` expressions with:

- Type mapping using TypeMapper
- Default value generation
- Comprehensive descriptions with metadata
- Support for nested attributes with all nesting modes

See [`lib/TerranixCodegen/OptionBuilder.hs`](./lib/TerranixCodegen/OptionBuilder.hs) and [Option Builder documentation](./docs/src/option-builder.md).

### 4. Module Generation (Complete)

Assembles complete NixOS modules from schemas:

- `generateResourceModule`: Creates `options.resource.{type}` modules
- `generateDataSourceModule`: Creates `options.data.{type}` modules
- `generateProviderModule`: Creates provider configuration modules
- Handles nested blocks recursively with proper nesting modes
- Supports all 5 nesting modes (single, group, list, set, map)

See [`lib/TerranixCodegen/ModuleGenerator.hs`](./lib/TerranixCodegen/ModuleGenerator.hs).

### 5. File Organization (Complete)

Organizes generated modules into a clean directory structure:

- Creates provider directories with proper nesting
- Generates `default.nix` import files at each level
- Writes individual module files for resources and data sources
- Pretty-prints Nix expressions using hnix

See [`lib/TerranixCodegen/FileOrganizer.hs`](./lib/TerranixCodegen/FileOrganizer.hs) and [`test/FileOrganizerSpec.hs`](./test/FileOrganizerSpec.hs).

### 6. Documentation Generation (Planned)

Future enhancement to create mdBook documentation with:

- Searchable resource reference
- Usage examples
- Argument/attribute listings
- Changelog generation

## Documentation

Detailed design documentation is available in [`docs/`](./docs/):

- **[Introduction](./docs/src/introduction.md)**: Project overview and motivation
- **[Design Overview](./docs/src/design-overview.md)**: Architecture and design decisions
- **[Transformation Examples](./docs/src/examples.md)**: Schema → module examples with HCL/Nix comparisons
- **[Documentation Generation](./docs/src/documentation-generation.md)**: Documentation strategy

Build the documentation locally:

```bash
cd docs
mdbook serve
# Open http://localhost:3000
```

## Building from Source

### Prerequisites

- Nix with flakes enabled
- GHC 9.6+ (if building without Nix)

### With Nix (Recommended)

```bash
# Development shell
nix develop

# Build
nix build

# Run tests
nix build .#checks.x86_64-linux.default
```

### With Cabal

```bash
cabal build
cabal test
cabal run terranix-codegen -- --help
```

## Project Structure

```
terranix-codegen/
├── lib/TerranixCodegen/       # Core library
│   ├── ProviderSchema/        # Schema type definitions (✅ complete)
│   │   ├── Attribute.hs
│   │   ├── Block.hs
│   │   ├── CtyType.hs
│   │   ├── Function.hs
│   │   ├── Provider.hs
│   │   ├── Schema.hs
│   │   └── Types.hs
│   ├── TypeMapper.hs          # CtyType → Nix type conversion (✅ complete)
│   ├── OptionBuilder.hs       # SchemaAttribute → mkOption (✅ complete)
│   ├── ModuleGenerator.hs     # Complete module generation (✅ complete)
│   ├── FileOrganizer.hs       # File organization and writing (✅ complete)
│   └── PrettyPrint.hs         # Nix expression pretty-printing
├── test/                      # Test suite
│   ├── TypeMapperSpec.hs      # Type mapper tests (25/25 ✅)
│   ├── OptionBuilderSpec.hs   # Option builder tests (31/31 ✅)
│   ├── ModuleGeneratorSpec.hs # Module generator tests (11/11 ✅)
│   ├── FileOrganizerSpec.hs   # File organizer tests (20/20 ✅)
│   └── TestUtils.hs           # Shared test utilities
├── app/                       # Executables
│   └── Main.hs                # CLI application with --print-schema flag (✅ complete)
├── docs/                      # Design documentation
│   └── src/
│       ├── introduction.md
│       ├── design-overview.md
│       ├── type-mapper.md
│       ├── option-builder.md
│       ├── examples.md
│       └── documentation-generation.md
├── nix/                       # Nix utilities
│   └── lib/
│       ├── tuple.nix          # Custom tupleOf type implementation
│       └── tuple.test.nix
├── vendor/                    # Vendored dependencies
├── flake.nix                  # Nix flake
├── terranix-codegen.cabal    # Cabal package definition
└── README.md                  # This file
```

## Why Haskell?

- **Type safety**: Terraform schemas are complex and recursive; Haskell's type system catches errors at compile time
- **Parsing**: `aeson` and `autodocodec` provide excellent JSON support
- **Code generation**: Pure functions and algebraic data types make generation logic clear and composable
- **Correctness**: Strong typing ensures generated modules exactly match provider schemas
- **Nix integration**: Both Haskell and Nix have excellent tooling in nixpkgs

## Contributing

Contributions are welcome! This project is actively being developed. Progress so far:

- [x] Implement Nix AST types (using hnix)
- [x] Implement Type Mapper (CtyType → Nix types)
- [x] Implement Option Builder (SchemaAttribute → mkOption)
- [x] Implement Module Generator (assembles complete modules)
- [x] Implement File Organizer (creates directory structure)
- [x] Add CLI with argument parsing
- [x] Write comprehensive tests (86/86 passing)
- [x] Create custom `types.tupleOf` implementation
- [ ] Implement documentation generator (mdBook)
- [ ] Add resource/provider filtering to CLI
- [ ] Add CI/CD pipeline
- [ ] Generate modules for popular providers (AWS, GCP, Azure)
- [ ] Publish to nixpkgs

Please open an issue before starting major work to discuss the approach.

## License

This project is licensed under the [Mozilla Public License 2.0 (MPL-2.0)](https://www.mozilla.org/en-US/MPL/2.0/).

## Acknowledgments

- [Terranix](https://terranix.org/) - Making Terraform configurations with Nix
- [terraform-json](https://github.com/hashicorp/terraform-json) - Reference Go implementation for schema types
- The NixOS and Terraform communities

______________________________________________________________________

**Note**: This is an independent project and is not officially affiliated with HashiCorp, Terraform, or Terranix.
