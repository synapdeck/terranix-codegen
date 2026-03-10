module TerranixCodegen.FileOrganizerSpec (spec) where

import Data.Map.Strict qualified as Map
import Data.Text qualified as T
import Data.Text.IO qualified as TIO
import Nix.TH (nix)
import System.Directory (createDirectoryIfMissing, doesDirectoryExist, doesFileExist)
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)
import Test.Hspec

import TerranixCodegen.FileOrganizer
import TerranixCodegen.ProviderSchema

-- | Helper to create an empty SchemaAttribute
emptyAttr :: SchemaAttribute
emptyAttr =
  SchemaAttribute
    { attributeType = Nothing
    , attributeNestedType = Nothing
    , attributeDescription = Nothing
    , attributeDescriptionKind = Nothing
    , attributeDeprecated = Nothing
    , attributeRequired = Nothing
    , attributeOptional = Nothing
    , attributeComputed = Nothing
    , attributeSensitive = Nothing
    , attributeWriteOnly = Nothing
    }

-- | Helper to create an empty SchemaBlock
emptyBlock :: SchemaBlock
emptyBlock =
  SchemaBlock
    { blockAttributes = Nothing
    , blockNestedBlocks = Nothing
    , blockDescription = Nothing
    , blockDescriptionKind = Nothing
    , blockDeprecated = Nothing
    }

-- | Helper to create a simple schema with one attribute
simpleSchema :: Schema
simpleSchema =
  Schema
    { schemaVersion = 0
    , schemaBlock =
        Just $
          emptyBlock
            { blockAttributes =
                Just $
                  Map.fromList
                    [ ("name", emptyAttr {attributeType = Just CtyString, attributeRequired = Just True})
                    ]
            }
    }

-- | Helper to create a minimal ProviderSchema
minimalProviderSchema :: ProviderSchema
minimalProviderSchema =
  ProviderSchema
    { configSchema = Nothing
    , resourceSchemas = Nothing
    , dataSourceSchemas = Nothing
    , ephemeralResourceSchemas = Nothing
    , actionSchemas = Nothing
    , functions = Nothing
    , resourceIdentitySchemas = Nothing
    , listResourceSchemas = Nothing
    }

spec :: Spec
spec = do
  describe "extractShortName" $ do
    it "extracts short name from OpenTofu registry path" $ do
      extractShortName "registry.opentofu.org/hashicorp/aws" `shouldBe` "aws"

    it "extracts short name from Terraform registry path" $ do
      extractShortName "registry.terraform.io/hashicorp/google" `shouldBe` "google"

    it "returns short name unchanged" $ do
      extractShortName "aws" `shouldBe` "aws"

  describe "stripProviderPrefix" $ do
    it "strips provider prefix from resource name" $ do
      stripProviderPrefix "aws" "aws_instance" `shouldBe` "instance"

    it "strips provider prefix from data source name" $ do
      stripProviderPrefix "aws" "aws_ami" `shouldBe` "ami"

    it "handles multi-part names" $ do
      stripProviderPrefix "google" "google_compute_instance" `shouldBe` "compute_instance"

    it "returns name as-is if no prefix match" $ do
      stripProviderPrefix "aws" "random_id" `shouldBe` "random_id"

    it "handles empty provider name" $ do
      stripProviderPrefix "" "aws_instance" `shouldBe` "aws_instance"

  describe "nixExprToText" $ do
    it "converts simple Nix expression to text" $ do
      let expr = [nix| { foo = "bar"; } |]
          text = nixExprToText expr
      -- The exact formatting may vary, but should contain the key parts
      text `shouldSatisfy` T.isInfixOf "foo"
      text `shouldSatisfy` T.isInfixOf "bar"

    it "converts mkOption expression to text" $ do
      let expr = [nix| mkOption { type = types.str; } |]
          text = nixExprToText expr
      text `shouldSatisfy` T.isInfixOf "mkOption"
      text `shouldSatisfy` T.isInfixOf "types.str"

  describe "organizeFiles" $ do
    it "creates directory structure for single provider" $ do
      withSystemTempDirectory "terranix-test" $ \tmpDir -> do
        let providerSchemas =
              ProviderSchemas
                { formatVersion = Just "1.0"
                , schemas =
                    Just $
                      Map.fromList
                        [
                          ( "registry.terraform.io/hashicorp/test"
                          , minimalProviderSchema
                              { resourceSchemas =
                                  Just $
                                    Map.fromList
                                      [("test_resource", simpleSchema)]
                              }
                          )
                        ]
                }

        organizeFiles tmpDir providerSchemas

        -- Check that provider directory was created
        doesDirectoryExist (tmpDir </> "registry.terraform.io/hashicorp/test") `shouldReturn` True

    it "creates top-level default.nix" $ do
      withSystemTempDirectory "terranix-test" $ \tmpDir -> do
        let providerSchemas =
              ProviderSchemas
                { formatVersion = Just "1.0"
                , schemas =
                    Just $
                      Map.fromList
                        [ ("test", minimalProviderSchema)
                        ]
                }

        organizeFiles tmpDir providerSchemas

        -- Check that top-level default.nix exists
        doesFileExist (tmpDir </> "default.nix") `shouldReturn` True

    it "handles provider with resources and data sources" $ do
      withSystemTempDirectory "terranix-test" $ \tmpDir -> do
        let providerSchemas =
              ProviderSchemas
                { formatVersion = Just "1.0"
                , schemas =
                    Just $
                      Map.fromList
                        [
                          ( "test"
                          , minimalProviderSchema
                              { resourceSchemas =
                                  Just $
                                    Map.fromList
                                      [("test_resource", simpleSchema)]
                              , dataSourceSchemas =
                                  Just $
                                    Map.fromList
                                      [("test_data", simpleSchema)]
                              }
                          )
                        ]
                }

        organizeFiles tmpDir providerSchemas

        let providerDir = tmpDir </> "test"

        -- Check directory structure
        doesDirectoryExist (providerDir </> "resources") `shouldReturn` True
        doesDirectoryExist (providerDir </> "data-sources") `shouldReturn` True

        -- Check resource files
        doesFileExist (providerDir </> "resources" </> "resource.nix") `shouldReturn` True
        doesFileExist (providerDir </> "resources" </> "default.nix") `shouldReturn` True

        -- Check data source files
        doesFileExist (providerDir </> "data-sources" </> "data.nix") `shouldReturn` True
        doesFileExist (providerDir </> "data-sources" </> "default.nix") `shouldReturn` True

  describe "organizeProvider" $ do
    it "creates all necessary directories" $ do
      withSystemTempDirectory "terranix-test" $ \tmpDir -> do
        let providerSchema =
              minimalProviderSchema
                { resourceSchemas =
                    Just $
                      Map.fromList
                        [("aws_instance", simpleSchema)]
                , dataSourceSchemas =
                    Just $
                      Map.fromList
                        [("aws_ami", simpleSchema)]
                }

        organizeProvider tmpDir "aws" providerSchema

        let providerDir = tmpDir </> "aws"
        doesDirectoryExist providerDir `shouldReturn` True
        doesDirectoryExist (providerDir </> "resources") `shouldReturn` True
        doesDirectoryExist (providerDir </> "data-sources") `shouldReturn` True

    it "creates provider.nix when config schema present" $ do
      withSystemTempDirectory "terranix-test" $ \tmpDir -> do
        let providerSchema =
              minimalProviderSchema
                { configSchema = Just simpleSchema
                }

        organizeProvider tmpDir "aws" providerSchema

        doesFileExist (tmpDir </> "aws" </> "provider.nix") `shouldReturn` True

    it "uses short provider name in attribute path for registry paths" $ do
      withSystemTempDirectory "terranix-test" $ \tmpDir -> do
        let providerSchema =
              minimalProviderSchema
                { configSchema = Just simpleSchema
                }

        organizeProvider tmpDir "registry.opentofu.org/hashicorp/aws" providerSchema

        let providerFile = tmpDir </> "registry.opentofu.org/hashicorp/aws" </> "provider.nix"
        doesFileExist providerFile `shouldReturn` True

        content <- TIO.readFile providerFile
        content `shouldSatisfy` T.isInfixOf "options.provider.aws"
        content `shouldNotSatisfy` T.isInfixOf "registry.opentofu.org"

    it "does not create provider.nix when config schema absent" $ do
      withSystemTempDirectory "terranix-test" $ \tmpDir -> do
        organizeProvider tmpDir "aws" minimalProviderSchema

        doesFileExist (tmpDir </> "aws" </> "provider.nix") `shouldReturn` False

  describe "generateResourcesDefault" $ do
    it "creates valid default.nix with imports" $ do
      withSystemTempDirectory "terranix-test" $ \tmpDir -> do
        createDirectoryIfMissing True tmpDir

        generateResourcesDefault tmpDir ["instance", "vpc", "subnet"]

        -- Check file exists
        let defaultFile = tmpDir </> "default.nix"
        doesFileExist defaultFile `shouldReturn` True

        -- Check content
        content <- TIO.readFile defaultFile
        content `shouldSatisfy` T.isInfixOf "imports"
        content `shouldSatisfy` T.isInfixOf "./instance.nix"
        content `shouldSatisfy` T.isInfixOf "./vpc.nix"
        content `shouldSatisfy` T.isInfixOf "./subnet.nix"

  describe "generateDataSourcesDefault" $ do
    it "creates valid default.nix with imports" $ do
      withSystemTempDirectory "terranix-test" $ \tmpDir -> do
        createDirectoryIfMissing True tmpDir

        generateDataSourcesDefault tmpDir ["ami", "availability_zones"]

        -- Check file exists
        let defaultFile = tmpDir </> "default.nix"
        doesFileExist defaultFile `shouldReturn` True

        -- Check content
        content <- TIO.readFile defaultFile
        content `shouldSatisfy` T.isInfixOf "imports"
        content `shouldSatisfy` T.isInfixOf "./ami.nix"
        content `shouldSatisfy` T.isInfixOf "./availability_zones.nix"

  describe "generateProviderDefault" $ do
    it "creates default.nix with all imports when everything present" $ do
      withSystemTempDirectory "terranix-test" $ \tmpDir -> do
        createDirectoryIfMissing True tmpDir

        generateProviderDefault tmpDir "aws" True True True

        -- Check file exists and content
        let defaultFile = tmpDir </> "default.nix"
        doesFileExist defaultFile `shouldReturn` True

        content <- TIO.readFile defaultFile
        content `shouldSatisfy` T.isInfixOf "./provider.nix"
        content `shouldSatisfy` T.isInfixOf "./resources"
        content `shouldSatisfy` T.isInfixOf "./data-sources"

    it "omits provider.nix when not present" $ do
      withSystemTempDirectory "terranix-test" $ \tmpDir -> do
        createDirectoryIfMissing True tmpDir

        generateProviderDefault tmpDir "aws" False True True

        content <- TIO.readFile (tmpDir </> "default.nix")
        content `shouldNotSatisfy` T.isInfixOf "./provider.nix"
        content `shouldSatisfy` T.isInfixOf "./resources"

    it "creates empty set when nothing present" $ do
      withSystemTempDirectory "terranix-test" $ \tmpDir -> do
        createDirectoryIfMissing True tmpDir

        generateProviderDefault tmpDir "aws" False False False

        content <- TIO.readFile (tmpDir </> "default.nix")
        T.strip content `shouldBe` "{}"

  describe "generateTopLevelDefault" $ do
    it "creates default.nix with provider imports" $ do
      withSystemTempDirectory "terranix-test" $ \tmpDir -> do
        generateTopLevelDefault tmpDir ["aws", "google", "azurerm"]

        -- Check file exists and content
        let defaultFile = tmpDir </> "default.nix"
        doesFileExist defaultFile `shouldReturn` True

        content <- TIO.readFile defaultFile
        content `shouldSatisfy` T.isInfixOf "./aws"
        content `shouldSatisfy` T.isInfixOf "./google"
        content `shouldSatisfy` T.isInfixOf "./azurerm"
