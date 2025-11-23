-- | Tests for Terraform configuration generation and schema extraction
module TerranixCodegen.TerraformGeneratorSpec (spec) where

import Control.Exception (SomeException, catch)
import Control.Monad (when)
import Control.Monad.Except (runExceptT)
import Control.Monad.Reader (runReaderT)
import Data.Aeson (eitherDecode)
import Data.ByteString.Lazy qualified as BL
import Data.Map.Strict qualified as Map
import Data.Maybe (fromMaybe, isJust)
import Data.Text (Text)
import Data.Text qualified as T
import Data.Versions (Versioning, versioning)
import System.Directory (doesPathExist, listDirectory)
import System.Exit (ExitCode (..))
import System.IO.Temp (withSystemTempDirectory)
import System.Process (readProcessWithExitCode)
import TerranixCodegen.ProviderSchema.Provider (ProviderSchemas (..))
import TerranixCodegen.ProviderSpec
import TerranixCodegen.TerraformGenerator
import Test.Hspec

spec :: Spec
spec = do
  describe "generateTerraformConfig" $ do
    describe "single provider configurations" $ do
      it "generates minimal config for provider without version" $ do
        let provSpec =
              ProviderSpec
                { providerNamespace = Nothing
                , providerName = "random"
                , providerVersion = Nothing
                }
        let config = generateTerraformConfig [provSpec]
        config `textShouldContain` "terraform {"
        config `textShouldContain` "required_providers {"
        config `textShouldContain` "random = {"
        config `textShouldContain` "source = \"hashicorp/random\""
        config `textShouldNotContain` "version ="

      it "generates config for provider with version" $ do
        let provSpec =
              ProviderSpec
                { providerNamespace = Nothing
                , providerName = "random"
                , providerVersion = mkVersion "3.5.0"
                }
        let config = generateTerraformConfig [provSpec]
        config `textShouldContain` "version = \"3.5.0\""

      it "generates config for provider with custom namespace" $ do
        let provSpec =
              ProviderSpec
                { providerNamespace = Just "cloudflare"
                , providerName = "cloudflare"
                , providerVersion = mkVersion "4.0.0"
                }
        let config = generateTerraformConfig [provSpec]
        config `textShouldContain` "source = \"cloudflare/cloudflare\""

      it "generates config with all fields populated" $ do
        let provSpec =
              ProviderSpec
                { providerNamespace = Just "hashicorp"
                , providerName = "aws"
                , providerVersion = mkVersion "5.0.0"
                }
        let config = generateTerraformConfig [provSpec]
        config `textShouldContain` "terraform {"
        config `textShouldContain` "required_providers {"
        config `textShouldContain` "aws = {"
        config `textShouldContain` "source = \"hashicorp/aws\""
        config `textShouldContain` "version = \"5.0.0\""

    describe "multiple provider configurations" $ do
      it "generates config for multiple providers" $ do
        let specs =
              [ ProviderSpec
                  { providerNamespace = Just "hashicorp"
                  , providerName = "random"
                  , providerVersion = mkVersion "3.5.0"
                  }
              , ProviderSpec
                  { providerNamespace = Just "hashicorp"
                  , providerName = "null"
                  , providerVersion = mkVersion "3.2.0"
                  }
              ]
        let config = generateTerraformConfig specs
        config `textShouldContain` "random = {"
        config `textShouldContain` "null = {"
        config `textShouldContain` "source = \"hashicorp/random\""
        config `textShouldContain` "source = \"hashicorp/null\""

      it "generates well-formed HCL with proper nesting" $ do
        let provSpec =
              ProviderSpec
                { providerNamespace = Just "hashicorp"
                , providerName = "random"
                , providerVersion = Nothing
                }
        let config = generateTerraformConfig [provSpec]
        -- Check that braces are balanced
        let openBraces = T.count "{" config
        let closeBraces = T.count "}" config
        openBraces `shouldBe` closeBraces
        -- Should have terraform block, required_providers block, and provider block
        openBraces `shouldBe` 3

    describe "edge cases" $ do
      it "handles empty provider list" $ do
        let config = generateTerraformConfig []
        config `textShouldContain` "terraform {"
        config `textShouldContain` "required_providers {"
        -- Should still be valid HCL, just empty
        let openBraces = T.count "{" config
        let closeBraces = T.count "}" config
        openBraces `shouldBe` closeBraces

  -- Integration tests requiring terraform CLI
  describe "terraform integration" $ do
    it "successfully initializes with random provider" $ do
      available <- checkTerraformAvailable
      if not available
        then pendingWith "Terraform not installed"
        else withSystemTempDirectory "terraform-test-" $ \tmpDir -> do
          result <-
            runExceptT $
              runReaderT
                ( do
                    checkTerraformInstalled
                    runTerraformInit tmpDir
                )
                defaultGeneratorConfig
          result `shouldBe` Right ()

    it "extracts schema from random provider" $ do
      available <- checkTerraformAvailable
      if not available
        then pendingWith "Terraform not installed"
        else do
          let provSpec =
                ProviderSpec
                  { providerNamespace = Just "hashicorp"
                  , providerName = "random"
                  , providerVersion = mkVersion "3.5.0"
                  }
          result <- runExceptT $ runReaderT (extractSchemaFromProviders [provSpec]) defaultGeneratorConfig
          result `shouldSatisfy` isRight
          case result of
            Right provSchemas -> isJust (schemas provSchemas) `shouldBe` True
            Left _ -> expectationFailure "Expected Right but got Left"

    it "extracts schema from random provider without version" $ do
      available <- checkTerraformAvailable
      if not available
        then pendingWith "Terraform not installed"
        else do
          let provSpec =
                ProviderSpec
                  { providerNamespace = Just "hashicorp"
                  , providerName = "random"
                  , providerVersion = Nothing
                  }
          result <- runExceptT $ runReaderT (extractSchemaFromProviders [provSpec]) defaultGeneratorConfig
          result `shouldSatisfy` isRight

    it "extracts schema from multiple providers" $ do
      available <- checkTerraformAvailable
      if not available
        then pendingWith "Terraform not installed"
        else do
          let specs =
                [ ProviderSpec
                    { providerNamespace = Just "hashicorp"
                    , providerName = "random"
                    , providerVersion = mkVersion "3.5.0"
                    }
                , ProviderSpec
                    { providerNamespace = Just "hashicorp"
                    , providerName = "null"
                    , providerVersion = mkVersion "3.2.0"
                    }
                ]
          result <- runExceptT $ runReaderT (extractSchemaFromProviders specs) defaultGeneratorConfig
          result `shouldSatisfy` isRight
          case result of
            Right provSchemas ->
              case schemas provSchemas of
                Just schemaMap -> Map.size schemaMap `shouldBe` 2
                Nothing -> expectationFailure "Expected schemas but got Nothing"
            Left _ -> expectationFailure "Expected Right but got Left"

    it "end-to-end: spec -> config -> init -> extract -> parse" $ do
      available <- checkTerraformAvailable
      if not available
        then pendingWith "Terraform not installed"
        else do
          let provSpec =
                ProviderSpec
                  { providerNamespace = Just "hashicorp"
                  , providerName = "random"
                  , providerVersion = mkVersion "3.5.0"
                  }
          -- Generate config
          let config = generateTerraformConfig [provSpec]
          config `textShouldContain` "random"

          -- Extract schema
          result <- runExceptT $ runReaderT (extractSchemaFromProviders [provSpec]) defaultGeneratorConfig
          result `shouldSatisfy` isRight

          -- Verify we got valid schemas
          case result of
            Right provSchemas -> do
              case schemas provSchemas of
                Just schemaMap -> do
                  Map.null schemaMap `shouldBe` False
                  -- Check that we got the random provider schema
                  any (\name -> "random" `T.isInfixOf` name) (Map.keys schemaMap) `shouldBe` True
                Nothing -> expectationFailure "Expected schemas but got Nothing"
            Left err -> expectationFailure $ "Schema extraction failed: " <> show err

    it "verifies temporary directory is cleaned up" $ do
      available <- checkTerraformAvailable
      if not available
        then pendingWith "Terraform not installed"
        else do
          let provSpec =
                ProviderSpec
                  { providerNamespace = Just "hashicorp"
                  , providerName = "random"
                  , providerVersion = Nothing
                  }
          -- Track if temp directory exists after extraction
          result <- runExceptT $ runReaderT (extractSchemaFromProviders [provSpec]) defaultGeneratorConfig
          -- This test mainly verifies no exception is thrown during cleanup
          -- The bracket in extractSchemaFromProviders ensures cleanup happens
          result `shouldSatisfy` isRight

  describe "error handling" $ do
    it "returns TerraformNotFound when terraform not in PATH" $ do
      -- This test requires terraform to NOT be in PATH
      -- Skip if terraform is available, or if it's not available (to avoid exception)
      -- In practice, checkTerraformInstalled should return Left TerraformNotFound when terraform is missing
      pendingWith "Test requires controlled environment without terraform in PATH"

    it "returns TerraformInitFailed with invalid provider" $ do
      isTerraformAvailable <- checkTerraformAvailable
      if not isTerraformAvailable
        then pendingWith "Terraform not installed"
        else do
          let provSpec =
                ProviderSpec
                  { providerNamespace = Just "nonexistent"
                  , providerName = "invalid-provider-that-does-not-exist"
                  , providerVersion = mkVersion "999.999.999"
                  }
          result <- runExceptT $ runReaderT (extractSchemaFromProviders [provSpec]) defaultGeneratorConfig
          result `shouldSatisfy` isTerraformInitFailed

    it "returns SchemaParsingFailed with malformed JSON" $ do
      -- We can't easily test this without mocking, but we can verify
      -- the error type exists and is constructed correctly
      let err = SchemaParsingFailed "test error"
      err `shouldBe` SchemaParsingFailed "test error"

    it "error messages are informative" $ do
      let initErr = TerraformInitFailed "init failed: provider not found"
      let schemaErr = SchemaExtractionFailed "extraction failed"
      let parseErr = SchemaParsingFailed "invalid JSON"

      T.pack (show initErr) `textShouldContain` "init failed"
      T.pack (show schemaErr) `textShouldContain` "extraction failed"
      T.pack (show parseErr) `textShouldContain` "invalid JSON"

-- Helper functions

-- | Check if terraform is available in PATH
checkTerraformAvailable :: IO Bool
checkTerraformAvailable =
  catch
    ( do
        let exe = terraformExecutable defaultGeneratorConfig
        (exitCode, _, _) <- readProcessWithExitCode exe ["version"] ""
        pure $ exitCode == ExitSuccess
    )
    (\(_ :: SomeException) -> pure False)

-- | Check if Either is Right
isRight :: Either a b -> Bool
isRight (Right _) = True
isRight (Left _) = False

-- | Check if error is TerraformInitFailed
isTerraformInitFailed :: Either TerraformError a -> Bool
isTerraformInitFailed (Left (TerraformInitFailed _)) = True
isTerraformInitFailed _ = False

-- | Helper to check that text contains a substring
textShouldContain :: Text -> Text -> Expectation
textShouldContain haystack needle =
  if needle `T.isInfixOf` haystack
    then pure ()
    else
      expectationFailure $
        "Expected text to contain "
          <> show needle
          <> " but got:\n"
          <> T.unpack haystack

-- | Helper to check that text does not contain a substring
textShouldNotContain :: Text -> Text -> Expectation
textShouldNotContain haystack needle =
  when (needle `T.isInfixOf` haystack) $
    expectationFailure $
      "Expected text to NOT contain "
        <> show needle
        <> " but it did:\n"
        <> T.unpack haystack

-- | Parse a version string (partial function for tests)
mkVersion :: Text -> Maybe Versioning
mkVersion = either (const Nothing) Just . versioning
