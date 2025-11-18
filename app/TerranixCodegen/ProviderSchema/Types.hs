{-# LANGUAGE DerivingVia #-}
{-# LANGUAGE OverloadedStrings #-}

module TerranixCodegen.ProviderSchema.Types (
  SchemaDescriptionKind (..),
  SchemaNestingMode (..),
) where

import Autodocodec (Autodocodec (..), HasCodec (..), bimapCodec, (<?>))
import Data.Aeson (FromJSON, ToJSON)
import Data.Text (Text)

-- | SchemaDescriptionKind describes the format type for a particular description field.
data SchemaDescriptionKind
  = Plain
  | Markdown
  deriving stock (Show, Eq, Ord)
  deriving (FromJSON, ToJSON) via (Autodocodec SchemaDescriptionKind)

instance HasCodec SchemaDescriptionKind where
  codec =
    bimapCodec fromText toText codec
      <?> "Description format kind (plain or markdown)"
    where
      fromText :: Text -> Either String SchemaDescriptionKind
      fromText "plain" = Right Plain
      fromText "markdown" = Right Markdown
      fromText other = Left $ "Expected 'plain' or 'markdown', got: " ++ show other

      toText :: SchemaDescriptionKind -> Text
      toText Plain = "plain"
      toText Markdown = "markdown"

-- | SchemaNestingMode is the nesting mode for a particular nested schema block.
data SchemaNestingMode
  = -- | Single block nesting mode - allows a single block of this type only
    NestingSingle
  | -- | Similar to Single but guarantees result will never be null
    NestingGroup
  | -- | Ordered list of blocks where duplicates are allowed
    NestingList
  | -- | Unordered list of blocks where duplicates are generally not allowed
    NestingSet
  | -- | Map of blocks keyed by label
    NestingMap
  deriving stock (Show, Eq, Ord)
  deriving (FromJSON, ToJSON) via (Autodocodec SchemaNestingMode)

instance HasCodec SchemaNestingMode where
  codec =
    bimapCodec fromText toText codec
      <?> "Nesting mode (single, group, list, set, or map)"
    where
      fromText :: Text -> Either String SchemaNestingMode
      fromText "single" = Right NestingSingle
      fromText "group" = Right NestingGroup
      fromText "list" = Right NestingList
      fromText "set" = Right NestingSet
      fromText "map" = Right NestingMap
      fromText other = Left $ "Expected 'single', 'group', 'list', 'set', or 'map', got: " ++ show other

      toText :: SchemaNestingMode -> Text
      toText NestingSingle = "single"
      toText NestingGroup = "group"
      toText NestingList = "list"
      toText NestingSet = "set"
      toText NestingMap = "map"
