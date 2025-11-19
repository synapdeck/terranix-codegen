{-# LANGUAGE StrictData #-}

module TerranixCodegen.ProviderSchema.Provider (
  ProviderSchema (..),
  ProviderSchemas (..),
) where

import Data.Aeson (FromJSON (..), ToJSON (..), withObject, (.:?))
import Data.Aeson qualified as Aeson
import Data.Map.Strict (Map)
import Data.Text qualified as T

import TerranixCodegen.ProviderSchema.Function
import TerranixCodegen.ProviderSchema.Identity
import TerranixCodegen.ProviderSchema.Schema

{- | ProviderSchema is the JSON representation of the schema of an entire provider,
including the provider configuration and any resources and data sources.
-}
data ProviderSchema = ProviderSchema
  { configSchema :: Maybe Schema
  -- ^ The schema for the provider's configuration
  , resourceSchemas :: Maybe (Map T.Text Schema)
  -- ^ The schemas for any resources in this provider
  , dataSourceSchemas :: Maybe (Map T.Text Schema)
  -- ^ The schemas for any data sources in this provider
  , ephemeralResourceSchemas :: Maybe (Map T.Text Schema)
  -- ^ The schemas for any ephemeral resources in this provider
  , actionSchemas :: Maybe (Map T.Text ActionSchema)
  -- ^ The schemas for any actions in this provider
  , functions :: Maybe (Map T.Text FunctionSignature)
  -- ^ The definitions for any functions in this provider
  , resourceIdentitySchemas :: Maybe (Map T.Text IdentitySchema)
  -- ^ The schemas for resources identities in this provider
  , listResourceSchemas :: Maybe (Map T.Text Schema)
  -- ^ The schemas for any list resources in this provider
  }
  deriving stock (Show, Eq)

instance ToJSON ProviderSchema where
  toJSON providerSchema =
    Aeson.object $
      filter
        ((/= Aeson.Null) . snd)
        [ "provider" Aeson..= configSchema providerSchema
        , "resource_schemas" Aeson..= resourceSchemas providerSchema
        , "data_source_schemas" Aeson..= dataSourceSchemas providerSchema
        , "ephemeral_resource_schemas" Aeson..= ephemeralResourceSchemas providerSchema
        , "action_schemas" Aeson..= actionSchemas providerSchema
        , "functions" Aeson..= functions providerSchema
        , "resource_identity_schemas" Aeson..= resourceIdentitySchemas providerSchema
        , "list_resource_schemas" Aeson..= listResourceSchemas providerSchema
        ]

instance FromJSON ProviderSchema where
  parseJSON = withObject "ProviderSchema" $ \o ->
    ProviderSchema
      <$> o .:? "provider"
      <*> o .:? "resource_schemas"
      <*> o .:? "data_source_schemas"
      <*> o .:? "ephemeral_resource_schemas"
      <*> o .:? "action_schemas"
      <*> o .:? "functions"
      <*> o .:? "resource_identity_schemas"
      <*> o .:? "list_resource_schemas"

{- | ProviderSchemas represents the schemas of all providers and resources in use
by the configuration.
-}
data ProviderSchemas = ProviderSchemas
  { formatVersion :: Maybe T.Text
  -- ^ The version of the plan format
  , schemas :: Maybe (Map T.Text ProviderSchema)
  -- ^ The schemas for the providers, indexed by provider type
  }
  deriving stock (Show, Eq)

instance ToJSON ProviderSchemas where
  toJSON providerSchemas =
    Aeson.object $
      filter
        ((/= Aeson.Null) . snd)
        [ "format_version" Aeson..= formatVersion providerSchemas
        , "provider_schemas" Aeson..= schemas providerSchemas
        ]

instance FromJSON ProviderSchemas where
  parseJSON = withObject "ProviderSchemas" $ \o ->
    ProviderSchemas
      <$> o .:? "format_version"
      <*> o .:? "provider_schemas"
