# Terranix Module Generator Design

## Overview

The Terranix Module Generator is a tool that automatically generates [Terranix](https://terranix.org/) modules from Terraform provider schemas. It bridges the gap between Terraform's provider ecosystem and Terranix's Nix-based configuration approach, enabling type-safe, composable infrastructure definitions.

### Goals

- **Automation**: Eliminate manual translation of Terraform provider schemas to Terranix modules
- **Correctness**: Ensure generated modules accurately reflect provider schemas
- **Type Safety**: Leverage NixOS module system for compile-time validation
- **Maintainability**: Support easy regeneration when providers update
- **Usability**: Provide intuitive CLI and well-documented output

## Architecture Overview

```
┌─────────────────────┐
│ terraform providers │
│  schema -json       │
└──────────┬──────────┘
           │ JSON
           ▼
┌─────────────────────┐
│  Schema Parser      │  (Already implemented)
│  ProviderSchemas    │
└──────────┬──────────┘
           │ Haskell Types
           ▼
┌─────────────────────┐
│  Module Generator   │  (To be implemented)
│  - Type Mapper      │
│  - Option Builder   │
│  - File Organizer   │
└──────────┬──────────┘
           │ Nix Modules
           ▼
┌─────────────────────┐
│  Output             │
│  providers/         │
│    aws/             │
│      resources/     │
│      data-sources/  │
│    ...              │
└─────────────────────┘
```

### Component Responsibilities

1. **Schema Parser** (✅ Complete)

   - Parses Terraform provider schema JSON
   - Validates schema structure
   - Provides strongly-typed Haskell representation
   - Location: `lib/TerranixCodegen/ProviderSchema/`

1. **Type Mapper** (✅ Complete)

   - Maps Terraform `CtyType` to Nix type expressions
   - Handles primitive, collection, and structural types
   - Preserves type constraints and metadata
   - Supports optional field wrapping with `types.nullOr`
   - Location: `lib/TerranixCodegen/TypeMapper.hs`
   - Tests: `test/TypeMapperSpec.hs` (18/18 passing)

1. **Option Builder** (✅ Complete)

   - Converts schema attributes to NixOS options
   - Generates documentation from schema descriptions
   - Handles required/optional/computed semantics
   - Supports metadata (deprecated, sensitive, write-only)
   - Fully supports nested attributes with all nesting modes
   - Location: `lib/TerranixCodegen/OptionBuilder.hs`
   - Tests: `test/OptionBuilderSpec.hs` (31/31 passing)

1. **Module Generator** (🔨 To Build)

   - Assembles complete NixOS modules
   - Handles nested blocks recursively
   - Manages different nesting modes (single, list, map, etc.)

1. **File Organizer** (🔨 To Build)

   - Creates directory structure
   - Generates import/export files
   - Manages cross-module references

## Type Mapping Strategy

The core challenge is mapping Terraform's type system (go-cty) to Nix's type system (NixOS modules).

### Primitive Types

| Terraform CtyType | Nix Type | Notes |
| ----------------- | ---------------- | ---------------------- |
| `CtyBool` | `types.bool` | Direct mapping |
| `CtyNumber` | `types.number` | Includes int and float |
| `CtyString` | `types.str` | Direct mapping |
| `CtyDynamic` | `types.anything` | Untyped/dynamic values |

### Collection Types (Homogeneous)

| Terraform CtyType | Nix Type | Example |
| ----------------- | --------------------------- | ---------------------- |
| `CtyList t` | `types.listOf (mapType t)` | `["a", "b"]` |
| `CtySet t` | `types.listOf (mapType t)` | Similar to list in Nix |
| `CtyMap t` | `types.attrsOf (mapType t)` | `{key = value;}` |

**Note**: Terraform Sets and Lists both map to `types.listOf` since Nix doesn't distinguish ordered/unordered at the type level.

### Structural Types

#### Objects

```haskell
CtyObject (Map Text CtyType) (Set Text)  -- attributes, optionals
```

Maps to:

```nix
types.submodule {
  options = {
    attr1 = mkOption { type = ...; };
    attr2 = mkOption { type = ...; default = null; };  # if optional
  };
}
```

#### Tuples

```haskell
CtyTuple [CtyType]
```

Maps to:

```nix
types.listOf types.anything  # with length validation
```

Or for known positions:

```nix
# Custom type validator checking length and element types
```

### Attribute Semantics

Terraform attributes have three orthogonal properties that affect Nix module generation:

| Property | Meaning | Nix Representation |
| ------------ | ----------------- | ------------------------------------ |
| **Required** | Must be in config | No `default` value |
| **Optional** | May be omitted | `default = null;` |
| **Computed** | Set by provider | `readOnly = true;` (if not settable) |

**Combinations**:

- `required=true`: User must provide value
- `optional=true`: User may provide value, `default = null;`
- `computed=true`: Provider can compute value
- `optional + computed`: User can provide OR provider computes
- Neither: Unusual, treat as optional

### Nested Blocks

Schema blocks with nesting modes map to different Nix structures:

| Nesting Mode | Terraform Example | Nix Type |
| --------------- | ------------------ | ------------------------------------------- |
| `NestingSingle` | Single block | `types.submodule { ... }` |
| `NestingGroup` | Single, never null | `types.submodule { ... }` (no default null) |
| `NestingList` | Ordered list | `types.listOf (types.submodule { ... })` |
| `NestingSet` | Unordered list | `types.listOf (types.submodule { ... })` |
| `NestingMap` | Map of blocks | `types.attrsOf (types.submodule { ... })` |

**Min/Max Items**: When specified, add validators:

```nix
type = types.listOf types.submodule { ... };
# Add assertion: length >= minItems && length <= maxItems
```

### Metadata Preservation

Schema metadata is preserved in generated modules:

- **Description**: → `description = "...";`
- **Description Kind**: Markdown descriptions use proper formatting
- **Deprecated**: → `warnings` in option definition
- **Sensitive**: → Documentation note (Nix doesn't hide values)
- **WriteOnly**: → Documentation note

## Module Structure

Generated modules follow a consistent directory structure that mirrors Terraform's organization:

```
providers/
├── {provider-name}/           # e.g., "aws", "google", "azurerm"
│   ├── default.nix            # Provider module entry point
│   ├── provider.nix           # Provider configuration options
│   ├── resources/
│   │   ├── default.nix        # Re-exports all resources
│   │   ├── {resource-name}.nix
│   │   └── ...
│   ├── data-sources/
│   │   ├── default.nix        # Re-exports all data sources
│   │   ├── {data-source-name}.nix
│   │   └── ...
│   └── functions/             # Provider functions (if any)
│       ├── default.nix
│       └── ...
└── default.nix                # Top-level exports all providers
```

### Module Format

Each resource/data source module follows this template:

```nix
{ lib, ... }:
with lib;
{
  options.{provider}.{resource_name}.{instance_name} = mkOption {
    type = types.attrsOf (types.submodule ({ config, ... }: {
      options = {
        # Generated options from schema
        id = mkOption {
          type = types.str;
          description = "Unique identifier (computed)";
          # Computed-only attributes might be readOnly
        };

        name = mkOption {
          type = types.str;
          description = "Resource name";
          # Required attribute has no default
        };

        tags = mkOption {
          type = types.attrsOf types.str;
          description = "Key-value tags";
          default = {};
        };

        # Nested block example
        nested_config = mkOption {
          type = types.listOf (types.submodule {
            options = {
              # Nested options...
            };
          });
          default = [];
        };
      };
    }));
    default = {};
    description = "Instances of {provider}_{resource_name}";
  };
}
```

### Provider Configuration Module

The provider configuration module (`provider.nix`) defines provider-level settings:

```nix
{ lib, ... }:
with lib;
{
  options.{provider_name} = mkOption {
    type = types.attrsOf (types.submodule {
      options = {
        # Provider configuration options from configSchema
        region = mkOption {
          type = types.str;
          description = "AWS region";
        };

        access_key = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "AWS access key";
        };

        # ... more provider options
      };
    });
    default = {};
    description = "{provider_name} provider configuration";
  };
}
```

### Cross-Module References

The `default.nix` files enable easy imports:

```nix
# providers/aws/default.nix
{
  imports = [
    ./provider.nix
    ./resources
    ./data-sources
  ];
}

# providers/aws/resources/default.nix
{
  imports = [
    ./instance.nix
    ./vpc.nix
    ./subnet.nix
    # ... all resources
  ];
}
```

Users can import selectively:

```nix
{
  imports = [ ./providers/aws ];  # Everything
  # OR
  imports = [ ./providers/aws/resources/instance.nix ];  # Just one resource
}
```

## CLI & User Workflow

### Input: Provider Schema

Users generate schema JSON using Terraform CLI:

```bash
# Initialize provider
terraform init

# Export schema
terraform providers schema -json > schema.json
```

This produces a JSON file with the complete provider schema structure.

### Tool Invocation

Basic usage:

```bash
terranix-codegen < schema.json
```

With options:

```bash
terranix-codegen \
  --input schema.json \
  --output ./terranix-modules \
  --provider aws \
  --format-style nixfmt
```

### CLI Arguments

| Flag | Description | Default |
| ----------------------- | --------------------------------------- | ------------- |
| `--input FILE` | Input schema JSON (or stdin) | stdin |
| `--output DIR` | Output directory | `./providers` |
| `--provider NAME` | Generate only specific provider(s) | all |
| `--resource PATTERN` | Filter resources by pattern | all |
| `--data-source PATTERN` | Filter data sources by pattern | all |
| `--format-style STYLE` | Nix formatter (nixfmt, alejandra, none) | nixfmt |
| `--no-docs` | Skip generating documentation comments | false |

### Output

The tool generates a complete Nix module hierarchy:

```
providers/
├── aws/
│   ├── default.nix
│   ├── provider.nix
│   ├── resources/
│   │   ├── default.nix
│   │   ├── instance.nix
│   │   ├── vpc.nix
│   │   └── ... (100+ files)
│   └── data-sources/
│       ├── default.nix
│       ├── ami.nix
│       └── ... (50+ files)
└── default.nix
```

### Integration with Terranix Projects

Users can integrate generated modules into existing terranix projects:

```nix
# terranix-config.nix
{
  imports = [
    # Import generated modules
    ./providers/aws
  ];

  # Use generated options
  resource.aws_instance.web = {
    ami = "ami-12345";
    instance_type = "t2.micro";
    tags = {
      Name = "web-server";
    };
  };
}
```

Then generate Terraform JSON:

```bash
terranix terranix-config.nix > terraform.json
terraform init
terraform apply
```

### Update Workflow

When providers update:

1. Update Terraform providers: `terraform init -upgrade`
1. Export new schema: `terraform providers schema -json > schema.json`
1. Regenerate modules: `terranix-codegen < schema.json`
1. Review changes (via git diff)
1. Update configurations if breaking changes

## Design Decisions

### Why NixOS Modules?

**Advantages**:

- **Type safety**: Catch configuration errors before runtime
- **Composition**: Easily combine and override configurations
- **Documentation**: Self-documenting via option descriptions
- **Validation**: Built-in constraint checking
- **IDE support**: Nix language servers understand module structure

**Trade-offs**:

- More verbose than raw Terraform HCL
- Learning curve for Nix module system
- Generated files are larger

### Why Generate Per-Resource Files?

**Advantages**:

- **Performance**: Import only needed resources
- **Clarity**: Easy to find and read individual resource definitions
- **Git-friendly**: Changes to provider affect only modified resources
- **Debugging**: Clear source of type errors

**Trade-offs**:

- More files to manage (100+ for large providers)
- Longer generation time
- Larger disk footprint

**Alternative considered**: Single file per provider (rejected due to 10,000+ line files)

### Why Preserve Schema Metadata?

Keeping descriptions, deprecation warnings, and other metadata ensures:

- Generated modules are self-documenting
- Users get IDE hints and warnings
- Deprecated options are clearly marked
- Migration to new schemas is smoother

### Why Support Filtering?

Large providers (AWS, Google Cloud) have hundreds of resources. Filtering allows:

- Faster generation for specific use cases
- Smaller module footprint
- Focused updates when only certain resources change

### Code Generation vs. Runtime Parsing

**Decision**: Code generation (static Nix modules)

**Rationale**:

- Nix modules provide compile-time safety
- No runtime dependencies on terranix-codegen
- Better IDE/tooling support
- Clearer error messages
- Can version generated modules independently

**Alternative**: Runtime schema parsing (rejected due to poor UX)

## Future Enhancements

Potential future improvements:

1. **Incremental Generation**: Only regenerate changed resources
1. **Custom Overlays**: User-defined modifications to generated modules
1. **Migration Helpers**: Automated config updates for breaking changes
1. **Validation Functions**: Generate custom validators for complex constraints
1. **Test Generation**: Generate basic terranix tests for each resource
1. **Documentation Site**: Generate browsable documentation (mdbook/nixos-manual)
1. **Provider Plugins**: Custom generation logic for specific providers
1. **Schema Caching**: Cache schemas to speed up regeneration

## References

- [Terraform Provider Schema](https://www.terraform.io/internals/json-format#provider-schemas)
- [Terranix Documentation](https://terranix.org/)
- [NixOS Module System](https://nixos.org/manual/nixos/stable/index.html#sec-writing-modules)
- [go-cty Type System](https://github.com/zclconf/go-cty)
