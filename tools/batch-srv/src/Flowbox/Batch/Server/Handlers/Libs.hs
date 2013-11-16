---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2013
---------------------------------------------------------------------------
module Flowbox.Batch.Server.Handlers.Libs (
    libraries,

    libraryByID,
    createLibrary,
    loadLibrary,
    unloadLibrary,
    storeLibrary,
    buildLibrary,
    runLibrary,
    libraryRootDef,
) 
where

import           Data.Int                                              (Int32)
import           Data.IORef                                            (IORef)
import qualified Data.Vector                                         as Vector
import           Data.Vector                                           (Vector)
import qualified Data.Text.Lazy                                      as Text
import           Data.Text.Lazy                                        (Text)

import           Flowbox.Prelude                                       
import qualified Defs_Types                                          as TDefs
import           Flowbox.Batch.Batch                                   (Batch)
import qualified Flowbox.Batch.Handlers.Libs                         as BatchL
import           Flowbox.Batch.Server.Handlers.Common                  (tRunScript)
import           Flowbox.Control.Error                                 
import qualified Flowbox.Luna.Lib.Library                            as Library
import           Flowbox.Luna.Lib.Library                              (Library)
import qualified Flowbox.Luna.Network.Def.DefManager                 as DefManager
import           Flowbox.Luna.Network.Def.DefManager                   (DefManager)
import           Flowbox.Luna.Tools.Serialize.Thrift.Conversion.Defs   ()
import           Flowbox.Luna.Tools.Serialize.Thrift.Conversion.Libs   ()
import           Flowbox.System.Log.Logger                             
import           Flowbox.Tools.Conversion.Thrift                       
import qualified Libs_Types                                          as TLibs



loggerIO :: LoggerIO
loggerIO = getLoggerIO "Flowbox.Batch.Server.Handlers.Libs"

------ public api -------------------------------------------------

libraries :: IORef Batch -> Maybe Int32 -> IO (Vector TLibs.Library)
libraries batchHandler mtprojectID = tRunScript $ do
    scriptIO $ loggerIO info "called libraries"
    batch     <- tryReadIORef batchHandler
    projectID <- tryGetID mtprojectID "projectID"
    scriptIO $ loggerIO debug $ "projectID: " ++ (show projectID)
    libs      <- tryRight $ BatchL.libraries projectID batch 
    let tlibs       = map (fst . encode) libs
        tlibsVector = Vector.fromList tlibs
    return tlibsVector


libraryByID :: IORef Batch -> Maybe Int32 -> Maybe Int32 -> IO TLibs.Library
libraryByID batchHandler mtlibID mtprojectID = tRunScript $ do
    scriptIO $ loggerIO info "called libraryByID"
    libID     <- tryGetID mtlibID "libID"
    projectID <- tryGetID mtprojectID "projectID"
    batch     <- tryReadIORef batchHandler
    scriptIO $ loggerIO debug $ "libID: " ++ (show libID) ++ " projectID: " ++ (show projectID)
    library   <- tryRight $ BatchL.libraryByID libID projectID batch
    return $ fst $ encode (libID, library)


createLibrary :: IORef Batch -> Maybe TLibs.Library -> Maybe Int32 -> IO TLibs.Library
createLibrary batchHandler mtlibrary mtprojectID = tRunScript $ do
    scriptIO $ loggerIO info "called createLibrary"
    tlibrary     <- mtlibrary <??> "'library' argument is missing" 
    (_, library) <- tryRight (decode (tlibrary, DefManager.empty) :: Either String (Library.ID, Library))
    projectID    <- tryGetID mtprojectID "projectID"
    batch        <- tryReadIORef batchHandler
    let libName = Library.name library
        libPath = Library.path library
    scriptIO $ loggerIO debug $ "library: " ++ (show library) ++ " projectID: " ++ (show projectID)
    (newBatch, newLibrary) <-tryRight $  BatchL.createLibrary libName libPath projectID batch
    tryWriteIORef batchHandler newBatch
    return $ fst $ (encode newLibrary :: (TLibs.Library, DefManager))


loadLibrary :: IORef Batch -> Maybe Text -> Maybe Int32 -> IO TLibs.Library
loadLibrary batchHandler mtpath mtprojectID= tRunScript $ do
    scriptIO $ loggerIO info "called loadLibrary"
    upath     <- tryGetUniPath mtpath "path"
    projectID <- tryGetID mtprojectID "projectID"
    batch     <- tryReadIORef batchHandler
    scriptIO $ loggerIO debug $ "path: " ++ (show upath) ++ " projectID: " ++ (show projectID)
    (newBatch, (newLibID, newLibrary)) <- scriptIO $ BatchL.loadLibrary upath projectID batch
    tryWriteIORef batchHandler newBatch
    return $ fst $ encode (newLibID, newLibrary)


unloadLibrary :: IORef Batch -> Maybe Int32 -> Maybe Int32 -> IO ()
unloadLibrary batchHandler mtlibID mtprojectID = tRunScript $ do
    scriptIO $ loggerIO info "called unloadLibrary"
    libID     <- tryGetID mtlibID "libID"
    projectID <- tryGetID mtprojectID "projectID"
    batch     <- tryReadIORef batchHandler
    scriptIO $ loggerIO debug $ "libID: " ++ (show libID) ++ " projectID: " ++ (show projectID)
    newBatch  <- tryRight $ BatchL.unloadLibrary libID projectID batch 
    tryWriteIORef batchHandler newBatch


storeLibrary :: IORef Batch -> Maybe Int32 -> Maybe Int32 -> IO ()
storeLibrary batchHandler mtlibID mtprojectID = tRunScript $ do
    scriptIO $ loggerIO info "called storeLibrary"
    libID     <- tryGetID mtlibID "libID"
    projectID <- tryGetID mtprojectID "projectID"
    batch     <- tryReadIORef batchHandler
    scriptIO $ loggerIO debug $ "libID: " ++ (show libID) ++ " projectID: " ++ (show projectID)
    scriptIO $ BatchL.storeLibrary libID projectID batch
    return ()


buildLibrary :: IORef Batch -> Maybe Int32 -> Maybe Int32 -> IO ()
buildLibrary batchHandler mtlibID mtprojectID = tRunScript $ do
    scriptIO $ loggerIO info "called buildLibrary"
    libID     <- tryGetID mtlibID "libID"
    projectID <- tryGetID mtprojectID "projectID"
    batch     <- tryReadIORef batchHandler
    scriptIO $ loggerIO debug $ "libID: " ++ (show libID) ++ " projectID: " ++ (show projectID)
    scriptIO $ BatchL.buildLibrary libID projectID batch
    return ()


runLibrary :: IORef Batch -> Maybe Int32 -> Maybe Int32 -> IO Text
runLibrary batchHandler mtlibID mtprojectID = tRunScript $ do
    scriptIO $ loggerIO info "called runLibrary"
    libID     <- tryGetID mtlibID "libID"
    projectID <- tryGetID mtprojectID "projectID"
    batch     <- tryReadIORef batchHandler
    scriptIO $ loggerIO debug $ "libID: " ++ (show libID) ++ " projectID: " ++ (show projectID)
    output <- scriptIO $ BatchL.runLibrary libID projectID batch
    return $ Text.pack output


libraryRootDef :: IORef Batch -> Maybe Int32 -> Maybe Int32 -> IO TDefs.Definition
libraryRootDef batchHandler mtlibID mtprojectID = tRunScript $ do
    scriptIO $ loggerIO info "called libraryRootDef"
    libID     <- tryGetID mtlibID "libID"
    projectID <- tryGetID mtprojectID "projectID"
    batch     <- tryReadIORef batchHandler
    scriptIO $ loggerIO debug $ "libID: " ++ (show libID) ++ " projectID: " ++ (show projectID)
    (arootDefID, rootDef) <- tryRight $ BatchL.libraryRootDef libID projectID batch
    return $ fst $ encode (arootDefID, rootDef)
