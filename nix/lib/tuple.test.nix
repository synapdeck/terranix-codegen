# Test suite for the tuple type
# This file contains comprehensive tests for the custom NixOS tuple type
{lib}: let
  # Import our custom tuple type
  tupleLib = import ./tuple.nix {inherit lib;};
  types = lib.types // tupleLib;

  # Helper to evaluate a module with the given options and config
  evalModule = options: config:
    lib.evalModules {
      modules = [
        {inherit options config;}
      ];
    };

  # Helper to check if evaluation throws an error
  # Uses deepSeq to force full evaluation
  shouldFail = expr: !(builtins.tryEval (builtins.deepSeq expr expr)).success;
in {
  tuple-type = {
    basic-validation = {
      testAcceptsCorrectLengthAndTypes = let
        result =
          evalModule {
            opt = lib.mkOption {
              type = types.tupleOf [types.str types.int types.bool];
            };
          } {
            opt = ["hello" 42 true];
          };
      in {
        expr = result.config.opt;
        expected = ["hello" 42 true];
      };

      testRejectsWrongLengthTooShort = {
        expr =
          shouldFail
          (
            evalModule {
              opt = lib.mkOption {
                type = types.tupleOf [types.str types.int types.bool];
              };
            } {
              opt = ["hello" 42];
            }
          ).config.opt;
        expected = true;
      };

      testRejectsWrongLengthTooLong = {
        expr =
          shouldFail
          (
            evalModule {
              opt = lib.mkOption {
                type = types.tupleOf [types.str types.int];
              };
            } {
              opt = ["hello" 42 true];
            }
          ).config.opt;
        expected = true;
      };

      testRejectsWrongTypeAtPosition0 = {
        expr =
          shouldFail
          (
            evalModule {
              opt = lib.mkOption {
                type = types.tupleOf [types.str types.int types.bool];
              };
            } {
              opt = [123 42 true];
            }
          ).config.opt;
        expected = true;
      };

      testRejectsWrongTypeAtPosition1 = {
        expr =
          shouldFail
          (
            evalModule {
              opt = lib.mkOption {
                type = types.tupleOf [types.str types.int types.bool];
              };
            } {
              opt = ["hello" "world" true];
            }
          ).config.opt;
        expected = true;
      };

      testRejectsWrongTypeAtPosition2 = {
        expr =
          shouldFail
          (
            evalModule {
              opt = lib.mkOption {
                type = types.tupleOf [types.str types.int types.bool];
              };
            } {
              opt = ["hello" 42 "yes"];
            }
          ).config.opt;
        expected = true;
      };
    };

    edge-cases = {
      testEmptyTupleWorks = let
        result =
          evalModule {
            opt = lib.mkOption {
              type = types.tupleOf [];
            };
          } {
            opt = [];
          };
      in {
        expr = result.config.opt;
        expected = [];
      };

      testEmptyTupleRejectsNonEmptyList = {
        expr =
          shouldFail
          (
            evalModule {
              opt = lib.mkOption {
                type = types.tupleOf [];
              };
            } {
              opt = [1];
            }
          ).config.opt;
        expected = true;
      };

      testSingleElementTupleWorks = let
        result =
          evalModule {
            opt = lib.mkOption {
              type = types.tupleOf [types.str];
            };
          } {
            opt = ["hello"];
          };
      in {
        expr = result.config.opt;
        expected = ["hello"];
      };
    };

    nested-collection-types = {
      testTupleWithLists = let
        result =
          evalModule {
            opt = lib.mkOption {
              type = types.tupleOf [
                (types.listOf types.str)
                (types.listOf types.int)
              ];
            };
          } {
            opt = [
              ["a" "b" "c"]
              [1 2 3]
            ];
          };
      in {
        expr = result.config.opt;
        expected = [
          ["a" "b" "c"]
          [1 2 3]
        ];
      };

      testTupleWithAttrs = let
        result =
          evalModule {
            opt = lib.mkOption {
              type = types.tupleOf [
                types.str
                (types.attrsOf types.int)
              ];
            };
          } {
            opt = [
              "name"
              {
                x = 1;
                y = 2;
              }
            ];
          };
      in {
        expr = result.config.opt;
        expected = [
          "name"
          {
            x = 1;
            y = 2;
          }
        ];
      };

      testTupleWithSubmodule = let
        result =
          evalModule {
            opt = lib.mkOption {
              type = types.tupleOf [
                types.str
                (types.submodule {
                  options = {
                    host = lib.mkOption {type = types.str;};
                    port = lib.mkOption {type = types.int;};
                  };
                })
              ];
            };
          } {
            opt = [
              "connection"
              {
                host = "localhost";
                port = 8080;
              }
            ];
          };
      in {
        expr = result.config.opt;
        expected = [
          "connection"
          {
            host = "localhost";
            port = 8080;
          }
        ];
      };
    };

    nested-tuples = {
      testTupleContainingTuple = let
        result =
          evalModule {
            opt = lib.mkOption {
              type = types.tupleOf [
                (types.tupleOf [types.str types.int])
                types.bool
              ];
            };
          } {
            opt = [
              ["hello" 42]
              true
            ];
          };
      in {
        expr = result.config.opt;
        expected = [
          ["hello" 42]
          true
        ];
      };

      testDeeplyNestedTuples = let
        result =
          evalModule {
            opt = lib.mkOption {
              type = types.tupleOf [
                (types.tupleOf [
                  types.str
                  (types.tupleOf [types.int types.bool])
                ])
                types.str
              ];
            };
          } {
            opt = [
              ["outer" [42 true]]
              "end"
            ];
          };
      in {
        expr = result.config.opt;
        expected = [
          ["outer" [42 true]]
          "end"
        ];
      };
    };

    type-composition = {
      testNullOrTupleWorks = let
        result =
          evalModule {
            opt = lib.mkOption {
              type = types.nullOr (types.tupleOf [types.str types.int]);
              default = null;
            };
          } {
            opt = null;
          };
      in {
        expr = result.config.opt;
        expected = null;
      };

      testNullOrTupleWithValue = let
        result =
          evalModule {
            opt = lib.mkOption {
              type = types.nullOr (types.tupleOf [types.str types.int]);
            };
          } {
            opt = ["hello" 42];
          };
      in {
        expr = result.config.opt;
        expected = ["hello" 42];
      };

      testListOfTuples = let
        result =
          evalModule {
            opt = lib.mkOption {
              type = types.listOf (types.tupleOf [types.int types.int]);
            };
          } {
            opt = [
              [1 2]
              [3 4]
              [5 6]
            ];
          };
      in {
        expr = result.config.opt;
        expected = [
          [1 2]
          [3 4]
          [5 6]
        ];
      };

      testAttrsOfTuples = let
        result =
          evalModule {
            opt = lib.mkOption {
              type = types.attrsOf (types.tupleOf [types.str types.int]);
            };
          } {
            opt = {
              first = ["one" 1];
              second = ["two" 2];
            };
          };
      in {
        expr = result.config.opt;
        expected = {
          first = ["one" 1];
          second = ["two" 2];
        };
      };
    };

    merging-behavior = {
      testLastDefinitionWins = let
        result =
          evalModule {
            opt = lib.mkOption {
              type = types.tupleOf [types.str types.int];
            };
          } {
            opt = lib.mkMerge [
              ["first" 1]
              (lib.mkForce ["second" 2])
            ];
          };
      in {
        expr = result.config.opt;
        expected = ["second" 2];
      };

      testValidatesAllDefinitions = {
        expr =
          shouldFail
          (
            evalModule {
              opt = lib.mkOption {
                type = types.tupleOf [types.str types.int];
              };
            } {
              opt = lib.mkMerge [
                ["valid" 1]
                ["invalid"] # Wrong length
              ];
            }
          ).config.opt;
        expected = true;
      };
    };

    real-world-examples = {
      testConnectionInfoTuple = let
        result =
          evalModule {
            connectionInfo = lib.mkOption {
              type = types.tupleOf [types.str types.port types.bool];
              description = "Connection tuple: [host, port, use_ssl]";
            };
          } {
            connectionInfo = ["example.com" 443 true];
          };
      in {
        expr = result.config.connectionInfo;
        expected = ["example.com" 443 true];
      };

      testCoordinatePair = let
        result =
          evalModule {
            coordinates = lib.mkOption {
              type = types.listOf (types.tupleOf [types.float types.float]);
              description = "List of [x, y] coordinate pairs";
            };
          } {
            coordinates = [
              [1.5 2.3]
              [4.7 5.1]
              [8.9 9.0]
            ];
          };
      in {
        expr = result.config.coordinates;
        expected = [
          [1.5 2.3]
          [4.7 5.1]
          [8.9 9.0]
        ];
      };

      testVersionTriple = let
        result =
          evalModule {
            version = lib.mkOption {
              type = types.tupleOf [types.int types.int types.int];
              description = "Version as [major, minor, patch]";
            };
          } {
            version = [1 2 3];
          };
      in {
        expr = result.config.version;
        expected = [1 2 3];
      };

      testRgbColor = let
        result =
          evalModule {
            color = lib.mkOption {
              type = types.tupleOf [types.int types.int types.int];
              description = "RGB color as [red, green, blue]";
            };
          } {
            color = [255 128 0];
          };
      in {
        expr = result.config.color;
        expected = [255 128 0];
      };
    };

    type-properties = {
      testHasCorrectName = {
        expr = (types.tupleOf [types.str types.int types.bool]).name;
        expected = "tupleOf[3]";
      };

      testHasDescription = {
        expr = (types.tupleOf [types.str types.int]).description;
        expected = "tuple of [string, signed integer]";
      };

      testCheckFunctionValidatesLength = {
        expr = (types.tupleOf [types.str types.int]).check ["a" 1 2];
        expected = false;
      };

      testCheckFunctionAcceptsCorrectLength = {
        expr = (types.tupleOf [types.str types.int]).check ["a" 1];
        expected = true;
      };

      testCheckFunctionRejectsNonLists = {
        expr = (types.tupleOf [types.str types.int]).check {
          a = 1;
          b = 2;
        };
        expected = false;
      };
    };
  };
}
