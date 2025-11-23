module TerranixCodegen.TypeMapperSpec (spec) where

import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Nix.TH (nix)
import Test.Hspec

import TerranixCodegen.ProviderSchema.CtyType
import TerranixCodegen.TypeMapper
import TestUtils (shouldMapTo)

spec :: Spec
spec = do
  describe "mapCtyTypeToNix" $ do
    describe "primitive types" $ do
      it "maps CtyBool to types.bool" $ do
        mapCtyTypeToNix CtyBool `shouldMapTo` [nix| types.bool |]

      it "maps CtyNumber to types.number" $ do
        mapCtyTypeToNix CtyNumber `shouldMapTo` [nix| types.number |]

      it "maps CtyString to types.str" $ do
        mapCtyTypeToNix CtyString `shouldMapTo` [nix| types.str |]

      it "maps CtyDynamic to types.anything" $ do
        mapCtyTypeToNix CtyDynamic `shouldMapTo` [nix| types.anything |]

    describe "collection types (homogeneous)" $ do
      it "maps CtyList CtyString to types.listOf types.str" $ do
        mapCtyTypeToNix (CtyList CtyString)
          `shouldMapTo` [nix| types.listOf types.str |]

      it "maps CtySet CtyNumber to types.listOf types.number" $ do
        mapCtyTypeToNix (CtySet CtyNumber)
          `shouldMapTo` [nix| types.listOf types.number |]

      it "maps CtyMap CtyBool to types.attrsOf types.bool" $ do
        mapCtyTypeToNix (CtyMap CtyBool)
          `shouldMapTo` [nix| types.attrsOf types.bool |]

    describe "nested collection types" $ do
      it "maps nested lists correctly" $ do
        mapCtyTypeToNix (CtyList (CtyList CtyString))
          `shouldMapTo` [nix| types.listOf (types.listOf types.str) |]

      it "maps map of lists correctly" $ do
        mapCtyTypeToNix (CtyMap (CtyList CtyNumber))
          `shouldMapTo` [nix| types.attrsOf (types.listOf types.number) |]

    describe "object types" $ do
      it "maps simple object with all required fields" $ do
        let objType =
              CtyObject
                (Map.fromList [("host", CtyString), ("port", CtyNumber)])
                Set.empty
        mapCtyTypeToNix objType
          `shouldMapTo` [nix|
            types.submodule {
              options = {
                host = mkOption { type = types.str; };
                port = mkOption { type = types.number; };
              };
            }
          |]

      it "maps object with optional fields using types.nullOr" $ do
        let objType =
              CtyObject
                (Map.fromList [("host", CtyString), ("timeout", CtyNumber)])
                (Set.fromList ["timeout"])
        mapCtyTypeToNix objType
          `shouldMapTo` [nix|
            types.submodule {
              options = {
                host = mkOption { type = types.str; };
                timeout = mkOption { type = types.nullOr types.number; };
              };
            }
          |]

      it "maps nested objects correctly" $ do
        let innerObj =
              CtyObject
                (Map.fromList [("subnet_id", CtyString), ("private_ip", CtyString)])
                (Set.fromList ["private_ip"])
            outerObj =
              CtyObject
                (Map.fromList [("name", CtyString), ("network_config", innerObj)])
                Set.empty
        mapCtyTypeToNix outerObj
          `shouldMapTo` [nix|
            types.submodule {
              options = {
                name = mkOption { type = types.str; };
                network_config = mkOption {
                  type = types.submodule {
                    options = {
                      private_ip = mkOption { type = types.nullOr types.str; };
                      subnet_id = mkOption { type = types.str; };
                    };
                  };
                };
              };
            }
          |]

    describe "tuple types" $ do
      it "maps simple tuple to types.tupleOf with element types" $ do
        let tupleType = CtyTuple [CtyString, CtyNumber, CtyBool]
        mapCtyTypeToNix tupleType
          `shouldMapTo` [nix| types.tupleOf [types.str types.number types.bool] |]

      it "maps empty tuple" $ do
        let tupleType = CtyTuple []
        mapCtyTypeToNix tupleType
          `shouldMapTo` [nix| types.tupleOf [] |]

      it "maps single-element tuple" $ do
        let tupleType = CtyTuple [CtyString]
        mapCtyTypeToNix tupleType
          `shouldMapTo` [nix| types.tupleOf [types.str] |]

      it "maps tuple with nested collection types" $ do
        let tupleType = CtyTuple [CtyList CtyString, CtyMap CtyNumber]
        mapCtyTypeToNix tupleType
          `shouldMapTo` [nix| types.tupleOf [(types.listOf types.str) (types.attrsOf types.number)] |]

      it "maps tuple containing object type" $ do
        let objType =
              CtyObject
                (Map.fromList [("name", CtyString)])
                Set.empty
            tupleType = CtyTuple [CtyString, objType]
        mapCtyTypeToNix tupleType
          `shouldMapTo` [nix|
            types.tupleOf [
              types.str
              (types.submodule {
                options = {
                  name = mkOption { type = types.str; };
                };
              })
            ]
          |]

      it "maps nested tuples" $ do
        let innerTuple = CtyTuple [CtyString, CtyNumber]
            outerTuple = CtyTuple [innerTuple, CtyBool]
        mapCtyTypeToNix outerTuple
          `shouldMapTo` [nix|
            types.tupleOf [
              (types.tupleOf [types.str types.number])
              types.bool
            ]
          |]

  describe "mapCtyTypeToNixWithOptional" $ do
    it "wraps required types without modification" $ do
      mapCtyTypeToNixWithOptional False CtyString
        `shouldMapTo` [nix| types.str |]

    it "wraps optional types with types.nullOr" $ do
      mapCtyTypeToNixWithOptional True CtyString
        `shouldMapTo` [nix| types.nullOr types.str |]

    it "wraps optional complex types correctly" $ do
      mapCtyTypeToNixWithOptional True (CtyList CtyString)
        `shouldMapTo` [nix| types.nullOr (types.listOf types.str) |]

  describe "complex real-world examples from documentation" $ do
    it "handles AWS instance-like schema (Example 8 from examples.md)" $ do
      let objType =
            CtyObject
              ( Map.fromList
                  [ ("ami", CtyString)
                  , ("instance_type", CtyString)
                  , ("subnet_id", CtyString)
                  , ("vpc_security_group_ids", CtySet CtyString)
                  , ("tags", CtyMap CtyString)
                  ]
              )
              (Set.fromList ["subnet_id", "vpc_security_group_ids", "tags"])
      mapCtyTypeToNix objType
        `shouldMapTo` [nix|
          types.submodule {
            options = {
              ami = mkOption { type = types.str; };
              instance_type = mkOption { type = types.str; };
              subnet_id = mkOption { type = types.nullOr types.str; };
              tags = mkOption { type = types.nullOr (types.attrsOf types.str); };
              vpc_security_group_ids = mkOption { type = types.nullOr (types.listOf types.str); };
            };
          }
        |]

    it "handles security group-like schema with nested blocks (Example 5 from examples.md)" $ do
      let ingressBlock =
            CtyObject
              ( Map.fromList
                  [ ("from_port", CtyNumber)
                  , ("to_port", CtyNumber)
                  , ("protocol", CtyString)
                  , ("cidr_blocks", CtyList CtyString)
                  ]
              )
              (Set.fromList ["cidr_blocks"])
          sgType =
            CtyObject
              (Map.fromList [("name", CtyString), ("ingress", CtyList ingressBlock)])
              Set.empty
      mapCtyTypeToNix sgType
        `shouldMapTo` [nix|
          types.submodule {
            options = {
              ingress = mkOption {
                type = types.listOf (types.submodule {
                  options = {
                    cidr_blocks = mkOption { type = types.nullOr (types.listOf types.str); };
                    from_port = mkOption { type = types.number; };
                    protocol = mkOption { type = types.str; };
                    to_port = mkOption { type = types.number; };
                  };
                });
              };
              name = mkOption { type = types.str; };
            };
          }
        |]

  describe "integration tests with tuple types" $ do
    it "handles realistic scenario with tuples in configuration" $ do
      -- Simulates a Terraform resource that has a tuple attribute
      -- For example, a resource with connection_info = tuple([string, number, bool])
      -- representing [host, port, use_ssl]
      let connectionInfoType = CtyTuple [CtyString, CtyNumber, CtyBool]
          resourceType =
            CtyObject
              ( Map.fromList
                  [ ("name", CtyString)
                  , ("connection_info", connectionInfoType)
                  , ("enabled", CtyBool)
                  ]
              )
              (Set.fromList ["enabled"])
      mapCtyTypeToNix resourceType
        `shouldMapTo` [nix|
          types.submodule {
            options = {
              connection_info = mkOption {
                type = types.tupleOf [types.str types.number types.bool];
              };
              enabled = mkOption { type = types.nullOr types.bool; };
              name = mkOption { type = types.str; };
            };
          }
        |]

    it "handles complex scenario with list of tuples" $ do
      -- A resource that has a list of coordinate pairs (tuples of numbers)
      -- coordinates = list(tuple([number, number]))
      let coordinateTuple = CtyTuple [CtyNumber, CtyNumber]
          coordinatesList = CtyList coordinateTuple
          resourceType =
            CtyObject
              (Map.fromList [("name", CtyString), ("coordinates", coordinatesList)])
              Set.empty
      mapCtyTypeToNix resourceType
        `shouldMapTo` [nix|
          types.submodule {
            options = {
              coordinates = mkOption {
                type = types.listOf (types.tupleOf [types.number types.number]);
              };
              name = mkOption { type = types.str; };
            };
          }
        |]
