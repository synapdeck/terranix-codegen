module Main (main) where

import CLI.Commands (runCommand)
import CLI.Parser (programInfo)
import Control.Exception (catch)
import Options.Applicative
import System.Exit (exitFailure)
import System.IO (hPutStrLn, stderr)
import TerranixCodegen.TerraformGenerator (TerraformError)

main :: IO ()
main = do
  cmd <- execParser programInfo
  runCommand cmd `catch` handleTerraformError
  where
    handleTerraformError :: TerraformError -> IO ()
    handleTerraformError err = do
      hPutStrLn stderr $ "Error: " <> show err
      exitFailure
