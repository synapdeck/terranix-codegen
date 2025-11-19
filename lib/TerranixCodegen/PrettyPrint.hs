module TerranixCodegen.PrettyPrint (
  prettyProviderSchemas,
  prettyProviderEntry,
  prettyProviderSchema,
  prettySection,
  prettySectionMaybe,
  prettyMapSection,
  prettyMapSectionMaybe,
  prettyNamedSchema,
  prettyNamedActionSchema,
  prettyNamedFunction,
  prettyNamedIdentity,
  prettySchema,
  prettyActionSchema,
  prettySchemaBlock,
  prettyDescription,
  prettyDescriptionMaybe,
  prettyNamedAttribute,
  prettyAttributeFlags,
  prettyAttributeType,
  prettyAttributeDetails,
  prettyNestedAttributeType,
  prettyNamedBlockType,
  prettySchemaBlockType,
  prettyMinMax,
  prettyMinMaxMaybe,
  prettyFunction,
  prettyParameter,
  prettyIdentity,
  prettyNamedIdentityAttribute,
) where

import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Maybe (catMaybes, fromMaybe)
import Data.Text (Text)
import Data.Text qualified as T
import Data.Word (Word64)
import Prettyprinter
import Prettyprinter.Render.Terminal
import TerranixCodegen.ProviderSchema

-- Helper to combine docs vertically, treating empty strings and mempty as truly empty
vstack :: [Doc AnsiStyle] -> Doc AnsiStyle
vstack [] = emptyDoc
vstack [x] = x
vstack (x : xs) = x <> line <> vstack xs

-- Helper to combine docs vertically, filtering out Nothing values to avoid blank lines
vsepMaybes :: [Maybe (Doc AnsiStyle)] -> Doc AnsiStyle
vsepMaybes = vsep . catMaybes

-- Color scheme
keywordColor :: AnsiStyle
keywordColor = color Blue <> bold

typeColor :: AnsiStyle
typeColor = color Cyan

nameColor :: AnsiStyle
nameColor = color Green <> bold

descColor :: AnsiStyle
descColor = color Yellow

attrColor :: AnsiStyle
attrColor = color Magenta

metaColor :: AnsiStyle
metaColor = colorDull White

errorColor :: AnsiStyle
errorColor = color Red <> bold

-- Pretty print ProviderSchemas
prettyProviderSchemas :: ProviderSchemas -> Doc AnsiStyle
prettyProviderSchemas ps =
  let header = annotate keywordColor "Provider Schemas"
      versionLine = case formatVersion ps of
        Nothing -> Nothing
        Just v -> Just $ indent 2 $ "Format Version:" <+> annotate metaColor (pretty v)
      providersDoc = case schemas ps of
        Nothing -> indent 2 $ annotate metaColor "(no providers)"
        Just provs ->
          if Map.null provs
            then indent 2 $ annotate metaColor "(no providers)"
            else vstack $ map prettyProviderEntry $ Map.toList provs
   in case versionLine of
        Nothing -> vstack [header, emptyDoc, providersDoc]
        Just v -> vstack [header, emptyDoc, v, emptyDoc, providersDoc]

prettyProviderEntry :: (Text, ProviderSchema) -> Doc AnsiStyle
prettyProviderEntry (name, schema) =
  vsep
    [ annotate keywordColor "Provider:" <+> annotate nameColor (pretty name)
    , indent 2 $ prettyProviderSchema schema
    , ""
    ]

-- Pretty print a single ProviderSchema
prettyProviderSchema :: ProviderSchema -> Doc AnsiStyle
prettyProviderSchema schema =
  vsepMaybes
    [ prettySectionMaybe "Configuration" (configSchema schema) prettySchema
    , prettyMapSectionMaybe "Resources" (resourceSchemas schema) prettyNamedSchema
    , prettyMapSectionMaybe "Data Sources" (dataSourceSchemas schema) prettyNamedSchema
    , prettyMapSectionMaybe "Ephemeral Resources" (ephemeralResourceSchemas schema) prettyNamedSchema
    , prettyMapSectionMaybe "Actions" (actionSchemas schema) prettyNamedActionSchema
    , prettyMapSectionMaybe "Functions" (functions schema) prettyNamedFunction
    , prettyMapSectionMaybe "Resource Identities" (resourceIdentitySchemas schema) prettyNamedIdentity
    , prettyMapSectionMaybe "List Resources" (listResourceSchemas schema) prettyNamedSchema
    ]

prettySection :: Text -> Maybe a -> (a -> Doc AnsiStyle) -> Doc AnsiStyle
prettySection _ Nothing _ = mempty
prettySection title (Just val) prettyFunc =
  vsep
    [ annotate keywordColor (pretty title) <> ":"
    , indent 2 $ prettyFunc val
    ]

prettySectionMaybe :: Text -> Maybe a -> (a -> Doc AnsiStyle) -> Maybe (Doc AnsiStyle)
prettySectionMaybe _ Nothing _ = Nothing
prettySectionMaybe title (Just val) prettyFunc =
  Just $
    vsep
      [ annotate keywordColor (pretty title) <> ":"
      , indent 2 $ prettyFunc val
      ]

prettyMapSection :: Text -> Maybe (Map Text a) -> ((Text, a) -> Doc AnsiStyle) -> Doc AnsiStyle
prettyMapSection _ Nothing _ = mempty
prettyMapSection title (Just m) prettyFunc
  | Map.null m = mempty
  | otherwise =
      vsep
        [ annotate keywordColor (pretty title) <> ":"
        , indent 2 $ vsep $ map prettyFunc $ Map.toList m
        ]

prettyMapSectionMaybe :: Text -> Maybe (Map Text a) -> ((Text, a) -> Doc AnsiStyle) -> Maybe (Doc AnsiStyle)
prettyMapSectionMaybe _ Nothing _ = Nothing
prettyMapSectionMaybe title (Just m) prettyFunc
  | Map.null m = Nothing
  | otherwise =
      Just $
        vsep
          [ annotate keywordColor (pretty title) <> ":"
          , indent 2 $ vsep $ map prettyFunc $ Map.toList m
          ]

prettyNamedSchema :: (Text, Schema) -> Doc AnsiStyle
prettyNamedSchema (name, schema) =
  vsep
    [ annotate nameColor (pretty name)
    , indent 2 $ prettySchema schema
    ]

prettyNamedActionSchema :: (Text, ActionSchema) -> Doc AnsiStyle
prettyNamedActionSchema (name, schema) =
  vsep
    [ annotate nameColor (pretty name)
    , indent 2 $ prettyActionSchema schema
    ]

prettyNamedFunction :: (Text, FunctionSignature) -> Doc AnsiStyle
prettyNamedFunction (name, func) =
  vsep
    [ annotate nameColor (pretty name)
    , indent 2 $ prettyFunction func
    ]

prettyNamedIdentity :: (Text, IdentitySchema) -> Doc AnsiStyle
prettyNamedIdentity (name, identity) =
  vsep
    [ annotate nameColor (pretty name)
    , indent 2 $ prettyIdentity identity
    ]

-- Pretty print Schema
prettySchema :: Schema -> Doc AnsiStyle
prettySchema schema =
  vsep
    [ "Version:" <+> annotate metaColor (pretty $ schemaVersion schema)
    , case schemaBlock schema of
        Nothing -> annotate metaColor "(no block definition)"
        Just blk -> prettySchemaBlock blk
    ]

-- Pretty print ActionSchema
prettyActionSchema :: ActionSchema -> Doc AnsiStyle
prettyActionSchema schema =
  case actionSchemaBlock schema of
    Nothing -> annotate metaColor "(no block definition)"
    Just blk -> prettySchemaBlock blk

-- Pretty print SchemaBlock
prettySchemaBlock :: SchemaBlock -> Doc AnsiStyle
prettySchemaBlock blk =
  vsepMaybes
    [ prettyDescriptionMaybe (blockDescription blk) (blockDescriptionKind blk)
    , if fromMaybe False (blockDeprecated blk)
        then Just $ annotate errorColor "⚠ DEPRECATED"
        else Nothing
    , prettyMapSectionMaybe "Attributes" (blockAttributes blk) prettyNamedAttribute
    , prettyMapSectionMaybe "Nested Blocks" (blockNestedBlocks blk) prettyNamedBlockType
    ]

prettyDescription :: Maybe Text -> Maybe SchemaDescriptionKind -> Doc AnsiStyle
prettyDescription Nothing _ = mempty
prettyDescription (Just desc) kind =
  let kindLabel = case kind of
        Just Markdown -> " (markdown)"
        _ -> ""
   in annotate descColor ("Description" <> kindLabel <> ":") <+> align (vsep $ map pretty $ T.lines desc)

prettyDescriptionMaybe :: Maybe Text -> Maybe SchemaDescriptionKind -> Maybe (Doc AnsiStyle)
prettyDescriptionMaybe Nothing _ = Nothing
prettyDescriptionMaybe (Just desc) kind =
  let kindLabel = case kind of
        Just Markdown -> " (markdown)"
        _ -> ""
   in Just $ annotate descColor ("Description" <> kindLabel <> ":") <+> align (vsep $ map pretty $ T.lines desc)

prettyNamedAttribute :: (Text, SchemaAttribute) -> Doc AnsiStyle
prettyNamedAttribute (name, attr) =
  vsep
    [ annotate attrColor (pretty name) <+> prettyAttributeFlags attr <+> prettyAttributeType attr
    , indent 2 $ prettyAttributeDetails attr
    ]

prettyAttributeFlags :: SchemaAttribute -> Doc AnsiStyle
prettyAttributeFlags attr =
  let flags =
        concat
          [ [annotate keywordColor "required" | fromMaybe False (attributeRequired attr)]
          , [annotate metaColor "optional" | fromMaybe False (attributeOptional attr)]
          , [annotate metaColor "computed" | fromMaybe False (attributeComputed attr)]
          , [annotate errorColor "sensitive" | fromMaybe False (attributeSensitive attr)]
          , [annotate errorColor "write-only" | fromMaybe False (attributeWriteOnly attr)]
          , [annotate errorColor "deprecated" | fromMaybe False (attributeDeprecated attr)]
          ]
   in if null flags then mempty else encloseSep "(" ")" ", " flags

prettyAttributeType :: SchemaAttribute -> Doc AnsiStyle
prettyAttributeType attr =
  case (attributeType attr, attributeNestedType attr) of
    (Just ty, _) -> ":" <+> annotate typeColor (pretty $ show ty)
    (_, Just _) -> ":" <+> annotate typeColor "nested"
    _ -> mempty

prettyAttributeDetails :: SchemaAttribute -> Doc AnsiStyle
prettyAttributeDetails attr =
  vsepMaybes
    [ prettyDescriptionMaybe (attributeDescription attr) (attributeDescriptionKind attr)
    , prettyNestedAttributeType <$> attributeNestedType attr
    ]

prettyNestedAttributeType :: SchemaNestedAttributeType -> Doc AnsiStyle
prettyNestedAttributeType nested =
  vsepMaybes
    [ (\mode -> "Nesting:" <+> annotate metaColor (pretty $ show mode)) <$> nestedNestingMode nested
    , prettyMinMaxMaybe (nestedMinItems nested) (nestedMaxItems nested)
    , prettyMapSectionMaybe "Nested Attributes" (nestedAttributes nested) prettyNamedAttribute
    ]

prettyNamedBlockType :: (Text, SchemaBlockType) -> Doc AnsiStyle
prettyNamedBlockType (name, blkType) =
  vsep
    [ annotate attrColor (pretty name)
    , indent 2 $ prettySchemaBlockType blkType
    ]

prettySchemaBlockType :: SchemaBlockType -> Doc AnsiStyle
prettySchemaBlockType blkType =
  vsepMaybes
    [ (\mode -> "Nesting:" <+> annotate metaColor (pretty $ show mode)) <$> blockTypeNestingMode blkType
    , prettyMinMaxMaybe (blockTypeMinItems blkType) (blockTypeMaxItems blkType)
    , prettySchemaBlock <$> blockTypeBlock blkType
    ]

prettyMinMax :: Maybe Word64 -> Maybe Word64 -> Doc AnsiStyle
prettyMinMax Nothing Nothing = mempty
prettyMinMax (Just minV) Nothing = "Min items:" <+> annotate metaColor (pretty minV)
prettyMinMax Nothing (Just maxV) = "Max items:" <+> annotate metaColor (pretty maxV)
prettyMinMax (Just minV) (Just maxV) =
  "Items:" <+> annotate metaColor (pretty minV <+> "to" <+> pretty maxV)

prettyMinMaxMaybe :: Maybe Word64 -> Maybe Word64 -> Maybe (Doc AnsiStyle)
prettyMinMaxMaybe Nothing Nothing = Nothing
prettyMinMaxMaybe (Just minV) Nothing = Just $ "Min items:" <+> annotate metaColor (pretty minV)
prettyMinMaxMaybe Nothing (Just maxV) = Just $ "Max items:" <+> annotate metaColor (pretty maxV)
prettyMinMaxMaybe (Just minV) (Just maxV) =
  Just $ "Items:" <+> annotate metaColor (pretty minV <+> "to" <+> pretty maxV)

-- Pretty print Function
prettyFunction :: FunctionSignature -> Doc AnsiStyle
prettyFunction func =
  vsepMaybes
    [ (\desc -> annotate descColor "Description:" <+> align (vsep $ map pretty $ T.lines desc)) <$> functionSignatureDescription func
    , (\summary -> annotate descColor "Summary:" <+> align (vsep $ map pretty $ T.lines summary)) <$> functionSignatureSummary func
    , (\msg -> annotate errorColor "⚠ DEPRECATED:" <+> pretty msg) <$> functionSignatureDeprecationMessage func
    , (\params -> vsep ["Parameters:", indent 2 $ vsep $ map prettyParameter params]) <$> functionSignatureParameters func
    , (\param -> vsep ["Variadic Parameter:", indent 2 $ prettyParameter param]) <$> functionSignatureVariadicParameter func
    , Just $ "Returns:" <+> annotate typeColor (pretty $ show $ functionSignatureReturnType func)
    ]

prettyParameter :: FunctionParameter -> Doc AnsiStyle
prettyParameter param =
  let nameDoc = annotate attrColor $ pretty $ fromMaybe "<unnamed>" (functionParameterName param)
      typeDoc = ":" <+> annotate typeColor (pretty $ show $ functionParameterType param)
      nullableDoc =
        if fromMaybe False (functionParameterIsNullable param)
          then annotate metaColor "(nullable)"
          else mempty
      descDoc = case functionParameterDescription param of
        Nothing -> mempty
        Just desc -> "—" <+> annotate descColor (pretty desc)
   in hsep [nameDoc, typeDoc, nullableDoc, descDoc]

-- Pretty print Identity
prettyIdentity :: IdentitySchema -> Doc AnsiStyle
prettyIdentity identity =
  vsep
    [ "Version:" <+> annotate metaColor (pretty $ identitySchemaVersion identity)
    , case identitySchemaAttributes identity of
        Nothing -> annotate metaColor "(no attributes)"
        Just attrs ->
          vsep
            [ "Attributes:"
            , indent 2 $ vsep $ map prettyNamedIdentityAttribute $ Map.toList attrs
            ]
    ]

prettyNamedIdentityAttribute :: (Text, IdentityAttribute) -> Doc AnsiStyle
prettyNamedIdentityAttribute (name, attr) =
  let nameDoc = annotate attrColor $ pretty name
      typeDoc = case identityAttributeType attr of
        Nothing -> mempty
        Just ty -> ":" <+> annotate typeColor (pretty $ show ty)
      flagDoc
        | fromMaybe False (identityAttributeRequiredForImport attr) =
            annotate keywordColor "required"
        | fromMaybe False (identityAttributeOptionalForImport attr) =
            annotate metaColor "optional"
        | otherwise = mempty
      descDoc = indent 2 . annotate descColor . pretty <$> identityAttributeDescription attr
   in vsepMaybes [Just $ hsep [nameDoc, typeDoc, flagDoc], descDoc]
