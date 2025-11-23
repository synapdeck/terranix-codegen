-- | Generate minimal Terraform configurations and extract provider schemas
module TerranixCodegen.TerraformGenerator (
  -- * Main API
  extractSchemaFromProviders,
  TerraformError (..),

  -- * Configuration
  GeneratorConfig (..),
  defaultGeneratorConfig,

  -- * Internal functions (exported for testing)
  generateTerraformConfig,
  checkTerraformInstalled,
  runTerraformInit,
  runTerraformSchemaExtract,
)
where

import Control.Exception (bracket)
import Control.Monad.Except (MonadError (throwError), runExceptT)
import Control.Monad.IO.Class (MonadIO (liftIO))
import Control.Monad.Reader (MonadReader, ask, asks, runReaderT)
import Data.ByteString.Lazy qualified as BL
import Data.Maybe (catMaybes, fromMaybe)
import Data.Text (Text)
import Data.Text qualified as T
import Data.Text.Encoding qualified as TE
import Data.Text.IO qualified as TIO
import Data.Versions (prettyV)
import Prettyprinter (Doc, Pretty (pretty), defaultLayoutOptions, dquotes, indent, layoutPretty, vsep, (<+>))
import Prettyprinter.Render.Text (renderStrict)
import System.Directory (removeDirectoryRecursive)
import System.Exit (ExitCode (..))
import System.FilePath ((</>))
import System.IO.Temp (createTempDirectory, getCanonicalTemporaryDirectory)
import System.Process (readProcessWithExitCode)
import TerranixCodegen.ProviderSchema (ProviderSchemas, parseProviderSchemas)
import TerranixCodegen.ProviderSpec (ProviderSpec (..))

-- | Configuration for the generator
newtype GeneratorConfig = GeneratorConfig
  { terraformExecutable :: FilePath
  -- ^ Path or name of the Terraform executable (default: "tofu")
  }
  deriving (Show, Eq)

-- | Default generator configuration
defaultGeneratorConfig :: GeneratorConfig
defaultGeneratorConfig =
  GeneratorConfig
    { terraformExecutable = "tofu"
    }

-- | Errors that can occur during Terraform operations
data TerraformError
  = TerraformNotFound
  | TerraformInitFailed String
  | SchemaExtractionFailed String
  | SchemaParsingFailed String
  deriving (Show, Eq)

{- | Extract provider schemas from a list of provider specifications

This function:

  1. Creates a temporary directory
  2. Generates a minimal Terraform configuration
  3. Runs @terraform init@ to download providers
  4. Runs @terraform providers schema -json@ to extract schemas
  5. Parses the JSON output
  6. Cleans up the temporary directory

Returns 'Left TerraformError' if any step fails.
-}
extractSchemaFromProviders :: (MonadIO m, MonadError TerraformError m, MonadReader GeneratorConfig m) => [ProviderSpec] -> m ProviderSchemas
extractSchemaFromProviders specs = do
  -- Get the config before entering bracket
  config <- ask
  -- Create temp directory and ensure cleanup
  tmpDir <- liftIO getCanonicalTemporaryDirectory
  result <- liftIO $ do
    bracket
      (createTempDirectory tmpDir "terranix-codegen-")
      removeDirectoryRecursive
      $ \workDir ->
        runExceptT $
          runReaderT
            ( do
                -- Generate Terraform configuration
                let tfContent = generateTerraformConfig specs
                let tfFile = workDir </> "main.tf"
                liftIO $ TIO.writeFile tfFile tfContent

                -- Check if terraform is available
                checkTerraformInstalled

                -- Run terraform init
                runTerraformInit workDir

                -- Extract schema
                schemaJson <- runTerraformSchemaExtract workDir

                -- Parse schema
                case parseProviderSchemas schemaJson of
                  Left err -> throwError $ SchemaParsingFailed err
                  Right schemas -> pure schemas
            )
            config

  -- Unwrap the result from the bracket
  case result of
    Left err -> throwError err
    Right schemas -> pure schemas

-- | Generate minimal Terraform configuration from provider specs
generateTerraformConfig :: [ProviderSpec] -> Text
generateTerraformConfig specs = renderStrict $ layoutPretty defaultLayoutOptions terraformDoc
  where
    terraformDoc :: Doc ann
    terraformDoc =
      vsep
        [ "terraform" <+> "{"
        , indent 2 $
            vsep
              [ "required_providers" <+> "{"
              , indent 2 $ vsep $ map providerBlock specs
              , "}"
              ]
        , "}"
        ]

    providerBlock :: ProviderSpec -> Doc ann
    providerBlock spec =
      vsep $
        catMaybes
          [ Just $ pretty (providerName spec) <+> "= {"
          , Just $ indent 2 $ "source" <+> "=" <+> dquotes (pretty (fromMaybe "hashicorp" (providerNamespace spec) <> "/" <> providerName spec))
          , fmap (\v -> indent 2 $ "version" <+> "=" <+> dquotes (pretty (prettyV v))) (providerVersion spec)
          , Just "}"
          ]

-- | Check if terraform is installed and available
checkTerraformInstalled :: (MonadIO m, MonadError TerraformError m, MonadReader GeneratorConfig m) => m ()
checkTerraformInstalled = do
  tfExe <- asks terraformExecutable
  (exitCode, _, _) <- liftIO $ readProcessWithExitCode tfExe ["version"] ""
  case exitCode of
    ExitSuccess -> pure ()
    ExitFailure _ -> throwError TerraformNotFound

-- | Run terraform init in the working directory
runTerraformInit :: (MonadIO m, MonadError TerraformError m, MonadReader GeneratorConfig m) => FilePath -> m ()
runTerraformInit workDir = do
  tfExe <- asks terraformExecutable
  (exitCode, stdout, stderr) <-
    liftIO $ readProcessWithExitCode tfExe ["-chdir=" <> workDir, "init", "-no-color"] ""
  case exitCode of
    ExitSuccess -> pure ()
    ExitFailure _ ->
      throwError $ TerraformInitFailed (stdout <> "\n" <> stderr)

-- | Run terraform providers schema -json and return the output
runTerraformSchemaExtract :: (MonadIO m, MonadError TerraformError m, MonadReader GeneratorConfig m) => FilePath -> m BL.ByteString
runTerraformSchemaExtract workDir = do
  tfExe <- asks terraformExecutable
  (exitCode, stdout, stderr) <-
    liftIO $ readProcessWithExitCode tfExe ["-chdir=" <> workDir, "providers", "schema", "-json"] ""
  case exitCode of
    ExitSuccess -> pure $ BL.fromStrict $ TE.encodeUtf8 $ T.pack stdout
    ExitFailure _ ->
      throwError $ SchemaExtractionFailed (stdout <> "\n" <> stderr)
