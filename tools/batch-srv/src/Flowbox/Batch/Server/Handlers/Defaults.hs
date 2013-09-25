---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2013
---------------------------------------------------------------------------
module Flowbox.Batch.Server.Handlers.Defaults (
    nodeDefaults,
    setNodeDefault,
    removeNodeDefault,
) 
where

import           Data.Int                                                    (Int32)
import           Data.IORef                                                  
import qualified Data.HashMap.Strict                                       as HashMap
import           Data.HashMap.Strict                                         (HashMap)
import qualified Data.Map                                                  as Map
import qualified Data.Vector                                               as Vector
import           Data.Vector                                                 (Vector)

import           Flowbox.Prelude                                             
import           Flowbox.Batch.Batch                                         (Batch(..))
import qualified Flowbox.Batch.Handlers.Defaults                           as BatchD
import           Flowbox.Batch.Server.Handlers.Common                        (tRunScript, vector2List)
import           Flowbox.Batch.Tools.Serialize.Thrift.Conversion.GraphView   ()
import           Flowbox.Control.Error                                       
import           Flowbox.Luna.Tools.Serialize.Thrift.Conversion.Graph        ()
import           Flowbox.System.Log.Logger                                   
import           Flowbox.Tools.Conversion                                    
import qualified Graph_Types                                               as TGraph



loggerIO :: LoggerIO
loggerIO = getLoggerIO "Flowbox.Batch.Server.Handlers.Defaults"

------ public api -------------------------------------------------


nodeDefaults :: IORef Batch -> Maybe Int32 -> Maybe Int32 -> Maybe Int32 -> Maybe Int32
             -> IO (HashMap (Vector Int32) TGraph.DefaultValue)
nodeDefaults batchHandler mtnodeID mtdefID mtlibID mtprojectID = tRunScript $ do
    scriptIO $ loggerIO info "called nodeDefaults"
    nodeID    <- tryGetID mtnodeID    "nodeID"
    defID     <- tryGetID mtdefID     "defID"
    libID     <- tryGetID mtlibID     "libID"
    projectID <- tryGetID mtprojectID "projectID"
    batch     <- tryReadIORef batchHandler
    scriptIO $ loggerIO debug $ "nodeID: " ++ (show nodeID) ++ " defID: " ++ (show defID) ++ " libID: " ++ (show libID) ++ " projectID: " ++ (show projectID)
    defaults  <- tryRight $ BatchD.nodeDefaults nodeID defID libID projectID batch
    let encodeMapItem (k, v) = (Vector.fromList $ map itoi32 k, encode v)
        tdefaults = HashMap.fromList $ map encodeMapItem $ Map.toList defaults
    return tdefaults


setNodeDefault :: IORef Batch -> Maybe (Vector Int32) -> Maybe TGraph.DefaultValue
               -> Maybe Int32 -> Maybe Int32 -> Maybe Int32 -> Maybe Int32 -> IO ()
setNodeDefault batchHandler mtdstPort mtvalue mtnodeID mtdefID mtlibID mtprojectID = tRunScript $ do
    scriptIO $ loggerIO info "called setNodeDefault"
    tdstPort  <- mtdstPort <??> "'dstPort' argument is missing"
    let dstPort = vector2List tdstPort
    tvalue    <- mtvalue   <??> "'value' argument is missing"
    value     <- tryRight $ decode tvalue
    nodeID    <- tryGetID mtnodeID    "nodeID"
    defID     <- tryGetID mtdefID     "defID"
    libID     <- tryGetID mtlibID     "libID"
    projectID <- tryGetID mtprojectID "projectID"
    batch     <- tryReadIORef batchHandler
    scriptIO $ loggerIO debug $ "dstPort: " ++ (show dstPort) ++ " value: " ++ (show value) ++ " nodeID: " ++ (show nodeID) ++ " defID: " ++ (show defID) ++ " libID: " ++ (show libID) ++ " projectID: " ++ (show projectID)
    newBatch  <- tryRight $ BatchD.setNodeDefault dstPort value nodeID defID libID projectID batch
    tryWriteIORef batchHandler newBatch


removeNodeDefault :: IORef Batch -> Maybe (Vector Int32)
                  -> Maybe Int32 -> Maybe Int32 -> Maybe Int32 -> Maybe Int32 -> IO ()
removeNodeDefault batchHandler mtdstPort mtnodeID mtdefID mtlibID mtprojectID = tRunScript $ do
    scriptIO $ loggerIO info "called removeNodeDefault"
    tdstPort  <- mtdstPort <??> "'dstPort' argument is missing"
    let dstPort = vector2List tdstPort
    nodeID    <- tryGetID mtnodeID    "nodeID"
    defID     <- tryGetID mtdefID     "defID"
    libID     <- tryGetID mtlibID     "libID"
    projectID <- tryGetID mtprojectID "projectID"   
    batch     <- tryReadIORef batchHandler
    scriptIO $ loggerIO debug $ "dstPort: " ++ (show dstPort) ++ " nodeID: " ++ (show nodeID) ++ " defID: " ++ (show defID) ++ " libID: " ++ (show libID) ++ " projectID: " ++ (show projectID)
    newBatch  <- tryRight $ BatchD.removeNodeDefault dstPort nodeID defID libID projectID batch
    tryWriteIORef batchHandler newBatch
    