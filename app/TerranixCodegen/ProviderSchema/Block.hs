{-# LANGUAGE StrictData #-}

module TerranixCodegen.ProviderSchema.Block (
  SchemaBlock (..),
  SchemaBlockType (..),
) where

import Data.Aeson (FromJSON (..), ToJSON (..), withObject, (.:?))
import Data.Aeson qualified as Aeson
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

instance ToJSON SchemaBlock where
  toJSON block =
    Aeson.object $
      filter
        ((/= Aeson.Null) . snd)
        [ "attributes" Aeson..= blockAttributes block
        , "block_types" Aeson..= blockNestedBlocks block
        , "description" Aeson..= blockDescription block
        , "description_kind" Aeson..= blockDescriptionKind block
        , "deprecated" Aeson..= blockDeprecated block
        ]

instance FromJSON SchemaBlock where
  parseJSON = withObject "SchemaBlock" $ \o ->
    SchemaBlock
      <$> o .:? "attributes"
      <*> o .:? "block_types"
      <*> o .:? "description"
      <*> o .:? "description_kind"
      <*> o .:? "deprecated"

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

instance ToJSON SchemaBlockType where
  toJSON blockType =
    Aeson.object $
      filter
        ((/= Aeson.Null) . snd)
        [ "nesting_mode" Aeson..= blockTypeNestingMode blockType
        , "block" Aeson..= blockTypeBlock blockType
        , "min_items" Aeson..= blockTypeMinItems blockType
        , "max_items" Aeson..= blockTypeMaxItems blockType
        ]

instance FromJSON SchemaBlockType where
  parseJSON = withObject "SchemaBlockType" $ \o ->
    SchemaBlockType
      <$> o .:? "nesting_mode"
      <*> o .:? "block"
      <*> o .:? "min_items"
      <*> o .:? "max_items"
