module TerranixCodegen.ModuleGeneratorSpec (spec) where

import Data.Map.Strict qualified as Map
import Nix.TH (nix)
import Test.Hspec

import TerranixCodegen.ModuleGenerator
import TerranixCodegen.ProviderSchema.Attribute
import TerranixCodegen.ProviderSchema.Block
import TerranixCodegen.ProviderSchema.CtyType
import TerranixCodegen.ProviderSchema.Schema
import TerranixCodegen.ProviderSchema.Types (SchemaNestingMode (..))
import TestUtils (shouldMapTo)

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

-- | Helper to create an empty Schema
emptySchema :: Schema
emptySchema =
  Schema
    { schemaVersion = 0
    , schemaBlock = Nothing
    }

spec :: Spec
spec = do
  describe "blockToSubmodule" $ do
    describe "simple blocks with only attributes" $ do
      it "converts block with single required attribute" $ do
        let block =
              emptyBlock
                { blockAttributes =
                    Just $
                      Map.fromList
                        [ ("name", emptyAttr {attributeType = Just CtyString, attributeRequired = Just True})
                        ]
                }
        blockToSubmodule block
          `shouldMapTo` [nix|
            types.submodule {
              options = {
                name = mkOption {
                  type = types.str;
                };
              };
            }
          |]

      it "converts block with multiple attributes" $ do
        let block =
              emptyBlock
                { blockAttributes =
                    Just $
                      Map.fromList
                        [ ("ami", emptyAttr {attributeType = Just CtyString, attributeRequired = Just True})
                        , ("count", emptyAttr {attributeType = Just CtyNumber, attributeOptional = Just True})
                        ]
                }
        blockToSubmodule block
          `shouldMapTo` [nix|
            types.submodule {
              options = {
                ami = mkOption {
                  type = types.str;
                };
                count = mkOption {
                  type = types.nullOr types.number;
                  default = null;
                };
              };
            }
          |]

      it "converts empty block" $ do
        let block = emptyBlock
        blockToSubmodule block
          `shouldMapTo` [nix|
            types.submodule {
              options = {};
            }
          |]

    describe "blocks with nested blocks" $ do
      it "converts block with single nesting mode nested block" $ do
        let nestedBlock =
              emptyBlock
                { blockAttributes =
                    Just $
                      Map.fromList
                        [ ("enabled", emptyAttr {attributeType = Just CtyBool, attributeRequired = Just True})
                        ]
                }
            blockType =
              SchemaBlockType
                { blockTypeNestingMode = Just NestingSingle
                , blockTypeBlock = Just nestedBlock
                , blockTypeMinItems = Nothing
                , blockTypeMaxItems = Nothing
                }
            block =
              emptyBlock
                { blockNestedBlocks =
                    Just $
                      Map.fromList
                        [("monitoring", blockType)]
                }
        blockToSubmodule block
          `shouldMapTo` [nix|
            types.submodule {
              options = {
                monitoring = mkOption {
                  type = types.submodule {
                    options = {
                      enabled = mkOption {
                        type = types.bool;
                      };
                    };
                  };
                  default = null;
                };
              };
            }
          |]

      it "converts block with list nesting mode nested block" $ do
        let nestedBlock =
              emptyBlock
                { blockAttributes =
                    Just $
                      Map.fromList
                        [ ("device_name", emptyAttr {attributeType = Just CtyString, attributeRequired = Just True})
                        ]
                }
            blockType =
              SchemaBlockType
                { blockTypeNestingMode = Just NestingList
                , blockTypeBlock = Just nestedBlock
                , blockTypeMinItems = Nothing
                , blockTypeMaxItems = Nothing
                }
            block =
              emptyBlock
                { blockNestedBlocks =
                    Just $
                      Map.fromList
                        [("ebs_block_device", blockType)]
                }
        blockToSubmodule block
          `shouldMapTo` [nix|
            types.submodule {
              options = {
                ebs_block_device = mkOption {
                  type = types.listOf (types.submodule {
                    options = {
                      device_name = mkOption {
                        type = types.str;
                      };
                    };
                  });
                  default = [];
                };
              };
            }
          |]

      it "converts block with map nesting mode nested block" $ do
        let nestedBlock =
              emptyBlock
                { blockAttributes =
                    Just $
                      Map.fromList
                        [ ("value", emptyAttr {attributeType = Just CtyString, attributeRequired = Just True})
                        ]
                }
            blockType =
              SchemaBlockType
                { blockTypeNestingMode = Just NestingMap
                , blockTypeBlock = Just nestedBlock
                , blockTypeMinItems = Nothing
                , blockTypeMaxItems = Nothing
                }
            block =
              emptyBlock
                { blockNestedBlocks =
                    Just $
                      Map.fromList
                        [("env", blockType)]
                }
        blockToSubmodule block
          `shouldMapTo` [nix|
            types.submodule {
              options = {
                env = mkOption {
                  type = types.attrsOf (types.submodule {
                    options = {
                      value = mkOption {
                        type = types.str;
                      };
                    };
                  });
                  default = {};
                };
              };
            }
          |]

      it "converts block with both attributes and nested blocks" $ do
        let nestedBlock =
              emptyBlock
                { blockAttributes =
                    Just $
                      Map.fromList
                        [ ("size", emptyAttr {attributeType = Just CtyNumber, attributeRequired = Just True})
                        ]
                }
            blockType =
              SchemaBlockType
                { blockTypeNestingMode = Just NestingSingle
                , blockTypeBlock = Just nestedBlock
                , blockTypeMinItems = Nothing
                , blockTypeMaxItems = Nothing
                }
            block =
              emptyBlock
                { blockAttributes =
                    Just $
                      Map.fromList
                        [("ami", emptyAttr {attributeType = Just CtyString, attributeRequired = Just True})]
                , blockNestedBlocks =
                    Just $
                      Map.fromList
                        [("root_block_device", blockType)]
                }
        blockToSubmodule block
          `shouldMapTo` [nix|
            types.submodule {
              options = {
                ami = mkOption {
                  type = types.str;
                };
                root_block_device = mkOption {
                  type = types.submodule {
                    options = {
                      size = mkOption {
                        type = types.number;
                      };
                    };
                  };
                  default = null;
                };
              };
            }
          |]

  describe "generateResourceModule" $ do
    it "generates complete resource module with simple attributes" $ do
      let schema =
            emptySchema
              { schemaBlock =
                  Just $
                    emptyBlock
                      { blockAttributes =
                          Just $
                            Map.fromList
                              [ ("ami", emptyAttr {attributeType = Just CtyString, attributeRequired = Just True})
                              , ("instance_type", emptyAttr {attributeType = Just CtyString, attributeRequired = Just True})
                              ]
                      }
              }
      generateResourceModule "aws" "aws_instance" schema
        `shouldMapTo` [nix|
          { lib, ... }:
          with lib;
          {
            options.resource.aws_instance = mkOption {
              type = types.attrsOf (types.submodule {
                options = {
                  ami = mkOption {
                    type = types.str;
                  };
                  instance_type = mkOption {
                    type = types.str;
                  };
                };
              });
              default = {};
              description = "Instances of aws_instance";
            };
          }
        |]

    it "generates resource module with nested blocks" $ do
      let rootDeviceBlock =
            emptyBlock
              { blockAttributes =
                  Just $
                    Map.fromList
                      [("volume_size", emptyAttr {attributeType = Just CtyNumber, attributeOptional = Just True})]
              }
          rootDeviceBlockType =
            SchemaBlockType
              { blockTypeNestingMode = Just NestingSingle
              , blockTypeBlock = Just rootDeviceBlock
              , blockTypeMinItems = Nothing
              , blockTypeMaxItems = Nothing
              }
          schema =
            emptySchema
              { schemaBlock =
                  Just $
                    emptyBlock
                      { blockAttributes =
                          Just $
                            Map.fromList
                              [("ami", emptyAttr {attributeType = Just CtyString, attributeRequired = Just True})]
                      , blockNestedBlocks =
                          Just $
                            Map.fromList
                              [("root_block_device", rootDeviceBlockType)]
                      }
              }
      generateResourceModule "aws" "aws_instance" schema
        `shouldMapTo` [nix|
          { lib, ... }:
          with lib;
          {
            options.resource.aws_instance = mkOption {
              type = types.attrsOf (types.submodule {
                options = {
                  ami = mkOption {
                    type = types.str;
                  };
                  root_block_device = mkOption {
                    type = types.submodule {
                      options = {
                        volume_size = mkOption {
                          type = types.nullOr types.number;
                          default = null;
                        };
                      };
                    };
                    default = null;
                  };
                };
              });
              default = {};
              description = "Instances of aws_instance";
            };
          }
        |]

  describe "generateDataSourceModule" $ do
    it "generates complete data source module" $ do
      let schema =
            emptySchema
              { schemaBlock =
                  Just $
                    emptyBlock
                      { blockAttributes =
                          Just $
                            Map.fromList
                              [("name", emptyAttr {attributeType = Just CtyString, attributeRequired = Just True})]
                      }
              }
      generateDataSourceModule "aws" "aws_ami" schema
        `shouldMapTo` [nix|
          { lib, ... }:
          with lib;
          {
            options.data.aws_ami = mkOption {
              type = types.attrsOf (types.submodule {
                options = {
                  name = mkOption {
                    type = types.str;
                  };
                };
              });
              default = {};
              description = "Instances of aws_ami data source";
            };
          }
        |]

  describe "generateProviderModule" $ do
    it "generates complete provider configuration module" $ do
      let schema =
            emptySchema
              { schemaBlock =
                  Just $
                    emptyBlock
                      { blockAttributes =
                          Just $
                            Map.fromList
                              [ ("region", emptyAttr {attributeType = Just CtyString, attributeRequired = Just True})
                              , ("access_key", emptyAttr {attributeType = Just CtyString, attributeOptional = Just True})
                              ]
                      }
              }
      generateProviderModule "aws" schema
        `shouldMapTo` [nix|
          { lib, ... }:
          with lib;
          {
            options.provider.aws = mkOption {
              type = types.attrsOf (types.submodule {
                options = {
                  access_key = mkOption {
                    type = types.nullOr types.str;
                    default = null;
                  };
                  region = mkOption {
                    type = types.str;
                  };
                };
              });
              default = {};
              description = "aws provider configuration";
            };
          }
        |]
