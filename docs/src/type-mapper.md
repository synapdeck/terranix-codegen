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

Tuples are currently mapped to `types.listOf types.anything` as Nix doesn't have fixed-length tuple types in the module system.

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

The Type Mapper has comprehensive test coverage (18 tests) using:

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

- Add length validation for tuples
- Support for custom type validators
- Better handling of complex nested structures
- Integration with schema metadata (deprecation, sensitivity, etc.)
