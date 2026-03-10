# Description Gaps Design

## Problem

Three gaps in how descriptions flow through the codegen pipeline:

1. **`SchemaDescriptionKind` is parsed but unused** — markdown descriptions are treated as plain text.
1. **Block descriptions get no metadata enrichment** — `blockDeprecated` is ignored in generated output.
1. **Top-level module descriptions are hardcoded** — `"Instances of <type>"` ignores the schema's actual block description.

Identity attribute descriptions (gap 4) are deferred to a separate effort.

## Approach: Unified `Description` Type

New module `lib/TerranixCodegen/Description.hs` encapsulating description text, kind, and rendering.

### The Type

```haskell
data Description = Description
  { descriptionText :: Text
  , descriptionKind :: SchemaDescriptionKind  -- Plain or Markdown
  }
```

### Constructors

- **`fromAttribute :: SchemaAttribute -> Maybe Description`** — extracts `attributeDescription` and enriches with metadata notes (DEPRECATED, WARNING, NOTE, computed). Preserves `attributeDescriptionKind`. Returns `Nothing` if all parts are empty. Replaces the current `buildDescription` in OptionBuilder.
- **`fromBlock :: SchemaBlock -> Maybe Description`** — extracts `blockDescription` and enriches with deprecated note when `blockDeprecated` is set. Preserves `blockDescriptionKind`.
- **`fromText :: Text -> SchemaDescriptionKind -> Description`** — simple constructor from raw text and kind.

### Rendering

```haskell
toNExpr :: Description -> NExpr
```

Rendering matrix:

| Kind | Lines | Output |
|----------|--------|-------------------------------|
| Plain | Single | `mkStr text` |
| Plain | Multi | `mkIndentedStr text` |
| Markdown | Single | `lib.mdDoc "text"` |
| Markdown | Multi | `lib.mdDoc ''text''` |

Returns an `NExpr` value, not a `Binding`. Callers construct the binding:

```haskell
NamedVar (mkSelector "description") (toNExpr desc) nullPos
```

Metadata notes (DEPRECATED, WARNING, etc.) are plain text appended to the description. The original `descriptionKind` is preserved since markdown renders plain text correctly.

## Integration

### OptionBuilder

- Remove internal `buildDescription :: SchemaAttribute -> Maybe Text`.
- Replace with `Description.fromAttribute` in `buildOption`.
- `buildOption` signature unchanged: `Text -> SchemaAttribute -> NExpr`.
- The multi-line/single-line string logic moves into `Description.toNExpr`.

### ModuleGenerator

**Block descriptions (nested blocks):**

```haskell
case Description.fromBlock block of
  Just desc -> Just $ NamedVar (mkSelector "description") (toNExpr desc) nullPos
  Nothing -> Nothing
```

`fromBlock` adds a deprecated note when `blockDeprecated = Just True`.

**Top-level resource/data source/provider descriptions:**

Pull from the schema's root block description with fallback to current hardcoded strings:

```haskell
descriptionBinding =
  NamedVar (mkSelector "description")
    (case schemaBlock schema >>= Description.fromBlock of
       Just desc -> toNExpr desc
       Nothing   -> mkStr $ "Instances of " <> resourceType)
    nullPos
```

Fallback strings:

- Resource: `"Instances of <type>"`
- Data source: `"Instances of <type> data source"`
- Provider: `"<name> provider configuration"`

No signature changes needed — `Schema` already contains `SchemaBlock` with descriptions.

## Testing

### New: `DescriptionSpec.hs`

- `fromAttribute` with plain/markdown descriptions
- `fromAttribute` metadata enrichment (deprecated, sensitive, writeOnly, computed)
- `fromBlock` with/without deprecated flag
- `fromBlock` with markdown kind
- `toNExpr` for all four rendering cases (plain/markdown x single/multi-line)

### Updated: `OptionBuilderSpec.hs`

- Existing tests pass unchanged (plain descriptions produce same output)
- New test: markdown-kind attribute generates `lib.mdDoc` wrapper

### Updated: `ModuleGeneratorSpec.hs`

- Block descriptions include deprecated note when `blockDeprecated = Just True`
- Top-level resource description uses schema block description
- Fallback to hardcoded description when schema block has no description

## Decisions

- **`lib.mdDoc` wrapping** only for `Markdown`-kind descriptions, not all descriptions.
- **Identity attributes** deferred to separate design effort.
- **Metadata notes** preserve original description kind (plain text appended to markdown is valid).
