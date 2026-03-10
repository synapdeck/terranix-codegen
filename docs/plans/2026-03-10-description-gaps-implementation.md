# Description Gaps Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create a unified `Description` type that handles markdown wrapping, block metadata enrichment, and top-level schema descriptions.

**Architecture:** New `Description` module sits between `ProviderSchema.*` types and code generators (`OptionBuilder`, `ModuleGenerator`). It encapsulates description text + kind, enrichment with metadata notes, and rendering to `NExpr` (choosing `mkStr`/`mkIndentedStr`/`lib.mdDoc` wrapping). Replaces the internal `buildDescription` in OptionBuilder and the direct `mkStr` in ModuleGenerator.

**Tech Stack:** Haskell (GHC2024), hnix (`Nix.Expr.Shorthands`, `Nix.Expr.Types`), Hspec

**Design doc:** `docs/plans/2026-03-10-description-gaps-design.md`

______________________________________________________________________

### Task 1: Create Description Module with Type and Constructors

**Files:**

- Create: `lib/TerranixCodegen/Description.hs`
- Create: `test/TerranixCodegen/DescriptionSpec.hs`
- Modify: `terranix-codegen.cabal:23-39` (add exposed module)
- Modify: `terranix-codegen.cabal:99-106` (add test module)

**Step 1: Register new modules in cabal**

Add `TerranixCodegen.Description` to library `exposed-modules` and `TerranixCodegen.DescriptionSpec` to test `other-modules` in `terranix-codegen.cabal`. The `cabal-gild` formatter will sort them.

In library `exposed-modules` (around line 23), add:

```
TerranixCodegen.Description
```

In test `other-modules` (around line 99), add:

```
TerranixCodegen.DescriptionSpec
```

**Step 2: Write failing tests for fromAttribute, fromBlock, and toNExpr**

Create `test/TerranixCodegen/DescriptionSpec.hs`:

```haskell
module TerranixCodegen.DescriptionSpec (spec) where

import Data.Text qualified as T
import Nix.TH (nix)
import Test.Hspec

import TerranixCodegen.Description
import TerranixCodegen.ProviderSchema.Attribute
import TerranixCodegen.ProviderSchema.Block
import TerranixCodegen.ProviderSchema.Types (SchemaDescriptionKind (..))
import TestUtils (shouldMapTo)

emptyAttr :: SchemaAttribute
emptyAttr =
  SchemaAttribute
    { attributeType = Nothing
    , attributeNestedType = Nothing
    , attributeDescription = Nothing
    , attributeDescriptionKind = Nothing
    , attributeDeprecated = Nothing
    , attributeRequired = Nothing
    , attributeOptional = Nothing
    , attributeComputed = Nothing
    , attributeSensitive = Nothing
    , attributeWriteOnly = Nothing
    }

emptyBlock :: SchemaBlock
emptyBlock =
  SchemaBlock
    { blockAttributes = Nothing
    , blockNestedBlocks = Nothing
    , blockDescription = Nothing
    , blockDescriptionKind = Nothing
    , blockDeprecated = Nothing
    }

spec :: Spec
spec = do
  describe "fromAttribute" $ do
    it "extracts plain description" $ do
      let attr = emptyAttr {attributeDescription = Just "hello"}
      let Just desc = fromAttribute attr
      descriptionText desc `shouldBe` "hello"
      descriptionKind desc `shouldBe` Plain

    it "extracts markdown description" $ do
      let attr =
            emptyAttr
              { attributeDescription = Just "hello"
              , attributeDescriptionKind = Just Markdown
              }
      let Just desc = fromAttribute attr
      descriptionText desc `shouldBe` "hello"
      descriptionKind desc `shouldBe` Markdown

    it "defaults to Plain when kind not specified" $ do
      let attr = emptyAttr {attributeDescription = Just "hello"}
      let Just desc = fromAttribute attr
      descriptionKind desc `shouldBe` Plain

    it "returns Nothing when no description or metadata" $ do
      fromAttribute emptyAttr `shouldBe` Nothing

    it "enriches with deprecation note" $ do
      let attr =
            emptyAttr
              { attributeDescription = Just "Old field"
              , attributeDeprecated = Just True
              }
      let Just desc = fromAttribute attr
      descriptionText desc `shouldSatisfy` T.isInfixOf "DEPRECATED"

    it "enriches with sensitivity warning" $ do
      let attr =
            emptyAttr
              { attributeDescription = Just "Secret"
              , attributeSensitive = Just True
              }
      let Just desc = fromAttribute attr
      descriptionText desc `shouldSatisfy` T.isInfixOf "WARNING"

    it "enriches with write-only note" $ do
      let attr =
            emptyAttr
              { attributeDescription = Just "Token"
              , attributeWriteOnly = Just True
              }
      let Just desc = fromAttribute attr
      descriptionText desc `shouldSatisfy` T.isInfixOf "write-only"

    it "enriches with computed note for computed-only attributes" $ do
      let attr =
            emptyAttr
              { attributeDescription = Just "ID"
              , attributeComputed = Just True
              }
      let Just desc = fromAttribute attr
      descriptionText desc `shouldSatisfy` T.isInfixOf "computed by the provider"

    it "does not add computed note for optional+computed attributes" $ do
      let attr =
            emptyAttr
              { attributeDescription = Just "IP"
              , attributeOptional = Just True
              , attributeComputed = Just True
              }
      let Just desc = fromAttribute attr
      descriptionText desc `shouldBe` "IP"

    it "preserves markdown kind with metadata enrichment" $ do
      let attr =
            emptyAttr
              { attributeDescription = Just "Old field"
              , attributeDescriptionKind = Just Markdown
              , attributeDeprecated = Just True
              }
      let Just desc = fromAttribute attr
      descriptionKind desc `shouldBe` Markdown

    it "creates description from metadata alone" $ do
      let attr = emptyAttr {attributeDeprecated = Just True}
      let Just desc = fromAttribute attr
      descriptionText desc `shouldSatisfy` T.isInfixOf "DEPRECATED"

  describe "fromBlock" $ do
    it "extracts plain block description" $ do
      let block = emptyBlock {blockDescription = Just "A block"}
      let Just desc = fromBlock block
      descriptionText desc `shouldBe` "A block"
      descriptionKind desc `shouldBe` Plain

    it "extracts markdown block description" $ do
      let block =
            emptyBlock
              { blockDescription = Just "A block"
              , blockDescriptionKind = Just Markdown
              }
      let Just desc = fromBlock block
      descriptionKind desc `shouldBe` Markdown

    it "returns Nothing for empty block" $ do
      fromBlock emptyBlock `shouldBe` Nothing

    it "enriches with deprecation note" $ do
      let block =
            emptyBlock
              { blockDescription = Just "Old block"
              , blockDeprecated = Just True
              }
      let Just desc = fromBlock block
      descriptionText desc `shouldSatisfy` T.isInfixOf "DEPRECATED"

    it "creates description from deprecated flag alone" $ do
      let block = emptyBlock {blockDeprecated = Just True}
      let Just desc = fromBlock block
      descriptionText desc `shouldSatisfy` T.isInfixOf "DEPRECATED"

  describe "toNExpr" $ do
    it "renders plain single-line as regular string" $ do
      toNExpr (fromText "hello" Plain) `shouldMapTo` [nix| "hello" |]

    it "renders markdown single-line with lib.mdDoc" $ do
      toNExpr (fromText "hello" Markdown) `shouldMapTo` [nix| lib.mdDoc "hello" |]
```

**Step 3: Run tests to verify they fail**

Run: `cabal test --enable-tests --test-show-details=direct 2>&1 | tail -20`
Expected: Compilation failure (`Could not find module 'TerranixCodegen.Description'`)

**Step 4: Implement Description module**

Create `lib/TerranixCodegen/Description.hs`:

```haskell
module TerranixCodegen.Description (
  Description (..),
  fromAttribute,
  fromBlock,
  fromText,
  toNExpr,
) where

import Data.Fix (Fix (..))
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import Data.Text qualified as T
import Nix.Expr.Shorthands
import Nix.Expr.Types

import TerranixCodegen.ProviderSchema.Attribute
import TerranixCodegen.ProviderSchema.Block
import TerranixCodegen.ProviderSchema.Types (SchemaDescriptionKind (..))

-- | A description with text and format kind (plain or markdown).
data Description = Description
  { descriptionText :: Text
  , descriptionKind :: SchemaDescriptionKind
  }
  deriving stock (Show, Eq)

-- | Create a Description from raw text and kind.
fromText :: Text -> SchemaDescriptionKind -> Description
fromText = Description

{- | Build a Description from schema attribute metadata.

Enriches with metadata notes:
  - Deprecation warnings
  - Sensitivity warnings
  - Write-only notes
  - Computed attribute notes

Returns Nothing if all parts are empty.
-}
fromAttribute :: SchemaAttribute -> Maybe Description
fromAttribute attr
  | T.null combinedDesc = Nothing
  | otherwise = Just $ Description finalDesc kind
  where
    kind = fromMaybe Plain (attributeDescriptionKind attr)

    nonEmptyParts = filter (not . T.null) parts
    combinedDesc = T.intercalate "\n\n" nonEmptyParts

    -- Add trailing newline only for multi-line descriptions
    finalDesc
      | length nonEmptyParts > 1 = combinedDesc <> "\n"
      | otherwise = combinedDesc

    parts =
      [ fromMaybe "" (attributeDescription attr)
      , if fromMaybe False (attributeDeprecated attr)
          then "DEPRECATED: This attribute is deprecated and may be removed in a future version."
          else ""
      , if fromMaybe False (attributeSensitive attr)
          then "WARNING: This attribute contains sensitive information and will not be displayed in logs."
          else ""
      , if fromMaybe False (attributeWriteOnly attr)
          then "NOTE: This attribute is write-only and will not be persisted in the Terraform state."
          else ""
      , if fromMaybe False (attributeComputed attr)
          && not (fromMaybe False (attributeRequired attr))
          && not (fromMaybe False (attributeOptional attr))
          then "This value is computed by the provider."
          else ""
      ]

{- | Build a Description from a schema block.

Enriches with deprecation note when blockDeprecated is set.
Returns Nothing if no description or metadata.
-}
fromBlock :: SchemaBlock -> Maybe Description
fromBlock block
  | T.null combinedDesc = Nothing
  | otherwise = Just $ Description finalDesc kind
  where
    kind = fromMaybe Plain (blockDescriptionKind block)

    nonEmptyParts = filter (not . T.null) parts
    combinedDesc = T.intercalate "\n\n" nonEmptyParts

    finalDesc
      | length nonEmptyParts > 1 = combinedDesc <> "\n"
      | otherwise = combinedDesc

    parts =
      [ fromMaybe "" (blockDescription block)
      , if fromMaybe False (blockDeprecated block)
          then "DEPRECATED: This block is deprecated and may be removed in a future version."
          else ""
      ]

{- | Render a Description to a NExpr value.

Rendering matrix:
  - Plain  + single-line → mkStr text
  - Plain  + multi-line  → mkIndentedStr text
  - Markdown + single-line → lib.mdDoc "text"
  - Markdown + multi-line  → lib.mdDoc ''text''
-}
toNExpr :: Description -> NExpr
toNExpr (Description text kind) =
  case kind of
    Plain
      | isMultiLine -> mkIndentedStr 16 text
      | otherwise -> mkStr text
    Markdown
      | isMultiLine -> mdDoc (mkIndentedStr 16 text)
      | otherwise -> mdDoc (mkStr text)
  where
    isMultiLine = T.any (== '\n') text
    mdDoc = mkApp (Fix $ NSelect Nothing (mkSym "lib") (mkSelector "mdDoc"))
```

**Step 5: Run tests to verify they pass**

Run: `cabal test --enable-tests --test-show-details=direct 2>&1 | tail -40`
Expected: All tests pass, including new DescriptionSpec tests

**Step 6: Commit**

```bash
git add lib/TerranixCodegen/Description.hs test/TerranixCodegen/DescriptionSpec.hs terranix-codegen.cabal
git commit -m "feat: add Description type with metadata enrichment and mdDoc rendering"
```

______________________________________________________________________

### Task 2: Integrate Description into OptionBuilder

**Files:**

- Modify: `lib/TerranixCodegen/OptionBuilder.hs:1-17` (imports)
- Modify: `lib/TerranixCodegen/OptionBuilder.hs:62-72` (descriptionBinding)
- Modify: `lib/TerranixCodegen/OptionBuilder.hs:143-197` (remove buildDescription)
- Modify: `test/TerranixCodegen/OptionBuilderSpec.hs` (add markdown test)

**Step 1: Add markdown-kind test to OptionBuilderSpec**

Add to `OptionBuilderSpec.hs` in the `describe "buildOption"` block, after the "edge cases" describe block:

```haskell
    describe "markdown descriptions" $ do
      it "wraps markdown description with lib.mdDoc" $ do
        let attr =
              emptyAttr
                { attributeType = Just CtyString
                , attributeDescription = Just "The AMI ID"
                , attributeDescriptionKind = Just Markdown
                , attributeRequired = Just True
                }
        buildOption "ami" attr
          `shouldMapTo` [nix|
            mkOption {
              type = types.str;
              description = lib.mdDoc "The AMI ID";
            }
          |]

      it "wraps multi-line markdown description with lib.mdDoc" $ do
        let attr =
              emptyAttr
                { attributeType = Just CtyString
                , attributeDescription = Just "The AMI ID"
                , attributeDescriptionKind = Just Markdown
                , attributeComputed = Just True
                }
        buildOption "ami" attr
          `shouldMapTo` [nix|
            mkOption {
              type = types.nullOr types.str;
              default = null;
              description = lib.mdDoc ''
                The AMI ID

                This value is computed by the provider.
              '';
              readOnly = true;
            }
          |]
```

Also add import for `SchemaDescriptionKind`:

```haskell
import TerranixCodegen.ProviderSchema.Types (SchemaDescriptionKind (..), SchemaNestingMode (..))
```

**Step 2: Run tests to verify the new test fails**

Run: `cabal test --enable-tests --test-show-details=direct 2>&1 | tail -20`
Expected: New markdown test fails (current code produces `mkStr` not `lib.mdDoc`)

**Step 3: Update OptionBuilder to use Description module**

In `lib/TerranixCodegen/OptionBuilder.hs`:

Replace imports — remove `Data.Text qualified as T`, add Description import:

```haskell
import Data.Fix (Fix (..))
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import Nix.Expr.Shorthands
import Nix.Expr.Types

import TerranixCodegen.Description qualified as Description
import TerranixCodegen.ProviderSchema.Attribute
import TerranixCodegen.ProviderSchema.Types (SchemaNestingMode (..))
import TerranixCodegen.TypeMapper (mapCtyTypeToNixWithOptional)
```

Replace `descriptionBinding` (lines 62-72):

```haskell
    -- Description binding (if description exists)
    descriptionBinding =
      case Description.fromAttribute attr of
        Just desc ->
          Just $
            NamedVar
              (mkSelector "description")
              (Description.toNExpr desc)
              nullPos
        Nothing -> Nothing
```

Delete `buildDescription` function (lines 143-197).

**Step 4: Run all tests to verify they pass**

Run: `cabal test --enable-tests --test-show-details=direct 2>&1 | tail -40`
Expected: ALL tests pass (existing + new markdown tests)

**Step 5: Commit**

```bash
git add lib/TerranixCodegen/OptionBuilder.hs test/TerranixCodegen/OptionBuilderSpec.hs
git commit -m "refactor: use Description module in OptionBuilder"
```

______________________________________________________________________

### Task 3: Integrate Description into ModuleGenerator — Block Descriptions

**Files:**

- Modify: `lib/TerranixCodegen/ModuleGenerator.hs:1-22` (imports)
- Modify: `lib/TerranixCodegen/ModuleGenerator.hs:276-279` (descriptionBinding in blockTypeToBinding)
- Modify: `lib/TerranixCodegen/ModuleGenerator.hs:378-387` (remove emptyBlock)
- Modify: `test/TerranixCodegen/ModuleGeneratorSpec.hs` (add block description tests)

**Step 1: Add block description tests to ModuleGeneratorSpec**

Add to `ModuleGeneratorSpec.hs` after the existing `describe "blockToSubmodule"` block, inside `spec`:

```haskell
  describe "block descriptions" $ do
    it "adds deprecation note to nested block description" $ do
      let nestedBlock =
            emptyBlock
              { blockAttributes =
                  Just $
                    Map.fromList
                      [("enabled", emptyAttr {attributeType = Just CtyBool, attributeRequired = Just True})]
              , blockDescription = Just "Old monitoring config"
              , blockDeprecated = Just True
              }
          blockType =
            SchemaBlockType
              { blockTypeNestingMode = Just NestingSingle
              , blockTypeBlock = Just nestedBlock
              , blockTypeMinItems = Nothing
              , blockTypeMaxItems = Nothing
              }
          block =
            emptyBlock
              { blockNestedBlocks =
                  Just $
                    Map.fromList [("monitoring", blockType)]
              }
      blockToSubmodule block
        `shouldMapTo` [nix|
          types.submodule {
            options = {
              monitoring = mkOption {
                type = types.submodule {
                  options = {
                    enabled = mkOption {
                      type = types.bool;
                    };
                  };
                };
                default = null;
                description = ''
                  Old monitoring config

                  DEPRECATED: This block is deprecated and may be removed in a future version.
                '';
              };
            };
          }
        |]

    it "wraps markdown block description with lib.mdDoc" $ do
      let nestedBlock =
            emptyBlock
              { blockAttributes =
                  Just $
                    Map.fromList
                      [("enabled", emptyAttr {attributeType = Just CtyBool, attributeRequired = Just True})]
              , blockDescription = Just "Enable monitoring"
              , blockDescriptionKind = Just Markdown
              }
          blockType =
            SchemaBlockType
              { blockTypeNestingMode = Just NestingSingle
              , blockTypeBlock = Just nestedBlock
              , blockTypeMinItems = Nothing
              , blockTypeMaxItems = Nothing
              }
          block =
            emptyBlock
              { blockNestedBlocks =
                  Just $
                    Map.fromList [("monitoring", blockType)]
              }
      blockToSubmodule block
        `shouldMapTo` [nix|
          types.submodule {
            options = {
              monitoring = mkOption {
                type = types.submodule {
                  options = {
                    enabled = mkOption {
                      type = types.bool;
                    };
                  };
                };
                default = null;
                description = lib.mdDoc "Enable monitoring";
              };
            };
          }
        |]
```

Also add import for `SchemaDescriptionKind`:

```haskell
import TerranixCodegen.ProviderSchema.Types (SchemaDescriptionKind (..), SchemaNestingMode (..))
```

**Step 2: Run tests to verify the new tests fail**

Run: `cabal test --enable-tests --test-show-details=direct 2>&1 | tail -20`
Expected: New tests fail (current code doesn't enrich block descriptions or handle markdown)

**Step 3: Update ModuleGenerator block description handling**

In `lib/TerranixCodegen/ModuleGenerator.hs`:

Add import:

```haskell
import TerranixCodegen.Description qualified as Description
```

Replace `descriptionBinding` in `blockTypeToBinding` (lines 276-279):

```haskell
    descriptionBinding =
      case blockTypeBlock blockType >>= Description.fromBlock of
        Just desc -> Just $ NamedVar (mkSelector "description") (Description.toNExpr desc) nullPos
        Nothing -> Nothing
```

Remove the unused `emptyBlock` helper (lines 378-387).

**Step 4: Run all tests to verify they pass**

Run: `cabal test --enable-tests --test-show-details=direct 2>&1 | tail -40`
Expected: ALL tests pass

**Step 5: Commit**

```bash
git add lib/TerranixCodegen/ModuleGenerator.hs test/TerranixCodegen/ModuleGeneratorSpec.hs
git commit -m "feat: enrich block descriptions with metadata and mdDoc support"
```

______________________________________________________________________

### Task 4: Integrate Description into ModuleGenerator — Top-Level Descriptions

**Files:**

- Modify: `lib/TerranixCodegen/ModuleGenerator.hs:82-86` (resource descriptionBinding)
- Modify: `lib/TerranixCodegen/ModuleGenerator.hs:135-139` (data source descriptionBinding)
- Modify: `lib/TerranixCodegen/ModuleGenerator.hs:197-201` (provider descriptionBinding)
- Modify: `test/TerranixCodegen/ModuleGeneratorSpec.hs` (add top-level description tests)

**Step 1: Add top-level description tests to ModuleGeneratorSpec**

Add to `ModuleGeneratorSpec.hs` inside the existing `describe "generateResourceModule"` block:

```haskell
    it "uses schema block description for resource module" $ do
      let schema =
            emptySchema
              { schemaBlock =
                  Just $
                    emptyBlock
                      { blockAttributes =
                          Just $
                            Map.fromList
                              [("name", emptyAttr {attributeType = Just CtyString, attributeRequired = Just True})]
                      , blockDescription = Just "Manages a compute instance"
                      }
              }
      generateResourceModule "aws" "aws_instance" schema
        `shouldMapTo` [nix|
          { lib, ... }:
          with lib;
          {
            options.resource.aws_instance = mkOption {
              type = types.attrsOf (types.submodule {
                options = {
                  name = mkOption {
                    type = types.str;
                  };
                };
              });
              default = {};
              description = "Manages a compute instance";
            };
          }
        |]
```

Add inside `describe "generateDataSourceModule"`:

```haskell
    it "uses schema block description for data source module" $ do
      let schema =
            emptySchema
              { schemaBlock =
                  Just $
                    emptyBlock
                      { blockAttributes =
                          Just $
                            Map.fromList
                              [("name", emptyAttr {attributeType = Just CtyString, attributeRequired = Just True})]
                      , blockDescription = Just "Fetches AMI information"
                      }
              }
      generateDataSourceModule "aws" "aws_ami" schema
        `shouldMapTo` [nix|
          { lib, ... }:
          with lib;
          {
            options.data.aws_ami = mkOption {
              type = types.attrsOf (types.submodule {
                options = {
                  name = mkOption {
                    type = types.str;
                  };
                };
              });
              default = {};
              description = "Fetches AMI information";
            };
          }
        |]
```

Add inside `describe "generateProviderModule"`:

```haskell
    it "uses schema block description for provider module" $ do
      let schema =
            emptySchema
              { schemaBlock =
                  Just $
                    emptyBlock
                      { blockAttributes =
                          Just $
                            Map.fromList
                              [("region", emptyAttr {attributeType = Just CtyString, attributeRequired = Just True})]
                      , blockDescription = Just "The AWS provider configuration"
                      }
              }
      generateProviderModule "aws" schema
        `shouldMapTo` [nix|
          { lib, ... }:
          with lib;
          {
            options.provider.aws = mkOption {
              type = types.attrsOf (types.submodule {
                options = {
                  region = mkOption {
                    type = types.str;
                  };
                };
              });
              default = {};
              description = "The AWS provider configuration";
            };
          }
        |]
```

**Step 2: Run tests to verify the new tests fail**

Run: `cabal test --enable-tests --test-show-details=direct 2>&1 | tail -20`
Expected: New tests fail (current code uses hardcoded descriptions)

**Step 3: Update top-level description handling**

In `lib/TerranixCodegen/ModuleGenerator.hs`, replace the three `descriptionBinding` definitions:

In `generateResourceModule` (lines 82-86):

```haskell
    descriptionBinding =
      NamedVar
        (mkSelector "description")
        ( case schemaBlock schema >>= Description.fromBlock of
            Just desc -> Description.toNExpr desc
            Nothing -> mkStr $ "Instances of " <> resourceType
        )
        nullPos
```

In `generateDataSourceModule` (lines 135-139):

```haskell
    descriptionBinding =
      NamedVar
        (mkSelector "description")
        ( case schemaBlock schema >>= Description.fromBlock of
            Just desc -> Description.toNExpr desc
            Nothing -> mkStr $ "Instances of " <> dataSourceType <> " data source"
        )
        nullPos
```

In `generateProviderModule` (lines 197-201):

```haskell
    descriptionBinding =
      NamedVar
        (mkSelector "description")
        ( case schemaBlock schema >>= Description.fromBlock of
            Just desc -> Description.toNExpr desc
            Nothing -> mkStr $ providerName <> " provider configuration"
        )
        nullPos
```

**Step 4: Run all tests to verify they pass**

Run: `cabal test --enable-tests --test-show-details=direct 2>&1 | tail -40`
Expected: ALL tests pass (existing tests still use schemas with no block description, so fallbacks are used)

**Step 5: Run nix flake check for full validation**

Run: `nix flake check`
Expected: All checks pass (build, format, lint)

**Step 6: Commit**

```bash
git add lib/TerranixCodegen/ModuleGenerator.hs test/TerranixCodegen/ModuleGeneratorSpec.hs
git commit -m "feat: use schema descriptions for top-level module descriptions"
```

______________________________________________________________________

### Notes

- **Existing tests are unaffected:** All current test schemas use `emptyBlock` with `blockDescription = Nothing`, so fallback descriptions are used and output is unchanged.
- **`blockTypeToOption` (exported, ModuleGenerator:298-329):** Not updated in this effort — it's a separate exported function that may have different consumers. Can be updated in a follow-up.
- **Indentation value 16:** Matches the existing `mkIndentedStr 16` convention in OptionBuilder. This controls Nix indented string formatting depth.
- **`lib.mdDoc` availability:** Generated modules use `{ lib, ... }: with lib;` wrapper, so both `lib.mdDoc` and bare `mdDoc` resolve. Using `lib.mdDoc` explicitly for clarity.
