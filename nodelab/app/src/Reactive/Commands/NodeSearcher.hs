{-# LANGUAGE OverloadedStrings #-}
module Reactive.Commands.NodeSearcher where


import           Data.Map                                        (Map)
import qualified Data.Map                                        as Map
import qualified Data.Text.Lazy                                  as Text
import           Utils.PreludePlus
import           Utils.Vector

import qualified JS.NodeSearcher                                 as UI

import qualified Batch.Workspace                                 as Workspace
import qualified Event.Keyboard                                  as Keyboard
import qualified Event.NodeSearcher                              as NodeSearcher
import qualified Object.Node                                     as Node
import qualified Object.Widget                                   as Widget
import qualified Object.Widget.Node                              as NodeModel

import           Reactive.Commands.Command                       (Command, performIO)
import           Reactive.Commands.RegisterNode                  (registerNode)
import           Reactive.Commands.Selection                     (selectedNodes)
import           Reactive.Commands.UpdateNode                    ()
import           Reactive.State.Global                           (inRegistry)
import qualified Reactive.State.Global                           as Global
import qualified Reactive.State.Graph                            as Graph
import qualified Reactive.State.UIRegistry                       as UIRegistry

import qualified Empire.API.Data.Node                            as Node
import           Empire.API.Data.NodeSearcher                    (Item (..), LunaModule (..), _Module)
import qualified Empire.API.Data.Port                            as Port
import qualified Empire.API.Data.ValueType                       as ValueType
import qualified Reactive.Plugins.Core.Action.NodeSearcher.Scope as Scope

searcherData :: Command Global.State LunaModule
searcherData = use $ Global.workspace . Workspace.nodeSearcherData

openFresh :: Command Global.State ()
openFresh = do
    mousePos <- use Global.mousePos
    performIO $ UI.initNodeSearcher "" 0 mousePos False

globalFunctions :: LunaModule -> LunaModule
globalFunctions (LunaModule items) = LunaModule $ Map.filter (== Function) items

scopedData :: Command Global.State LunaModule
scopedData = do
    completeData <- searcherData
    selected   <- inRegistry selectedNodes
    scope <- case selected of
            []     -> return Nothing
            [wf]   -> do
                let nodeId = wf ^. Widget.widget . NodeModel.nodeId
                vt <- preuse $ Global.graph . Graph.nodes . ix nodeId . Node.ports . ix (Port.OutPortId Port.All) . Port.valueType
                performIO $ putStrLn $ show vt
                return $ case vt of
                    Nothing -> Nothing
                    Just vt -> case vt of
                        ValueType.AnyType -> Nothing
                        ValueType.TypeIdent ti -> Just ti
            (_:_) -> return Nothing
    performIO $ putStrLn $ show scope
    case scope of
        Nothing -> return completeData
        Just tn -> do
            let (LunaModule gf) = globalFunctions completeData
                (LunaModule items) = completeData
                tn' = if Text.isPrefixOf "List" (Text.pack tn) then "List" else (Text.pack tn)
                mayScope = items ^? ix tn' . _Module
                scope = fromMaybe (LunaModule mempty) mayScope
                (LunaModule scopefuns) = globalFunctions scope
                overallScope = LunaModule $ Map.union scopefuns gf
            performIO $ putStrLn $ show overallScope
            return overallScope


querySearch :: Text -> Command Global.State ()
querySearch query = do
    sd <- scopedData
    let items = Scope.searchInScope False sd query
    performIO $ UI.displayQueryResults items

queryTree :: Text -> Command Global.State ()
queryTree query = do
    sd <- scopedData
    let items = Scope.moduleItems False sd query
    performIO $ UI.displayTreeResults items

openCommand :: Command Global.State ()
openCommand = do
    mousePos <- use Global.mousePos
    performIO $ UI.initNodeSearcher "" 0 mousePos True