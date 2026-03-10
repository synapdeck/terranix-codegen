{- | File Organizer for Terranix Code Generator

This module handles organizing generated Nix modules into a clean directory structure.

Directory structure:
  providers/
  ├── default.nix                # Top-level: imports all providers
  ├── {provider}/
  │   ├── default.nix            # Provider-level: imports provider.nix, resources/, data-sources/
  │   ├── provider.nix           # Provider configuration module
  │   ├── resources/
  │   │   ├── default.nix        # Imports all resources
  │   │   └── {resource}.nix     # Individual resource modules
  │   └── data-sources/
  │       ├── default.nix        # Imports all data sources
  │       └── {datasource}.nix   # Individual data source modules
-}
module TerranixCodegen.FileOrganizer (
  organizeFiles,
  organizeProvider,
  writeResourceModule,
  writeDataSourceModule,
  writeProviderConfigModule,
  generateResourcesDefault,
  generateDataSourcesDefault,
  generateProviderDefault,
  generateTopLevelDefault,
  nixExprToText,
  stripProviderPrefix,
  extractShortName,
) where

import Control.Monad (forM, forM_, unless)
import Data.Foldable (for_)
import Data.Map.Strict qualified as Map
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import Data.Text qualified as T
import Data.Text.IO qualified as TIO
import Nix.Expr.Types (NExpr)
import Nix.Pretty (prettyNix)
import Prettyprinter (defaultLayoutOptions, layoutPretty)
import Prettyprinter.Render.Text (renderStrict)
import System.Directory (createDirectoryIfMissing)
import System.FilePath ((</>))

import TerranixCodegen.ModuleGenerator (generateDataSourceModule, generateProviderModule, generateResourceModule)
import TerranixCodegen.ProviderSchema

{- | Convert a Nix expression (NExpr) to formatted text.

Uses the hnix pretty-printer to generate human-readable Nix code.
-}
nixExprToText :: NExpr -> Text
nixExprToText expr =
  renderStrict $ layoutPretty defaultLayoutOptions $ prettyNix expr

{- | Strip provider prefix from resource/data source names.

Examples:
  "aws_instance" -> "instance"
  "aws_ami" -> "ami"
  "google_compute_instance" -> "compute_instance"

If the name doesn't start with the provider prefix, returns the name as-is.
-}
stripProviderPrefix :: Text -> Text -> Text
stripProviderPrefix providerName name =
  fromMaybe name (T.stripPrefix (providerName <> "_") name)

{- | Extract the short provider name from a full registry path.

The schema JSON uses full registry paths as keys (e.g. @"registry.opentofu.org\/hashicorp\/aws"@),
but terranix uses short names in attribute paths (e.g. @options.provider.aws@).

Examples:

  * @"registry.opentofu.org\/hashicorp\/aws"@ → @"aws"@
  * @"registry.terraform.io\/hashicorp\/google"@ → @"google"@
  * @"aws"@ → @"aws"@
-}
extractShortName :: Text -> Text
extractShortName = snd . T.breakOnEnd "/"

{- | Organize all providers from a ProviderSchemas into a directory structure.

This is the main entry point for the file organizer.
-}
organizeFiles :: FilePath -> ProviderSchemas -> IO ()
organizeFiles outputDir providerSchemas = do
  -- Create base output directory
  createDirectoryIfMissing True outputDir

  case schemas providerSchemas of
    Nothing -> putStrLn "No providers found in schema"
    Just providersMap -> do
      let providerNames = Map.keys providersMap

      -- Process each provider
      forM_ (Map.toList providersMap) $ \(providerName, providerSchema) -> do
        putStrLn $ "Organizing provider: " <> T.unpack providerName
        organizeProvider outputDir providerName providerSchema

      -- Generate top-level default.nix
      generateTopLevelDefault outputDir providerNames

{- | Organize a single provider's modules into directories.

Creates the directory structure and writes all files for one provider.
-}
organizeProvider :: FilePath -> Text -> ProviderSchema -> IO ()
organizeProvider outputDir providerName providerSchema = do
  let shortName = extractShortName providerName
      providerDir = outputDir </> T.unpack providerName
      resourcesDir = providerDir </> "resources"
      dataSourcesDir = providerDir </> "data-sources"

  -- Create directories
  createDirectoryIfMissing True providerDir
  createDirectoryIfMissing True resourcesDir
  createDirectoryIfMissing True dataSourcesDir

  -- Write provider configuration module (if present)
  let hasProvider = case configSchema providerSchema of
        Just _ -> True
        Nothing -> False
  for_ (configSchema providerSchema) $ \schema ->
    writeProviderConfigModule providerDir shortName schema

  -- Write resource modules
  let resources = maybe [] Map.toList (resourceSchemas providerSchema)

  resourceNames <- forM resources $ \(resourceType, schema) -> do
    writeResourceModule resourcesDir shortName resourceType schema
    pure $ stripProviderPrefix shortName resourceType

  -- Write data source modules
  let dataSources = maybe [] Map.toList (dataSourceSchemas providerSchema)

  dataSourceNames <- forM dataSources $ \(dataSourceType, schema) -> do
    writeDataSourceModule dataSourcesDir shortName dataSourceType schema
    pure $ stripProviderPrefix shortName dataSourceType

  -- Generate default.nix files
  unless (null resourceNames) $
    generateResourcesDefault resourcesDir resourceNames

  unless (null dataSourceNames) $
    generateDataSourcesDefault dataSourcesDir dataSourceNames

  generateProviderDefault providerDir providerName hasProvider (not $ null resourceNames) (not $ null dataSourceNames)

{- | Write a resource module file.

Generates the module using ModuleGenerator and writes it to:
  {outputDir}/{stripped-name}.nix
-}
writeResourceModule :: FilePath -> Text -> Text -> Schema -> IO ()
writeResourceModule outputDir providerName resourceType schema = do
  let expr = generateResourceModule providerName resourceType schema
      nixText = nixExprToText expr
      filename = T.unpack (stripProviderPrefix providerName resourceType) <> ".nix"
      filepath = outputDir </> filename

  TIO.writeFile filepath nixText
  putStrLn $ "  Created resource: " <> filename

{- | Write a data source module file.

Generates the module using ModuleGenerator and writes it to:
  {outputDir}/{stripped-name}.nix
-}
writeDataSourceModule :: FilePath -> Text -> Text -> Schema -> IO ()
writeDataSourceModule outputDir providerName dataSourceType schema = do
  let expr = generateDataSourceModule providerName dataSourceType schema
      nixText = nixExprToText expr
      filename = T.unpack (stripProviderPrefix providerName dataSourceType) <> ".nix"
      filepath = outputDir </> filename

  TIO.writeFile filepath nixText
  putStrLn $ "  Created data source: " <> filename

{- | Write the provider configuration module.

Generates the provider configuration and writes it to:
  {outputDir}/provider.nix
-}
writeProviderConfigModule :: FilePath -> Text -> Schema -> IO ()
writeProviderConfigModule outputDir providerName schema = do
  let expr = generateProviderModule providerName schema
      nixText = nixExprToText expr
      filepath = outputDir </> "provider.nix"

  TIO.writeFile filepath nixText
  putStrLn "  Created provider config: provider.nix"

{- | Generate the default.nix file for resources directory.

Creates an import list of all resource files.
-}
generateResourcesDefault :: FilePath -> [Text] -> IO ()
generateResourcesDefault outputDir resourceNames = do
  let imports = map (\name -> "    ./" <> name <> ".nix") resourceNames
      content =
        T.unlines
          [ "{"
          , "  imports = ["
          , T.intercalate "\n" imports
          , "  ];"
          , "}"
          ]
      filepath = outputDir </> "default.nix"

  TIO.writeFile filepath content
  putStrLn $ "  Created resources/default.nix with " <> show (length resourceNames) <> " imports"

{- | Generate the default.nix file for data-sources directory.

Creates an import list of all data source files.
-}
generateDataSourcesDefault :: FilePath -> [Text] -> IO ()
generateDataSourcesDefault outputDir dataSourceNames = do
  let imports = map (\name -> "    ./" <> name <> ".nix") dataSourceNames
      content =
        T.unlines
          [ "{"
          , "  imports = ["
          , T.intercalate "\n" imports
          , "  ];"
          , "}"
          ]
      filepath = outputDir </> "default.nix"

  TIO.writeFile filepath content
  putStrLn $ "  Created data-sources/default.nix with " <> show (length dataSourceNames) <> " imports"

{- | Generate the provider-level default.nix file.

Imports provider.nix, resources/, and data-sources/ as appropriate.
-}
generateProviderDefault :: FilePath -> Text -> Bool -> Bool -> Bool -> IO ()
generateProviderDefault outputDir _providerName hasProvider hasResources hasDataSources = do
  let imports =
        concat
          [ ["    ./provider.nix" | hasProvider]
          , ["    ./resources" | hasResources]
          , ["    ./data-sources" | hasDataSources]
          ]
      content =
        if null imports
          then "{}"
          else
            T.unlines
              [ "{"
              , "  imports = ["
              , T.intercalate "\n" imports
              , "  ];"
              , "}"
              ]
      filepath = outputDir </> "default.nix"

  TIO.writeFile filepath content
  putStrLn "  Created provider default.nix"

{- | Generate the top-level default.nix file.

Imports all provider directories.
-}
generateTopLevelDefault :: FilePath -> [Text] -> IO ()
generateTopLevelDefault outputDir providerNames = do
  let imports = map ("    ./" <>) providerNames
      content =
        T.unlines
          [ "{"
          , "  imports = ["
          , T.intercalate "\n" imports
          , "  ];"
          , "}"
          ]
      filepath = outputDir </> "default.nix"

  TIO.writeFile filepath content
  putStrLn $ "Created top-level default.nix with " <> show (length providerNames) <> " provider(s)"
