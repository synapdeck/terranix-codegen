{-# LANGUAGE StrictData #-}

module TerranixCodegen.ProviderSchema.CtyType (
  CtyType (..),
  friendlyName,
  isPrimitive,
  isCollection,
  isStructural,
) where

import Control.Applicative ((<|>))
import Data.Aeson (FromJSON (..), ToJSON (..), Value (..), withArray, withText)
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KM
import Data.Aeson.Types (Parser)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as T
import Data.Vector qualified as V

{- | CtyType represents a type from the go-cty type system used by Terraform.
This mirrors the type system defined in github.com/zclconf/go-cty/cty
-}
data CtyType
  = -- Primitive types
    CtyBool
  | CtyNumber
  | CtyString
  | CtyDynamic
  | -- Collection types (homogeneous)
    CtyList CtyType
  | CtySet CtyType
  | CtyMap CtyType
  | -- Structural types

    -- | Object with attribute types and optional attribute names
    CtyObject (Map Text CtyType) (Set.Set Text)
  | -- | Tuple with element types
    CtyTuple [CtyType]
  deriving stock (Eq, Ord)

instance Show CtyType where
  show = T.unpack . friendlyName

instance ToJSON CtyType where
  toJSON CtyBool = String "bool"
  toJSON CtyNumber = String "number"
  toJSON CtyString = String "string"
  toJSON CtyDynamic = String "dynamic"
  toJSON (CtyList elemType) = Array $ V.fromList [String "list", toJSON elemType]
  toJSON (CtySet elemType) = Array $ V.fromList [String "set", toJSON elemType]
  toJSON (CtyMap elemType) = Array $ V.fromList [String "map", toJSON elemType]
  toJSON (CtyObject attrTypes optionals)
    | Set.null optionals =
        Array $
          V.fromList
            [ String "object"
            , Object $ KM.fromMap $ Map.mapKeys Key.fromText $ Map.map toJSON attrTypes
            ]
    | otherwise =
        Array $
          V.fromList
            [ String "object"
            , Object $ KM.fromMap $ Map.mapKeys Key.fromText $ Map.map toJSON attrTypes
            , Array $ V.fromList $ map String $ Set.toList optionals
            ]
  toJSON (CtyTuple elemTypes) =
    Array $
      V.fromList
        [ String "tuple"
        , Array $ V.fromList $ map toJSON elemTypes
        ]

instance FromJSON CtyType where
  parseJSON v = parsePrimitive v <|> parseCompound v
    where
      parsePrimitive = withText "CtyType" $ \case
        "bool" -> pure CtyBool
        "number" -> pure CtyNumber
        "string" -> pure CtyString
        "dynamic" -> pure CtyDynamic
        other -> fail $ "Unknown primitive type: " <> show other

      parseCompound = withArray "CtyType" $ \arr -> do
        case V.toList arr of
          [] -> fail "Empty array in CtyType"
          (String tag : rest) -> case (tag, rest) of
            ("list", [elemType]) -> CtyList <$> parseJSON elemType
            ("set", [elemType]) -> CtySet <$> parseJSON elemType
            ("map", [elemType]) -> CtyMap <$> parseJSON elemType
            ("object", [Object attrs]) -> do
              attrMap <- parseAttrs attrs
              pure $ CtyObject attrMap Set.empty
            ("object", [Object attrs, Array optionals]) -> do
              attrMap <- parseAttrs attrs
              optList <- mapM parseOptional (V.toList optionals)
              pure $ CtyObject attrMap (Set.fromList optList)
            ("tuple", [Array elemTypes]) -> do
              types <- mapM parseJSON (V.toList elemTypes)
              pure $ CtyTuple types
            _ -> fail $ "Invalid CtyType structure: " <> show (tag, rest)
          _ -> fail "CtyType array must start with a string tag"

      parseAttrs :: KM.KeyMap Value -> Parser (Map Text CtyType)
      parseAttrs km = do
        let pairs = KM.toList km
        parsedPairs <- mapM (\(k, val) -> (,) (Key.toText k) <$> parseJSON val) pairs
        pure $ Map.fromList parsedPairs

      parseOptional :: Value -> Parser Text
      parseOptional = withText "optional key" pure

-- | Get a human-friendly name for a CtyType
friendlyName :: CtyType -> Text
friendlyName CtyBool = "bool"
friendlyName CtyNumber = "number"
friendlyName CtyString = "string"
friendlyName CtyDynamic = "dynamic"
friendlyName (CtyList t) = "list(" <> friendlyName t <> ")"
friendlyName (CtySet t) = "set(" <> friendlyName t <> ")"
friendlyName (CtyMap t) = "map(" <> friendlyName t <> ")"
friendlyName (CtyObject attrs opts) =
  "object({"
    <> T.intercalate ", " (map (\(k, v) -> showOpt k <> "=" <> friendlyName v) $ Map.toList attrs)
    <> "})"
  where
    showOpt k = if Set.member k opts then k <> "?" else k
friendlyName (CtyTuple types) =
  "tuple(["
    <> T.intercalate ", " (map friendlyName types)
    <> "])"

-- | Check if a type is a primitive type
isPrimitive :: CtyType -> Bool
isPrimitive CtyBool = True
isPrimitive CtyNumber = True
isPrimitive CtyString = True
isPrimitive CtyDynamic = True
isPrimitive _ = False

-- | Check if a type is a collection type
isCollection :: CtyType -> Bool
isCollection (CtyList _) = True
isCollection (CtySet _) = True
isCollection (CtyMap _) = True
isCollection _ = False

-- | Check if a type is a structural type
isStructural :: CtyType -> Bool
isStructural (CtyObject _ _) = True
isStructural (CtyTuple _) = True
isStructural _ = False
