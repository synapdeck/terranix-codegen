module Main (main) where

import Data.ByteString.Lazy qualified as BL
import Prettyprinter.Render.Terminal (putDoc)
import System.Environment (getArgs, getProgName)
import System.Exit (exitFailure)
import System.IO (hPutStrLn, stderr)

import TerranixCodegen.PrettyPrint
import TerranixCodegen.ProviderSchema

main :: IO ()
main = do
  args <- getArgs
  case args of
    [] -> do
      -- Read from stdin
      input <- BL.getContents
      processInput input
    [filePath] -> do
      -- Read from file
      input <- BL.readFile filePath
      processInput input
    _ -> do
      progName <- getProgName
      hPutStrLn stderr $ "Usage: " ++ progName ++ " [FILE]"
      hPutStrLn stderr "  Reads and pretty-prints a Terraform provider schema"
      hPutStrLn stderr "  If no FILE is specified, reads from stdin"
      exitFailure

processInput :: BL.ByteString -> IO ()
processInput input = do
  hPutStrLn stderr "Starting parse..."
  case parseProviderSchemas input of
    Left err -> do
      hPutStrLn stderr $ "Error: " ++ err
      exitFailure
    Right ss -> do
      hPutStrLn stderr "Parsed successfully"

      putDoc $ prettyProviderSchemas ss

      hPutStrLn stderr "Done"
