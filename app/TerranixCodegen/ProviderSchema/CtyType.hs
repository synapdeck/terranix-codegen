{-# LANGUAGE DerivingVia #-}
{-# LANGUAGE OverloadedStrings #-}

module TerranixCodegen.ProviderSchema.CtyType (
    CtyType (..),
    friendlyName,
    isPrimitive,
    isCollection,
    isStructural,
) where

import Autodocodec (Autodocodec (..), HasCodec (..), bimapCodec, codec)
import Data.Aeson (FromJSON, ToJSON, Value (..))
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KM
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
    deriving (FromJSON, ToJSON) via (Autodocodec CtyType)

instance Show CtyType where
    show = T.unpack . friendlyName

instance HasCodec CtyType where
    codec = bimapCodec decode encode codec
      where
        decode :: Value -> Either String CtyType
        decode (String "bool") = Right CtyBool
        decode (String "number") = Right CtyNumber
        decode (String "string") = Right CtyString
        decode (String "dynamic") = Right CtyDynamic
        decode (Array arr) = case V.toList arr of
            [String "list", elemTypeVal] ->
                case decode elemTypeVal of
                    Left err -> Left err
                    Right t -> Right (CtyList t)
            [String "set", elemTypeVal] ->
                case decode elemTypeVal of
                    Left err -> Left err
                    Right t -> Right (CtySet t)
            [String "map", elemTypeVal] ->
                case decode elemTypeVal of
                    Left err -> Left err
                    Right t -> Right (CtyMap t)
            [String "object", Object attrs] ->
                case parseAttrs attrs of
                    Left err -> Left err
                    Right attrMap -> Right (CtyObject attrMap Set.empty)
            [String "object", Object attrs, Array optArr] ->
                case (parseAttrs attrs, parseOptionals optArr) of
                    (Right attrMap, Right opts) -> Right (CtyObject attrMap opts)
                    (Left err, _) -> Left err
                    (_, Left err) -> Left err
            [String "tuple", Array elemTypesArr] ->
                case mapM decode (V.toList elemTypesArr) of
                    Left err -> Left err
                    Right types -> Right (CtyTuple types)
            _ -> Left "Invalid cty type array format"
        decode _ = Left "Expected string or array for cty type"

        encode :: CtyType -> Value
        encode CtyBool = String "bool"
        encode CtyNumber = String "number"
        encode CtyString = String "string"
        encode CtyDynamic = String "dynamic"
        encode (CtyList elemType) = Array $ V.fromList [String "list", encode elemType]
        encode (CtySet elemType) = Array $ V.fromList [String "set", encode elemType]
        encode (CtyMap elemType) = Array $ V.fromList [String "map", encode elemType]
        encode (CtyObject attrTypes optionals)
            | Set.null optionals =
                Array $
                    V.fromList
                        [ String "object"
                        , Object $ KM.fromMap $ Map.mapKeys Key.fromText $ Map.map encode attrTypes
                        ]
            | otherwise =
                Array $
                    V.fromList
                        [ String "object"
                        , Object $ KM.fromMap $ Map.mapKeys Key.fromText $ Map.map encode attrTypes
                        , Array $ V.fromList $ map String $ Set.toList optionals
                        ]
        encode (CtyTuple elemTypes) =
            Array $
                V.fromList
                    [ String "tuple"
                    , Array $ V.fromList $ map encode elemTypes
                    ]

        -- Helper to parse attribute map
        parseAttrs :: KM.KeyMap Value -> Either String (Map Text CtyType)
        parseAttrs km = do
            let attrList = KM.toList km
            typedPairs <- mapM (\(k, v) -> case decode v of
                                    Left err -> Left err
                                    Right t -> Right (Key.toText k, t)) attrList
            Right $ Map.fromList typedPairs

        -- Helper to parse optional attribute names
        parseOptionals :: V.Vector Value -> Either String (Set.Set Text)
        parseOptionals arr = do
            names <- mapM (\case
                            String s -> Right s
                            _ -> Left "Expected string in optionals array") (V.toList arr)
            Right $ Set.fromList names

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
