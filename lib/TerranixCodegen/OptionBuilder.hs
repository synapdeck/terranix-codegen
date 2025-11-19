{-# LANGUAGE OverloadedStrings #-}

module TerranixCodegen.OptionBuilder (
  buildOption,
  attributesToSubmodule,
) where

import Data.Fix (Fix (..))
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import Data.Text qualified as T
import Nix.Expr.Shorthands
import Nix.Expr.Types

import TerranixCodegen.ProviderSchema.Attribute
import TerranixCodegen.ProviderSchema.Types (SchemaNestingMode (..))
import TerranixCodegen.TypeMapper (mapCtyTypeToNixWithOptional)

{- | Build a NixOS mkOption expression from a SchemaAttribute.

This is the main entry point for converting Terraform schema attributes
into NixOS module options. It handles:
  - Type mapping (using TypeMapper)
  - Default value generation
  - Description building with metadata
  - Read-only flag for computed-only attributes

Example usage:
  buildOption "ami" schemaAttr  →  mkOption { type = types.str; description = "..."; }
-}
buildOption :: Text -> SchemaAttribute -> NExpr
buildOption _attrName attr =
  mkSym "mkOption" `mkApp` optionArg
  where
    optionArg =
      Fix $
        NSet
          NonRecursive
          bindings

    -- Collect all bindings, filtering out Nothings
    bindings = catMaybes [Just typeBinding, defaultBinding, descriptionBinding, readOnlyBinding]

    -- Type binding (always present)
    typeBinding =
      NamedVar
        (mkSelector "type")
        (buildType attr)
        nullPos

    -- Default binding (only for optional/computed attributes)
    defaultBinding =
      case buildDefault attr of
        Just defaultExpr ->
          Just $
            NamedVar
              (mkSelector "default")
              defaultExpr
              nullPos
        Nothing -> Nothing

    -- Description binding (if description exists)
    descriptionBinding =
      case buildDescription attr of
        Just desc ->
          Just $
            NamedVar
              (mkSelector "description")
              -- Use indented strings for multi-line, regular strings for single-line
              (if T.any (== '\n') desc then mkIndentedStr 16 desc else mkStr desc)
              nullPos
        Nothing -> Nothing

    -- Read-only binding (only for computed-only attributes)
    readOnlyBinding =
      if isReadOnly attr
        then
          Just $
            NamedVar
              (mkSelector "readOnly")
              (mkBool True)
              nullPos
        else Nothing

catMaybes :: [Maybe a] -> [a]
catMaybes = foldr (\mx xs -> maybe xs (: xs) mx) []

{- | Build the Nix type expression for a SchemaAttribute.

Handles both direct CtyType and nested attribute types.
Wraps optional attributes with types.nullOr.
-}
buildType :: SchemaAttribute -> NExpr
buildType attr =
  case (attributeType attr, attributeNestedType attr) of
    -- Direct CtyType (most common case)
    (Just ctyType, Nothing) ->
      mapCtyTypeToNixWithOptional (isOptionalAttribute attr) ctyType
    -- Nested attribute type (requires submodule handling)
    (Nothing, Just nestedType) ->
      let submodule = buildNestedAttributeType nestedType
          baseType = applyNestingMode (fromMaybe NestingSingle (nestedNestingMode nestedType)) submodule
       in if isOptionalAttribute attr
            then nixTypes "nullOr" `mkApp` baseType
            else baseType
    -- Both present (shouldn't happen according to schema spec)
    (Just ctyType, Just _) ->
      -- Prefer the direct type
      mapCtyTypeToNixWithOptional (isOptionalAttribute attr) ctyType
    -- Neither present (shouldn't happen, but handle gracefully)
    (Nothing, Nothing) ->
      nixTypes "anything"

{- | Determine if an attribute is optional.

An attribute is optional if:
  - attributeOptional is True, OR
  - attributeComputed is True (computed attributes can be omitted)
-}
isOptionalAttribute :: SchemaAttribute -> Bool
isOptionalAttribute attr =
  fromMaybe False (attributeOptional attr)
    || fromMaybe False (attributeComputed attr)

{- | Determine the default value for an attribute.

Rules:
  - Required attributes: No default
  - Optional attributes: default = null
  - Computed-only attributes: default = null
  - Lists/Sets (future): default = []
  - Maps (future): default = {}
-}
buildDefault :: SchemaAttribute -> Maybe NExpr
buildDefault attr
  -- Required attributes have no default
  | fromMaybe False (attributeRequired attr) = Nothing
  -- Optional or computed attributes default to null
  | isOptionalAttribute attr = Just mkNull
  -- Otherwise no default
  | otherwise = Nothing

{- | Build a comprehensive description from schema metadata.

Combines:
  - Base description text
  - Deprecation warnings
  - Sensitivity warnings
  - Write-only notes
  - Computed attribute notes
-}
buildDescription :: SchemaAttribute -> Maybe Text
buildDescription attr =
  if T.null combinedDesc
    then Nothing
    else Just finalDesc
  where
    nonEmptyParts = filter (not . T.null) parts
    combinedDesc = T.intercalate "\n\n" nonEmptyParts

    -- Add trailing newline only for multi-line descriptions (more than one part)
    finalDesc =
      if length nonEmptyParts > 1
        then combinedDesc <> "\n"
        else combinedDesc

    parts =
      [ baseDesc
      , deprecationNote
      , sensitiveNote
      , writeOnlyNote
      , computedNote
      ]

    baseDesc = fromMaybe "" (attributeDescription attr)

    deprecationNote =
      if fromMaybe False (attributeDeprecated attr)
        then "DEPRECATED: This attribute is deprecated and may be removed in a future version."
        else ""

    sensitiveNote =
      if fromMaybe False (attributeSensitive attr)
        then "WARNING: This attribute contains sensitive information and will not be displayed in logs."
        else ""

    writeOnlyNote =
      if fromMaybe False (attributeWriteOnly attr)
        then "NOTE: This attribute is write-only and will not be persisted in the Terraform state."
        else ""

    computedNote =
      if fromMaybe False (attributeComputed attr)
        && not (fromMaybe False (attributeRequired attr))
        && not (fromMaybe False (attributeOptional attr))
        then "This value is computed by the provider."
        else ""

{- | Determine if an attribute should be marked as read-only.

An attribute is read-only if it is computed but not required or optional.
This indicates it's a computed-only attribute that users cannot set.
-}
isReadOnly :: SchemaAttribute -> Bool
isReadOnly attr =
  fromMaybe False (attributeComputed attr)
    && not (fromMaybe False (attributeRequired attr))
    && not (fromMaybe False (attributeOptional attr))

-- | Helper to reference types.* from the NixOS module system
nixTypes :: Text -> NExpr
nixTypes name = mkSym "types" `mkSelect` name

-- | Helper to build a select expression (attribute access)
mkSelect :: NExpr -> Text -> NExpr
mkSelect expr attr = Fix $ NSelect Nothing expr (mkSelector attr)

{- | Build a submodule type from a SchemaNestedAttributeType.

Converts the nested attributes to a types.submodule with options.
-}
buildNestedAttributeType :: SchemaNestedAttributeType -> NExpr
buildNestedAttributeType nestedType =
  case nestedAttributes nestedType of
    Just attrs -> attributesToSubmodule attrs
    Nothing -> nixTypes "attrs" -- Fallback if no attributes defined

{- | Convert a Map of SchemaAttributes to a types.submodule expression.

This creates:
  types.submodule {
    options = {
      attr1 = mkOption { ... };
      attr2 = mkOption { ... };
    };
  }
-}
attributesToSubmodule :: Map Text SchemaAttribute -> NExpr
attributesToSubmodule attrs =
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
          (map attrToBinding (Map.toList attrs))

    attrToBinding (name, attr) =
      NamedVar
        (mkSelector name)
        (buildOption name attr)
        nullPos

{- | Apply a nesting mode wrapper to a submodule type.

Maps Terraform nesting modes to Nix type expressions:
  - NestingSingle: types.submodule (as-is)
  - NestingGroup: types.submodule (as-is, never null)
  - NestingList: types.listOf types.submodule
  - NestingSet: types.listOf types.submodule
  - NestingMap: types.attrsOf types.submodule
-}
applyNestingMode :: SchemaNestingMode -> NExpr -> NExpr
applyNestingMode mode submodule =
  case mode of
    NestingSingle -> submodule
    NestingGroup -> submodule
    NestingList -> nixTypes "listOf" `mkApp` submodule
    NestingSet -> nixTypes "listOf" `mkApp` submodule
    NestingMap -> nixTypes "attrsOf" `mkApp` submodule
