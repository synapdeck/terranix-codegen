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
      , cmdTerraformExecutable :: Maybe FilePath
      }
  | Show
      { cmdSchemaInput :: SchemaInput
      , cmdTerraformExecutable :: Maybe FilePath
      }
  | ExtractSchema
      { cmdSchemaInput :: SchemaInput
      , cmdPrettyJson :: Bool
      , cmdTerraformExecutable :: Maybe FilePath
      }
  deriving (Show)
