# Documentation Generation

Generating comprehensive, accurate documentation is essential for making generated Terranix modules usable and maintainable. This document outlines the strategy for automatically generating documentation from Terraform provider schemas.

## Why Documentation Matters

Generated modules without documentation are difficult to use because:

1. **Discovery**: Users can't find available resources and their options
2. **Understanding**: Type signatures alone don't explain what attributes do
3. **Validation**: Users need to know constraints (required fields, valid values)
4. **Migration**: Deprecation warnings guide users to newer patterns
5. **IDE Support**: Documentation enables autocomplete and inline help

Since Terraform provider schemas already contain rich metadata (descriptions, types, constraints), we can generate documentation automatically rather than requiring manual maintenance.

## Documentation Sources

The Terraform provider schema provides several sources of documentation:

### From Schema Attributes

```json
{
  "ami": {
    "type": "string",
    "description": "AMI to use for the instance",
    "description_kind": "plain",
    "required": true
  }
}
```

Extractable information:
- **Description**: Human-readable explanation
- **Type**: Data type (string, number, bool, list, object, etc.)
- **Required/Optional**: Whether the attribute must be provided
- **Computed**: Whether the provider sets this value
- **Sensitive**: Whether the value contains secrets
- **Deprecated**: Whether the attribute is deprecated

### From Schema Blocks

```json
{
  "root_block_device": {
    "nesting_mode": "single",
    "block": {
      "attributes": { ... }
    },
    "min_items": 1,
    "max_items": 1
  }
}
```

Extractable information:
- **Nesting mode**: How blocks are structured (single, list, map)
- **Min/Max items**: Constraints on number of blocks
- **Nested structure**: Recursive block and attribute definitions

### From Provider Metadata

```json
{
  "provider_schemas": {
    "registry.terraform.io/hashicorp/aws": {
      "provider": { ... },
      "resource_schemas": { ... },
      "data_source_schemas": { ... }
    }
  }
}
```

Extractable information:
- **Provider name**: E.g., "aws", "google", "azurerm"
- **Resource types**: All available resources
- **Data source types**: All available data sources
- **Schema versions**: For tracking changes over time

## Documentation Types

### 1. Inline Module Documentation

Documentation embedded directly in the generated Nix modules as option descriptions.

**Purpose**: Provide IDE hints and inline help

**Example**:
```nix
ami = mkOption {
  type = types.str;
  description = ''
    AMI to use for the instance.

    This must be an AMI ID in the format ami-xxxxxxxx.
    The AMI must be available in the selected region.
  '';
};
```

**Advantages**:
- Immediately available in the Nix REPL
- IDE integration (nix-lsp, nil)
- No separate documentation to maintain

**Limitations**:
- Limited formatting options
- No cross-references between options
- Hard to browse all options

### 2. Web Documentation (mdBook)

Generate browsable web documentation with search, navigation, and examples using mdBook.

**Purpose**: Primary documentation format for users

**Structure**:
```
docs/
├── providers/
│   ├── aws/
│   │   ├── index.md
│   │   ├── resources/
│   │   │   ├── instance.md
│   │   │   ├── vpc.md
│   │   │   └── ...
│   │   └── data-sources/
│   │       ├── ami.md
│   │       └── ...
│   ├── google/
│   └── ...
└── SUMMARY.md
```

**Example Page** (`resources/instance.md`):

````markdown
# aws_instance

Launch and manage EC2 instances.

## Example Usage

```nix
resource.aws_instance.web = {
  ami           = "ami-0c55b159cbfafe1f0";
  instance_type = "t2.micro";

  tags = {
    Name = "Web Server";
  };
};
```

## Argument Reference

### Required Arguments

- **`ami`** (string) - AMI to use for the instance. This must be an AMI ID in the format `ami-xxxxxxxx`.
- **`instance_type`** (string) - Instance type to launch. Examples: `"t2.micro"`, `"t3.medium"`.

### Optional Arguments

- **`tags`** (map of string) - Key-value tags to assign to the instance. Default: `{}`.
- **`subnet_id`** (string) - VPC subnet ID to launch in. Default: `null`.

### Computed Attributes

- **`id`** (string, read-only) - Instance ID assigned by AWS.
- **`public_ip`** (string, read-only) - Public IP address, if assigned.

## Block Reference

### `root_block_device`

Configure the root EBS volume.

- **`volume_size`** (number) - Size of the volume in GiB. Default: `null`.
- **`volume_type`** (string) - Type of volume. Values: `"gp2"`, `"gp3"`, `"io1"`. Default: `null`.

### `ebs_block_device`

Additional EBS volumes to attach. Can be specified multiple times.

- **`device_name`** (string, required) - Device name to attach to (e.g., `/dev/sdf`).
- **`volume_size`** (number) - Size of the volume in GiB.
- **`encrypted`** (bool) - Whether to encrypt the volume. Default: `null`.

## See Also

- [aws_ami](../data-sources/ami.md) - Find AMI IDs
- [aws_subnet](./subnet.md) - Manage VPC subnets
````

**Advantages**:
- User-friendly and searchable
- Can include examples and guides
- Easy to navigate and discover
- Can link to Terraform docs
- Modern, familiar interface
- Great developer experience

**Build Command**:
```bash
cd docs && mdbook build
# Output: docs/book/
```

## Documentation Structure

### Resource/Data Source Pages

Each resource and data source gets its own documentation page with:

**1. Overview**
- Brief description of what the resource manages
- Link to upstream Terraform provider docs

**2. Example Usage**
- Complete working example in Terranix
- Common use cases
- Multiple examples for complex resources

**3. Argument Reference**
Organized by:
- **Required Arguments**: Must be specified
- **Optional Arguments**: Can be omitted
- **Computed Arguments**: Set by provider (read-only)

For each argument:
- Name and type
- Description (from schema)
- Default value
- Valid values or constraints
- Deprecation warnings

**4. Block Reference**
For nested blocks:
- Block name and purpose
- Nesting mode (single, list, map)
- Min/max items
- Nested arguments

**5. Deprecations and Migrations**
- Deprecated arguments with alternatives
- Migration guides for breaking changes

**6. See Also**
- Related resources
- Data sources
- External links

### Provider Configuration Pages

Document provider-level configuration:

**Example** (`providers/aws.md`):
```markdown
# AWS Provider

Configure the AWS provider for Terranix.

## Example Usage

```nix
provider.aws.main = {
  region = "us-east-1";

  assume_role = {
    role_arn = "arn:aws:iam::123456789012:role/TerraformRole";
  };
};
```

## Configuration Reference

- **`region`** (string, required) - AWS region for API requests
- **`access_key`** (string) - AWS access key ID
- **`secret_key`** (string) - AWS secret access key
```

### Index Pages

Top-level pages for navigation:

**Provider Index** (`providers/aws/index.md`):
- Overview of provider
- Installation/setup instructions
- Authentication methods
- List of all resources
- List of all data sources

**Global Index** (`index.md`):
- List of all supported providers
- Quick start guide
- How to use generated modules

## Implementation Approach

### Phase 1: Inline Documentation (Minimum Viable)

Generate Nix modules with comprehensive option descriptions.

**Implementation**:
```haskell
generateOption :: SchemaAttribute -> NixOption
generateOption attr = NixOption
  { optionType = mapCtyType (attributeType attr)
  , optionDescription = buildDescription attr
  , optionDefault = if isOptional attr then Just NixNull else Nothing
  }

buildDescription :: SchemaAttribute -> Text
buildDescription attr = T.unlines $ catMaybes
  [ attributeDescription attr
  , formatDeprecation (attributeDeprecated attr)
  , formatSensitive (attributeSensitive attr)
  , formatComputed (attributeComputed attr)
  ]

formatDeprecation :: Maybe Bool -> Maybe Text
formatDeprecation (Just True) = Just "\nDEPRECATED: This attribute is deprecated."
formatDeprecation _ = Nothing
```

### Phase 2: Web Documentation (mdBook)

Generate markdown files and build with mdBook.

**Implementation**:
```haskell
generateDocs :: ProviderSchema -> IO ()
generateDocs schema = do
  createProviderIndex schema
  forM_ (resourceSchemas schema) $ \(name, resSchema) -> do
    generateResourceDoc name resSchema
  generateSummary schema

generateResourceDoc :: Text -> Schema -> IO ()
generateResourceDoc name schema = do
  let doc = ResourceDoc
        { docTitle = name
        , docDescription = extractDescription schema
        , docExample = generateExample name schema
        , docArguments = generateArgumentDocs schema
        , docBlocks = generateBlockDocs schema
        }
  writeMarkdown (docPath name) (renderResourceDoc doc)
```

**Output Structure**:
```
docs/
├── book.toml              # mdBook configuration
├── src/
│   ├── SUMMARY.md         # Table of contents
│   ├── introduction.md    # Getting started
│   ├── providers/
│   │   ├── aws/
│   │   │   ├── index.md
│   │   │   ├── resources/
│   │   │   │   └── *.md
│   │   │   └── data-sources/
│   │   │       └── *.md
│   │   └── ...
│   └── guides/
│       ├── installation.md
│       └── migration.md
└── theme/                 # Custom styling
```

### Phase 3: Interactive Documentation

Add interactive features:
- **Search**: Full-text search across all documentation
- **Type Explorer**: Interactive type browser
- **Example Generator**: Generate examples from schemas
- **Changelog**: Track schema changes between provider versions

## Documentation Metadata

Enhance generated documentation with additional metadata:

### Terraform Provider Links

Link to upstream Terraform documentation:
```nix
# In module comments
# Terraform Docs: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance
```

### Schema Version Tracking

Document which provider version the modules were generated from:
```markdown
---
provider: aws
provider_version: 5.31.0
schema_version: 0
generated_at: 2025-01-17T10:30:00Z
---
```

### Examples from Community

Option to include curated examples:
```markdown
## Community Examples

- [Multi-region deployment](./examples/multi-region.md)
- [Auto-scaling group](./examples/asg.md)
```

## Keeping Documentation Up-to-Date

### Regeneration Workflow

When providers update:

1. **Fetch new schema**:
   ```bash
   terraform init -upgrade
   terraform providers schema -json > schema.json
   ```

2. **Regenerate modules and docs**:
   ```bash
   terranix-codegen --input schema.json --output ./modules --docs ./docs
   ```

3. **Review changes**:
   ```bash
   git diff docs/
   ```

4. **Highlight breaking changes**:
   - Deprecated → removed attributes
   - Changed types
   - New required attributes

### Changelog Generation

Automatically generate changelogs by comparing schemas:

```markdown
# Changelog: AWS Provider 5.30.0 → 5.31.0

## aws_instance

### Added
- `maintenance_options` - Configure instance maintenance behavior

### Deprecated
- `credit_specification` - Use `credit_specification` block instead

### Changed
- `network_interface.device_index` now required (was optional)
```

## Documentation Best Practices

### 1. Use Clear, Consistent Language

**Good**:
```
AMI to use for the instance. Must be an AMI ID in the format ami-xxxxxxxx.
```

**Bad**:
```
The AMI. (string)
```

### 2. Provide Context and Examples

**Good**:
```
`instance_type` (string, required)

Instance type to launch. Determines CPU, memory, and network performance.

Common types:
- `"t2.micro"` - 1 vCPU, 1 GiB RAM (free tier eligible)
- `"t3.medium"` - 2 vCPU, 4 GiB RAM
- `"m5.large"` - 2 vCPU, 8 GiB RAM

See [AWS Instance Types](https://aws.amazon.com/ec2/instance-types/) for complete list.
```

**Bad**:
```
`instance_type` (string) - The instance type.
```

### 3. Explain Relationships

**Good**:
```
`subnet_id` (string)

VPC subnet ID to launch the instance in. The subnet determines the
availability zone and VPC for the instance.

If not specified, uses the default subnet in the default VPC.

See also: [aws_subnet](./subnet.md)
```

### 4. Document Computed Attributes Clearly

**Good**:
```
`id` (string, read-only)

Instance ID assigned by AWS after the instance is created.

Format: `i-xxxxxxxxxxxxxxxxx`

This value is computed and cannot be set.
```

### 5. Warn About Sensitive Data

**Good**:
```
`password` (string, sensitive)

Database password.

**Warning**: This value will be stored in the Terraform state file in
plain text. Use a secrets management system for production deployments.
```

## Tooling

### mdBook

The primary tool for generating web documentation:

- **Fast**: Rust-based, compiles quickly even for large doc sets
- **Simple**: Minimal configuration, sensible defaults
- **Great search**: Built-in full-text search
- **Excellent Nix integration**: Easy to package and build
- **Customizable**: Themes, plugins, preprocessors

**Installation**:
```nix
# In your flake.nix or shell.nix
buildInputs = [ pkgs.mdbook ];
```

### Custom Documentation Generator

Build a Haskell tool to generate documentation:

```haskell
module TerranixCodegen.Docs where

data DocFormat
  = InlineNix      -- Embedded in modules
  | MdBook         -- Web documentation
  | Changelog      -- Version comparison
  | JSON           -- Structured data for tooling

generateDocs :: ProviderSchemas -> DocFormat -> IO ()
```

### Example Build Integration

```nix
{
  terranix-aws-docs = pkgs.stdenv.mkDerivation {
    name = "terranix-aws-docs";
    src = ./docs;
    buildInputs = [ pkgs.mdbook ];
    buildPhase = "mdbook build";
    installPhase = ''
      mkdir -p $out
      cp -r book/* $out/
    '';
  };
}
```

## Future Enhancements

### 1. Auto-generated Diagrams

Generate diagrams showing resource relationships:
```
aws_instance
  ├─ requires: aws_subnet
  ├─ requires: aws_security_group
  ├─ creates: aws_ebs_volume (via ebs_block_device)
  └─ referenced by: aws_lb_target_group_attachment
```

### 2. Migration Assistants

Generate migration guides for breaking changes:
```markdown
## Migrating from v4 to v5

The `availability_zone` attribute has been removed. Use the `placement` block instead:

**Before**:
```nix
availability_zone = "us-east-1a";
```

**After**:
```nix
placement = {
  availability_zone = "us-east-1a";
};
```
```

### 3. AI-Enhanced Descriptions

Optionally enhance schema descriptions with AI-generated examples and explanations.

### 4. Usage Analytics

Track which resources are most commonly used to prioritize documentation improvements.

## Summary

Good documentation is critical for generated modules. By leveraging the rich metadata in Terraform provider schemas, we can automatically generate:

1. **Inline documentation** embedded in modules for IDE support
2. **mdBook web documentation** for discovery, learning, and reference
3. **Changelogs** tracking provider updates and breaking changes
4. **Examples** showing common usage patterns

This approach provides a modern documentation experience that's searchable, browsable, and maintainable, without the complexity of legacy documentation formats.
