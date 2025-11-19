# Introduction

**terranix-codegen** is a code generator that automatically creates [Terranix](https://terranix.org/) modules from Terraform provider schemas. It bridges the gap between Terraform's vast provider ecosystem and Terranix's type-safe, Nix-based infrastructure configuration.

## What is Terranix?

Terranix is a tool that lets you write Terraform configurations using the Nix language instead of HashiCorp Configuration Language (HCL). This brings several advantages:

- **Type safety**: Leverage Nix's type system and NixOS modules
- **Composition**: Reuse and combine configurations using Nix's module system
- **Functional**: Pure, declarative infrastructure definitions
- **Tooling**: Use Nix's rich ecosystem of tools and libraries

Instead of writing Terraform HCL:

```hcl
resource "aws_instance" "web" {
  ami           = "ami-123456"
  instance_type = "t2.micro"
}
```

You write Nix:

```nix
resource.aws_instance.web = {
  ami = "ami-123456";
  instance_type = "t2.micro";
};
```

Terranix then generates the Terraform JSON configuration.

## The Problem

While Terranix is powerful, manually creating Nix modules for every Terraform provider is tedious and error-prone:

- **Hundreds of providers**: AWS alone has 1000+ resources
- **Frequent updates**: Providers add new resources and attributes constantly
- **Type information**: Schemas define types, constraints, and documentation
- **Manual maintenance**: Keeping modules in sync with providers is a full-time job

## The Solution

terranix-codegen solves this by automatically generating Terranix modules from Terraform provider schemas:

```
Terraform Provider → Schema JSON → terranix-codegen → Nix Modules
```

### What It Does

1. **Reads** Terraform provider schemas (from `terraform providers schema -json`)
1. **Parses** the schema into strongly-typed Haskell data structures
1. **Generates** NixOS modules with proper types and documentation
1. **Organizes** modules into a clean directory structure
1. **Produces** documentation (mdBook format) for easy browsing

### What You Get

After running terranix-codegen on the AWS provider, you get:

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
└── docs/                     # Generated documentation
    └── book/                 # Built mdBook site
```

Each module includes:

- **Type-safe options**: Proper Nix types for every attribute
- **Documentation**: Descriptions, constraints, deprecation warnings
- **Validation**: Required/optional checks, nesting modes
- **Examples**: Usage examples in documentation

## How It Works

terranix-codegen is built in Haskell and uses a multi-phase approach:

### 1. Schema Parsing (✅ Complete)

The schema parser reads Terraform's JSON schema format and converts it into Haskell types:

- `ProviderSchema`: Top-level provider container
- `Schema`: Individual resource/data source schemas
- `SchemaBlock`: Nested configuration blocks
- `SchemaAttribute`: Individual attributes
- `CtyType`: Terraform's type system (primitives, collections, objects)

See [`app/TerranixCodegen/ProviderSchema/`](../../app/TerranixCodegen/ProviderSchema/) for the complete type definitions.

### 2. Type Mapping (✅ Complete)

Maps Terraform types to Nix types using hnix AST generation:

| Terraform | Nix |
|-----------|-----|
| `string` | `types.str` |
| `number` | `types.number` |
| `bool` | `types.bool` |
| `dynamic` | `types.anything` |
| `list(T)` | `types.listOf (mapType T)` |
| `set(T)` | `types.listOf (mapType T)` |
| `map(T)` | `types.attrsOf (mapType T)` |
| `object({...})` | `types.submodule { options = {...}; }` |
| `tuple([...])` | `types.listOf types.anything` |

Implementation includes:

- Full support for nested types
- Optional field handling with `types.nullOr`
- Comprehensive test coverage with quasiquoter-based assertions

### 3. Module Generation (🔨 To Build)

Generates NixOS modules from schemas:

- Converts attributes to options
- Handles nested blocks recursively
- Preserves metadata (descriptions, deprecations)
- Generates proper defaults (null for optional, none for required)

### 4. Documentation Generation (🔨 To Build)

Creates mdBook documentation:

- Resource reference pages with examples
- Argument/attribute listings
- Block structure documentation
- Searchable, browsable web interface

## Project Status

**Current State**: Active development

- ✅ **Schema parsing**: Complete and tested
- ✅ **Design documentation**: Architecture defined
- ✅ **Type Mapper**: Complete with 18 passing tests
- 🔨 **Option Builder**: Not yet implemented
- 🔨 **Module Generator**: Not yet implemented
- 🔨 **File Organizer**: Not yet implemented
- 🔨 **Documentation generation**: Not yet implemented
- 🔨 **CLI**: Not yet implemented

## Quick Start

(Once implemented, the workflow will be:)

```bash
# 1. Get provider schema
cd your-terraform-project/
terraform init
terraform providers schema -json > schema.json

# 2. Generate Terranix modules
terranix-codegen --input schema.json --output ./terranix-modules

# 3. Use the generated modules
# In your terranix configuration:
{
  imports = [ ./terranix-modules/aws ];

  resource.aws_instance.web = {
    ami = "ami-123456";
    instance_type = "t2.micro";
  };
}

# 4. Generate Terraform JSON
terranix terranix-config.nix > config.tf.json

# 5. Apply with Terraform
terraform init
terraform apply
```

## Documentation

This documentation covers the design and architecture of terranix-codegen:

- **[Design Overview](./design-overview.md)**: Architecture, components, and design decisions
- **[Transformation Examples](./examples.md)**: Concrete examples of schema → module transformations
- **[Documentation Generation](./documentation-generation.md)**: Strategy for generating user documentation

## Why Haskell?

terranix-codegen is written in Haskell for several reasons:

- **Type safety**: The schema is complex and recursive; Haskell's type system catches errors
- **Parsing**: `aeson` and `autodocodec` make JSON parsing straightforward
- **Code generation**: Pure functions and algebraic data types make generation logic clear
- **Correctness**: Strong typing ensures generated modules match schemas exactly
- **Nix integration**: Both Haskell and Nix have excellent tooling in nixpkgs

## Contributing

(Future section for contribution guidelines)

## License

terranix-codegen is licensed under the [Mozilla Public License 2.0 (MPL-2.0)](https://www.mozilla.org/en-US/MPL/2.0/).
