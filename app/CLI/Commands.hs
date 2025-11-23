module CLI.Commands (
  runCommand,
)
where

import CLI.Types
import Control.Monad.Except (runExceptT)
import Control.Monad.Reader (runReaderT)
import Data.Aeson (encode)
import Data.Aeson.Encode.Pretty (encodePretty)
import Data.ByteString.Lazy qualified as BL
import Data.Maybe (fromMaybe)
import Data.Text qualified as T
import Prettyprinter (Doc, annotate, hardline, pipe, pretty, vcat, vsep, (<+>))
import Prettyprinter.Render.Terminal (AnsiStyle, Color (..), bold, color, hPutDoc, putDoc)
import System.Exit (exitFailure)
import System.IO (hPutStrLn, stderr)
import TerranixCodegen.FileOrganizer
import TerranixCodegen.PrettyPrint
import TerranixCodegen.ProviderSchema
import TerranixCodegen.ProviderSpec
import TerranixCodegen.TerraformGenerator (GeneratorConfig (..), TerraformError (..), defaultGeneratorConfig, extractSchemaFromProviders)

-- | Execute a command
runCommand :: Command -> IO ()
runCommand cmd = case cmd of
  Generate input output printSchema tfExe -> do
    schemas <- loadSchemas tfExe input
    if printSchema
      then do
        putDoc $ prettyProviderSchemas schemas
        hPutStrLn stderr "Done"
      else do
        hPutStrLn stderr $ "Generating modules to: " <> output
        organizeFiles output schemas
        hPutStrLn stderr "✓ Module generation complete!"
  Show input tfExe -> do
    schemas <- loadSchemas tfExe input
    putDoc $ prettyProviderSchemas schemas
  ExtractSchema input prettyJson tfExe -> do
    schemas <- loadSchemas tfExe input
    let jsonOutput
          | prettyJson = encodePretty schemas
          | otherwise = encode schemas
    BL.putStr jsonOutput

-- | Load schemas from various input sources
loadSchemas :: Maybe FilePath -> SchemaInput -> IO ProviderSchemas
loadSchemas tfExe input = case input of
  FromFile maybePath -> loadFromFile maybePath
  FromProviderSpecs specs -> loadFromProviderSpecs tfExe specs
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
      hPutDoc stderr $
        vsep
          [ annotate (color Red <> bold) "Error:" <+> "Failed to parse schema"
          , hardline
          , pretty err
          , mempty
          ]
      exitFailure
    Right schemas -> do
      hPutStrLn stderr "Schema parsed successfully"
      pure schemas

-- | Load schemas by generating minimal Terraform from provider specs
loadFromProviderSpecs :: Maybe FilePath -> [T.Text] -> IO ProviderSchemas
loadFromProviderSpecs tfExe specTexts = do
  -- Parse provider specifications
  specs <- case mapM parseProviderSpecText specTexts of
    Left err -> do
      hPutDoc stderr $
        vsep
          [ annotate (color Red <> bold) "Error:" <+> "Failed to parse provider specification"
          , hardline
          , pretty err
          , mempty
          ]
      exitFailure
    Right parsed -> pure parsed

  -- Display provider specs being processed
  hPutDoc stderr $
    vsep
      [ "Generating Terraform for" <+> pretty (length specs) <+> "provider(s)..."
      , vcat $ map (\spec -> "  -" <+> pretty (formatProviderSpec spec)) specs
      , mempty
      ]

  -- Extract schemas using Terraform with custom executable if provided
  let config = case tfExe of
        Nothing -> defaultGeneratorConfig
        Just exe -> defaultGeneratorConfig {terraformExecutable = exe}
  result <- runExceptT $ runReaderT (extractSchemaFromProviders specs) config
  case result of
    Left err -> do
      hPutDoc stderr $ formatTerraformError err
      exitFailure
    Right schemas -> pure schemas

-- | Load provider specs from a JSON file and then load schemas
loadFromProvidersFile :: FilePath -> IO ProviderSchemas
loadFromProvidersFile _path = do
  -- TODO: Implement config file parsing
  hPutDoc stderr $
    vsep
      [ annotate (color Red <> bold) "Error:" <+> "--providers-file is not yet implemented"
      , mempty
      ]
  exitFailure

-- | Format TerraformError into a user-friendly colorized message
formatTerraformError :: TerraformError -> Doc AnsiStyle
formatTerraformError err = case err of
  TerraformNotFound ->
    vsep
      [ annotate (color Red <> bold) "Error:" <+> "Terraform not found"
      , hardline
      , "The 'terraform' command is not available on your system."
      , "Please install Terraform from" <+> annotate (color Cyan) "https://www.terraform.io/downloads"
      ]
  TerraformInitFailed output ->
    vsep
      [ annotate (color Red <> bold) "Error:" <+> "Terraform initialization failed"
      , hardline
      , "The" <+> annotate (color Yellow) "'terraform init'" <+> "command failed with the following output:"
      , hardline
      , formatTerraformOutput output
      ]
  SchemaExtractionFailed output ->
    vsep
      [ annotate (color Red <> bold) "Error:" <+> "Failed to extract provider schema"
      , hardline
      , "The" <+> annotate (color Yellow) "'terraform providers schema -json'" <+> "command failed:"
      , hardline
      , formatTerraformOutput output
      ]
  SchemaParsingFailed parseErr ->
    vsep
      [ annotate (color Red <> bold) "Error:" <+> "Failed to parse provider schema"
      , hardline
      , "The schema JSON returned by Terraform could not be parsed:"
      , hardline
      , pretty parseErr
      ]

-- | Format terraform command output with vertical line and red color
formatTerraformOutput :: String -> Doc AnsiStyle
formatTerraformOutput =
  annotate (color Red)
    . vcat
    . fmap (\line -> pipe <+> pretty line)
    . lines
