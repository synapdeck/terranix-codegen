{-# LANGUAGE DeriveGeneric #-}

-- | Types and parsers for Terraform provider specifications
module TerranixCodegen.ProviderSpec (
  -- * Types
  ProviderSpec (..),
  ProvidersConfig (..),

  -- * Parsing
  parseProviderSpec,
  parseProviderSpecText,

  -- * Formatting
  formatProviderSpec,
)
where

import Control.Monad (void)
import Data.Aeson (FromJSON (..), ToJSON (..), object, withObject, (.:), (.=))
import Data.Text (Text)
import Data.Text qualified as T
import Data.Void (Void)
import GHC.Generics (Generic)
import Text.Megaparsec (
  MonadParsec (..),
  Parsec,
  errorBundlePretty,
  many,
  optional,
  parse,
  some,
  (<|>),
 )
import Text.Megaparsec.Char (alphaNumChar, char)

-- | Parser type for provider specifications
type Parser = Parsec Void Text

{- | Specification for a Terraform provider

Examples:
 * @hashicorp/aws:5.0.0@ - full specification
 * @hashicorp/aws@ - latest version
 * @aws:5.0.0@ - default namespace (hashicorp)
 * @aws@ - default namespace and latest version
-}
data ProviderSpec = ProviderSpec
  { providerNamespace :: !Text
  -- ^ Provider namespace (e.g., "hashicorp", "cloudflare")
  , providerName :: !Text
  -- ^ Provider name (e.g., "aws", "google", "azurerm")
  , providerVersion :: !(Maybe Text)
  -- ^ Provider version (e.g., "5.0.0"), Nothing means latest
  }
  deriving (Show, Eq, Generic)

instance ToJSON ProviderSpec where
  toJSON spec =
    object
      [ "namespace" .= providerNamespace spec
      , "name" .= providerName spec
      , "version" .= providerVersion spec
      ]

instance FromJSON ProviderSpec where
  parseJSON = withObject "ProviderSpec" $ \v ->
    ProviderSpec
      <$> v .: "namespace"
      <*> v .: "name"
      <*> v .: "version"

{- | Configuration file structure for provider specifications

JSON format:
@
{
 "providers": [
   "aws",
   "hashicorp/google:4.0.0",
   "cloudflare/cloudflare"
 ]
}
@
-}
newtype ProvidersConfig = ProvidersConfig
  { configProviders :: [Text]
  -- ^ List of provider specification strings
  }
  deriving (Show, Eq, Generic)

instance ToJSON ProvidersConfig where
  toJSON config = object ["providers" .= configProviders config]

instance FromJSON ProvidersConfig where
  parseJSON = withObject "ProvidersConfig" $ \v ->
    ProvidersConfig <$> v .: "providers"

{- | Parse a provider specification string

Supported formats:

 * @namespace\/name:version@ - Full specification (e.g., @hashicorp\/aws:5.0.0@)
 * @namespace\/name@ - Use latest version (e.g., @hashicorp\/aws@)
 * @name:version@ - Default to hashicorp namespace (e.g., @aws:5.0.0@)
 * @name@ - Default namespace and latest (e.g., @aws@)

Returns @Left errorMessage@ if the spec is invalid, @Right ProviderSpec@ otherwise.
-}
parseProviderSpec :: String -> Either String ProviderSpec
parseProviderSpec = parseProviderSpecText . T.pack

-- | Parse a provider specification from Text
parseProviderSpecText :: Text -> Either String ProviderSpec
parseProviderSpecText input =
  case parse providerSpecParser "" input of
    Left err -> Left $ errorBundlePretty err
    Right spec -> Right spec

-- | Megaparsec parser for provider specifications
providerSpecParser :: Parser ProviderSpec
providerSpecParser = do
  -- Try to parse namespace/name format first
  (namespace, name) <-
    ( do
        ns <- identifierParser
        void $ char '/'
        n <- identifierParser
        pure (ns, n)
    )
      <|> ( do
              -- Otherwise just parse name with default namespace
              n <- identifierParser
              pure ("hashicorp", n)
          )

  -- Optional version after colon
  version <- optional versionParser

  eof

  pure $ ProviderSpec namespace name version

{- | Parse an identifier (namespace or provider name)
Identifiers can contain alphanumeric characters, hyphens, and underscores
-}
identifierParser :: Parser Text
identifierParser = do
  first <- alphaNumChar
  rest <- many (alphaNumChar <|> char '-' <|> char '_')
  pure $ T.pack (first : rest)

-- | Parse a version string after a colon
versionParser :: Parser Text
versionParser = do
  void $ char ':'
  -- Version can contain alphanumeric, dots, hyphens (e.g., 5.0.0, 1.2.3-beta)
  version <- some (alphaNumChar <|> char '.' <|> char '-')
  pure $ T.pack version

-- | Format a provider spec for display
formatProviderSpec :: ProviderSpec -> Text
formatProviderSpec spec =
  providerNamespace spec
    <> "/"
    <> providerName spec
    <> maybe "" (":" <>) (providerVersion spec)
