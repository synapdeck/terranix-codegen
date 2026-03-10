# Type Mapping

The type mapper converts Terraform's [go-cty](https://github.com/zclconf/go-cty) types to NixOS module types. This is the core of the code generation pipeline -- everything else is wiring.

Implementation: `lib/TerranixCodegen/TypeMapper.hs`

## Mapping table

### Primitives

| Terraform | Nix |
|-----------|-----|
| `string` | `types.str` |
| `number` | `types.number` |
| `bool` | `types.bool` |
| `dynamic` | `types.anything` |

### Collections

| Terraform | Nix | Notes |
|-----------|-----|-------|
| `list(T)` | `types.listOf (mapType T)` | |
| `set(T)` | `types.listOf (mapType T)` | Nix has no set type; mapped to list |
| `map(T)` | `types.attrsOf (mapType T)` | |

### Structural types

| Terraform | Nix |
|-----------|-----|
| `object({...})` | `types.submodule { options = {...}; }` |
| `tuple([...])` | `types.tupleOf [...]` |

All mappings are recursive -- a `list(object({name = string}))` produces `types.listOf (types.submodule { options = { name = mkOption { type = types.str; }; }; })`.

## Objects

Terraform objects have typed fields, some of which may be optional:

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

Optional object fields are wrapped in `types.nullOr`.

## Tuples

Terraform tuples are fixed-length lists with per-position types. Nix has no built-in tuple type, so we provide a custom [`types.tupleOf`](../../nix/lib/tuple.nix) that validates both length and per-element types.

```haskell
CtyTuple [CtyString, CtyNumber, CtyBool]
```

Generates:

```nix
types.tupleOf [types.str types.number types.bool]
```

`tupleOf` is implemented as a proper `mkOptionType` with merge support, functor composition, and position-aware error messages.

## Optional wrapping

The type mapper has two entry points:

- `mapCtyTypeToNix` -- returns the bare type
- `mapCtyTypeToNixWithOptional` -- wraps in `types.nullOr` when the attribute is optional or computed

This wrapping is applied at the attribute level by the option builder, not within nested type structures.

## Attribute semantics

How Terraform's `required`/`optional`/`computed` flags affect the generated option:

| Flags | Type wrapping | Default | readOnly |
|-------|--------------|---------|----------|
| required | bare type | none (user must provide) | no |
| optional | `types.nullOr T` | `null` | no |
| computed only | `types.nullOr T` | `null` | yes |
| optional + computed | `types.nullOr T` | `null` | no |

## Block nesting modes

Nested blocks in Terraform schemas have a nesting mode that determines how they appear in configuration:

| Mode | Nix type | Default |
|------|----------|---------|
| `single` | `types.submodule { ... }` | `null` |
| `group` | `types.submodule { ... }` | none |
| `list` | `types.listOf (types.submodule { ... })` | `[]` |
| `set` | `types.listOf (types.submodule { ... })` | `[]` |
| `map` | `types.attrsOf (types.submodule { ... })` | `{}` |

`set` maps to `listOf` for the same reason as collection sets -- Nix doesn't distinguish ordered from unordered at the type level.
