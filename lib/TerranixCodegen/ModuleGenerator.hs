module TerranixCodegen.ModuleGenerator (
  generateResourceModule,
  generateDataSourceModule,
  generateProviderModule,
  blockToSubmodule,
  blockTypeToOption,
) where

import Data.Fix (Fix (..))
import Data.List.NonEmpty (NonEmpty ((:|)))
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Maybe (catMaybes, fromMaybe)
import Data.Text (Text)
import Nix.Expr.Shorthands
import Nix.Expr.Types

import TerranixCodegen.Description qualified as Description
import TerranixCodegen.OptionBuilder (attributesToSubmodule, buildOption)
import TerranixCodegen.ProviderSchema.Attribute
import TerranixCodegen.ProviderSchema.Block
import TerranixCodegen.ProviderSchema.Schema
import TerranixCodegen.ProviderSchema.Types (SchemaNestingMode (..))

{- | Generate a complete NixOS module for a Terraform resource.

Creates a module with the structure:

@
{ lib, ... }:
with lib;
{
  options.resource.{resourceType} = mkOption {
    type = types.attrsOf (types.submodule { options = {...}; });
    default = {};
    description = "\<schema block description or fallback\>";
  };
}
@

Uses the schema's block description when available, otherwise falls back to
"Instances of {resourceType}".

Example:

@
generateResourceModule "aws" "aws_instance" schema
@
-}
generateResourceModule :: Text -> Text -> Schema -> NExpr
generateResourceModule _providerName resourceType schema =
  moduleWrapper
    [resourceBinding]
  where
    resourceBinding =
      NamedVar
        (StaticKey (VarName "options") :| [StaticKey (VarName "resource"), StaticKey (VarName resourceType)])
        resourceOption
        nullPos

    resourceOption =
      mkSym "mkOption" `mkApp` resourceOptionArg

    resourceOptionArg =
      Fix $
        NSet
          NonRecursive
          [ typeBinding
          , defaultBinding
          , descriptionBinding
          ]

    typeBinding =
      NamedVar
        (mkSelector "type")
        instancesType
        nullPos

    instancesType =
      nixTypes "attrsOf" `mkApp` instanceSubmodule

    instanceSubmodule =
      case schemaBlock schema of
        Just block -> blockToSubmodule block
        Nothing -> nixTypes "attrs" -- Fallback for empty schema
    defaultBinding =
      NamedVar
        (mkSelector "default")
        (Fix $ NSet NonRecursive [])
        nullPos

    descriptionBinding =
      NamedVar
        (mkSelector "description")
        ( case schemaBlock schema >>= Description.fromBlock of
            Just desc -> Description.toNExpr desc
            Nothing -> mkStr $ "Instances of " <> resourceType
        )
        nullPos

{- | Generate a complete NixOS module for a Terraform data source.

Similar to generateResourceModule but uses "data" instead of "resource".
-}
generateDataSourceModule :: Text -> Text -> Schema -> NExpr
generateDataSourceModule _providerName dataSourceType schema =
  moduleWrapper
    [dataSourceBinding]
  where
    dataSourceBinding =
      NamedVar
        (StaticKey (VarName "options") :| [StaticKey (VarName "data"), StaticKey (VarName dataSourceType)])
        dataSourceOption
        nullPos

    dataSourceOption =
      mkSym "mkOption" `mkApp` dataSourceOptionArg

    dataSourceOptionArg =
      Fix $
        NSet
          NonRecursive
          [ typeBinding
          , defaultBinding
          , descriptionBinding
          ]

    typeBinding =
      NamedVar
        (mkSelector "type")
        instancesType
        nullPos

    instancesType =
      nixTypes "attrsOf" `mkApp` instanceSubmodule

    instanceSubmodule =
      case schemaBlock schema of
        Just block -> blockToSubmodule block
        Nothing -> nixTypes "attrs"

    defaultBinding =
      NamedVar
        (mkSelector "default")
        (Fix $ NSet NonRecursive [])
        nullPos

    descriptionBinding =
      NamedVar
        (mkSelector "description")
        ( case schemaBlock schema >>= Description.fromBlock of
            Just desc -> Description.toNExpr desc
            Nothing -> mkStr $ "Instances of " <> dataSourceType <> " data source"
        )
        nullPos

{- | Generate a complete NixOS module for a Terraform provider configuration.

Creates a module with the structure:

@
{ lib, ... }:
with lib;
{
  options.provider.{providerName} = mkOption {
    type = types.attrsOf (types.submodule { options = {...}; });
    default = {};
    description = "\<schema block description or fallback\>";
  };
}
@

Uses the schema's block description when available, otherwise falls back to
"{providerName} provider configuration".
-}
generateProviderModule :: Text -> Schema -> NExpr
generateProviderModule providerName schema =
  moduleWrapper
    [providerBinding]
  where
    providerBinding =
      NamedVar
        (StaticKey (VarName "options") :| [StaticKey (VarName "provider"), StaticKey (VarName providerName)])
        providerOption
        nullPos

    providerOption =
      mkSym "mkOption" `mkApp` providerOptionArg

    providerOptionArg =
      Fix $
        NSet
          NonRecursive
          [ typeBinding
          , defaultBinding
          , descriptionBinding
          ]

    typeBinding =
      NamedVar
        (mkSelector "type")
        configType
        nullPos

    configType =
      nixTypes "attrsOf" `mkApp` configSubmodule

    configSubmodule =
      case schemaBlock schema of
        Just block -> blockToSubmodule block
        Nothing -> nixTypes "attrs"

    defaultBinding =
      NamedVar
        (mkSelector "default")
        (Fix $ NSet NonRecursive [])
        nullPos

    descriptionBinding =
      NamedVar
        (mkSelector "description")
        ( case schemaBlock schema >>= Description.fromBlock of
            Just desc -> Description.toNExpr desc
            Nothing -> mkStr $ providerName <> " provider configuration"
        )
        nullPos

{- | Convert a SchemaBlock to a types.submodule expression.

Processes:
  - blockAttributes: Converted to options using OptionBuilder
  - blockNestedBlocks: Converted to nested options with nesting mode wrappers

Returns: @types.submodule { options = {...}; }@
-}
blockToSubmodule :: SchemaBlock -> NExpr
blockToSubmodule block =
  case (blockAttributes block, blockNestedBlocks block) of
    -- Both attributes and nested blocks
    (Just attrs, Just nestedBlocks) ->
      let attrOptions = attributesToOptions attrs
          blockOptions = nestedBlocksToOptions nestedBlocks
       in nixTypes "submodule" `mkApp` submoduleArg (attrOptions <> blockOptions)
    -- Only attributes
    (Just attrs, Nothing) ->
      attributesToSubmodule attrs
    -- Only nested blocks
    (Nothing, Just nestedBlocks) ->
      nixTypes "submodule" `mkApp` submoduleArg (nestedBlocksToOptions nestedBlocks)
    -- Empty block
    (Nothing, Nothing) ->
      nixTypes "submodule" `mkApp` submoduleArg []

-- | Convert a map of nested blocks to a list of option bindings.
nestedBlocksToOptions :: Map Text SchemaBlockType -> [Binding NExpr]
nestedBlocksToOptions nestedBlocks =
  map (uncurry blockTypeToBinding) (Map.toList nestedBlocks)

{- | Convert a SchemaBlockType to an option binding.

Applies the appropriate nesting mode wrapper to the block.
-}
blockTypeToBinding :: Text -> SchemaBlockType -> Binding NExpr
blockTypeToBinding name blockType =
  NamedVar
    (mkSelector name)
    option
    nullPos
  where
    option = mkSym "mkOption" `mkApp` optionArg

    optionArg =
      Fix $
        NSet
          NonRecursive
          (catMaybes [Just typeBinding, defaultBinding, descriptionBinding])

    typeBinding =
      NamedVar
        (mkSelector "type")
        typeExpr
        nullPos

    typeExpr =
      case blockTypeBlock blockType of
        Just innerBlock ->
          let submodule = blockToSubmodule innerBlock
              nestingMode = fromMaybe NestingSingle (blockTypeNestingMode blockType)
           in applyBlockNestingMode nestingMode submodule
        Nothing -> nixTypes "attrs"

    -- Default value based on nesting mode
    defaultBinding =
      case blockTypeNestingMode blockType of
        Just NestingSingle -> Just $ NamedVar (mkSelector "default") mkNull nullPos
        Just NestingGroup -> Nothing -- No default for NestingGroup (required)
        Just NestingList -> Just $ NamedVar (mkSelector "default") (mkList []) nullPos
        Just NestingSet -> Just $ NamedVar (mkSelector "default") (mkList []) nullPos
        Just NestingMap -> Just $ NamedVar (mkSelector "default") (Fix $ NSet NonRecursive []) nullPos
        Nothing -> Just $ NamedVar (mkSelector "default") mkNull nullPos -- Default to Single behavior
    descriptionBinding =
      case blockTypeBlock blockType >>= Description.fromBlock of
        Just desc -> Just $ NamedVar (mkSelector "description") (Description.toNExpr desc) nullPos
        Nothing -> Nothing

{- | Apply a nesting mode wrapper to a submodule type.

Maps block nesting modes to Nix type expressions.
-}
applyBlockNestingMode :: SchemaNestingMode -> NExpr -> NExpr
applyBlockNestingMode mode submodule =
  case mode of
    NestingSingle -> submodule
    NestingGroup -> submodule
    NestingList -> nixTypes "listOf" `mkApp` submodule
    NestingSet -> nixTypes "listOf" `mkApp` submodule
    NestingMap -> nixTypes "attrsOf" `mkApp` submodule

{- | Helper function to convert a named block type to an option.

Returns the name and the mkOption expression.
-}
blockTypeToOption :: Text -> SchemaBlockType -> (Text, NExpr)
blockTypeToOption name blockType =
  (name, mkSym "mkOption" `mkApp` optionArg)
  where
    optionArg =
      Fix $
        NSet
          NonRecursive
          (catMaybes [Just typeBinding, defaultBinding])

    typeBinding =
      NamedVar
        (mkSelector "type")
        typeExpr
        nullPos

    typeExpr =
      case blockTypeBlock blockType of
        Just innerBlock ->
          let submodule = blockToSubmodule innerBlock
              nestingMode = fromMaybe NestingSingle (blockTypeNestingMode blockType)
           in applyBlockNestingMode nestingMode submodule
        Nothing -> nixTypes "attrs"

    defaultBinding =
      case blockTypeNestingMode blockType of
        Just NestingList -> Just $ NamedVar (mkSelector "default") (mkList []) nullPos
        Just NestingSet -> Just $ NamedVar (mkSelector "default") (mkList []) nullPos
        Just NestingMap -> Just $ NamedVar (mkSelector "default") (Fix $ NSet NonRecursive []) nullPos
        Just NestingSingle -> Just $ NamedVar (mkSelector "default") mkNull nullPos
        Just NestingGroup -> Nothing
        Nothing -> Just $ NamedVar (mkSelector "default") mkNull nullPos

-- Helper functions

-- | Create the standard module wrapper: { lib, ... }: with lib; { ... }
moduleWrapper :: [Binding NExpr] -> NExpr
moduleWrapper bindings =
  Fix $
    NAbs
      (ParamSet Nothing Variadic [(VarName "lib", Nothing)])
      ( Fix $
          NWith
            (mkSym "lib")
            (Fix $ NSet NonRecursive bindings)
      )

-- | Create a submodule argument: { options = {...}; }
submoduleArg :: [Binding NExpr] -> NExpr
submoduleArg optionBindings =
  Fix $
    NSet
      NonRecursive
      [optionsBinding]
  where
    optionsBinding =
      NamedVar
        (mkSelector "options")
        (Fix $ NSet NonRecursive optionBindings)
        nullPos

-- | Convert attributes to option bindings.
attributesToOptions :: Map Text SchemaAttribute -> [Binding NExpr]
attributesToOptions attrs =
  map (uncurry attrToBinding) (Map.toList attrs)
  where
    attrToBinding name attr =
      NamedVar
        (mkSelector name)
        (buildOption name attr)
        nullPos

-- | Helper to reference types.* from the NixOS module system
nixTypes :: Text -> NExpr
nixTypes name = mkSym "types" `mkSelect` name

-- | Helper to build a select expression (attribute access)
mkSelect :: NExpr -> Text -> NExpr
mkSelect expr attr = Fix $ NSelect Nothing expr (mkSelector attr)
