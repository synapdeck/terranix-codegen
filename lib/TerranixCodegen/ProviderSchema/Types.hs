{-# LANGUAGE StrictData #-}

module TerranixCodegen.ProviderSchema.Types (
  SchemaDescriptionKind (..),
  SchemaNestingMode (..),
) where

import Data.Aeson (FromJSON (..), ToJSON (..), withText)
import Data.Text (Text)

-- | SchemaDescriptionKind describes the format type for a particular description field.
data SchemaDescriptionKind
  = Plain
  | Markdown
  deriving stock (Show, Eq, Ord)

instance ToJSON SchemaDescriptionKind where
  toJSON Plain = toJSON ("plain" :: Text)
  toJSON Markdown = toJSON ("markdown" :: Text)

instance FromJSON SchemaDescriptionKind where
  parseJSON = withText "SchemaDescriptionKind" $ \case
    "plain" -> pure Plain
    "markdown" -> pure Markdown
    other -> fail $ "Unknown description kind: " <> show other

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

instance ToJSON SchemaNestingMode where
  toJSON NestingSingle = toJSON ("single" :: Text)
  toJSON NestingGroup = toJSON ("group" :: Text)
  toJSON NestingList = toJSON ("list" :: Text)
  toJSON NestingSet = toJSON ("set" :: Text)
  toJSON NestingMap = toJSON ("map" :: Text)

instance FromJSON SchemaNestingMode where
  parseJSON = withText "SchemaNestingMode" $ \case
    "single" -> pure NestingSingle
    "group" -> pure NestingGroup
    "list" -> pure NestingList
    "set" -> pure NestingSet
    "map" -> pure NestingMap
    other -> fail $ "Unknown nesting mode: " <> show other
