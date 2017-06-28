module LunaStudio.Data.PortRef
    ( module LunaStudio.Data.PortRef
    , nodeLoc
    ) where

import           Control.DeepSeq         (NFData)
import           Data.Binary             (Binary)
import           LunaStudio.Data.Node    (NodeId)
import           LunaStudio.Data.NodeLoc (HasNodeLoc (..), NodeLoc)
import qualified LunaStudio.Data.NodeLoc as NodeLoc
import           LunaStudio.Data.Port    (AnyPortId (..), InPortId, OutPortId)
import           Prologue


data InPortRef  = InPortRef  { _dstNodeLoc :: NodeLoc
                             , _dstPortId :: InPortId
                             } deriving (Eq, Generic, NFData, Ord, Show)

data OutPortRef = OutPortRef { _srcNodeLoc :: NodeLoc
                             , _srcPortId :: OutPortId
                             } deriving (Eq, Generic, NFData, Ord, Show)

data AnyPortRef = OutPortRef' OutPortRef | InPortRef' InPortRef deriving (Eq, Generic, NFData, Show)

makeLenses ''AnyPortRef
makePrisms ''AnyPortRef
makeLenses ''OutPortRef
makePrisms ''OutPortRef
makeLenses ''InPortRef
makePrisms ''InPortRef

instance Binary AnyPortRef
instance Binary InPortRef
instance Binary OutPortRef

instance Ord AnyPortRef where
  (InPortRef'  _)  `compare` (OutPortRef' _) = LT
  (OutPortRef' _)  `compare` (InPortRef'  _) = GT
  (InPortRef'  a)  `compare` (InPortRef'  b) = a `compare` b
  (OutPortRef' a)  `compare` (OutPortRef' b) = a `compare` b

instance HasNodeLoc InPortRef  where nodeLoc = dstNodeLoc
instance HasNodeLoc OutPortRef where nodeLoc = srcNodeLoc
instance HasNodeLoc AnyPortRef where
    nodeLoc = lens getNodeLoc setNodeLoc  where
        getNodeLoc (OutPortRef' outPortRef) = outPortRef ^. nodeLoc
        getNodeLoc (InPortRef'  inPortRef)  = inPortRef  ^. nodeLoc
        setNodeLoc (OutPortRef' outPortRef) nl = OutPortRef' $ outPortRef & nodeLoc .~ nl
        setNodeLoc (InPortRef'  inPortRef ) nl = InPortRef'  $ inPortRef  & nodeLoc .~ nl

{-# DEPRECATED nodeId "Use nodeLoc" #-}
nodeId :: Lens' AnyPortRef NodeId
nodeId = nodeLoc . NodeLoc.nodeId

portId :: Lens' AnyPortRef AnyPortId
portId f (OutPortRef' (OutPortRef nl pid)) = OutPortRef' . OutPortRef nl . outPortId' <$> f (OutPortId' pid)
portId f (InPortRef'  (InPortRef  nl pid)) = InPortRef'  . InPortRef  nl . inPortId'  <$> f (InPortId'  pid)

dstNodeId :: Lens' InPortRef NodeId
dstNodeId = dstNodeLoc . NodeLoc.nodeId

srcNodeId :: Lens' OutPortRef NodeId
srcNodeId = srcNodeLoc . NodeLoc.nodeId

toAnyPortRef :: NodeLoc -> AnyPortId -> AnyPortRef
toAnyPortRef nl (InPortId' pid)  = InPortRef'  $ InPortRef  nl pid
toAnyPortRef nl (OutPortId' pid) = OutPortRef' $ OutPortRef nl pid