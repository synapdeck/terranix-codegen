{-# LANGUAGE StrictData #-}

module TerranixCodegen.ProviderSchema.Attribute (
  SchemaAttribute (..),
  SchemaNestedAttributeType (..),
) where

import Data.Aeson (FromJSON (..), ToJSON (..), withObject, (.:?))
import Data.Aeson qualified as Aeson
import Data.Map.Strict (Map)
import Data.Text qualified as T
import Data.Word (Word64)
import TerranixCodegen.ProviderSchema.CtyType
import TerranixCodegen.ProviderSchema.Types

{- | SchemaAttribute describes an attribute within a schema block.
Either attributeType or attributeNestedType is set, never both.
-}
data SchemaAttribute = SchemaAttribute
  { attributeType :: Maybe CtyType
  -- ^ The attribute type (cty.Type)
  , attributeNestedType :: Maybe SchemaNestedAttributeType
  -- ^ Details about a nested attribute type
  , attributeDescription :: Maybe T.Text
  -- ^ Description for this attribute
  , attributeDescriptionKind :: Maybe SchemaDescriptionKind
  -- ^ Format of the description (defaults to plain text)
  , attributeDeprecated :: Maybe Bool
  -- ^ If true, this attribute is deprecated
  , attributeRequired :: Maybe Bool
  -- ^ If true, this attribute must be entered in configuration
  , attributeOptional :: Maybe Bool
  -- ^ If true, this attribute is optional
  , attributeComputed :: Maybe Bool
  -- ^ If true, this attribute can be set by the provider
  , attributeSensitive :: Maybe Bool
  -- ^ If true, this attribute is sensitive and will not be displayed in logs
  , attributeWriteOnly :: Maybe Bool
  -- ^ If true, this attribute is write only and not persisted in state
  }
  deriving stock (Show, Eq)

instance ToJSON SchemaAttribute where
  toJSON attr =
    Aeson.object $
      filter
        ((/= Aeson.Null) . snd)
        [ "type" Aeson..= attributeType attr
        , "nested_type" Aeson..= attributeNestedType attr
        , "description" Aeson..= attributeDescription attr
        , "description_kind" Aeson..= attributeDescriptionKind attr
        , "deprecated" Aeson..= attributeDeprecated attr
        , "required" Aeson..= attributeRequired attr
        , "optional" Aeson..= attributeOptional attr
        , "computed" Aeson..= attributeComputed attr
        , "sensitive" Aeson..= attributeSensitive attr
        , "write_only" Aeson..= attributeWriteOnly attr
        ]

instance FromJSON SchemaAttribute where
  parseJSON = withObject "SchemaAttribute" $ \o ->
    SchemaAttribute
      <$> o .:? "type"
      <*> o .:? "nested_type"
      <*> o .:? "description"
      <*> o .:? "description_kind"
      <*> o .:? "deprecated"
      <*> o .:? "required"
      <*> o .:? "optional"
      <*> o .:? "computed"
      <*> o .:? "sensitive"
      <*> o .:? "write_only"

{- | SchemaNestedAttributeType describes a nested attribute which tracks
additional metadata beyond what a simple cty.Object could express.
-}
data SchemaNestedAttributeType = SchemaNestedAttributeType
  { nestedAttributes :: Maybe (Map T.Text SchemaAttribute)
  -- ^ Map of nested attributes
  , nestedNestingMode :: Maybe SchemaNestingMode
  -- ^ The nesting mode for this attribute
  , nestedMinItems :: Maybe Word64
  -- ^ Lower limit on number of items (not applicable to single nesting mode)
  , nestedMaxItems :: Maybe Word64
  -- ^ Upper limit on number of items (not applicable to single nesting mode)
  }
  deriving stock (Show, Eq)

instance ToJSON SchemaNestedAttributeType where
  toJSON nested =
    Aeson.object $
      filter
        ((/= Aeson.Null) . snd)
        [ "attributes" Aeson..= nestedAttributes nested
        , "nesting_mode" Aeson..= nestedNestingMode nested
        , "min_items" Aeson..= nestedMinItems nested
        , "max_items" Aeson..= nestedMaxItems nested
        ]

instance FromJSON SchemaNestedAttributeType where
  parseJSON = withObject "SchemaNestedAttributeType" $ \o ->
    SchemaNestedAttributeType
      <$> o .:? "attributes"
      <*> o .:? "nesting_mode"
      <*> o .:? "min_items"
      <*> o .:? "max_items"
