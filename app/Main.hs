module Main (main) where

import CLI.Commands (runCommand)
import CLI.Parser (programInfo)
import Options.Applicative

main :: IO ()
main = do
  cmd <- execParser programInfo
  runCommand cmd
