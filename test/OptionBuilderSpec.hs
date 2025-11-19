module OptionBuilderSpec (spec) where

import Nix.TH (nix)
import Test.Hspec

import TerranixCodegen.OptionBuilder
import TerranixCodegen.ProviderSchema.Attribute
import TerranixCodegen.ProviderSchema.CtyType
import TestUtils (shouldMapTo)

-- | Helper to create a minimal SchemaAttribute
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

spec :: Spec
spec = do
  describe "buildOption" $ do
    describe "required attributes" $ do
      it "builds mkOption for required string attribute" $ do
        let attr =
              emptyAttr
                { attributeType = Just CtyString
                , attributeDescription = Just "AMI to use for the instance"
                , attributeRequired = Just True
                }
        buildOption "ami" attr
          `shouldMapTo` [nix|
            mkOption {
              type = types.str;
              description = "AMI to use for the instance";
            }
          |]

      it "builds mkOption for required number attribute" $ do
        let attr =
              emptyAttr
                { attributeType = Just CtyNumber
                , attributeDescription = Just "Instance count"
                , attributeRequired = Just True
                }
        buildOption "count" attr
          `shouldMapTo` [nix|
            mkOption {
              type = types.number;
              description = "Instance count";
            }
          |]

      it "builds mkOption for required boolean attribute" $ do
        let attr =
              emptyAttr
                { attributeType = Just CtyBool
                , attributeDescription = Just "Enable monitoring"
                , attributeRequired = Just True
                }
        buildOption "monitoring" attr
          `shouldMapTo` [nix|
            mkOption {
              type = types.bool;
              description = "Enable monitoring";
            }
          |]

    describe "optional attributes" $ do
      it "builds mkOption for optional string with default null" $ do
        let attr =
              emptyAttr
                { attributeType = Just CtyString
                , attributeDescription = Just "Availability zone"
                , attributeOptional = Just True
                }
        buildOption "availability_zone" attr
          `shouldMapTo` [nix|
            mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Availability zone";
            }
          |]

      it "builds mkOption for optional number with default null" $ do
        let attr =
              emptyAttr
                { attributeType = Just CtyNumber
                , attributeDescription = Just "CPU credits"
                , attributeOptional = Just True
                }
        buildOption "cpu_credits" attr
          `shouldMapTo` [nix|
            mkOption {
              type = types.nullOr types.number;
              default = null;
              description = "CPU credits";
            }
          |]

      it "builds mkOption for optional list type" $ do
        let attr =
              emptyAttr
                { attributeType = Just (CtyList CtyString)
                , attributeDescription = Just "Security group IDs"
                , attributeOptional = Just True
                }
        buildOption "security_groups" attr
          `shouldMapTo` [nix|
            mkOption {
              type = types.nullOr (types.listOf types.str);
              default = null;
              description = "Security group IDs";
            }
          |]

      it "builds mkOption for optional map type" $ do
        let attr =
              emptyAttr
                { attributeType = Just (CtyMap CtyString)
                , attributeDescription = Just "Resource tags"
                , attributeOptional = Just True
                }
        buildOption "tags" attr
          `shouldMapTo` [nix|
            mkOption {
              type = types.nullOr (types.attrsOf types.str);
              default = null;
              description = "Resource tags";
            }
          |]

    describe "computed attributes" $ do
      it "builds mkOption for computed-only attribute with readOnly flag" $ do
        let attr =
              emptyAttr
                { attributeType = Just CtyString
                , attributeDescription = Just "Instance ID"
                , attributeComputed = Just True
                }
        buildOption "id" attr
          `shouldMapTo` [nix|
            mkOption {
              type = types.nullOr types.str;
              default = null;
              description = ''
                Instance ID

                This value is computed by the provider.
              '';
              readOnly = true;
            }
          |]

      it "builds mkOption for optional+computed attribute without readOnly" $ do
        let attr =
              emptyAttr
                { attributeType = Just CtyString
                , attributeDescription = Just "Public IP address"
                , attributeOptional = Just True
                , attributeComputed = Just True
                }
        buildOption "public_ip" attr
          `shouldMapTo` [nix|
            mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Public IP address";
            }
          |]

    describe "deprecated attributes" $ do
      it "adds deprecation warning to description" $ do
        let attr =
              emptyAttr
                { attributeType = Just CtyString
                , attributeDescription = Just "Old availability zone field"
                , attributeOptional = Just True
                , attributeDeprecated = Just True
                }
        buildOption "availability_zone_old" attr
          `shouldMapTo` [nix|
            mkOption {
              type = types.nullOr types.str;
              default = null;
              description = ''
                Old availability zone field

                DEPRECATED: This attribute is deprecated and may be removed in a future version.
              '';
            }
          |]

    describe "sensitive attributes" $ do
      it "adds sensitivity warning to description" $ do
        let attr =
              emptyAttr
                { attributeType = Just CtyString
                , attributeDescription = Just "Database password"
                , attributeRequired = Just True
                , attributeSensitive = Just True
                }
        buildOption "password" attr
          `shouldMapTo` [nix|
            mkOption {
              type = types.str;
              description = ''
                Database password

                WARNING: This attribute contains sensitive information and will not be displayed in logs.
              '';
            }
          |]

    describe "write-only attributes" $ do
      it "adds write-only note to description" $ do
        let attr =
              emptyAttr
                { attributeType = Just CtyString
                , attributeDescription = Just "Temporary token"
                , attributeRequired = Just True
                , attributeWriteOnly = Just True
                }
        buildOption "token" attr
          `shouldMapTo` [nix|
            mkOption {
              type = types.str;
              description = ''
                Temporary token

                NOTE: This attribute is write-only and will not be persisted in the Terraform state.
              '';
            }
          |]

    describe "combined metadata" $ do
      it "combines multiple metadata fields in description" $ do
        let attr =
              emptyAttr
                { attributeType = Just CtyString
                , attributeDescription = Just "Legacy password field"
                , attributeOptional = Just True
                , attributeDeprecated = Just True
                , attributeSensitive = Just True
                }
        buildOption "old_password" attr
          `shouldMapTo` [nix|
            mkOption {
              type = types.nullOr types.str;
              default = null;
              description = ''
                Legacy password field

                DEPRECATED: This attribute is deprecated and may be removed in a future version.

                WARNING: This attribute contains sensitive information and will not be displayed in logs.
              '';
            }
          |]

      it "handles all metadata flags together" $ do
        let attr =
              emptyAttr
                { attributeType = Just CtyString
                , attributeDescription = Just "Complex attribute"
                , attributeOptional = Just True
                , attributeDeprecated = Just True
                , attributeSensitive = Just True
                , attributeWriteOnly = Just True
                }
        buildOption "complex" attr
          `shouldMapTo` [nix|
            mkOption {
              type = types.nullOr types.str;
              default = null;
              description = ''
                Complex attribute

                DEPRECATED: This attribute is deprecated and may be removed in a future version.

                WARNING: This attribute contains sensitive information and will not be displayed in logs.

                NOTE: This attribute is write-only and will not be persisted in the Terraform state.
              '';
            }
          |]

    describe "attributes without descriptions" $ do
      it "builds mkOption without description field when not provided" $ do
        let attr =
              emptyAttr
                { attributeType = Just CtyString
                , attributeRequired = Just True
                }
        buildOption "name" attr
          `shouldMapTo` [nix|
            mkOption {
              type = types.str;
            }
          |]

      it "still adds metadata notes even without base description" $ do
        let attr =
              emptyAttr
                { attributeType = Just CtyString
                , attributeOptional = Just True
                , attributeDeprecated = Just True
                }
        buildOption "field" attr
          `shouldMapTo` [nix|
            mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "DEPRECATED: This attribute is deprecated and may be removed in a future version.";
            }
          |]

    describe "complex types" $ do
      it "handles list of strings" $ do
        let attr =
              emptyAttr
                { attributeType = Just (CtyList CtyString)
                , attributeDescription = Just "List of subnet IDs"
                , attributeRequired = Just True
                }
        buildOption "subnet_ids" attr
          `shouldMapTo` [nix|
            mkOption {
              type = types.listOf types.str;
              description = "List of subnet IDs";
            }
          |]

      it "handles map of numbers" $ do
        let attr =
              emptyAttr
                { attributeType = Just (CtyMap CtyNumber)
                , attributeDescription = Just "Port mappings"
                , attributeOptional = Just True
                }
        buildOption "ports" attr
          `shouldMapTo` [nix|
            mkOption {
              type = types.nullOr (types.attrsOf types.number);
              default = null;
              description = "Port mappings";
            }
          |]

      it "handles set of booleans" $ do
        let attr =
              emptyAttr
                { attributeType = Just (CtySet CtyBool)
                , attributeDescription = Just "Feature flags"
                , attributeRequired = Just True
                }
        buildOption "features" attr
          `shouldMapTo` [nix|
            mkOption {
              type = types.listOf types.bool;
              description = "Feature flags";
            }
          |]

    describe "edge cases" $ do
      it "handles attribute with no type (defaults to types.anything)" $ do
        let attr =
              emptyAttr
                { attributeDescription = Just "Unknown type"
                , attributeRequired = Just True
                }
        buildOption "unknown" attr
          `shouldMapTo` [nix|
            mkOption {
              type = types.anything;
              description = "Unknown type";
            }
          |]

      it "handles CtyDynamic type" $ do
        let attr =
              emptyAttr
                { attributeType = Just CtyDynamic
                , attributeDescription = Just "Dynamic value"
                , attributeOptional = Just True
                }
        buildOption "dynamic" attr
          `shouldMapTo` [nix|
            mkOption {
              type = types.nullOr types.anything;
              default = null;
              description = "Dynamic value";
            }
          |]

    describe "real-world examples" $ do
      it "handles AWS instance AMI attribute" $ do
        let attr =
              emptyAttr
                { attributeType = Just CtyString
                , attributeDescription = Just "AMI to use for the instance"
                , attributeRequired = Just True
                }
        buildOption "ami" attr
          `shouldMapTo` [nix|
            mkOption {
              type = types.str;
              description = "AMI to use for the instance";
            }
          |]

      it "handles AWS instance tags attribute" $ do
        let attr =
              emptyAttr
                { attributeType = Just (CtyMap CtyString)
                , attributeDescription = Just "A map of tags to assign to the resource"
                , attributeOptional = Just True
                }
        buildOption "tags" attr
          `shouldMapTo` [nix|
            mkOption {
              type = types.nullOr (types.attrsOf types.str);
              default = null;
              description = "A map of tags to assign to the resource";
            }
          |]

      it "handles AWS instance ARN (computed)" $ do
        let attr =
              emptyAttr
                { attributeType = Just CtyString
                , attributeDescription = Just "ARN of the instance"
                , attributeComputed = Just True
                }
        buildOption "arn" attr
          `shouldMapTo` [nix|
            mkOption {
              type = types.nullOr types.str;
              default = null;
              description = ''
                ARN of the instance

                This value is computed by the provider.
              '';
              readOnly = true;
            }
          |]
