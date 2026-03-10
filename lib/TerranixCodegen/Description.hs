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
import Nix.Expr.Types (NExpr, NExprF (..))

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
  - Plain  + single-line -> mkStr text
  - Plain  + multi-line  -> mkIndentedStr text
  - Markdown + single-line -> lib.mdDoc "text"
  - Markdown + multi-line  -> lib.mdDoc ''text''
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
