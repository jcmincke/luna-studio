---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2013
---------------------------------------------------------------------------
module Flowbox.Batch.Server.Handlers.Common (
	throw',
	tRunScript,
	vector2List,
) where


import           Data.Int                          (Int32)
import           Prelude                         hiding (error)
import           Control.Exception                 (throw)
import           Data.Text.Lazy                    (pack)
import qualified Data.Vector                     as Vector
import           Data.Vector                       (Vector)
                                    
import           Batch_Types                       (ArgumentException(ArgumentException))
import           Flowbox.Control.Error             
import           Flowbox.Tools.Conversion.Thrift   
import           Flowbox.System.Log.Logger         


loggerIO :: LoggerIO
loggerIO = getLoggerIO "Flowbox.Batch.Server.Handlers.Common"


throw' :: String -> c
throw' = throw . ArgumentException . Just . pack


tRunScript :: Script a -> IO a
tRunScript s = do
    e <- runEitherT s
    case e of
        Left  m -> do 
        	loggerIO error m
        	throw' m
        Right a -> return a

vector2List :: Vector Int32 -> [Int]
vector2List = map i32toi . Vector.toList
