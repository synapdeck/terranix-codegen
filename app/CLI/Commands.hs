module CLI.Commands (
  runCommand,
)
where

import CLI.Types
import Data.Aeson (encode)
import Data.Aeson.Encode.Pretty (encodePretty)
import Data.ByteString.Lazy qualified as BL
import Data.Maybe (fromMaybe)
import Data.Text qualified as T
import Prettyprinter.Render.Terminal (putDoc)
import System.Exit (exitFailure)
import System.IO (hPutStrLn, stderr)
import TerranixCodegen.FileOrganizer
import TerranixCodegen.PrettyPrint
import TerranixCodegen.ProviderSchema
import TerranixCodegen.ProviderSpec
import TerranixCodegen.TerraformGenerator

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
loadFromProviderSpecs :: [T.Text] -> IO ProviderSchemas
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
