module CLI.Types (
  SchemaInput (..),
  Command (..),
)
where

import Data.Text (Text)

-- | Input source for schemas
data SchemaInput
  = -- | Read from file or stdin
    FromFile (Maybe FilePath)
  | -- | Generate from provider specifications
    FromProviderSpecs [Text]
  | -- | Read provider specs from JSON file
    FromProvidersFile FilePath
  deriving (Show)

-- | CLI commands
data Command
  = Generate
      { cmdSchemaInput :: SchemaInput
      , cmdOutput :: FilePath
      , cmdPrintSchema :: Bool
      }
  | Show
      { cmdSchemaInput :: SchemaInput
      }
  | ExtractSchema
      { cmdSchemaInput :: SchemaInput
      , cmdPrettyJson :: Bool
      }
  deriving (Show)
