# terranix-codegen

> Automatically generate [Terranix](https://terranix.org/) modules from Terraform provider schemas

[![License: MPL 2.0](https://img.shields.io/badge/License-MPL_2.0-brightgreen.svg)](https://opensource.org/licenses/MPL-2.0)

**terranix-codegen** bridges the gap between Terraform's vast provider ecosystem and Terranix's type-safe, Nix-based infrastructure configuration by automatically generating NixOS modules from Terraform provider schemas.

## Project Status

**Early Development** - The schema parser is complete, but code generation is not yet implemented.

- **Schema parsing**: Complete and tested
- **Design documentation**: Architecture defined
- **Code generation**: Not yet implemented
- **Documentation generation**: Not yet implemented
- **CLI**: Not yet implemented

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

## Quick Start (Future)

Once implemented, the workflow will be:

```bash
# 1. Get provider schema
terraform providers schema -json > schema.json

# 2. Generate Terranix modules
terranix-codegen --input schema.json --output ./terranix-modules

# 3. Use in your Terranix config
cat > config.nix <<EOF
{
  imports = [ ./terranix-modules/aws ];

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

### 2. Type Mapping (Planned)

Maps Terraform's type system to Nix:

| Terraform | Nix |
|-----------|-----|
| `string` | `types.str` |
| `list(T)` | `types.listOf (mapType T)` |
| `object({...})` | `types.submodule { options = {...}; }` |

### 3. Module Generation (Planned)

Generates NixOS modules with:

- Proper types for all attributes
- Documentation from schema descriptions
- Validation for required/optional fields
- Support for nested blocks and complex types

### 4. Documentation Generation (Planned)

Creates mdBook documentation with:

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
├── app/
│   ├── Main.hs
│   └── TerranixCodegen/
│       ├── ProviderSchema/    # Schema type definitions (complete)
│       │   ├── Attribute.hs
│       │   ├── Block.hs
│       │   ├── CtyType.hs
│       │   ├── Function.hs
│       │   ├── Provider.hs
│       │   ├── Schema.hs
│       │   └── Types.hs
│       ├── Generator/         # Code generation (to be implemented)
│       └── Docs/              # Documentation generation (to be implemented)
├── docs/                      # Design documentation
│   └── src/
│       ├── introduction.md
│       ├── design-overview.md
│       ├── examples.md
│       └── documentation-generation.md
├── vendor/
│   └── terraform-json/        # Reference Go implementation
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

Contributions are welcome! This project is in early development, and there's plenty of work to do:

- [ ] Implement Nix AST types
- [ ] Implement module generator
- [ ] Implement documentation generator
- [ ] Add CLI with argument parsing
- [ ] Write tests for generation logic
- [ ] Add CI/CD pipeline
- [ ] Generate modules for popular providers (AWS, GCP, Azure)

Please open an issue before starting major work to discuss the approach.

## License

This project is licensed under the [Mozilla Public License 2.0 (MPL-2.0)](https://www.mozilla.org/en-US/MPL/2.0/).

## Acknowledgments

- [Terranix](https://terranix.org/) - Making Terraform configurations with Nix
- [terraform-json](https://github.com/hashicorp/terraform-json) - Reference Go implementation for schema types
- The NixOS and Terraform communities

______________________________________________________________________

**Note**: This is an independent project and is not officially affiliated with HashiCorp, Terraform, or Terranix.
