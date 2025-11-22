{-# LANGUAGE OverloadedStrings #-}

-- | Generate minimal Terraform configurations and extract provider schemas
module TerranixCodegen.TerraformGenerator (
  extractSchemaFromProviders,
  TerraformError (..),
)
where

import Control.Exception (Exception, bracket, throwIO)
import Data.ByteString.Lazy qualified as BL
import Data.Text (Text)
import Data.Text qualified as T
import Data.Text.Encoding qualified as TE
import Data.Text.IO qualified as TIO
import System.Directory (removeDirectoryRecursive)
import System.Exit (ExitCode (..))
import System.FilePath ((</>))
import System.IO.Temp (createTempDirectory, getCanonicalTemporaryDirectory)
import System.Process (readProcessWithExitCode)
import TerranixCodegen.ProviderSchema (ProviderSchemas, parseProviderSchemas)
import TerranixCodegen.ProviderSpec (ProviderSpec (..))

-- | Errors that can occur during Terraform operations
data TerraformError
  = TerraformNotFound
  | TerraformInitFailed String
  | SchemaExtractionFailed String
  | SchemaParsingFailed String
  deriving (Show, Eq)

instance Exception TerraformError

{- | Extract provider schemas from a list of provider specifications

This function:

  1. Creates a temporary directory
  2. Generates a minimal Terraform configuration
  3. Runs @terraform init@ to download providers
  4. Runs @terraform providers schema -json@ to extract schemas
  5. Parses the JSON output
  6. Cleans up the temporary directory

May throw 'TerraformError' if any step fails.
-}
extractSchemaFromProviders :: [ProviderSpec] -> IO ProviderSchemas
extractSchemaFromProviders specs = do
  -- Create temp directory and ensure cleanup
  tmpDir <- getCanonicalTemporaryDirectory
  bracket
    (createTempDirectory tmpDir "terranix-codegen-")
    removeDirectoryRecursive
    $ \workDir -> do
      -- Generate Terraform configuration
      let tfContent = generateTerraformConfig specs
      let tfFile = workDir </> "main.tf"
      TIO.writeFile tfFile tfContent

      -- Check if terraform is available
      checkTerraformInstalled

      -- Run terraform init
      runTerraformInit workDir

      -- Extract schema
      schemaJson <- runTerraformSchemaExtract workDir

      -- Parse schema
      case parseProviderSchemas schemaJson of
        Left err -> throwIO $ SchemaParsingFailed err
        Right schemas -> pure schemas

-- | Generate minimal Terraform configuration from provider specs
generateTerraformConfig :: [ProviderSpec] -> Text
generateTerraformConfig specs =
  T.unlines
    [ "terraform {"
    , "  required_providers {"
    , T.unlines (map providerBlock specs)
    , "  }"
    , "}"
    ]
  where
    providerBlock :: ProviderSpec -> Text
    providerBlock spec =
      let sourceLine = "      source  = \"" <> providerNamespace spec <> "/" <> providerName spec <> "\""
          versionLine = case providerVersion spec of
            Nothing -> ""
            Just v -> "\n      version = \"" <> v <> "\""
       in T.unlines
            [ "    " <> providerName spec <> " = {"
            , sourceLine <> versionLine
            , "    }"
            ]

-- | Check if terraform is installed and available
checkTerraformInstalled :: IO ()
checkTerraformInstalled = do
  (exitCode, _, _) <- readProcessWithExitCode "terraform" ["version"] ""
  case exitCode of
    ExitSuccess -> pure ()
    ExitFailure _ -> throwIO TerraformNotFound

-- | Run terraform init in the working directory
runTerraformInit :: FilePath -> IO ()
runTerraformInit workDir = do
  (exitCode, stdout, stderr) <-
    readProcessWithExitCode "terraform" ["-chdir=" <> workDir, "init", "-no-color"] ""
  case exitCode of
    ExitSuccess -> pure ()
    ExitFailure _ ->
      throwIO $ TerraformInitFailed (stdout <> "\n" <> stderr)

-- | Run terraform providers schema -json and return the output
runTerraformSchemaExtract :: FilePath -> IO BL.ByteString
runTerraformSchemaExtract workDir = do
  (exitCode, stdout, stderr) <-
    readProcessWithExitCode "terraform" ["-chdir=" <> workDir, "providers", "schema", "-json"] ""
  case exitCode of
    ExitSuccess -> pure $ BL.fromStrict $ TE.encodeUtf8 $ T.pack stdout
    ExitFailure _ ->
      throwIO $ SchemaExtractionFailed (stdout <> "\n" <> stderr)
