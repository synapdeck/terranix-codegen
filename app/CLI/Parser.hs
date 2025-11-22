module CLI.Parser (
  programInfo,
)
where

import CLI.Types
import Data.Text qualified as T
import Data.Version (showVersion)
import Options.Applicative
import Paths_terranix_codegen (version)
import Prettyprinter

-- | Parse schema input options (used across multiple commands)
schemaInputParser :: Parser SchemaInput
schemaInputParser =
  fromProvidersFile <|> fromProviderSpecs <|> fromFile
  where
    fromFile =
      FromFile
        <$> optional
          ( strOption
              ( long "input"
                  <> short 'i'
                  <> metavar "FILE"
                  <> help "Input Terraform provider schema JSON file (default: stdin)"
              )
          )

    fromProviderSpecs =
      FromProviderSpecs
        <$> some
          ( T.pack
              <$> strOption
                ( long "provider"
                    <> short 'p'
                    <> metavar "SPEC"
                    <> help "Provider specification (e.g., aws, hashicorp/aws:5.0.0)"
                )
          )

    fromProvidersFile =
      FromProvidersFile
        <$> strOption
          ( long "providers-file"
              <> metavar "FILE"
              <> help "JSON file containing provider specifications"
          )

-- | Parser for the 'generate' subcommand
generateCommand :: Parser Command
generateCommand =
  Generate
    <$> schemaInputParser
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
          <> help "Pretty-print the schema instead of generating modules"
      )

-- | Parser for the 'show' subcommand
showCommand :: Parser Command
showCommand = Show <$> schemaInputParser

-- | Parser for the 'schema' subcommand
schemaCommand :: Parser Command
schemaCommand =
  ExtractSchema
    <$> schemaInputParser
    <*> switch
      ( long "pretty"
          <> short 'P'
          <> help "Pretty-print JSON output (default: compact)"
      )

-- | Parser for all commands
commandParser :: Parser Command
commandParser =
  hsubparser
    ( command
        "generate"
        ( info
            (generateCommand <**> helper)
            (progDesc "Generate Terranix modules from schema or provider specs")
        )
        <> command
          "show"
          ( info
              (showCommand <**> helper)
              (progDesc "Pretty-print provider schema")
          )
        <> command
          "schema"
          ( info
              (schemaCommand <**> helper)
              (progDesc "Extract and print provider schema as JSON")
          )
    )

-- | Program info for --help
programInfo :: ParserInfo Command
programInfo =
  info
    (commandParser <**> helper <**> versionOption)
    ( fullDesc
        <> progDesc "Generate Terranix modules from Terraform provider schemas"
        <> header "terranix-codegen - Terraform provider to Terranix module generator"
        <> footerDoc (Just footerDoc')
    )

-- | Footer documentation with examples
footerDoc' :: Doc ann
footerDoc' =
  vsep
    [ line
    , "Examples:"
    , indent 2 $
        vsep
          [ "# Generate from stdin"
          , "terraform providers schema -json | terranix-codegen generate -o ./modules"
          , line
          , "# Generate from file"
          , "terranix-codegen generate -i schema.json -o ./modules"
          , line
          , "# Generate from provider specs"
          , "terranix-codegen generate -p aws -p google -o ./modules"
          , "terranix-codegen generate -p hashicorp/aws:5.0.0 -o ./modules"
          , line
          , "# Pretty-print schema from provider spec"
          , "terranix-codegen show -p aws"
          , line
          , "# Extract schema JSON from provider specs"
          , "terranix-codegen schema -p aws -p google > schema.json"
          , "terranix-codegen schema -p aws --pretty > schema.json"
          ]
    ]

-- | Version option parser
versionOption :: Parser (a -> a)
versionOption =
  infoOption
    (showVersion version)
    ( long "version"
        <> short 'v'
        <> help "Show version information"
        <> hidden
    )
