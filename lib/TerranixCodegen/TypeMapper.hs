module TerranixCodegen.TypeMapper (
  mapCtyTypeToNix,
  mapCtyTypeToNixWithOptional,
) where

import Data.Fix (Fix (..))
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Nix.Expr.Shorthands
import Nix.Expr.Types

import TerranixCodegen.ProviderSchema.CtyType

{- | Map a Terraform CtyType to a Nix type expression.

This generates expressions like:
  - types.str
  - types.bool
  - types.number
  - types.listOf types.str
  - types.attrsOf types.str
  - types.submodule { options = {...}; }

The resulting NExpr can be pretty-printed to produce Nix code.
-}
mapCtyTypeToNix :: CtyType -> NExpr
mapCtyTypeToNix = \case
  -- Primitive types map directly to NixOS type primitives
  CtyBool -> nixTypes "bool"
  CtyNumber -> nixTypes "number"
  CtyString -> nixTypes "str"
  CtyDynamic -> nixTypes "anything"
  -- Collection types (homogeneous)
  -- Both lists and sets map to types.listOf since Nix doesn't distinguish ordered/unordered
  CtyList elemType ->
    nixTypes "listOf" `mkApp` mapCtyTypeToNix elemType
  CtySet elemType ->
    nixTypes "listOf" `mkApp` mapCtyTypeToNix elemType
  -- Maps become attribute sets in Nix
  CtyMap elemType ->
    nixTypes "attrsOf" `mkApp` mapCtyTypeToNix elemType
  -- Structural types
  CtyObject attrTypes optionals ->
    mapObjectToSubmodule attrTypes optionals
  CtyTuple elemTypes ->
    -- Map to types.tupleOf with proper element types
    -- This generates: types.tupleOf [types.str, types.number, ...]
    nixTypes "tupleOf" `mkApp` mkTypeList elemTypes

{- | Map a CtyType to a Nix type expression, optionally wrapping in types.nullOr.

This is used for optional attributes:
  - Required: mapCtyTypeToNixWithOptional False ctyType  →  types.str
  - Optional: mapCtyTypeToNixWithOptional True ctyType   →  types.nullOr types.str
-}
mapCtyTypeToNixWithOptional :: Bool -> CtyType -> NExpr
mapCtyTypeToNixWithOptional isOptional ctyType =
  if isOptional
    then nixTypes "nullOr" `mkApp` mapCtyTypeToNix ctyType
    else mapCtyTypeToNix ctyType

-- | Helper to reference types.* from the NixOS module system
nixTypes :: Text -> NExpr
nixTypes name = mkSym "types" `mkSelect` name

-- | Helper to build a select expression (attribute access)
mkSelect :: NExpr -> Text -> NExpr
mkSelect expr attr = Fix $ NSelect Nothing expr (mkSelector attr)

{- | Helper to build a Nix list of type expressions
Maps each CtyType to its Nix type and wraps in a list
Example: [CtyString, CtyNumber] -> [types.str, types.number]
-}
mkTypeList :: [CtyType] -> NExpr
mkTypeList elemTypes = Fix $ NList (map mapCtyTypeToNix elemTypes)

{- | Map a Terraform object type to a Nix submodule.

An object like:
  object({
    host = string
    port = number
  })

Becomes:
  types.submodule {
    options = {
      host = mkOption { type = types.str; };
      port = mkOption { type = types.number; };
    };
  }
-}
mapObjectToSubmodule :: Map.Map Text CtyType -> Set.Set Text -> NExpr
mapObjectToSubmodule attrTypes optionals =
  nixTypes "submodule" `mkApp` submoduleArg
  where
    submoduleArg =
      Fix $
        NSet
          NonRecursive
          [optionsBinding]

    optionsBinding =
      NamedVar
        (mkSelector "options")
        optionsSet
        nullPos

    optionsSet =
      Fix $
        NSet
          NonRecursive
          (map makeOptionBinding $ Map.toList attrTypes)

    makeOptionBinding :: (Text, CtyType) -> Binding NExpr
    makeOptionBinding (attrName, attrType) =
      NamedVar
        (mkSelector attrName)
        (mkOptionCall attrName attrType)
        nullPos

    mkOptionCall :: Text -> CtyType -> NExpr
    mkOptionCall attrName attrType =
      mkSym "mkOption" `mkApp` optionArg
      where
        isOptional = Set.member attrName optionals
        optionArg =
          Fix $
            NSet
              NonRecursive
              [typeBinding]

        typeBinding =
          NamedVar
            (mkSelector "type")
            (mapCtyTypeToNixWithOptional isOptional attrType)
            nullPos
