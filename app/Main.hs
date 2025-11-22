module Main (main) where

import Control.Exception (catch)
import Data.Aeson (encode)
import Data.Aeson.Encode.Pretty (encodePretty)
import Data.ByteString.Lazy qualified as BL
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import Data.Text qualified as T
import Options.Applicative
import Prettyprinter.Render.Terminal (putDoc)
import System.Exit (exitFailure)
import System.IO (hPutStrLn, stderr)
import TerranixCodegen.FileOrganizer
import TerranixCodegen.PrettyPrint
import TerranixCodegen.ProviderSchema
import TerranixCodegen.ProviderSpec
import TerranixCodegen.TerraformGenerator

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

-- | Parse schema input options (used across multiple commands)
schemaInputParser :: Parser SchemaInput
schemaInputParser =
  fromProvidersFile <|> fromProviderSpecs <|> fromFile
  where
    fromFile =
      FromFile
        <$> optional
          ( strOption
              ( long "input"
                  <> short 'i'
                  <> metavar "FILE"
                  <> help "Input Terraform provider schema JSON file (default: stdin)"
              )
          )

    fromProviderSpecs =
      FromProviderSpecs
        <$> some
          ( T.pack
              <$> strOption
                ( long "provider"
                    <> short 'p'
                    <> metavar "SPEC"
                    <> help "Provider specification (e.g., aws, hashicorp/aws:5.0.0)"
                )
          )

    fromProvidersFile =
      FromProvidersFile
        <$> strOption
          ( long "providers-file"
              <> metavar "FILE"
              <> help "JSON file containing provider specifications"
          )

-- | Parser for the 'generate' subcommand
generateCommand :: Parser Command
generateCommand =
  Generate
    <$> schemaInputParser
    <*> strOption
      ( long "output"
          <> short 'o'
          <> metavar "DIR"
          <> value "./providers"
          <> showDefault
          <> help "Output directory for generated Nix modules"
      )
    <*> switch
      ( long "print-schema"
          <> help "Pretty-print the schema instead of generating modules"
      )

-- | Parser for the 'show' subcommand
showCommand :: Parser Command
showCommand = Show <$> schemaInputParser

-- | Parser for the 'schema' subcommand
schemaCommand :: Parser Command
schemaCommand =
  ExtractSchema
    <$> schemaInputParser
    <*> switch
      ( long "pretty"
          <> short 'P'
          <> help "Pretty-print JSON output (default: compact)"
      )

-- | Parser for all commands
commandParser :: Parser Command
commandParser =
  hsubparser
    ( command
        "generate"
        ( info
            (generateCommand <**> helper)
            (progDesc "Generate Terranix modules from schema or provider specs")
        )
        <> command
          "show"
          ( info
              (showCommand <**> helper)
              (progDesc "Pretty-print provider schema")
          )
        <> command
          "schema"
          ( info
              (schemaCommand <**> helper)
              (progDesc "Extract and print provider schema as JSON")
          )
    )

-- | Program info for --help
programInfo :: ParserInfo Command
programInfo =
  info
    (commandParser <**> helper)
    ( fullDesc
        <> progDesc "Generate Terranix modules from Terraform provider schemas"
        <> header "terranix-codegen - Terraform provider to Terranix module generator"
        <> footer footerText
    )
  where
    footerText =
      unlines
        [ ""
        , "Examples:"
        , "  # Generate from stdin"
        , "  terraform providers schema -json | terranix-codegen generate -o ./modules"
        , ""
        , "  # Generate from file"
        , "  terranix-codegen generate -i schema.json -o ./modules"
        , ""
        , "  # Generate from provider specs"
        , "  terranix-codegen generate -p aws -p google -o ./modules"
        , "  terranix-codegen generate -p hashicorp/aws:5.0.0 -o ./modules"
        , ""
        , "  # Pretty-print schema from provider spec"
        , "  terranix-codegen show -p aws"
        , ""
        , "  # Extract schema JSON from provider specs"
        , "  terranix-codegen schema -p aws -p google > schema.json"
        , "  terranix-codegen schema -p aws --pretty > schema.json"
        ]

main :: IO ()
main = do
  cmd <- execParser programInfo
  runCommand cmd `catch` handleTerraformError
  where
    handleTerraformError :: TerraformError -> IO ()
    handleTerraformError err = do
      hPutStrLn stderr $ "Error: " <> show err
      exitFailure

-- | Execute a command
runCommand :: Command -> IO ()
runCommand cmd = case cmd of
  Generate input output printSchema -> do
    schemas <- loadSchemas input
    if printSchema
      then do
        putDoc $ prettyProviderSchemas schemas
        hPutStrLn stderr "Done"
      else do
        hPutStrLn stderr $ "Generating modules to: " <> output
        organizeFiles output schemas
        hPutStrLn stderr "✓ Module generation complete!"
  Show input -> do
    schemas <- loadSchemas input
    putDoc $ prettyProviderSchemas schemas
  ExtractSchema input prettyJson -> do
    schemas <- loadSchemas input
    let jsonOutput
          | prettyJson = encodePretty schemas
          | otherwise = encode schemas
    BL.putStr jsonOutput

-- | Load schemas from various input sources
loadSchemas :: SchemaInput -> IO ProviderSchemas
loadSchemas input = case input of
  FromFile maybePath -> loadFromFile maybePath
  FromProviderSpecs specs -> loadFromProviderSpecs specs
  FromProvidersFile path -> loadFromProvidersFile path

-- | Load schemas from a file or stdin
loadFromFile :: Maybe FilePath -> IO ProviderSchemas
loadFromFile maybePath = do
  let source = fromMaybe "stdin" maybePath
  hPutStrLn stderr $ "Reading schema from " <> source
  content <- maybe BL.getContents BL.readFile maybePath

  hPutStrLn stderr "Parsing provider schema..."
  case parseProviderSchemas content of
    Left err -> do
      hPutStrLn stderr $ "Error parsing schema: " <> err
      exitFailure
    Right schemas -> do
      hPutStrLn stderr "Schema parsed successfully"
      pure schemas

-- | Load schemas by generating minimal Terraform from provider specs
loadFromProviderSpecs :: [Text] -> IO ProviderSchemas
loadFromProviderSpecs specTexts = do
  -- Parse provider specifications
  specs <- case mapM parseProviderSpecText specTexts of
    Left err -> do
      hPutStrLn stderr $ "Error parsing provider specification: " <> err
      exitFailure
    Right parsed -> pure parsed

  hPutStrLn stderr $ "Generating Terraform for " <> show (length specs) <> " provider(s)..."
  mapM_ (hPutStrLn stderr . ("  - " <>) . T.unpack . formatProviderSpec) specs

  -- Extract schemas using Terraform
  extractSchemaFromProviders specs

-- | Load provider specs from a JSON file and then load schemas
loadFromProvidersFile :: FilePath -> IO ProviderSchemas
loadFromProvidersFile _path = do
  -- TODO: Implement config file parsing
  hPutStrLn stderr "Error: --providers-file is not yet implemented"
  exitFailure
