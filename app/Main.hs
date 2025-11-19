module Main (main) where

import Data.ByteString.Lazy qualified as BL
import Data.Maybe (fromMaybe)
import Options.Applicative
import Prettyprinter.Render.Terminal (putDoc)
import System.Exit (exitFailure)
import System.IO (hPutStrLn, stderr)

import TerranixCodegen.FileOrganizer
import TerranixCodegen.PrettyPrint
import TerranixCodegen.ProviderSchema

-- | CLI options for terranix-codegen
data Options = Options
  { optInput :: Maybe FilePath
  -- ^ Input schema file (Nothing means stdin)
  , optOutput :: FilePath
  -- ^ Output directory for generated modules
  , optPrintSchema :: Bool
  -- ^ Just print the schema instead of generating modules
  }
  deriving (Show)

-- | Parser for CLI options
optionsParser :: Parser Options
optionsParser =
  Options
    <$> optional
      ( strOption
          ( long "input"
              <> short 'i'
              <> metavar "FILE"
              <> help "Input Terraform provider schema JSON file (default: stdin)"
          )
      )
    <*> strOption
      ( long "output"
          <> short 'o'
          <> metavar "DIR"
          <> value "./providers"
          <> showDefault
          <> help "Output directory for generated Nix modules"
      )
    <*> switch
      ( long "print-schema"
          <> short 'p'
          <> help "Pretty-print the schema instead of generating modules"
      )

-- | Program info for --help
programInfo :: ParserInfo Options
programInfo =
  info
    (optionsParser <**> helper)
    ( fullDesc
        <> progDesc "Generate Terranix modules from Terraform provider schemas"
        <> header "terranix-codegen - Terraform provider to Terranix module generator"
        <> footer footerText
    )
  where
    footerText =
      unlines
        [ ""
        , "Examples:"
        , "  # Generate from stdin"
        , "  terraform providers schema -json | terranix-codegen -o ./modules"
        , ""
        , "  # Generate from file"
        , "  terranix-codegen -i schema.json -o ./modules"
        , ""
        , "  # Use default output directory (./providers)"
        , "  terraform providers schema -json | terranix-codegen"
        , ""
        , "  # Pretty-print schema instead of generating modules"
        , "  terraform providers schema -json | terranix-codegen --print-schema"
        , "  terranix-codegen -i schema.json -p"
        ]

main :: IO ()
main = do
  opts <- execParser programInfo
  generateModules opts

-- | Main generation logic
generateModules :: Options -> IO ()
generateModules opts = do
  -- Read input
  hPutStrLn stderr $ "Reading schema from " <> inputSource
  input <- maybe BL.getContents BL.readFile (optInput opts)

  -- Parse schema
  hPutStrLn stderr "Parsing provider schema..."
  case parseProviderSchemas input of
    Left err -> do
      hPutStrLn stderr $ "Error parsing schema: " <> err
      exitFailure
    Right providerSchemas -> do
      hPutStrLn stderr "Schema parsed successfully"

      if optPrintSchema opts
        then do
          -- Print schema mode
          putDoc $ prettyProviderSchemas providerSchemas
          hPutStrLn stderr "Done"
        else do
          -- Generate and organize files
          hPutStrLn stderr $ "Generating modules to: " <> optOutput opts
          organizeFiles (optOutput opts) providerSchemas
          hPutStrLn stderr "✓ Module generation complete!"
  where
    inputSource = fromMaybe "stdin" (optInput opts)
