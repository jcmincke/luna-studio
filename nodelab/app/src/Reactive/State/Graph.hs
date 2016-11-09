{-# LANGUAGE OverloadedStrings #-}

module Reactive.State.Graph
    ( State(..)
    , addConnection
    , addNode
    , connectionIdsContainingNode
    , connectionIdsContainingNodes
    , connectionWidgets
    , connectionWidgetsMap
    , connectionsContainingNode
    , connectionsContainingNodes
    , connectionsMap
    , connections
    , getConnectionNodeIds
    , getConnections
    , getConnectionsMap
    , getNodes
    , getNodesMap
    , hasConnections
    , inputsMap
    , inputsId
    , inputWidgets
    , inputWidgetsMap
    , lookUpConnection
    , nodes
    , nodesMap
    , nodeWidgets
    , nodeWidgetsMap
    , outputs
    , outputsId
    , outputWidget
    , portWidgets
    , portWidgetsMap
    , removeConnections
    , removeNode
    , updateNodes
    ) where

import           Utils.PreludePlus          hiding ((.=))

import           Data.Hashable              (Hashable)
import           Data.HashMap.Strict        (HashMap)
import qualified Data.HashMap.Strict        as HashMap
import           Data.IntMap                (IntMap)
import qualified Data.IntMap                as IntMap
import qualified Data.Map.Strict            as Map
import qualified Data.Set                   as Set
import           Data.UUID.Types            (UUID)

import           Data.Aeson                 hiding ((.:))
import           Empire.API.Data.Connection (Connection (..), ConnectionId)
import qualified Empire.API.Data.Connection as Connection
import           Empire.API.Data.Input      (Input)
import           Empire.API.Data.Node       (Node, NodeId)
import qualified Empire.API.Data.Node       as Node
import           Empire.API.Data.Output     (Output)
import           Empire.API.Data.Port       (InPort, OutPort)
import           Empire.API.Data.PortRef    (AnyPortRef, InPortRef, OutPortRef)
import qualified Empire.API.Data.PortRef    as PortRef
import qualified Empire.API.JSONInstances   ()
import           Object.UITypes             (WidgetId)
import           Reactive.Commands.Command  (Command)


type NodesMap       = HashMap NodeId Node
type ConnectionsMap = HashMap InPortRef Connection


instance (ToJSON b) => ToJSON (HashMap UUID b) where
    toJSON = toJSON . Map.fromList . HashMap.toList
    {-# INLINE toJSON #-}

instance (ToJSON b) => ToJSON  (HashMap AnyPortRef b) where
    toJSON = toJSON . Map.fromList . HashMap.toList
    {-# INLINE toJSON #-}

instance (ToJSON b) => ToJSON  (HashMap InPortRef b) where
    toJSON = toJSON . Map.fromList . HashMap.toList
    {-# INLINE toJSON #-}

instance Default (HashMap a b) where def = HashMap.empty
instance Hashable InPort
instance Hashable OutPort
instance Hashable InPortRef
instance Hashable OutPortRef
instance Hashable AnyPortRef

data State = State { _nodesMap             :: NodesMap
                   , _connectionsMap       :: ConnectionsMap
                   , _inputsId             :: Maybe NodeId
                   , _inputsMap            :: IntMap Input
                   , _outputsId            :: Maybe NodeId
                   , _outputs              :: Maybe Output
                   , _nodeWidgetsMap       :: HashMap NodeId     WidgetId
                   , _connectionWidgetsMap :: HashMap InPortRef  WidgetId
                   , _portWidgetsMap       :: HashMap AnyPortRef WidgetId
                   , _inputWidgetsMap      :: IntMap WidgetId
                   , _outputWidget         :: Maybe WidgetId
                   } deriving (Show, Eq, Generic)

makeLenses ''State

instance ToJSON State
instance Default State where
    def = State def def def def def def def def def def def

connectionToNodeIds :: Connection -> (NodeId, NodeId)
connectionToNodeIds conn = ( conn ^. Connection.src . PortRef.srcNodeId
                           , conn ^. Connection.dst . PortRef.dstNodeId)

nodes :: Getter State [Node]
nodes = to getNodes

nodeWidgets :: Getter State [WidgetId]
nodeWidgets = to $ HashMap.elems . view nodeWidgetsMap

connections :: Getter State [Connection]
connections = to getConnections

connectionWidgets :: Getter State [WidgetId]
connectionWidgets = to $ HashMap.elems . view connectionWidgetsMap

inputWidgets :: Getter State [WidgetId]
inputWidgets = to $ IntMap.elems . view inputWidgetsMap

portWidgets :: Getter State [WidgetId]
portWidgets = to $ HashMap.elems . view portWidgetsMap

getNodes :: State -> [Node]
getNodes = HashMap.elems . getNodesMap

getNodesMap :: State -> NodesMap
getNodesMap = view nodesMap

getConnections :: State -> [Connection]
getConnections = HashMap.elems . getConnectionsMap

getConnectionsMap :: State -> ConnectionsMap
getConnectionsMap = view connectionsMap

getConnectionNodeIds :: ConnectionId -> State -> Maybe (NodeId, NodeId)
getConnectionNodeIds connId state = connectionToNodeIds <$> conn
    where conn = lookUpConnection state connId

updateNodes :: NodesMap -> State -> State
updateNodes newNodesMap state = state & nodesMap .~ newNodesMap

addNode :: Node -> State -> State
addNode newNode state  = state & nodesMap . at (newNode ^. Node.nodeId) ?~ newNode

removeNode :: NodeId -> State -> State
removeNode remNodeId state = state & nodesMap . at remNodeId .~ Nothing

addConnection :: OutPortRef -> InPortRef -> Command State ConnectionId
addConnection sourcePortRef destPortRef = do
    connectionsMap . at destPortRef ?= Connection sourcePortRef destPortRef
    return destPortRef

removeConnections :: [ConnectionId] -> State -> State
removeConnections connIds state = foldr removeConnection state connIds

removeConnection :: ConnectionId -> State -> State
removeConnection connId state = state & connectionsMap . at connId .~ Nothing

lookUpConnection :: State -> ConnectionId -> Maybe Connection
lookUpConnection state connId = HashMap.lookup connId $ getConnectionsMap state

containsNode :: NodeId -> Connection -> Bool
containsNode nid conn = startsWithNode nid conn
                    || endsWithNode   nid conn

startsWithNode :: NodeId -> Connection -> Bool
startsWithNode nid conn = conn ^. Connection.src . PortRef.srcNodeId == nid

endsWithNode :: NodeId -> Connection -> Bool
endsWithNode nid conn = conn ^. Connection.dst . PortRef.dstNodeId == nid

connectionsContainingNode :: NodeId -> State -> [Connection]
connectionsContainingNode nid state = filter (containsNode nid) $ getConnections state

connectionsContainingNodes :: Set.Set NodeId -> State -> [Connection]
connectionsContainingNodes nodeIds state = do
  let connections' = filter ((flip Set.member nodeIds) . (view $ Connection.src . PortRef.srcNodeId)) $ getConnections state
  filter ((flip Set.member nodeIds) . (view $ Connection.dst . PortRef.dstNodeId)) connections'

connectionIdsContainingNode :: NodeId -> State -> [ConnectionId]
connectionIdsContainingNode nid state = (view Connection.connectionId) <$> connectionsContainingNode nid state

connectionIdsContainingNodes :: Set.Set NodeId -> State -> [ConnectionId]
connectionIdsContainingNodes nodeIds state = (view Connection.connectionId) <$> connectionsContainingNodes nodeIds state

hasConnections :: NodeId -> State -> Bool
hasConnections = (not . null) .: connectionsContainingNode
