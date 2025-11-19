# Type Mapper

The Type Mapper is responsible for converting Terraform's `CtyType` type system to Nix type expressions that work with the NixOS module system.

## Overview

Located in `lib/TerranixCodegen/TypeMapper.hs`, the Type Mapper provides two main functions:

- `mapCtyTypeToNix :: CtyType -> NExpr` - Maps a Terraform type to a Nix type expression
- `mapCtyTypeToNixWithOptional :: Bool -> CtyType -> NExpr` - Optionally wraps the type in `types.nullOr`

## Type Mappings

### Primitive Types

| Terraform CtyType | Nix Type Expression | Example |
|-------------------|---------------------|---------|
| `CtyBool` | `types.bool` | Boolean values |
| `CtyNumber` | `types.number` | Integers and floats |
| `CtyString` | `types.str` | Text strings |
| `CtyDynamic` | `types.anything` | Untyped/dynamic values |

### Collection Types

| Terraform CtyType | Nix Type Expression | Notes |
|-------------------|---------------------|-------|
| `CtyList T` | `types.listOf (mapType T)` | Ordered list |
| `CtySet T` | `types.listOf (mapType T)` | Unordered set (Nix doesn't distinguish) |
| `CtyMap T` | `types.attrsOf (mapType T)` | Key-value map |
| `CtyTuple [T1, T2, ...]` | `types.tupleOf [mapType T1, mapType T2, ...]` | Fixed-length tuple with typed positions |

### Structural Types

#### Objects

Terraform objects become NixOS submodules:

```haskell
CtyObject
  (Map.fromList [("host", CtyString), ("port", CtyNumber)])
  (Set.fromList ["port"])  -- optional fields
```

Generates:

```nix
types.submodule {
  options = {
    host = mkOption { type = types.str; };
    port = mkOption { type = types.nullOr types.number; };
  };
}
```

#### Tuples

Tuples are mapped to a custom `types.tupleOf` type that provides type-safe fixed-length tuples.

**Example:**

```haskell
CtyTuple [CtyString, CtyNumber, CtyBool]
```

Generates:

```nix
types.tupleOf [types.str types.number types.bool]
```

**Features:**

- **Fixed length validation**: Ensures the list has exactly the specified number of elements
- **Per-position type checking**: Each element is validated against its corresponding type
- **Type composition**: Can be nested and combined with other types like `listOf`, `nullOr`, etc.
- **Better error messages**: Position-aware errors like "Element \[0\]: expected string, got number"

**Usage in modules:**

```nix
# A module using tupleOf
{ config, lib, types, ... }:
{
  options.connection_info = lib.mkOption {
    type = types.tupleOf [types.str types.number types.bool];
    description = "Connection information: [host, port, use_ssl]";
  };
}

# Valid value
config.connection_info = ["example.com" 443 true];

# Invalid values
config.connection_info = ["example.com" 443];           # Error: wrong length
config.connection_info = ["example.com" "443" true];    # Error: wrong type at position 1
```

**Implementation:**

The `tupleOf` type is defined in `nix/lib/tuple.nix` and follows NixOS module system conventions:

- Uses `mkOptionType` for proper integration
- Implements `merge` for combining multiple definitions
- Provides `functor` for type composition
- Includes `nestedTypes` and `getSubOptions` for documentation generation

**Common patterns:**

```haskell
-- Empty tuple
CtyTuple []
-- Generates: types.tupleOf []

-- Single-element tuple
CtyTuple [CtyString]
-- Generates: types.tupleOf [types.str]

-- Nested collections in tuples
CtyTuple [CtyList CtyString, CtyMap CtyNumber]
-- Generates: types.tupleOf [(types.listOf types.str) (types.attrsOf types.number)]

-- List of tuples (coordinate pairs)
CtyList (CtyTuple [CtyNumber, CtyNumber])
-- Generates: types.listOf (types.tupleOf [types.number types.number])

-- Nested tuples
CtyTuple [CtyTuple [CtyString, CtyNumber], CtyBool]
-- Generates: types.tupleOf [(types.tupleOf [types.str types.number]) types.bool]
```

## Optional Field Handling

Optional fields are wrapped in `types.nullOr`:

- `mapCtyTypeToNixWithOptional False CtyString` → `types.str`
- `mapCtyTypeToNixWithOptional True CtyString` → `types.nullOr types.str`

This allows users to omit optional fields (they default to `null`).

## Implementation Details

### Using hnix

The Type Mapper generates `NExpr` values using the hnix library's AST constructors:

```haskell
nixTypes :: Text -> NExpr
nixTypes name = mkSym "types" `mkSelect` name

-- Example: types.str
nixTypes "str"

-- Example: types.listOf types.str
nixTypes "listOf" `mkApp` nixTypes "str"
```

### Object Generation

Objects require careful construction of nested `NSet` and `Binding` values to create the proper `types.submodule` structure. The implementation uses:

- `NSet` for attribute sets (`{ ... }`)
- `NamedVar` for bindings (`name = value;`)
- Recursive calls to handle nested objects

## Testing

The Type Mapper has comprehensive test coverage (25 tests) using:

- **Nix.TH quasiquoter**: Expected values defined with `[nix| ... |]` syntax
- **stripPositionInfo**: Custom `shouldMapTo` operator that normalizes AST before comparison
- **Real-world examples**: Tests based on AWS and other provider schemas from documentation

### Test Structure

```haskell
it "maps CtyList CtyString to types.listOf types.str" $ do
  mapCtyTypeToNix (CtyList CtyString)
    `shouldMapTo` [nix| types.listOf types.str |]
```

The `shouldMapTo` operator is defined as:

```haskell
shouldMapTo :: NExpr -> NExpr -> Expectation
shouldMapTo actual expected =
  stripPositionInfo actual `shouldBe` stripPositionInfo expected
```

## Usage Example

```haskell
import TerranixCodegen.TypeMapper
import TerranixCodegen.ProviderSchema.CtyType

-- Simple type
let stringType = mapCtyTypeToNix CtyString
-- Result: types.str

-- Collection type
let listType = mapCtyTypeToNix (CtyList CtyString)
-- Result: types.listOf types.str

-- Object type
let objType = CtyObject
      (Map.fromList [("name", CtyString), ("count", CtyNumber)])
      (Set.fromList ["count"])  -- count is optional
let nixType = mapCtyTypeToNix objType
-- Result: types.submodule { options = { ... }; }
```

## Demo Program

Run `cabal run type-mapper-demo` to see examples of all type mappings with pretty-printed Nix output.

## Future Enhancements

- ✅ ~~Add length validation for tuples~~ (Implemented via `types.tupleOf`)
- Support for additional custom type validators
- Better handling of complex nested structures
- Integration with schema metadata (deprecation, sensitivity, etc.)
- Consider upstreaming `tupleOf` type to nixpkgs
