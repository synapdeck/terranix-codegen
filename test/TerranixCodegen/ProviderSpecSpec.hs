-- | Tests for Terraform provider specification parsing and formatting
module TerranixCodegen.ProviderSpecSpec (spec) where

import Data.Aeson (decode, encode)
import Data.ByteString.Lazy.Char8 qualified as BL
import Data.Text (Text)
import Data.Text qualified as T
import Data.Versions (Versioning, versioning)
import TerranixCodegen.ProviderSpec
import Test.Hspec

spec :: Spec
spec = do
  describe "parseProviderSpec" $ do
    describe "valid formats" $ do
      it "parses namespace/name:version format" $ do
        parseProviderSpec "hashicorp/aws:5.0.0"
          `shouldBe` Right
            ( ProviderSpec
                { providerNamespace = Just "hashicorp"
                , providerName = "aws"
                , providerVersion = mkVersion "5.0.0"
                }
            )

      it "parses namespace/name format (latest version)" $ do
        parseProviderSpec "hashicorp/aws"
          `shouldBe` Right
            ( ProviderSpec
                { providerNamespace = Just "hashicorp"
                , providerName = "aws"
                , providerVersion = Nothing
                }
            )

      it "parses name:version format (no namespace)" $ do
        parseProviderSpec "aws:5.0.0"
          `shouldBe` Right
            ( ProviderSpec
                { providerNamespace = Nothing
                , providerName = "aws"
                , providerVersion = mkVersion "5.0.0"
                }
            )

      it "parses name format (no namespace, latest version)" $ do
        parseProviderSpec "aws"
          `shouldBe` Right
            ( ProviderSpec
                { providerNamespace = Nothing
                , providerName = "aws"
                , providerVersion = Nothing
                }
            )

      it "parses names with hyphens" $ do
        parseProviderSpec "terraform-providers/google-beta:4.0.0"
          `shouldBe` Right
            ( ProviderSpec
                { providerNamespace = Just "terraform-providers"
                , providerName = "google-beta"
                , providerVersion = mkVersion "4.0.0"
                }
            )

      it "parses names with underscores" $ do
        parseProviderSpec "custom_org/my_provider:1.2.3"
          `shouldBe` Right
            ( ProviderSpec
                { providerNamespace = Just "custom_org"
                , providerName = "my_provider"
                , providerVersion = mkVersion "1.2.3"
                }
            )

      it "parses names with numbers" $ do
        parseProviderSpec "org123/provider456:7.8.9"
          `shouldBe` Right
            ( ProviderSpec
                { providerNamespace = Just "org123"
                , providerName = "provider456"
                , providerVersion = mkVersion "7.8.9"
                }
            )

      it "parses complex semver versions" $ do
        parseProviderSpec "cloudflare/cloudflare:4.0.0-rc1"
          `shouldBe` Right
            ( ProviderSpec
                { providerNamespace = Just "cloudflare"
                , providerName = "cloudflare"
                , providerVersion = mkVersion "4.0.0-rc1"
                }
            )

      it "parses versions with build metadata" $ do
        parseProviderSpec "vendor/tool:1.2.3+build.123"
          `shouldBe` Right
            ( ProviderSpec
                { providerNamespace = Just "vendor"
                , providerName = "tool"
                , providerVersion = mkVersion "1.2.3+build.123"
                }
            )

      it "parses single character names" $ do
        parseProviderSpec "a/b:1.0.0"
          `shouldBe` Right
            ( ProviderSpec
                { providerNamespace = Just "a"
                , providerName = "b"
                , providerVersion = mkVersion "1.0.0"
                }
            )

      it "parses long provider names" $ do
        let longName = "very-long-provider-name-with-many-segments" :: Text
        parseProviderSpec (T.unpack $ "hashicorp/" <> longName <> ":1.0.0")
          `shouldBe` Right
            ( ProviderSpec
                { providerNamespace = Just "hashicorp"
                , providerName = longName
                , providerVersion = mkVersion "1.0.0"
                }
            )

      it "parses mixed case identifiers" $ do
        parseProviderSpec "HashiCorp/AWS:5.0.0"
          `shouldBe` Right
            ( ProviderSpec
                { providerNamespace = Just "HashiCorp"
                , providerName = "AWS"
                , providerVersion = mkVersion "5.0.0"
                }
            )

    describe "error cases" $ do
      it "rejects empty string" $ do
        parseProviderSpec "" `shouldSatisfy` isLeft

      it "rejects string with only namespace and slash" $ do
        parseProviderSpec "hashicorp/" `shouldSatisfy` isLeft

      it "rejects string with only colon" $ do
        parseProviderSpec ":" `shouldSatisfy` isLeft

      it "rejects multiple slashes" $ do
        parseProviderSpec "hash/corp/aws:5.0.0" `shouldSatisfy` isLeft

      it "rejects names starting with hyphen" $ do
        parseProviderSpec "-aws:5.0.0" `shouldSatisfy` isLeft

      it "rejects names with spaces" $ do
        parseProviderSpec "hash corp/aws:5.0.0" `shouldSatisfy` isLeft

      it "rejects names with special characters" $ do
        parseProviderSpec "hash@corp/aws:5.0.0" `shouldSatisfy` isLeft

      it "rejects trailing content after version" $ do
        parseProviderSpec "hashicorp/aws:5.0.0 extra" `shouldSatisfy` isLeft

  describe "formatProviderSpec" $ do
    it "formats spec with all fields" $ do
      formatProviderSpec
        ( ProviderSpec
            { providerNamespace = Just "hashicorp"
            , providerName = "aws"
            , providerVersion = mkVersion "5.0.0"
            }
        )
        `shouldBe` "hashicorp/aws:5.0.0"

    it "formats spec without namespace" $ do
      formatProviderSpec
        ( ProviderSpec
            { providerNamespace = Nothing
            , providerName = "aws"
            , providerVersion = mkVersion "5.0.0"
            }
        )
        `shouldBe` "aws:5.0.0"

    it "formats spec without version" $ do
      formatProviderSpec
        ( ProviderSpec
            { providerNamespace = Just "hashicorp"
            , providerName = "aws"
            , providerVersion = Nothing
            }
        )
        `shouldBe` "hashicorp/aws"

    it "formats spec with only name" $ do
      formatProviderSpec
        ( ProviderSpec
            { providerNamespace = Nothing
            , providerName = "aws"
            , providerVersion = Nothing
            }
        )
        `shouldBe` "aws"

    it "round-trips: parse then format equals original (with namespace and version)" $ do
      let original = "hashicorp/aws:5.0.0"
      case parseProviderSpec original of
        Left err -> expectationFailure $ "Parse failed: " <> err
        Right parsed -> formatProviderSpec parsed `shouldBe` T.pack original

    it "round-trips: parse then format equals original (name only)" $ do
      let original = "aws"
      case parseProviderSpec original of
        Left err -> expectationFailure $ "Parse failed: " <> err
        Right parsed -> formatProviderSpec parsed `shouldBe` T.pack original

    it "round-trips: parse then format equals original (namespace, no version)" $ do
      let original = "hashicorp/aws"
      case parseProviderSpec original of
        Left err -> expectationFailure $ "Parse failed: " <> err
        Right parsed -> formatProviderSpec parsed `shouldBe` T.pack original

  describe "JSON serialization" $ do
    it "round-trips ToJSON/FromJSON with all fields" $ do
      let providerSpec =
            ProviderSpec
              { providerNamespace = Just "hashicorp"
              , providerName = "aws"
              , providerVersion = mkVersion "5.0.0"
              }
      decode (encode providerSpec) `shouldBe` Just providerSpec

    it "round-trips ToJSON/FromJSON without namespace" $ do
      let providerSpec =
            ProviderSpec
              { providerNamespace = Nothing
              , providerName = "aws"
              , providerVersion = mkVersion "5.0.0"
              }
      decode (encode providerSpec) `shouldBe` Just providerSpec

    it "round-trips ToJSON/FromJSON without version" $ do
      let providerSpec =
            ProviderSpec
              { providerNamespace = Just "hashicorp"
              , providerName = "aws"
              , providerVersion = Nothing
              }
      decode (encode providerSpec) `shouldBe` Just providerSpec

    it "parses valid JSON string" $ do
      let json = "\"hashicorp/aws:5.0.0\""
      decode json
        `shouldBe` Just
          ( ProviderSpec
              { providerNamespace = Just "hashicorp"
              , providerName = "aws"
              , providerVersion = mkVersion "5.0.0"
              }
          )

    it "rejects invalid JSON string" $ do
      let json = BL.pack "\"invalid spec with spaces:1.0.0\""
      (decode json :: Maybe ProviderSpec) `shouldBe` Nothing

    it "serializes to formatted string" $ do
      let providerSpec =
            ProviderSpec
              { providerNamespace = Just "hashicorp"
              , providerName = "aws"
              , providerVersion = mkVersion "5.0.0"
              }
      encode providerSpec `shouldBe` "\"hashicorp/aws:5.0.0\""

-- Helper functions

-- | Check if Either is Left
isLeft :: Either a b -> Bool
isLeft (Left _) = True
isLeft (Right _) = False

-- | Parse a version string (partial function for tests)
mkVersion :: Text -> Maybe Versioning
mkVersion = either (const Nothing) Just . versioning
