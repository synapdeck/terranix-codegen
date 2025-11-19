# Option Builder

The **Option Builder** is responsible for converting Terraform schema attributes into NixOS `mkOption` expressions with proper types, defaults, descriptions, and metadata.

## Overview

The Option Builder sits between the Type Mapper and the Module Generator in the code generation pipeline:

```
SchemaAttribute → [Option Builder] → mkOption { ... } → [Module Generator] → Complete Module
```

### Location

- **Implementation**: `lib/TerranixCodegen/OptionBuilder.hs`
- **Tests**: `test/OptionBuilderSpec.hs`
- **Test Coverage**: 24/24 tests passing

## Core Functionality

### Main Entry Point

```haskell
buildOption :: Text -> SchemaAttribute -> NExpr
```

Takes an attribute name and its schema definition, returns a complete `mkOption` expression.

**Example Input** (SchemaAttribute):

```haskell
SchemaAttribute
  { attributeType = Just CtyString
  , attributeDescription = Just "AMI to use for the instance"
  , attributeRequired = Just True
  , ...
  }
```

**Example Output** (Nix):

```nix
mkOption {
  type = types.str;
  description = "AMI to use for the instance";
}
```

## Type Handling

The Option Builder delegates type conversion to the Type Mapper while adding the optional/required logic:

- **Required attributes**: Direct type (e.g., `types.str`)
- **Optional attributes**: Wrapped with `types.nullOr` (e.g., `types.nullOr types.str`)
- **Computed attributes**: Treated as optional (can be `null` if provider hasn't set it yet)

```haskell
buildType :: SchemaAttribute -> NExpr
```

### Attribute Semantics

| Required | Optional | Computed | Type Wrapping | Default Value |
|----------|----------|----------|---------------|---------------|
| True | - | - | `types.str` | No default |
| - | True | - | `types.nullOr types.str` | `null` |
| - | - | True | `types.nullOr types.str` | `null` |
| - | True | True | `types.nullOr types.str` | `null` |

## Default Values

```haskell
buildDefault :: SchemaAttribute -> Maybe NExpr
```

Determines the appropriate default value:

- **Required attributes**: `Nothing` (no default, user must provide)
- **Optional attributes**: `Just mkNull` (defaults to `null`)
- **Computed-only attributes**: `Just mkNull` (provider will set value)

## Description Building

```haskell
buildDescription :: SchemaAttribute -> Maybe Text
```

Combines multiple metadata sources into comprehensive descriptions:

### Base Description

The primary description from `attributeDescription` field.

### Metadata Warnings

Additional information appended based on schema flags:

1. **Deprecation** (`attributeDeprecated = True`):

   ```
   DEPRECATED: This attribute is deprecated and may be removed in a future version.
   ```

1. **Sensitivity** (`attributeSensitive = True`):

   ```
   WARNING: This attribute contains sensitive information and will not be displayed in logs.
   ```

1. **Write-Only** (`attributeWriteOnly = True`):

   ```
   NOTE: This attribute is write-only and will not be persisted in the Terraform state.
   ```

1. **Computed-Only** (computed but not required/optional):

   ```
   This value is computed by the provider.
   ```

### String Formatting

- **Single-line descriptions**: Use double-quoted strings (`"..."`)
- **Multi-line descriptions**: Use indented strings (`''...''`) with trailing newline

**Example**:

```nix
# Single-line
description = "AMI to use for the instance";

# Multi-line
description = ''
  Legacy password field

  DEPRECATED: This attribute is deprecated and may be removed in a future version.

  WARNING: This attribute contains sensitive information and will not be displayed in logs.
'';
```

## Read-Only Attributes

```haskell
isReadOnly :: SchemaAttribute -> Bool
```

Marks attributes as `readOnly = true` when:

- `attributeComputed = True`
- AND neither `attributeRequired` nor `attributeOptional` are `True`

This indicates the attribute is computed-only and cannot be set by the user.

**Example**:

```nix
mkOption {
  type = types.nullOr types.str;
  default = null;
  description = ''
    Instance ID

    This value is computed by the provider.
  '';
  readOnly = true;
}
```

## Helper Functions

### `isOptionalAttribute`

```haskell
isOptionalAttribute :: SchemaAttribute -> Bool
```

Determines if an attribute is optional by checking:

- `attributeOptional = True`, OR
- `attributeComputed = True` (computed values can be omitted)

### `catMaybes`

```haskell
catMaybes :: [Maybe a] -> [a]
```

Filters out `Nothing` values from binding lists, ensuring the generated `mkOption` only includes relevant fields.

## Complete Examples

### Example 1: Required String Attribute

**Input**:

```haskell
SchemaAttribute
  { attributeType = Just CtyString
  , attributeDescription = Just "AMI to use for the instance"
  , attributeRequired = Just True
  , ...
  }
```

**Output**:

```nix
mkOption {
  type = types.str;
  description = "AMI to use for the instance";
}
```

### Example 2: Optional Map with Default

**Input**:

```haskell
SchemaAttribute
  { attributeType = Just (CtyMap CtyString)
  , attributeDescription = Just "Resource tags"
  , attributeOptional = Just True
  , ...
  }
```

**Output**:

```nix
mkOption {
  type = types.nullOr (types.attrsOf types.str);
  default = null;
  description = "Resource tags";
}
```

### Example 3: Computed-Only Attribute

**Input**:

```haskell
SchemaAttribute
  { attributeType = Just CtyString
  , attributeDescription = Just "Instance ID"
  , attributeComputed = Just True
  , ...
  }
```

**Output**:

```nix
mkOption {
  type = types.nullOr types.str;
  default = null;
  description = ''
    Instance ID

    This value is computed by the provider.
  '';
  readOnly = true;
}
```

### Example 4: Deprecated Sensitive Attribute

**Input**:

```haskell
SchemaAttribute
  { attributeType = Just CtyString
  , attributeDescription = Just "Legacy password field"
  , attributeOptional = Just True
  , attributeDeprecated = Just True
  , attributeSensitive = Just True
  , ...
  }
```

**Output**:

```nix
mkOption {
  type = types.nullOr types.str;
  default = null;
  description = ''
    Legacy password field

    DEPRECATED: This attribute is deprecated and may be removed in a future version.

    WARNING: This attribute contains sensitive information and will not be displayed in logs.
  '';
}
```

## Design Decisions

### Why Track All Metadata?

Preserving deprecation warnings, sensitivity flags, and other metadata ensures:

- Generated modules are self-documenting
- Users receive appropriate warnings in their IDE
- Migration paths are clearer when schemas change

### Why Use `readOnly` for Computed-Only Attributes?

Marking computed-only attributes as `readOnly` prevents users from attempting to set values that will be ignored or cause errors. This provides better type safety and clearer intent.

### Why Different String Formats?

- **Double-quoted strings**: Better for single-line descriptions, cleaner in generated code
- **Indented strings**: Better for multi-line descriptions, preserve formatting, handle special characters naturally

### Why Default to `null` for Optional Attributes?

This aligns with Terraform's semantics where optional attributes are omitted from configuration and treated as unset/null. Using `null` as the default allows users to explicitly override provider-computed values when `optional + computed`.

## Integration with Type Mapper

The Option Builder depends on the Type Mapper for type conversion:

```haskell
import TerranixCodegen.TypeMapper (mapCtyTypeToNixWithOptional)

buildType attr =
  mapCtyTypeToNixWithOptional (isOptionalAttribute attr) ctyType
```

This separation of concerns keeps the Option Builder focused on option structure and metadata, while the Type Mapper handles the complexity of type system mapping.

## Future Enhancements

Potential improvements for the Option Builder:

1. **Nested Attribute Support**: Full support for `SchemaNestedAttributeType` (currently uses placeholder `types.attrs`)
1. **Default Value Inference**: Smart defaults for list/map types based on nesting mode
1. **Validation Functions**: Generate custom validators for constraints (min/max items, regex patterns)
1. **Example Values**: Include example configurations in descriptions
1. **Conflict Detection**: Mark mutually exclusive attributes in descriptions

## Testing Strategy

The test suite (`test/OptionBuilderSpec.hs`) covers:

- **Attribute semantics**: Required, optional, computed, and combinations
- **Type handling**: Primitives, collections, complex types
- **Metadata**: Deprecation, sensitivity, write-only flags
- **Description building**: Single-line, multi-line, metadata combinations
- **Edge cases**: Missing types, no descriptions, all metadata flags together
- **Real-world examples**: Based on AWS provider patterns

All tests use the `shouldMapTo` helper from `test/TestUtils.hs` to compare generated Nix expressions with expected output, ignoring source position metadata.
