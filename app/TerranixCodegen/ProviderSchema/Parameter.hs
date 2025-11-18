{-# LANGUAGE DerivingVia #-}
{-# LANGUAGE OverloadedStrings #-}

module TerranixCodegen.ProviderSchema.Parameter where

import Autodocodec (Autodocodec (..), HasCodec (..), object, optionalFieldWithDefault, requiredField, (.=))
import Data.Aeson (FromJSON, ToJSON)
import qualified Data.Text as T

data Parameter = Parameter
    { name :: T.Text
    , type_ :: String
    , description :: T.Text
    , isNullable :: Bool
    }
    deriving stock (Show, Eq, Ord)
    deriving (FromJSON, ToJSON) via (Autodocodec Parameter)

instance HasCodec Parameter where
    codec =
        object "Parameter" $
            Parameter
                <$> requiredField "name" "Parameter name" .= name
                <*> requiredField "type" "Parameter type" .= type_
                <*> requiredField "description" "Parameter description" .= description
                <*> optionalFieldWithDefault "is_nullable" False "Whether the parameter accepts null values" .= isNullable
