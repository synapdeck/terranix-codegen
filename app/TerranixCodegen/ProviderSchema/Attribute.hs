{-# LANGUAGE DerivingVia #-}
{-# LANGUAGE OverloadedStrings #-}

module TerranixCodegen.ProviderSchema.Attribute
    ( SchemaAttribute (..)
    , SchemaNestedAttributeType (..)
    ) where

import Autodocodec (Autodocodec (..), HasCodec (..), object, optionalField, (.=))
import Data.Aeson (FromJSON, ToJSON)
import Data.Map.Strict (Map)
import qualified Data.Text as T
import Data.Word (Word64)
import TerranixCodegen.ProviderSchema.CtyType
import TerranixCodegen.ProviderSchema.Types

-- | SchemaAttribute describes an attribute within a schema block.
-- Either attributeType or attributeNestedType is set, never both.
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
    deriving (FromJSON, ToJSON) via (Autodocodec SchemaAttribute)

instance HasCodec SchemaAttribute where
    codec =
        object "SchemaAttribute" $
            SchemaAttribute
                <$> optionalField "type" "The attribute type (cty.Type)" .= attributeType
                <*> optionalField "nested_type" "Details about a nested attribute type" .= attributeNestedType
                <*> optionalField "description" "Description for this attribute" .= attributeDescription
                <*> optionalField "description_kind" "Format of the description (defaults to plain text)" .= attributeDescriptionKind
                <*> optionalField "deprecated" "If true, this attribute is deprecated" .= attributeDeprecated
                <*> optionalField "required" "If true, this attribute must be entered in configuration" .= attributeRequired
                <*> optionalField "optional" "If true, this attribute is optional" .= attributeOptional
                <*> optionalField "computed" "If true, this attribute can be set by the provider" .= attributeComputed
                <*> optionalField "sensitive" "If true, this attribute is sensitive and will not be displayed in logs" .= attributeSensitive
                <*> optionalField "write_only" "If true, this attribute is write only and not persisted in state" .= attributeWriteOnly

-- | SchemaNestedAttributeType describes a nested attribute which tracks
-- additional metadata beyond what a simple cty.Object could express.
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
    deriving (FromJSON, ToJSON) via (Autodocodec SchemaNestedAttributeType)

instance HasCodec SchemaNestedAttributeType where
    codec =
        object "SchemaNestedAttributeType" $
            SchemaNestedAttributeType
                <$> optionalField "attributes" "Map of nested attributes" .= nestedAttributes
                <*> optionalField "nesting_mode" "The nesting mode for this attribute" .= nestedNestingMode
                <*> optionalField "min_items" "Lower limit on number of items (not applicable to single nesting mode)" .= nestedMinItems
                <*> optionalField "max_items" "Upper limit on number of items (not applicable to single nesting mode)" .= nestedMaxItems
