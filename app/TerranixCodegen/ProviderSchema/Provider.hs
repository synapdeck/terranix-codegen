{-# LANGUAGE DerivingVia #-}
{-# LANGUAGE OverloadedStrings #-}

module TerranixCodegen.ProviderSchema.Provider
    ( ProviderSchema (..)
    , ProviderSchemas (..)
    ) where

import Autodocodec (Autodocodec (..), HasCodec (..), object, optionalField, (.=))
import Data.Aeson (FromJSON, ToJSON)
import Data.Map.Strict (Map)
import qualified Data.Text as T
import TerranixCodegen.ProviderSchema.Function
import TerranixCodegen.ProviderSchema.Identity
import TerranixCodegen.ProviderSchema.Schema

-- | ProviderSchema is the JSON representation of the schema of an entire provider,
-- including the provider configuration and any resources and data sources.
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
    deriving (FromJSON, ToJSON) via (Autodocodec ProviderSchema)

instance HasCodec ProviderSchema where
    codec =
        object "ProviderSchema" $
            ProviderSchema
                <$> optionalField "provider" "The schema for the provider's configuration" .= configSchema
                <*> optionalField "resource_schemas" "The schemas for any resources in this provider" .= resourceSchemas
                <*> optionalField "data_source_schemas" "The schemas for any data sources in this provider" .= dataSourceSchemas
                <*> optionalField "ephemeral_resource_schemas" "The schemas for any ephemeral resources in this provider" .= ephemeralResourceSchemas
                <*> optionalField "action_schemas" "The schemas for any actions in this provider" .= actionSchemas
                <*> optionalField "functions" "The definitions for any functions in this provider" .= functions
                <*> optionalField "resource_identity_schemas" "The schemas for resources identities in this provider" .= resourceIdentitySchemas
                <*> optionalField "list_resource_schemas" "The schemas for any list resources in this provider" .= listResourceSchemas

-- | ProviderSchemas represents the schemas of all providers and resources in use
-- by the configuration.
data ProviderSchemas = ProviderSchemas
    { formatVersion :: Maybe T.Text
    -- ^ The version of the plan format
    , schemas :: Maybe (Map T.Text ProviderSchema)
    -- ^ The schemas for the providers, indexed by provider type
    }
    deriving stock (Show, Eq)
    deriving (FromJSON, ToJSON) via (Autodocodec ProviderSchemas)

instance HasCodec ProviderSchemas where
    codec =
        object "ProviderSchemas" $
            ProviderSchemas
                <$> optionalField "format_version" "The version of the plan format" .= formatVersion
                <*> optionalField "provider_schemas" "The schemas for the providers, indexed by provider type" .= schemas
