{-# LANGUAGE StrictData #-}

module TerranixCodegen.ProviderSchema.Identity (
  IdentityAttribute (..),
  IdentitySchema (..),
) where

import Data.Aeson (FromJSON (..), ToJSON (..), withObject, (.:), (.:?))
import Data.Aeson qualified as Aeson
import Data.Map.Strict (Map)
import Data.Text qualified as T
import Data.Word (Word64)

import TerranixCodegen.ProviderSchema.CtyType

-- | IdentityAttribute describes an identity attribute.
data IdentityAttribute = IdentityAttribute
  { identityAttributeType :: Maybe CtyType
  -- ^ The identity attribute type (cty.Type)
  , identityAttributeDescription :: Maybe T.Text
  -- ^ Description of the identity attribute
  , identityAttributeRequiredForImport :: Maybe Bool
  -- ^ If true, this attribute must be specified in configuration during import
  , identityAttributeOptionalForImport :: Maybe Bool
  -- ^ If true, this attribute is not required during import (can be supplied by provider)
  }
  deriving stock (Show, Eq)

instance ToJSON IdentityAttribute where
  toJSON attr =
    Aeson.object $
      filter
        ((/= Aeson.Null) . snd)
        [ "type" Aeson..= identityAttributeType attr
        , "description" Aeson..= identityAttributeDescription attr
        , "required_for_import" Aeson..= identityAttributeRequiredForImport attr
        , "optional_for_import" Aeson..= identityAttributeOptionalForImport attr
        ]

instance FromJSON IdentityAttribute where
  parseJSON = withObject "IdentityAttribute" $ \o ->
    IdentityAttribute
      <$> o .:? "type"
      <*> o .:? "description"
      <*> o .:? "required_for_import"
      <*> o .:? "optional_for_import"

-- | IdentitySchema is the JSON representation of a particular resource identity schema.
data IdentitySchema = IdentitySchema
  { identitySchemaVersion :: Word64
  -- ^ The version of the particular resource identity schema
  , identitySchemaAttributes :: Maybe (Map T.Text IdentityAttribute)
  -- ^ Map of identity attributes
  }
  deriving stock (Show, Eq)

instance ToJSON IdentitySchema where
  toJSON schema =
    Aeson.object $
      filter
        ((/= Aeson.Null) . snd)
        [ "version" Aeson..= identitySchemaVersion schema
        , "attributes" Aeson..= identitySchemaAttributes schema
        ]

instance FromJSON IdentitySchema where
  parseJSON = withObject "IdentitySchema" $ \o ->
    IdentitySchema
      <$> o .: "version"
      <*> o .:? "attributes"
