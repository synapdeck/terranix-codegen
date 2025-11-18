{-# LANGUAGE DerivingVia #-}
{-# LANGUAGE OverloadedStrings #-}

module TerranixCodegen.ProviderSchema.Block (
  SchemaBlock (..),
  SchemaBlockType (..),
) where

import Autodocodec (Autodocodec (..), HasCodec (..), object, optionalField, (.=))
import Data.Aeson (FromJSON, ToJSON)
import Data.Map.Strict (Map)
import Data.Text qualified as T
import Data.Word (Word64)
import TerranixCodegen.ProviderSchema.Attribute
import TerranixCodegen.ProviderSchema.Types

-- | SchemaBlock represents a nested block within a particular schema.
data SchemaBlock = SchemaBlock
  { blockAttributes :: Maybe (Map T.Text SchemaAttribute)
  -- ^ The attributes defined at this level of the block
  , blockNestedBlocks :: Maybe (Map T.Text SchemaBlockType)
  -- ^ Any nested blocks within this block
  , blockDescription :: Maybe T.Text
  -- ^ Description for this block
  , blockDescriptionKind :: Maybe SchemaDescriptionKind
  -- ^ Format of the description (defaults to plain text)
  , blockDeprecated :: Maybe Bool
  -- ^ If true, this block is deprecated
  }
  deriving stock (Show, Eq)
  deriving (FromJSON, ToJSON) via (Autodocodec SchemaBlock)

instance HasCodec SchemaBlock where
  codec =
    object "SchemaBlock" $
      SchemaBlock
        <$> optionalField "attributes" "The attributes defined at this level of the block" .= blockAttributes
        <*> optionalField "block_types" "Any nested blocks within this block" .= blockNestedBlocks
        <*> optionalField "description" "Description for this block" .= blockDescription
        <*> optionalField "description_kind" "Format of the description (defaults to plain text)" .= blockDescriptionKind
        <*> optionalField "deprecated" "If true, this block is deprecated" .= blockDeprecated

-- | SchemaBlockType describes a nested block within a schema.
data SchemaBlockType = SchemaBlockType
  { blockTypeNestingMode :: Maybe SchemaNestingMode
  -- ^ The nesting mode for this block
  , blockTypeBlock :: Maybe SchemaBlock
  -- ^ The block data for this block type
  , blockTypeMinItems :: Maybe Word64
  -- ^ Lower limit on items that can be declared of this block type
  , blockTypeMaxItems :: Maybe Word64
  -- ^ Upper limit on items that can be declared of this block type
  }
  deriving stock (Show, Eq)
  deriving (FromJSON, ToJSON) via (Autodocodec SchemaBlockType)

instance HasCodec SchemaBlockType where
  codec =
    object "SchemaBlockType" $
      SchemaBlockType
        <$> optionalField "nesting_mode" "The nesting mode for this block" .= blockTypeNestingMode
        <*> optionalField "block" "The block data for this block type" .= blockTypeBlock
        <*> optionalField "min_items" "Lower limit on items that can be declared of this block type" .= blockTypeMinItems
        <*> optionalField "max_items" "Upper limit on items that can be declared of this block type" .= blockTypeMaxItems
