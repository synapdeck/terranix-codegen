{-# LANGUAGE DerivingVia #-}
{-# LANGUAGE OverloadedStrings #-}

module TerranixCodegen.ProviderSchema.Function
    ( FunctionSignature (..)
    , FunctionParameter (..)
    ) where

import Autodocodec (Autodocodec (..), HasCodec (..), object, optionalField, requiredField, (.=))
import Data.Aeson (FromJSON, ToJSON)
import qualified Data.Text as T
import TerranixCodegen.ProviderSchema.CtyType

-- | FunctionParameter represents a parameter to a function.
data FunctionParameter = FunctionParameter
    { functionParameterName :: Maybe T.Text
    -- ^ Optional name for the argument
    , functionParameterDescription :: Maybe T.Text
    -- ^ Optional human-readable description of the argument
    , functionParameterIsNullable :: Maybe Bool
    -- ^ True if null is acceptable value for the argument
    , functionParameterType :: CtyType
    -- ^ Type that any argument for this parameter must conform to
    }
    deriving stock (Show, Eq)
    deriving (FromJSON, ToJSON) via (Autodocodec FunctionParameter)

instance HasCodec FunctionParameter where
    codec =
        object "FunctionParameter" $
            FunctionParameter
                <$> optionalField "name" "Optional name for the argument" .= functionParameterName
                <*> optionalField "description" "Optional human-readable description of the argument" .= functionParameterDescription
                <*> optionalField "is_nullable" "True if null is acceptable value for the argument" .= functionParameterIsNullable
                <*> requiredField "type" "Type that any argument for this parameter must conform to" .= functionParameterType

-- | FunctionSignature represents a function signature.
data FunctionSignature = FunctionSignature
    { functionSignatureDescription :: Maybe T.Text
    -- ^ Optional human-readable description of the function
    , functionSignatureSummary :: Maybe T.Text
    -- ^ Optional shortened description of the function
    , functionSignatureDeprecationMessage :: Maybe T.Text
    -- ^ Optional deprecation message
    , functionSignatureReturnType :: CtyType
    -- ^ The function's return type
    , functionSignatureParameters :: Maybe [FunctionParameter]
    -- ^ The function's fixed positional parameters
    , functionSignatureVariadicParameter :: Maybe FunctionParameter
    -- ^ The function's variadic parameter if supported
    }
    deriving stock (Show, Eq)
    deriving (FromJSON, ToJSON) via (Autodocodec FunctionSignature)

instance HasCodec FunctionSignature where
    codec =
        object "FunctionSignature" $
            FunctionSignature
                <$> optionalField "description" "Optional human-readable description of the function" .= functionSignatureDescription
                <*> optionalField "summary" "Optional shortened description of the function" .= functionSignatureSummary
                <*> optionalField "deprecation_message" "Optional deprecation message" .= functionSignatureDeprecationMessage
                <*> requiredField "return_type" "The function's return type" .= functionSignatureReturnType
                <*> optionalField "parameters" "The function's fixed positional parameters" .= functionSignatureParameters
                <*> optionalField "variadic_parameter" "The function's variadic parameter if supported" .= functionSignatureVariadicParameter
