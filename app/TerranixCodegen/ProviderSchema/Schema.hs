{-# LANGUAGE DerivingVia #-}
{-# LANGUAGE OverloadedStrings #-}

module TerranixCodegen.ProviderSchema.Schema (
  Schema (..),
  ActionSchema (..),
) where

import Autodocodec (Autodocodec (..), HasCodec (..), object, optionalField, requiredField, (.=))
import Data.Aeson (FromJSON, ToJSON)
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
  deriving (FromJSON, ToJSON) via (Autodocodec Schema)

instance HasCodec Schema where
  codec =
    object "Schema" $
      Schema
        <$> requiredField "version" "The version of the particular resource schema" .= schemaVersion
        <*> optionalField "block" "The root-level block of configuration values" .= schemaBlock

-- | ActionSchema is the JSON representation of an action schema.
newtype ActionSchema = ActionSchema
  { actionSchemaBlock :: Maybe SchemaBlock
  -- ^ The root-level block of configuration values
  }
  deriving stock (Show, Eq)
  deriving (FromJSON, ToJSON) via (Autodocodec ActionSchema)

instance HasCodec ActionSchema where
  codec =
    object "ActionSchema" $
      ActionSchema
        <$> optionalField "block" "The root-level block of configuration values" .= actionSchemaBlock
