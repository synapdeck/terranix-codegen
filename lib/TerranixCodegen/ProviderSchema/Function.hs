{-# LANGUAGE StrictData #-}

module TerranixCodegen.ProviderSchema.Function (
  FunctionSignature (..),
  FunctionParameter (..),
) where

import Data.Aeson (FromJSON (..), ToJSON (..), withObject, (.:), (.:?))
import Data.Aeson qualified as Aeson
import Data.Text qualified as T
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

instance ToJSON FunctionParameter where
  toJSON param =
    Aeson.object $
      filter
        ((/= Aeson.Null) . snd)
        [ "name" Aeson..= functionParameterName param
        , "description" Aeson..= functionParameterDescription param
        , "is_nullable" Aeson..= functionParameterIsNullable param
        , "type" Aeson..= functionParameterType param
        ]

instance FromJSON FunctionParameter where
  parseJSON = withObject "FunctionParameter" $ \o ->
    FunctionParameter
      <$> o .:? "name"
      <*> o .:? "description"
      <*> o .:? "is_nullable"
      <*> o .: "type"

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

instance ToJSON FunctionSignature where
  toJSON sig =
    Aeson.object $
      filter
        ((/= Aeson.Null) . snd)
        [ "description" Aeson..= functionSignatureDescription sig
        , "summary" Aeson..= functionSignatureSummary sig
        , "deprecation_message" Aeson..= functionSignatureDeprecationMessage sig
        , "return_type" Aeson..= functionSignatureReturnType sig
        , "parameters" Aeson..= functionSignatureParameters sig
        , "variadic_parameter" Aeson..= functionSignatureVariadicParameter sig
        ]

instance FromJSON FunctionSignature where
  parseJSON = withObject "FunctionSignature" $ \o ->
    FunctionSignature
      <$> o .:? "description"
      <*> o .:? "summary"
      <*> o .:? "deprecation_message"
      <*> o .: "return_type"
      <*> o .:? "parameters"
      <*> o .:? "variadic_parameter"
