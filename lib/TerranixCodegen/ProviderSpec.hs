{-# LANGUAGE DeriveGeneric #-}

-- | Types and parsers for Terraform provider specifications
module TerranixCodegen.ProviderSpec (
  -- * Types
  ProviderSpec (..),

  -- * Parsing
  parseProviderSpec,
  parseProviderSpecText,

  -- * Formatting
  formatProviderSpec,
)
where

import Data.Aeson (FromJSON (..), ToJSON (..), withText)
import Data.Text (Text)
import Data.Text qualified as T
import Data.Versions (Versioning, prettyV, versioning')
import Data.Void (Void)
import GHC.Generics (Generic)
import Text.Megaparsec (
  MonadParsec (..),
  Parsec,
  errorBundlePretty,
  many,
  optional,
  parse,
  (<|>),
 )
import Text.Megaparsec.Char (alphaNumChar, char)

-- | Parser type for provider specifications
type Parser = Parsec Void Text

{- | Specification for a Terraform provider

Examples:
 * @hashicorp/aws:5.0.0@ - full specification with namespace and version
 * @hashicorp/aws@ - namespace with latest version
 * @aws:5.0.0@ - no namespace, with version
 * @aws@ - no namespace, latest version
-}
data ProviderSpec = ProviderSpec
  { providerNamespace :: !(Maybe Text)
  -- ^ Provider namespace (e.g., "hashicorp", "cloudflare"), Nothing means no namespace specified
  , providerName :: !Text
  -- ^ Provider name (e.g., "aws", "google", "azurerm")
  , providerVersion :: !(Maybe Versioning)
  -- ^ Provider version (e.g., "5.0.0"), Nothing means latest
  }
  deriving (Show, Eq, Generic)

instance ToJSON ProviderSpec where
  toJSON = toJSON . formatProviderSpec

instance FromJSON ProviderSpec where
  parseJSON = withText "ProviderSpec" $ \txt ->
    case parseProviderSpecText txt of
      Left err -> fail err
      Right spec -> pure spec

{- | Parse a provider specification string

Supported formats:

 * @namespace\/name:version@ - Full specification (e.g., @hashicorp\/aws:5.0.0@)
 * @namespace\/name@ - Namespace with latest version (e.g., @hashicorp\/aws@)
 * @name:version@ - No namespace, with version (e.g., @aws:5.0.0@)
 * @name@ - No namespace, latest version (e.g., @aws@)

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
  -- Try to parse namespace first
  namespace <- optional $ identifierParser <* char '/'

  -- Parse name
  name <- identifierParser

  -- Optional version after colon
  version <- optional $ char ':' *> versioning'

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

-- | Format a provider spec for display
formatProviderSpec :: ProviderSpec -> Text
formatProviderSpec spec =
  mconcat
    [ maybe "" (<> "/") (providerNamespace spec)
    , providerName spec
    , maybe "" ((":" <>) . prettyV) (providerVersion spec)
    ]
