module Empire.Commands.GraphBuilder where

import           Prologue

import           Control.Monad.State
import           Control.Monad.Error          (throwError)

import qualified Data.IntMap                  as IntMap
import           Data.Map                     (Map)
import qualified Data.Map                     as Map
import           Data.Maybe                   (catMaybes, fromMaybe, maybeToList)
import qualified Data.Text.Lazy               as Text
import           Data.Record                  (ANY (..), caseTest, of')
import           Data.Layer.Cover             (uncover)
import           Data.Graph                   (source)
import           Data.Prop                    (prop)

import           Empire.Data.Graph            (Graph)
import qualified Empire.Data.Graph            as Graph

import           Empire.API.Data.DefaultValue (PortDefault (..), Value (..))
import qualified Empire.API.Data.Graph        as API
import           Empire.API.Data.Node         (NodeId)
import qualified Empire.API.Data.Node         as API
import           Empire.API.Data.NodeMeta     (NodeMeta (..))
import           Empire.API.Data.Port         (InPort (..), OutPort (..), Port (..), PortId (..), PortState (..))
import           Empire.API.Data.PortRef      (InPortRef (..), OutPortRef (..))
import           Empire.API.Data.ValueType    (ValueType (..))

import           Empire.Data.AST              (NodeRef, EdgeRef)
import           Empire.ASTOp                 (ASTOp, runASTOp)
import qualified Empire.ASTOps.Builder        as ASTBuilder
import qualified Empire.ASTOps.Print          as Print
import qualified Empire.Commands.AST          as AST
import qualified Empire.Commands.GraphUtils   as GraphUtils
import           Empire.Empire

import           Luna.Syntax.AST.Term         (Acc (..), App (..), Blank (..), Match (..), Var (..), Cons (..))
import qualified Luna.Syntax.AST.Lit          as Lit
import qualified Luna.Syntax.Builder          as Builder
import           Luna.Syntax.Builder          (Type (..))


buildGraph :: Command Graph API.Graph
buildGraph = API.Graph <$> buildNodes <*> buildConnections

buildNodes :: Command Graph [API.Node]
buildNodes = do
    allNodeIds <- uses Graph.nodeMapping IntMap.keys
    mapM buildNode allNodeIds

buildNode :: NodeId -> Command Graph API.Node
buildNode nid = do
    ref   <- GraphUtils.getASTTarget nid
    uref  <- GraphUtils.getASTPointer nid
    expr  <- zoom Graph.ast $ runASTOp $ Print.printNodeExpression ref
    meta  <- zoom Graph.ast $ AST.readMeta uref
    name  <- getNodeName nid
    ports <- buildPorts ref
    let portMap = Map.fromList $ flip fmap ports $ \p@(Port id _ _) -> (id, p)
    return $ API.Node nid (Text.pack name) (API.ExpressionNode $ Text.pack expr) portMap $ fromMaybe def meta

getNodeName :: NodeId -> Command Graph String
getNodeName nid = do
    vref <- GraphUtils.getASTVar nid
    zoom Graph.ast $ runASTOp $ do
        vnode <- Builder.read vref
        caseTest (uncover vnode) $ of' $ \(Var n) -> return . toString $ n

getPortState :: ASTOp m => NodeRef -> m PortState
getPortState ref = do
    isConnected <- ASTBuilder.isGraphNode ref
    if isConnected then return Connected else do
        node <- Builder.read ref
        caseTest (uncover node) $ do
            of' $ \(Lit.String s)   -> return . WithDefault . Constant . StringValue $ s
            of' $ \(Lit.Number _ n) -> return . WithDefault . Constant $ case n of
                Lit.Integer  i -> IntValue $ fromIntegral i
                Lit.Rational r -> RationalValue r
            of' $ \Blank   -> return NotConnected
            of' $ \ANY     -> Print.printExpression ref >>= return . WithDefault . Expression

buildPort :: ASTOp m => (PortId, NodeRef) -> m Port
buildPort (portId, ref) = Port portId AnyType <$> getPortState ref

buildSelfPort :: ASTOp m => NodeRef -> m (Maybe Port)
buildSelfPort nodeRef = do
    node <- Builder.read nodeRef
    caseTest (uncover node) $ do
        of' $ \(Acc _ t) -> Builder.follow source t >>= fmap Just . buildPort . ((,) $ InPortId Self)
        of' $ \(App t _) -> Builder.follow source t >>= buildSelfPort
        of' $ \(Var _)   -> return . Just $ Port (InPortId Self) AnyType NotConnected
        of' $ \ANY       -> return Nothing

getTypeRep :: ASTOp m => NodeRef -> m ValueType
getTypeRep ref = do
    tp <- Builder.follow source =<< Builder.follow (prop Type) ref
    tpNode <- Builder.read tp
    caseTest (uncover tpNode) $ do
        of' $ \(Cons (Lit.String s)) -> return $ TypeIdent s
        of' $ \ANY -> return AnyType

buildPorts :: NodeRef -> Command Graph [Port]
buildPorts ref = zoom Graph.ast $ runASTOp $ do
    args     <- getPositionalNodeRefs ref
    selfPort <- maybeToList <$> buildSelfPort ref
    argPorts <- mapM buildPort $ zip (InPortId . Arg <$> [0..]) args
    tpRep <- getTypeRep ref
    return $ selfPort ++ argPorts ++ [Port (OutPortId All) tpRep NotConnected]

buildConnections :: Command Graph [(OutPortRef, InPortRef)]
buildConnections = do
    allNodes <- uses Graph.nodeMapping IntMap.keys
    edges <- mapM getNodeInputs allNodes
    return $ concat edges

getSelfNodeRef' :: ASTOp m => Bool -> NodeRef -> m (Maybe NodeRef)
getSelfNodeRef' seenAcc nodeRef = do
    node <- Builder.read nodeRef
    caseTest (uncover node) $ do
        of' $ \(Acc _ t) -> Builder.follow source t >>= getSelfNodeRef' True
        of' $ \(App t _) -> Builder.follow source t >>= getSelfNodeRef' seenAcc
        of' $ \ANY       -> return $ if seenAcc then Just nodeRef else Nothing

getSelfNodeRef :: ASTOp m => NodeRef -> m (Maybe NodeRef)
getSelfNodeRef = getSelfNodeRef' False

getPositionalNodeRefs :: ASTOp m => NodeRef -> m [NodeRef]
getPositionalNodeRefs nodeRef = do
    node <- Builder.read nodeRef
    caseTest (uncover node) $ do
        of' $ \(App _ args) -> ASTBuilder.unpackArguments args
        of' $ \ANY          -> return []

getNodeInputs :: NodeId -> Command Graph [(OutPortRef, InPortRef)]
getNodeInputs nodeId = do
    ref         <- GraphUtils.getASTTarget nodeId
    selfMay     <- zoom Graph.ast $ runASTOp $ getSelfNodeRef ref
    selfNodeMay <- case selfMay of
        Just self -> zoom Graph.ast $ runASTOp $ ASTBuilder.getNodeId self
        Nothing   -> return Nothing
    let selfConnMay = (,) <$> (OutPortRef <$> selfNodeMay <*> Just All)
                          <*> (Just $ InPortRef nodeId Self)

    args <- zoom Graph.ast $ runASTOp $ getPositionalNodeRefs ref
    nodeMays <- mapM (zoom Graph.ast . runASTOp . ASTBuilder.getNodeId) args
    let withInd  = zip nodeMays [0..]
        onlyExt  = catMaybes $ (\(n, i) -> (,) <$> n <*> Just i) <$> withInd
        conns    = flip fmap onlyExt $ \(n, i) -> (OutPortRef n All, InPortRef nodeId (Arg i))
    return $ (maybeToList selfConnMay) ++ conns
