{-# LANGUAGE StrictData #-}

module TerranixCodegen.ProviderSchema.Schema (
  Schema (..),
  ActionSchema (..),
) where

import Data.Aeson (FromJSON (..), ToJSON (..), withObject, (.:), (.:?))
import Data.Aeson qualified as Aeson
import Data.Word (Word64)
import TerranixCodegen.ProviderSchema.Block

{- | Schema is the JSON representation of a particular schema
(provider configuration, resources, data sources).
-}
data Schema = Schema
  { schemaVersion :: Word64
  -- ^ The version of the particular resource schema
  , schemaBlock :: Maybe SchemaBlock
  -- ^ The root-level block of configuration values
  }
  deriving stock (Show, Eq)

instance ToJSON Schema where
  toJSON schema =
    Aeson.object $
      filter
        ((/= Aeson.Null) . snd)
        [ "version" Aeson..= schemaVersion schema
        , "block" Aeson..= schemaBlock schema
        ]

instance FromJSON Schema where
  parseJSON = withObject "Schema" $ \o ->
    Schema
      <$> o .: "version"
      <*> o .:? "block"

-- | ActionSchema is the JSON representation of an action schema.
newtype ActionSchema = ActionSchema
  { actionSchemaBlock :: Maybe SchemaBlock
  -- ^ The root-level block of configuration values
  }
  deriving stock (Show, Eq)

instance ToJSON ActionSchema where
  toJSON actionSchema =
    Aeson.object $
      filter
        ((/= Aeson.Null) . snd)
        ["block" Aeson..= actionSchemaBlock actionSchema]

instance FromJSON ActionSchema where
  parseJSON = withObject "ActionSchema" $ \o ->
    ActionSchema
      <$> o .:? "block"
