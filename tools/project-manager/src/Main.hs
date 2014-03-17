---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------
module Main where

import qualified Flowbox.Bus.Client               as Client
import qualified Flowbox.Bus.EndPoint             as EP
import qualified Flowbox.Config.Config            as Config
import           Flowbox.Options.Applicative      hiding (info)
import qualified Flowbox.Options.Applicative      as Opt
import           Flowbox.Prelude
import           Flowbox.ProjectManager.Cmd       (Cmd)
import qualified Flowbox.ProjectManager.Cmd       as Cmd
import qualified Flowbox.ProjectManager.Context   as Context
import qualified Flowbox.ProjectManager.Processor as Processor
import qualified Flowbox.ProjectManager.Version   as Version
import           Flowbox.System.Log.Logger



rootLogger :: Logger
rootLogger = getLogger "Flowbox"


parser :: Parser Cmd
parser = Opt.flag' Cmd.Version (long "version" <> hidden)
       <|> Cmd.Run
           <$> optIntFlag (Just "verbose") 'v' 2 3 "Verbose level (level range is 0-5, default level is 3)"
           <*> switch    ( long "no-color"          <> help "Disable color output" )


opts :: ParserInfo Cmd
opts = Opt.info (helper <*> parser)
                (Opt.fullDesc <> Opt.header (Version.full False))


main :: IO ()
main = execParser opts >>= run


run :: Cmd -> IO ()
run cmd = case cmd of
    Cmd.Version  -> putStrLn (Version.full False) -- TODO [PM] hardcoded numeric = False
    Cmd.Run {} -> do
          cfg <- Config.load
          ctx <- Context.mk cfg
          r <- Client.run (EP.clientFromConfig cfg) Processor.topics (Processor.process ctx)
          print r

