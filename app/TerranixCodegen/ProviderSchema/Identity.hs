{-# LANGUAGE DerivingVia #-}
{-# LANGUAGE OverloadedStrings #-}

module TerranixCodegen.ProviderSchema.Identity (
  IdentityAttribute (..),
  IdentitySchema (..),
) where

import Autodocodec (Autodocodec (..), HasCodec (..), object, optionalField, requiredField, (.=))
import Data.Aeson (FromJSON, ToJSON)
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
  deriving (FromJSON, ToJSON) via (Autodocodec IdentityAttribute)

instance HasCodec IdentityAttribute where
  codec =
    object "IdentityAttribute" $
      IdentityAttribute
        <$> optionalField "type" "The identity attribute type (cty.Type)" .= identityAttributeType
        <*> optionalField "description" "Description of the identity attribute" .= identityAttributeDescription
        <*> optionalField "required_for_import" "If true, this attribute must be specified in configuration during import" .= identityAttributeRequiredForImport
        <*> optionalField "optional_for_import" "If true, this attribute is not required during import (can be supplied by provider)" .= identityAttributeOptionalForImport

-- | IdentitySchema is the JSON representation of a particular resource identity schema.
data IdentitySchema = IdentitySchema
  { identitySchemaVersion :: Word64
  -- ^ The version of the particular resource identity schema
  , identitySchemaAttributes :: Maybe (Map T.Text IdentityAttribute)
  -- ^ Map of identity attributes
  }
  deriving stock (Show, Eq)
  deriving (FromJSON, ToJSON) via (Autodocodec IdentitySchema)

instance HasCodec IdentitySchema where
  codec =
    object "IdentitySchema" $
      IdentitySchema
        <$> requiredField "version" "The version of the particular resource identity schema" .= identitySchemaVersion
        <*> optionalField "attributes" "Map of identity attributes" .= identitySchemaAttributes
