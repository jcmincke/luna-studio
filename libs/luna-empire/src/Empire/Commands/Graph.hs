{-# LANGUAGE PartialTypeSignatures #-}
module Empire.Commands.Graph (module Empire.Commands.Graph) where
-- <<<<<<< HEAD
-- import           Empire.Commands.Breadcrumb       (makeGraph, makeGraphCls, zoomBreadcrumb, fileImportPaths)
-- import           Empire.Data.AST                  (InvalidConnectionException (..), EdgeRef, NodeRef, NotInputEdgeException (..),
--                                                    NotUnifyException, PortDoesNotExistException(..), ConnectionException(..),
--                                                    SomeASTException, astExceptionFromException, astExceptionToException)
-- import           Empire.Data.Layers               (SpanLength, SpanOffset)
-- import           Empire.Data.Library              (Library)
-- import           Luna.Syntax.Text.Parser.State.Marker (TermMap(..))
-- import           LunaStudio.Data.Breadcrumb       (Breadcrumb (..), BreadcrumbItem(Redirection, Definition), Named, _Redirection)
-- import           LunaStudio.Data.NodeSearcher     (ImportName, ImportsHints, ClassHints(..), ModuleHints(..))
-- =======

-- import Empire.Commands.Graph.Autolayout as X
-- import Empire.Commands.Graph.Breadcrumb as X
-- import Empire.Commands.Graph.Code       as X
-- import Empire.Commands.Graph.Context    as X
-- import Empire.Commands.Graph.Metadata   as X
-- import Empire.Commands.Graph.NodeMeta   as X

import Empire.Prelude hiding (head)

import qualified Control.Concurrent.MVar.Lifted       as Lifted
import qualified Data.Aeson                           as Aeson
import qualified Data.Aeson.Text                      as Aeson
import qualified Data.Bimap                           as Bimap
import qualified Data.Graph.Data.Component.Vector     as PtrList
import qualified Data.Graph.Data.Layer.Class          as Layer
import qualified Data.Graph.Store                     as Store
import qualified Data.List                            as List
import qualified Data.List.Split                      as Split
import qualified Data.Map                             as Map
import qualified Data.Mutable.Class                   as Mutable
import qualified Data.Set                             as Set
import qualified Data.Text                            as Text
import qualified Data.Text.Encoding                   as Text
import qualified Data.Text.Lazy                       as TL
import qualified Data.Text.IO                         as Text
import qualified Data.Text.Span                       as Span
import qualified Data.UUID.V4                         as UUID (nextRandom)
import qualified Data.Vector.Storable.Foreign         as Foreign
import qualified Empire.ASTOps.BreadcrumbHierarchy    as ASTBreadcrumb
import qualified Empire.ASTOps.Builder                as ASTBuilder
import qualified Empire.ASTOps.Modify                 as ASTModify
import qualified Empire.ASTOps.Parse                  as ASTParse
import qualified Empire.ASTOps.Print                  as ASTPrint
import qualified Empire.ASTOps.Read                   as ASTRead
import qualified Empire.Commands.AST                  as AST
import qualified Empire.Commands.Autolayout           as Autolayout
import qualified Empire.Commands.Code                 as Code
import qualified Empire.Commands.GraphBuilder         as GraphBuilder
import qualified Empire.Commands.GraphUtils           as GraphUtils
import qualified Empire.Commands.Library              as Library
import qualified Empire.Commands.Publisher            as Publisher
import qualified Empire.Commands.Typecheck            as Typecheck
import qualified Empire.Data.BreadcrumbHierarchy      as BH
import qualified Empire.Data.FileMetadata             as FileMetadata
import qualified Empire.Data.Graph                    as Graph
import qualified Empire.Data.Library                  as Library
import qualified Luna.IR                              as IR
import qualified Luna.IR.Term.Ast.Class               as Term
import qualified Luna.Package                         as Package
import qualified Luna.Pass.Scheduler                  as Scheduler
import qualified Luna.Pass.Sourcing.Data.Class        as Class
import qualified Luna.Pass.Sourcing.Data.Def          as Def
import qualified Luna.Pass.Sourcing.Data.Unit         as Unit
import qualified Luna.Pass.Sourcing.UnitLoader        as ModLoader
import qualified Luna.Pass.Sourcing.UnitMapper        as UnitMapper
import qualified Luna.Std                             as Std
import qualified Luna.Syntax.Text.Analysis.SpanTree   as SpanTree
import qualified Luna.Syntax.Text.Lexer               as Lexer
import qualified Luna.Syntax.Text.Parser.Ast.CodeSpan as CodeSpan
import qualified LunaStudio.API.Control.Interpreter   as Interpreter
import qualified LunaStudio.Data.Breadcrumb           as Breadcrumb
import qualified LunaStudio.Data.Error                as ErrorAPI
import qualified LunaStudio.Data.Graph                as APIGraph
import qualified LunaStudio.Data.GraphLocation        as GraphLocation
import qualified LunaStudio.Data.Node                 as Node
import qualified LunaStudio.Data.NodeLoc              as NodeLoc
import qualified LunaStudio.Data.NodeMeta             as NodeMeta
import qualified LunaStudio.Data.Port                 as Port
import qualified LunaStudio.Data.PortRef              as PortRef
import qualified LunaStudio.Data.Position             as Position
import qualified LunaStudio.Data.Range                as Range
import qualified Path
import qualified Safe

import Control.Arrow                        ((***))
import Control.Concurrent                   (readMVar, swapMVar)
import Control.Exception.Safe               (tryAny)
import Control.Lens                         (Prism', re, traverseOf_, uses, (^..), (^?!))
import Control.Monad                        (forM)
import Control.Monad.Catch                  (handle, try)
import Control.Monad.State                  hiding (forM_, void, when)
import Data.Char                            (isDigit, isSeparator, isSpace, isUpper)
import Data.Coerce                          (coerce)
-- import Data.Foldable                        (toList)
import Data.List                            (find, nub, sortBy, sortOn, (++), findIndices)
import Data.Map                             (Map)
import Data.Maybe                           (fromMaybe, maybeToList)
import Data.Set                             (Set)
import Data.Text                            (Text)
import Data.Text.Position                   (Delta(..))
import Data.Text.Span                       (SpacedSpan (..), leftSpacedSpan)
import Data.Text.Strict.Lens                (packed)
import Debug
import Empire.ASTOp                         (ASTOp, ClassOp, GraphOp, liftScheduler,
                                             runASTOp, runAliasAnalysis)
import Empire.ASTOps.BreadcrumbHierarchy    (prepareChild)
import Empire.ASTOps.Parse                  (FunctionParsing (..))
import Empire.Commands.Code                 (addExprMapping, getExprMap,
                                             getNextExprMarker, setExprMap)
import Empire.Commands.Breadcrumb
import Empire.Commands.Library
import Empire.Data.AST                      (ConnectionException (..), EdgeRef,
                                             InvalidConnectionException (..),
                                             NodeRef,
                                             NotInputEdgeException (..),
                                             NotUnifyException,
                                             PortDoesNotExistException (..),
                                             SomeASTException,
                                             astExceptionFromException,
                                             astExceptionToException)
import Empire.Data.FileMetadata             (FileMetadata(..), MarkerNodeMeta (MarkerNodeMeta))
import Empire.Data.Graph                    (ClsGraph, Graph)
import Empire.Data.Layers                   (SpanLength, SpanOffset)
import Empire.Data.Library                  (Library)
import Empire.Empire                        as Empire
import GHC.Stack                            (renderStack, whoCreated)
import Luna.Pass.Data.Stage                 (Stage)
import Luna.Syntax.Text.Analysis.SpanTree   (Spanned (Spanned))
import Luna.Syntax.Text.Parser.Ast.CodeSpan (CodeSpan)
import Luna.Syntax.Text.Parser.State.Marker (TermMap(..))
import LunaStudio.Data.Breadcrumb           (Breadcrumb (..), BreadcrumbItem(Definition, Redirection),
                                             _Redirection, Named)
import LunaStudio.Data.Connection           (Connection (..), ConnectionId)
import LunaStudio.Data.Constants            (gapBetweenNodes)
import LunaStudio.Data.GraphLocation        (GraphLocation (..), (|>))
import LunaStudio.Data.Node                 (ExpressionNode (..), NodeId)
import LunaStudio.Data.NodeCache            (NodeCache (..), nodeMetaMap, nodeIdMap)
import LunaStudio.Data.NodeLoc              (NodeLoc (..))
import LunaStudio.Data.NodeMeta             (NodeMeta)
import LunaStudio.Data.Point                (Point)
import LunaStudio.Data.Port                 (InPortId, InPortIndex (..),
                                             getPortNumber)
import LunaStudio.Data.PortDefault          (PortDefault)
import LunaStudio.Data.PortRef              (AnyPortRef (..), InPortRef (..),
                                             OutPortRef (..))
import LunaStudio.Data.Position             (Position)
import LunaStudio.Data.Range                (Range (..))
import LunaStudio.Data.Searcher.Node        (ClassHints (..), LibrariesHintsMap,
                                             LibraryHints (LibraryHints),
                                             LibraryName)
import LunaStudio.Data.TextDiff             (TextDiff (..))


addImports :: GraphLocation -> Set Text -> Empire ()
addImports loc@(GraphLocation file _) modulesToImport = do
    newCode <- withUnit (GraphLocation file def) $ do
        existingImports <- runASTOp getImportsInFile
        let imports = nativeModuleName : "Std.Base" : existingImports
        let neededImports = filter (`notElem` imports) $ toList modulesToImport
        code <- use Graph.code
        let newImports = map (\i -> Text.concat ["import ", i, "\n"]) neededImports
        return $ Text.concat $ newImports ++ [code]
    reloadCode loc newCode
    typecheckWithRecompute loc
    -- qualName <- Typecheck.filePathToQualName file
    -- withUnit (GraphLocation file def) $ do
    --     modulesMVar <- view modules
    --     importPaths <- liftIO $ getImportPaths loc
    --     Lifted.modifyMVar modulesMVar $ \cmpModules -> do
    --         res <- runModuleTypecheck qualName importPaths cmpModules
    --         case res of
    --             Left err                          -> liftIO (print err) >> return (cmpModules, ())
    --             Right (newImports, newCmpModules) -> return (newCmpModules, ())


addNode :: GraphLocation -> NodeId -> Text -> NodeMeta -> Empire ExpressionNode
addNode = addNodeCondTC True

addNodeCondTC :: Bool -> GraphLocation -> NodeId -> Text -> NodeMeta -> Empire ExpressionNode
addNodeCondTC tc loc@(GraphLocation f _) uuid expr meta
    | GraphLocation _ (Breadcrumb []) <- loc = do
        node <- addFunNode loc AppendNone uuid expr meta
        when_ (isJust $ node ^. Node.toEnter) $ do
            withGraph (loc |> Breadcrumb.Definition (node ^. Node.nodeId)) $
                let noIndent = 0
                in runASTOp $ ASTBuilder.ensureFunctionIsValid noIndent
        resendCode loc
        return node
    | otherwise = do
        let runner = if tc then withTC loc False else withGraph loc
        (node, indent) <- runner $ do
            node   <- addNodeNoTC loc uuid expr Nothing meta
            indent <- runASTOp Code.getCurrentIndentationLength
            return (node, indent)
        when_ (isJust $ node ^. Node.toEnter) $ do
            withGraph (loc |> Breadcrumb.Lambda (node ^. Node.nodeId)) $
                runASTOp $ ASTBuilder.ensureFunctionIsValid indent
        resendCode loc
        return node

findPreviousFunction :: NodeMeta -> [NodeRef] -> ClassOp (Maybe NodeRef)
findPreviousFunction newMeta functions = do
    functionWithPositions <- forM functions $ \fun -> do
        meta <- fromMaybe def <$> AST.readMeta fun
        return (fun, Position.toTuple $ meta ^. NodeMeta.position)
    let newMetaX = newMeta ^. NodeMeta.position . Position.x
        functionsToTheLeft = filter (\(f, (x, y)) -> x < newMetaX) functionWithPositions
        nearestNode = Safe.headMay $ reverse $ sortOn (view $ _2 . _1) functionsToTheLeft
    return $ fmap (view _1) nearestNode

putNewFunctionRef :: EdgeRef -> Maybe NodeRef -> [EdgeRef] -> ClassOp [EdgeRef]
putNewFunctionRef newFunction Nothing                    functions  = return (newFunction : functions)
putNewFunctionRef newFunction (Just _)                   []         = return [newFunction]
putNewFunctionRef newFunction pf@(Just previousFunction) (fun:funs) = do
    fun' <- source fun
    if fun' == previousFunction
        then return (fun:newFunction:funs)
        else putNewFunctionRef newFunction pf funs >>= return . (fun:)

insertFunAfter :: Maybe NodeRef -> NodeRef -> Text -> ClassOp Int
insertFunAfter previousFunction function code = do
    let defaultFunSpace = 2
    case previousFunction of
        Nothing -> do
            unit <- use Graph.clsClass
            funs <- ASTRead.unitDefinitions unit
            let firstFunction = Safe.headMay funs
            funBlockStart <- case firstFunction of
                Just fun -> Code.functionBlockStartRef fun
                _        -> Code.functionBlockStartRef =<< ASTRead.classFromUnit unit
            (off, off') <- case firstFunction of
                Just firstFun -> do
                    LeftSpacedSpan (SpacedSpan off len) <- view CodeSpan.realSpan <$> getLayer @CodeSpan firstFun
                    off' <- if (off /= 0) then return off else do
                        putLayer @CodeSpan firstFun $ CodeSpan.mkRealSpan (LeftSpacedSpan (SpacedSpan defaultFunSpace len))
                        return defaultFunSpace
                    return (off, off')
                Nothing     -> return (defaultFunSpace, 0)
            let indentedCode = (if (isNothing firstFunction && funBlockStart /= 0)
                                then Text.replicate (fromIntegral off) "\n"
                                else "")
                             <> code
                             <> Text.replicate (fromIntegral off') "\n"
            Code.insertAt funBlockStart indentedCode
            LeftSpacedSpan (SpacedSpan _ funLen) <- view CodeSpan.realSpan <$> getLayer @CodeSpan function
            let newOffset = if funBlockStart == 0 then 0 else off
            putLayer @CodeSpan function $ CodeSpan.mkRealSpan (LeftSpacedSpan (SpacedSpan newOffset funLen))
            return $ Text.length indentedCode
        Just pf -> do
            funBlockStart <- Code.functionBlockStartRef pf
            LeftSpacedSpan (SpacedSpan off len) <- view CodeSpan.realSpan <$> getLayer @CodeSpan pf
            let indentedCode = Text.replicate (fromIntegral defaultFunSpace) "\n" <> code
            Code.insertAt (funBlockStart+len) indentedCode
            LeftSpacedSpan (SpacedSpan _ funLen) <- view CodeSpan.realSpan <$> getLayer @CodeSpan function
            putLayer @CodeSpan function $ CodeSpan.mkRealSpan (LeftSpacedSpan (SpacedSpan defaultFunSpace funLen))
            return $ Text.length indentedCode

addFunNode :: GraphLocation -> FunctionParsing -> NodeId -> Text -> NodeMeta -> Empire ExpressionNode
addFunNode loc parsing uuid expr meta = withUnit loc $ do
    (parse, code) <- ASTParse.runFunHackParser expr parsing
    (name, markedFunction, markedCode) <- runASTOp $ do
        name <- ASTRead.cutThroughDocAndMarked parse >>= \x -> matchExpr x $ \case
            ASGFunction n _ _ -> do
                name <- handle
                    (\(_e::ASTRead.InvalidNameException) -> return "") $
                        ASTRead.getVarName' =<< source n
                return $ nameToString name
            a -> error (show a <> " " <> convert expr)
        index  <- getNextTopLevelMarker
        marker <- IR.marker index
        let markerText = Code.makeMarker index
            markerLen  = convert $ Text.length markerText
        putLayer @CodeSpan marker $ CodeSpan.mkRealSpan (LeftSpacedSpan (SpacedSpan 0 markerLen))
        markedNode <- IR.marked' marker parse
        when (meta /= def) $ AST.writeMeta markedNode meta
        Graph.clsCodeMarkers . at index ?= generalize markedNode
        putLayer @CodeSpan markedNode $ CodeSpan.mkRealSpan (LeftSpacedSpan (SpacedSpan 0 (markerLen + convert (Text.length code))))
        let markedCode = Text.concat [markerText, code]
        return (name, generalize markedNode, markedCode)
    unit <- use $ Graph.userState . Graph.clsClass
    (insertedCharacters, codePosition) <- runASTOp $ do
        funs <- ASTRead.unitDefinitions unit
        previousFunction <- findPreviousFunction meta funs
        insertedCharacters <- insertFunAfter previousFunction markedFunction markedCode
        cls' <- ASTRead.classFromUnit unit
        Just (cls'' :: Expr (ClsASG)) <- narrowTerm cls'
        l <- coerce <$> link markedFunction cls''
        matchExpr cls' $ \case
            ClsASG _ _ _ _ decls -> do
                links <- coerce <$> ptrListToList decls
                newFuns <- putNewFunctionRef l previousFunction links
                l <- PtrList.fromList (coerce newFuns)
                IR.UniTermRecord a <- Layer.read @IR.Model cls''
                let a' = a & IR.decls_Record .~ l
                Layer.write @IR.Model cls'' $ IR.UniTermRecord a'
        codePosition       <- Code.functionBlockStartRef markedFunction
        return (fromIntegral insertedCharacters, codePosition)

    Graph.userState . Graph.clsFuns . traverse . Graph._FunctionDefinition . Graph.funGraph . Graph.fileOffset %= (\off -> if off >= codePosition then off + insertedCharacters else off)
    (uuid', graph) <- makeGraphCls markedFunction Nothing (Just uuid)

    runASTOp $ GraphBuilder.buildClassNode uuid' graph

addNodeNoTC :: GraphLocation -> NodeId -> Text -> Maybe Text -> NodeMeta -> Command Graph ExpressionNode
addNodeNoTC loc uuid input name meta = do
    let propInput = Text.strip input
    parse <- ASTParse.parseExpr propInput
    expr <- runASTOp $ do
        indent <- Code.getCurrentIndentationLength
        ASTBuilder.ensureFunctionIsValid indent
        Code.propagateLengths parse
        (parsedNode, newName) <- AST.addNode uuid name (generateNodeName parse) parse
        index        <- getNextExprMarker
        marker       <- IR.marker index
        putLayer @SpanLength marker $ convert $ Text.length $ Code.makeMarker index
        markedNode   <- IR.marked' marker parsedNode
        [l, r]       <- inputs markedNode
        putLayer @SpanOffset l 0
        putLayer @SpanOffset r 0
        addExprMapping index markedNode
        let textExpr = Code.makeMarker index <> maybe mempty (<> " = ") newName <> propInput
        let nodeSpan = fromIntegral $ Text.length textExpr
        putLayer @SpanLength markedNode nodeSpan
        putInSequence markedNode textExpr meta
        putIntoHierarchy uuid markedNode
        return markedNode
    runAliasAnalysis
    node <- runASTOp $ do
        putChildrenIntoHierarchy uuid expr
        AST.writeMeta expr meta
        GraphBuilder.buildNode uuid
    return node

addNodeWithConnection :: GraphLocation -> NodeLoc -> Text -> NodeMeta -> Maybe NodeId -> Empire ExpressionNode
addNodeWithConnection location nl@(NodeLoc _ nodeId) expression nodeMeta connectTo = do
    node <- addNodeCondTC False location nodeId expression nodeMeta
    for_ connectTo $ \nid -> do
        handle (\(e :: SomeASTException) -> return ()) $ do
            pattern <- withGraph location $ runASTOp $ ASTRead.nodeIsPatternMatch nid
            when pattern $ throwM InvalidConnectionException
            let firstWord = unsafeHead $ Text.words expression
            let shouldConnectToArg w = isUpper (Text.head w)
                ports = node ^.. Node.inPorts . traverse . Port.portId
                selfs = filter (\a -> all (== Self) a && not (null a)) ports
                longestSelfChain = Safe.headDef [Self] $ reverse $ sortBy (compare `on` length) selfs
                port = if shouldConnectToArg firstWord then [Arg 0] else longestSelfChain
            void $ connectCondTC False location (OutPortRef (convert nid) mempty) (InPortRef' $ InPortRef nl port)
            withGraph location $ runASTOp $ autolayoutNodesAST [nodeId]
    typecheck location
    return node

findPreviousSeq :: NodeRef -> Set.Set NodeRef -> GraphOp (Maybe NodeRef)
findPreviousSeq seq nodesToTheLeft = matchExpr seq $ \case
    Seq l r -> do
        l' <- source l
        r' <- source r
        if Set.member r' nodesToTheLeft then return (Just r') else findPreviousSeq l' nodesToTheLeft
    _ -> return $ if Set.member seq nodesToTheLeft then Just seq else Nothing

findPreviousNodeInSequence :: NodeRef -> NodeMeta -> [(NodeRef, NodeMeta)] -> GraphOp (Maybe NodeRef)
findPreviousNodeInSequence seq meta nodes = do
    let position           = Position.toTuple $ view NodeMeta.position meta
        nodesWithPositions = map (\(n, m) -> (n, Position.toTuple $ m ^. NodeMeta.position)) nodes
        nodesToTheLeft     = filter (\(n, (x, y)) -> x <= fst position) nodesWithPositions
    findPreviousSeq seq (Set.fromList $ map fst nodesToTheLeft)

findM :: Monad m => (a -> m Bool) -> [a] -> m (Maybe a)
findM p [] = return Nothing
findM p (x:xs) = do
     b <- p x
     if b then return (Just x) else findM p xs

setSeqOffsets :: NodeRef -> Delta -> Delta -> GraphOp ()
setSeqOffsets node loff roff = do
    [l, r] <- inputs node
    putLayer @SpanOffset l loff
    putLayer @SpanOffset r roff

insertAfter :: NodeRef -> Maybe NodeRef -> NodeRef -> Delta -> Text -> GraphOp (NodeRef, Bool)
insertAfter s after new textBeginning code = do
    indentBy <- Code.getCurrentIndentationLength
    matchExpr s $ \case
        Seq l r -> do
            rt <- source r
            if Just rt == after
                then do
                    Code.insertAt (fromIntegral textBeginning) ("\n" <> Text.replicate (fromIntegral indentBy) " " <> code)
                    newSeq <- generalize <$> IR.seq s new
                    putLayer @SpanLength newSeq =<< getLayer @SpanLength s
                    setSeqOffsets newSeq 0 (indentBy + 1)
                    return (newSeq, True)
                else do
                    lt     <- source l
                    rlen   <- getLayer @SpanLength rt
                    roff   <- getLayer @SpanOffset r
                    (res, shouldUpdate) <- insertAfter lt after new (textBeginning - rlen - roff) code
                    when shouldUpdate (replaceSource res $ coerce l)
                    return (res, False)
        _ -> do
            if after == Just s
                then do
                    Code.insertAt (fromIntegral textBeginning) ("\n" <> Text.replicate (fromIntegral indentBy) " " <> code)
                    newSeq <- generalize <$> IR.seq s new
                    putLayer @SpanLength newSeq =<< getLayer @SpanLength s
                    setSeqOffsets newSeq 0 (indentBy + 1)
                    return (newSeq, True)
                else do
                    slen <- getLayer @SpanLength s
                    Code.insertAt (fromIntegral $ textBeginning - slen) (code <> "\n" <> Text.replicate (fromIntegral indentBy) " ")
                    newSeq <- generalize <$> IR.seq new s
                    putLayer @SpanLength newSeq =<< getLayer @SpanLength s
                    setSeqOffsets newSeq 0 (indentBy + 1)
                    return (newSeq, True)

insertAfterAndUpdate :: NodeRef -> Maybe NodeRef -> NodeRef -> Delta -> Text -> GraphOp ()
insertAfterAndUpdate s after new textBeginning code = do
    (newS, shouldUpdate) <- insertAfter s after new textBeginning code
    when shouldUpdate $ updateGraphSeq $ Just newS
    indentBy <- Code.getCurrentIndentationLength
    newLen <- getLayer @SpanLength new
    Code.gossipLengthsChangedBy (newLen + indentBy + 1) newS

getCurrentFunctionOutput :: GraphOp NodeRef
getCurrentFunctionOutput = do
    seq <- ASTRead.getCurrentBody
    matchExpr seq $ \case
        Seq _ r -> source r
        _ -> return seq

putInSequence :: NodeRef -> Text -> NodeMeta -> GraphOp ()
putInSequence ref code meta = do
    oldSeq             <- ASTRead.getCurrentBody
    nodes              <- AST.readSeq oldSeq
    nodesAndMetas      <- mapM (\n -> (n,) <$> AST.readMeta n) nodes
    let nodesWithMetas =  mapMaybe (\(n,m) -> (n,) <$> m) nodesAndMetas
    nearestNode        <- findPreviousNodeInSequence oldSeq meta nodesWithMetas
    blockEnd           <- Code.getCurrentBlockEnd
    currentOutput      <- getCurrentFunctionOutput
    anonOutput         <- ASTRead.isAnonymous currentOutput
    none               <- ASTRead.isNone currentOutput
    insertAfterAndUpdate oldSeq nearestNode ref blockEnd code
    when (Just currentOutput == nearestNode && anonOutput && not none) $ do
        Just nid <- GraphBuilder.getNodeIdWhenMarked currentOutput
        ASTBuilder.ensureNodeHasName generateNodeName nid
        v <- ASTRead.getASTVar nid
        setOutputTo v

addOutputAtEnd :: NodeRef -> NodeRef -> Delta -> GraphOp NodeRef
addOutputAtEnd initial out blockEnd = do
    indentBy <- Code.getCurrentIndentationLength
    code     <- ASTPrint.printFullExpression out
    seq      <- generalize <$> IR.seq initial out
    len      <- getLayer @SpanLength initial
    outLen   <- getLayer @SpanLength out
    let offset = indentBy + 1
    putLayer @SpanLength seq $ len + offset + outLen
    Code.insertAt blockEnd ("\n" <> Text.replicate (fromIntegral indentBy) " " <> code)
    setSeqOffsets seq 0 offset
    return seq

reconnectOut :: NodeRef -> NodeRef -> Delta -> GraphOp (Maybe NodeRef)
reconnectOut seq out blockEnd = matchExpr seq $ \case
    Seq l r -> do
        right <- source r
        matchExpr right $ \case
            Marked _ _ -> Just <$> addOutputAtEnd seq out blockEnd
            _             -> do
                len <- getLayer @SpanLength right
                ASTBuilder.replaceEdgeSource (coerce r) (blockEnd - len) out
                return Nothing
    Marked _ _ -> Just <$> addOutputAtEnd seq out blockEnd
    _             -> do
        len  <- getLayer @SpanLength seq
        code <- ASTPrint.printFullExpression out
        Code.applyDiff (blockEnd - len) blockEnd code
        return $ Just out

setOutputTo :: NodeRef -> GraphOp ()
setOutputTo out = do
    oldSeq   <- ASTRead.getCurrentBody
    blockEnd <- Code.getCurrentBlockEnd
    newSeq   <- reconnectOut oldSeq out blockEnd
    traverse_ (updateGraphSeq . Just) newSeq

updateGraphSeqWithWhilelist :: [NodeRef] -> Maybe NodeRef -> GraphOp ()
updateGraphSeqWithWhilelist whitelist newOut = do
    currentTgt   <- ASTRead.getCurrentASTTarget
    Just outLink <- ASTRead.getFirstNonLambdaLink currentTgt
    oldSeq       <- source outLink
    case newOut of
        Just o  -> do
            oldSeqLen <- getLayer @SpanLength oldSeq
            newSeqLen <- getLayer @SpanLength o
            Code.gossipLengthsChangedBy (newSeqLen - oldSeqLen) =<< target outLink
            replaceSource o $ coerce outLink
        Nothing -> do
            none <- generalize <$> IR.cons "None" []
            let noneLen = fromIntegral $ length ("None"::String)
            replaceSource none $ coerce outLink
            Code.gossipLengthsChangedBy noneLen none
            blockEnd <- Code.getCurrentBlockEnd
            Code.insertAt (blockEnd - noneLen) "None"
            return ()
    deepDeleteWithWhitelist oldSeq $ Set.union (Set.fromList whitelist) (Set.fromList (maybeToList newOut))
    oldRef <- use $ Graph.breadcrumbHierarchy . BH.self
    when (oldRef == oldSeq) $ for_ newOut (Graph.breadcrumbHierarchy . BH.self .=)

updateGraphSeq :: Maybe NodeRef -> GraphOp ()
updateGraphSeq newOut = updateGraphSeqWithWhilelist [] newOut

updateCodeSpan' :: NodeRef -> GraphOp (LeftSpacedSpan Delta)
updateCodeSpan' ref = matchExpr ref $ \case
    Seq l r -> do
        l' <- updateCodeSpan' =<< source l
        r' <- updateCodeSpan' =<< source r
        let span = l' <> r'
        setCodeSpan ref span
        return span
    _ -> readCodeSpan ref

updateCodeSpan :: NodeRef -> GraphOp ()
updateCodeSpan ref = do
    updateCodeSpan' ref
    LeftSpacedSpan (SpacedSpan off len) <- readCodeSpan ref
    fileOffset <- use Graph.fileOffset
    setCodeSpan ref (leftSpacedSpan fileOffset len)

addPort :: GraphLocation -> OutPortRef -> Empire ()
addPort loc portRef = addPortWithConnections loc portRef Nothing []

addPortNoTC :: GraphLocation -> OutPortRef -> Maybe Text -> Command Graph ()
addPortNoTC loc (OutPortRef nl pid) name = runASTOp $ do
    let nid      = convert nl
        position = getPortNumber (pid)
    (inE, _) <- GraphBuilder.getEdgePortMapping
    when (inE /= nid) $ throwM $ NotInputEdgeException inE nid
    ref <- ASTRead.getCurrentASTTarget
    ASTBuilder.detachNodeMarkersForArgs ref
    ids      <- uses Graph.breadcrumbHierarchy BH.topLevelIDs
    varNames <- catMaybes <$> mapM GraphBuilder.getNodeName ids
    ASTModify.addLambdaArg position ref name $ map convert varNames
    newLam <- ASTRead.getCurrentASTTarget
    ASTBuilder.attachNodeMarkersForArgs nid [] newLam

addPortWithConnections :: GraphLocation -> OutPortRef -> Maybe Text -> [AnyPortRef] -> Empire ()
addPortWithConnections loc portRef name connectTo = do
    withTC loc False $ do
        addPortNoTC loc portRef name
        for_ connectTo $ connectNoTC loc portRef
    resendCode loc

addSubgraph :: GraphLocation -> [ExpressionNode] -> [Connection] -> Empire [ExpressionNode]
addSubgraph loc@(GraphLocation _ (Breadcrumb [])) nodes _ = do
    res <- forM nodes $ \n -> addFunNode loc ParseAsIs (n ^. Node.nodeId) (n ^. Node.code) (n ^. Node.nodeMeta)
    resendCode loc
    return res
addSubgraph loc nodes conns = do
    newNodes <- withTC loc False $ do
        newNodes <- forM nodes $ \n -> addNodeNoTC loc (n ^. Node.nodeId) (n ^. Node.code) (n ^. Node.name) (n ^. Node.nodeMeta)
        for_ conns $ \(Connection src dst) -> connectNoTC loc src (InPortRef' dst)
        return newNodes
    resendCode loc
    return newNodes

removeNodes :: GraphLocation -> [NodeId] -> Empire ()
removeNodes loc@(GraphLocation file (Breadcrumb [])) nodeIds = do
    withUnit loc $ do
        funs <- use $ Graph.userState . Graph.clsFuns

        let graphsToRemove = Map.elems $ Map.filterWithKey (\a _ -> a `elem` nodeIds) funs
        Graph.userState . Graph.clsFuns .= Map.filterWithKey (\a _ -> a `notElem` nodeIds) funs

        unit <- use $ Graph.userState . Graph.clsClass
        runASTOp $ do
            cls' <- ASTRead.classFromUnit unit
            Just (cls'' :: Expr (ClsASG)) <- narrowTerm cls'
            funs <- matchExpr cls' $ \case
                ClsASG _ _ _ _ f' -> do
                    f <- ptrListToList f'
                    links <- mapM (\link -> (link,) <$> source link) f
                    forM links $ \(link, fun) -> do
                        nid <- ASTRead.getNodeId fun
                        return $ case nid of
                            Just i -> if i `elem` nodeIds then Left link else Right link
                            _      -> Right link
            let (toRemove, left) = partitionEithers funs
            spans <- forM toRemove $ \candidate -> do
                ref <- source candidate
                start <- Code.functionBlockStartRef ref
                LeftSpacedSpan (SpacedSpan off len) <- view CodeSpan.realSpan <$> getLayer @CodeSpan.CodeSpan ref
                return (start - off, start + len)
            forM (reverse spans) $ \(start, end) -> do
                let removedCharacters = end - start
                Graph.clsFuns . traverse . Graph._FunctionDefinition . Graph.funGraph . Graph.fileOffset %= (\off -> if off > end then off - removedCharacters else off)
                Code.removeAt start end
            IR.UniTermRecord a <- getLayer @IR.Model cls''
            l <- PtrList.fromList (coerce left)
            let a' = a & IR.decls_Record .~ l
            putLayer @IR.Model cls'' $ IR.UniTermRecord a'
            -- IR.modifyExprTerm cls'' $ wrapped . IR.termClsASG_decls .~ (map unsafeGeneralize left)
            mapM (deleteSubtree <=< source) toRemove
            return ()
    resendCode loc
removeNodes loc@(GraphLocation file _) nodeIds = do
    withTC loc False $ runASTOp $ mapM_ removeNodeNoTC nodeIds
    resendCode loc

deepRemoveExprMarkers :: BH.BChild -> GraphOp ()
deepRemoveExprMarkers chld = do
    removeExprMarker $ chld ^. BH.self
    traverseOf_ (BH._LambdaChild . BH.children     . traverse) deepRemoveExprMarkers chld
    traverseOf_ (BH._ExprChild   . BH.portChildren . traverse . re BH._LambdaChild) deepRemoveExprMarkers chld

removeNodeNoTC :: NodeId -> GraphOp [NodeId]
removeNodeNoTC nodeId = do
    astRef        <- ASTRead.getASTRef nodeId
    obsoleteEdges <- getOutEdges nodeId
    traverse_ disconnectPort obsoleteEdges
    mapM deepRemoveExprMarkers =<< use (Graph.breadcrumbHierarchy . BH.children . at nodeId)
    Graph.breadcrumbHierarchy . BH.children . at nodeId .= Nothing
    removeFromSequence astRef
    return $ map (view PortRef.dstNodeId) obsoleteEdges

removeExprMarker :: NodeRef -> GraphOp ()
removeExprMarker ref = do
    exprMap <- getExprMap
    let newExprMap = Map.filter (/= ref) exprMap
    setExprMap newExprMap

unpinSequenceElement :: NodeRef -> NodeRef -> GraphOp (Maybe NodeRef, Bool)
unpinSequenceElement seq ref = matchExpr seq $ \case
    Seq l r -> do
        rt <- source r
        if rt == ref
            then do
                Just offset <- Code.getOffsetRelativeToFile ref
                len         <- getLayer @SpanLength ref
                edgeOff     <- getLayer @SpanOffset r
                Code.removeAt (offset - edgeOff) (offset + len)
                lt          <- source l
                return (Just lt, True)
            else do
                lt    <- source l
                recur <- unpinSequenceElement lt ref
                case recur of
                    (Just newRef, True) -> do -- left child changed
                        len    <- getLayer @SpanLength ref
                        indent <- Code.getCurrentIndentationLength
                        Code.gossipLengthsChangedBy (negate $ len + indent + 1) lt
                        ASTModify.substitute newRef lt
                        irDelete lt
                        return (Just newRef, False)
                    (Nothing, True)     -> do -- left child removed, right child replaces whole seq
                        roff     <- getLayer @SpanOffset r
                        loff     <- getLayer @SpanOffset l
                        Just pos <- Code.getOffsetRelativeToFile ref
                        Code.removeAt pos (pos + roff + loff)
                        return (Just rt, True)
                    (res, False)        -> return (res, False)
    _ -> do
        Just offset <- Code.getOffsetRelativeToFile ref
        len         <- getLayer @SpanLength ref
        Code.removeAt offset (offset + len)
        return (Nothing, True)

unpinFromSequence :: NodeRef -> GraphOp ()
unpinFromSequence ref = do
    oldSeq <- ASTRead.getCurrentBody
    (newS, shouldUpdate) <- unpinSequenceElement oldSeq ref
    when shouldUpdate (updateGraphSeqWithWhilelist [ref] newS)

removeFromSequence :: NodeRef -> GraphOp ()
removeFromSequence ref = do
    unpinFromSequence ref
    deleteSubtree ref

removePort :: GraphLocation -> OutPortRef -> Empire ()
removePort loc portRef = do
    withTC loc False $ runASTOp $ do
        let nodeId = portRef ^. PortRef.srcNodeId
        ref <- ASTRead.getCurrentASTTarget
        ASTBuilder.detachNodeMarkersForArgs ref
        (inE, _) <- GraphBuilder.getEdgePortMapping
        if nodeId == inE then ASTModify.removeLambdaArg (portRef ^. PortRef.srcPortId) ref
                         else throwM $ NotInputEdgeException inE nodeId
        newLam <- ASTRead.getCurrentASTTarget
        ASTBuilder.attachNodeMarkersForArgs nodeId [] newLam
        GraphBuilder.buildInputSidebar nodeId
    resendCode loc

movePort :: GraphLocation -> OutPortRef -> Int -> Empire ()
movePort loc portRef newPosition = do
    withTC loc False $ runASTOp $ do
        let nodeId = portRef ^. PortRef.srcNodeId
        ref        <- ASTRead.getCurrentASTTarget
        (input, _) <- GraphBuilder.getEdgePortMapping
        if nodeId == input then ASTModify.moveLambdaArg (portRef ^. PortRef.srcPortId) newPosition ref
                           else throwM $ NotInputEdgeException input nodeId
        ref        <- ASTRead.getCurrentASTTarget
        ASTBuilder.attachNodeMarkersForArgs nodeId [] ref
        GraphBuilder.buildInputSidebar nodeId
    resendCode loc

renamePort :: GraphLocation -> OutPortRef -> Text -> Empire ()
renamePort loc portRef newName = do
    withTC loc False $ runASTOp $ do
        let nodeId = portRef ^. PortRef.srcNodeId
        ref        <- ASTRead.getCurrentASTTarget
        (input, _) <- GraphBuilder.getEdgePortMapping
        if nodeId == input then ASTModify.renameLambdaArg (portRef ^. PortRef.srcPortId) (Text.unpack newName) ref
                           else throwM $ NotInputEdgeException input nodeId
        GraphBuilder.buildInputSidebar nodeId
    resendCode loc

getPortName :: GraphLocation -> OutPortRef -> Empire Text
getPortName loc portRef = do
    withGraph loc $ runASTOp $ do
        let nodeId = portRef ^. PortRef.srcNodeId
            portId = portRef ^. PortRef.srcPortId
            arg    = getPortNumber portId
        ref        <- ASTRead.getCurrentASTTarget
        (input, _) <- GraphBuilder.getEdgePortMapping
        portsNames <- GraphBuilder.getPortsNames ref Nothing
        if nodeId == input
            then maybe (throwM $ PortDoesNotExistException portId) (return . convert) $ Safe.atMay portsNames arg
            else throwM $ NotInputEdgeException input nodeId

setNodeExpression :: GraphLocation -> NodeId -> Text -> Empire Node.Node
setNodeExpression loc@(GraphLocation file _) nodeId expr' = do
    let expression = Text.strip expr'
    (newCode, sidebar) <- withGraph loc $ runASTOp $ do
        (_, output) <- GraphBuilder.getEdgePortMapping
        (oldExpr, oldBegin) <- if nodeId == output
            then do
                oldExpr       <- ASTRead.getCurrentASTRef
                Just oldBegin <- Code.getOffsetRelativeToFile oldExpr
                pure (oldExpr, oldBegin)
            else do
                oldExpr  <- ASTRead.getASTTarget nodeId
                oldBegin <- Code.getASTTargetBeginning nodeId
                pure (oldExpr, oldBegin)
        oldLen <- getLayer @SpanLength oldExpr
        let oldEnd = oldBegin + oldLen
        code <- Code.applyDiff oldBegin oldEnd expression
        pure (code, nodeId == output)
    reloadCode loc newCode
    resendCode loc
    withGraph loc $ runASTOp $ do
        (_, output) <- GraphBuilder.getEdgePortMapping
        if sidebar
        then Node.OutputSidebar'  <$> GraphBuilder.buildOutputSidebar output
        else Node.ExpressionNode' <$> GraphBuilder.buildNode nodeId


updateExprMap :: NodeRef -> NodeRef -> GraphOp ()
updateExprMap new old = do
    exprMap <- getExprMap
    let updated = Map.map (\a -> if a == old then new else a) exprMap
    setExprMap updated




connectCondTC :: Bool -> GraphLocation -> OutPortRef -> AnyPortRef -> Empire Connection
connectCondTC True  loc outPort anyPort = connect loc outPort anyPort
connectCondTC False loc outPort anyPort = do
    connection <- withGraph loc $ connectNoTC loc outPort anyPort
    resendCode loc
    return connection

connect :: GraphLocation -> OutPortRef -> AnyPortRef -> Empire Connection
connect loc outPort anyPort = do
    connection <- withTC loc False $ connectNoTC loc outPort anyPort
    resendCode loc
    return connection

reorder :: NodeId -> NodeId -> GraphOp ()
reorder dst src = do
    dstDownstream <- getNodeDownstream dst
    let wouldIntroduceCycle = src `elem` dstDownstream
    if wouldIntroduceCycle then return () else do
        dstDownAST    <- mapM ASTRead.getASTRef dstDownstream
        nodes         <- ASTRead.getCurrentBody >>= AST.readSeq
        srcAst        <- ASTRead.getASTRef src
        let srcIndex    = List.elemIndex srcAst nodes
            downIndices = sortOn snd $ map (\a -> (a, a `List.elemIndex` nodes)) dstDownAST
            leftToSrc   = map fst $ filter ((< srcIndex) . snd) downIndices
        let f :: NodeRef -> NodeRef -> GraphOp NodeRef
            f acc e = do
                oldSeq   <- ASTRead.getCurrentBody
                code     <- Code.getCodeOf e
                unpinFromSequence e
                blockEnd <- Code.getCurrentBlockEnd
                oldSeq'   <- ASTRead.getCurrentBody
                insertAfterAndUpdate oldSeq' (Just acc) e blockEnd code
                return e
        foldM f srcAst leftToSrc
        return ()

getNodeDownstream :: NodeId -> GraphOp [NodeId]
getNodeDownstream nodeId = do
    conns <- map (\(a,b) -> (a^.PortRef.srcNodeLoc, b^.PortRef.dstNodeId)) <$> GraphBuilder.buildConnections
    (_, output) <- GraphBuilder.getEdgePortMapping
    let connsWithoutOutput = map (over _1 convert) $ filter ((/= output) . snd) conns
        go c n             = let next = map snd $ filter ((== n) . fst) c
                             in next ++ concatMap (go c) next
    return $ nodeId : go connsWithoutOutput nodeId

connectPersistent :: OutPortRef -> AnyPortRef -> GraphOp Connection
connectPersistent src@(OutPortRef (convert -> srcNodeId) srcPort) (InPortRef' dst@(InPortRef (NodeLoc _ dstNodeId) dstPort)) = do
    -- FIXME[MK]: passing the `generateNodeName` here is a hack arising from cyclic module deps. Need to remove together with modules refactoring.
    whenM (not <$> ASTRead.isInputSidebar srcNodeId) $ do
        ref   <- ASTRead.getASTRef srcNodeId
        s     <- ASTRead.getCurrentBody
        nodes <- AST.readSeq s
        ASTBuilder.ensureNodeHasName generateNodeName srcNodeId
        when (unsafeLast nodes == ref) $ do
            var <- ASTRead.getASTVar srcNodeId
            setOutputTo var
    srcAst <- ASTRead.getASTOutForPort srcNodeId (src ^. PortRef.srcPortId)
    (input, output) <- GraphBuilder.getEdgePortMapping
    when (input /= srcNodeId && output /= dstNodeId) $ do
        src'   <- ASTRead.getASTRef srcNodeId
        dstAst <- ASTRead.getASTRef dstNodeId
        s      <- ASTRead.getCurrentBody
        nodes  <- AST.readSeq s
        let srcPos = List.elemIndex src' nodes
            dstPos = List.elemIndex dstAst nodes
        when (dstPos < srcPos) $ reorder dstNodeId srcNodeId
    case dstPort of
        [] -> makeWhole srcAst dstNodeId
        _  -> makeInternalConnection srcAst dstNodeId dstPort
    return $ Connection src dst
connectPersistent src@(OutPortRef srcNodeId srcPort) (OutPortRef' dst@(OutPortRef d@(NodeLoc _ dstNodeId) dstPort)) = do
    case dstPort of
        []    -> do
            ASTBuilder.flipNode dstNodeId
            connectPersistent src (InPortRef' (InPortRef d []))
        _ : _ -> throwM InvalidConnectionException


connectNoTC :: GraphLocation -> OutPortRef -> AnyPortRef -> Command Graph Connection
connectNoTC loc outPort anyPort = runASTOp $ do
    (inputSidebar, outputSidebar) <- GraphBuilder.getEdgePortMapping
    let OutPortRef outNodeId outPortId = outPort
        inNodeId = anyPort ^. PortRef.nodeId
        inPortId = anyPort ^. PortRef.portId
    let codeForId id | id == inputSidebar  = return "input sidebar"
                     | id == outputSidebar = return "output sidebar"
                     | otherwise           = ASTRead.getASTPointer id >>= Code.getCodeOf
    outNodeCode <- codeForId (convert outNodeId) `catch` (\(_e::SomeASTException) -> return "unknown code")
    inNodeCode  <- codeForId inNodeId `catch` (\(_e::SomeASTException) -> return "unknown code")
    connectPersistent outPort anyPort `catch` (\(e::SomeASTException) ->
        throwM $ ConnectionException (convert outNodeId) outNodeCode (outPort ^. PortRef.srcPortId) inNodeId inNodeCode inPortId e)

data SelfPortDefaultException = SelfPortDefaultException InPortRef
    deriving (Show)

instance Exception SelfPortDefaultException where
    fromException = astExceptionFromException
    toException = astExceptionToException

getPortDefault :: GraphLocation -> InPortRef -> Empire (Maybe PortDefault)
getPortDefault loc port@(InPortRef  _ (Self : _))             = throwM $ SelfPortDefaultException port
getPortDefault loc (InPortRef (NodeLoc _ nodeId) (Arg x : _)) = withGraph loc $ runASTOp $ flip GraphBuilder.getInPortDefault x =<< GraphUtils.getASTTarget nodeId
getPortDefault loc (InPortRef (NodeLoc _ nodeId) [])          = withGraph loc $ runASTOp $ GraphBuilder.getDefault =<< GraphUtils.getASTTarget nodeId

setPortDefault :: GraphLocation -> InPortRef -> Maybe PortDefault -> Empire ()
setPortDefault loc (InPortRef (NodeLoc _ nodeId) port) (Just val) = do
    withTC loc False $ do
        parsed <- ASTParse.parsePortDefault val
        runAliasAnalysis
        runASTOp $ case port of
            [] -> makeWhole parsed nodeId
            _  -> makeInternalConnection parsed nodeId port
    resendCode loc
setPortDefault loc port Nothing = do
    withTC loc False $ runASTOp $ disconnectPort port
    resendCode loc

disconnect :: GraphLocation -> InPortRef -> Empire ()
disconnect loc@(GraphLocation file _) port@(InPortRef (NodeLoc _ nid) _) = do
    withTC loc False $ do
        runASTOp $ disconnectPort port
        runAliasAnalysis
    resendCode loc



getBuffer :: FilePath -> Empire Text
getBuffer file = getCode (GraphLocation file (Breadcrumb []))

getGraphCondTC :: Bool -> GraphLocation -> Empire APIGraph.Graph
getGraphCondTC tc loc = withImports getFullGraph where
    getFullGraph = (if tc then withTC' loc True else withBreadcrumb loc)
        (runASTOp buildGraph)
        (runASTOp buildClassGraph)
    unlessError action = maybe action throwM
    buildGraph = unlessError GraphBuilder.buildGraph =<< use Graph.parseError
    buildClassGraph = unlessError GraphBuilder.buildClassGraph
        =<< use Graph.clsParseError
    withImports graphGetter = getAvailableImports loc >>= \imports ->
        (& APIGraph.imports .~ imports) <$> graphGetter

getGraph :: GraphLocation -> Empire APIGraph.Graph
getGraph = getGraphCondTC True

getGraphNoTC :: GraphLocation -> Empire APIGraph.Graph
getGraphNoTC = getGraphCondTC False

getNodes :: GraphLocation -> Empire [ExpressionNode]
getNodes loc = withTC' loc True (runASTOp (view APIGraph.nodes <$> GraphBuilder.buildGraph))
                                (runASTOp (view APIGraph.nodes <$> GraphBuilder.buildClassGraph))

getConnections :: GraphLocation -> Empire [Connection]
getConnections loc = withTC loc True $ runASTOp $ view APIGraph.connections <$> GraphBuilder.buildGraph

decodeLocation :: GraphLocation -> Empire (Breadcrumb (Named BreadcrumbItem))
decodeLocation loc@(GraphLocation file crumbs) = case crumbs of
        Breadcrumb [] -> return $ Breadcrumb []
        _             -> do
            definitionsIDs <- withUnit (GraphLocation file (Breadcrumb [])) $ do
                funs <- use $ Graph.userState . Graph.clsFuns
                return $ Map.map (view $ Graph._FunctionDefinition . Graph.funName) funs
            withGraph (functionLocation loc) $ GraphBuilder.decodeBreadcrumbs definitionsIDs crumbs

renameNode :: GraphLocation -> NodeId -> Text -> Empire ()
renameNode loc nid name
    | GraphLocation f (Breadcrumb []) <- loc = do
        let stripped = Text.strip name
        oldLen <- withUnit loc $ do
            _ <- liftIO $ ASTParse.runProperVarParser stripped
            oldName <- use $ Graph.userState . Graph.clsFuns . ix nid . Graph._FunctionDefinition . Graph.funName
            Graph.userState . Graph.clsFuns %= Map.adjust (Graph._FunctionDefinition . Graph.funName .~ (Text.unpack stripped)) nid
            runASTOp $ do
                fun     <- ASTRead.getFunByNodeId nid >>= ASTRead.cutThroughDocAndMarked
                matchExpr fun $ \case
                    ASGFunction n _ _ -> do
                        len <- getLayer @SpanLength =<< source n
                        flip ASTModify.renameVar (convert stripped) =<< source n
                        return len
        withGraph (GraphLocation f (Breadcrumb [Breadcrumb.Definition nid])) $ runASTOp $ do
            self   <- use $ Graph.breadcrumbHierarchy . BH.self
            v      <- ASTRead.getVarNode self
            Code.replaceAllUses v oldLen stripped
        resendCode loc
    | otherwise = do
        withTC loc False $ do
            _        <- ASTParse.runProperPatternParser name
            pat      <- ASTParse.parsePattern name
            runASTOp $ do
                Code.propagateLengths pat
                ASTBuilder.ensureNodeHasName generateNodeName nid
                ref      <- ASTRead.getASTPointer nid
                v        <- ASTRead.getASTVar nid
                patIsVar <- ASTRead.isVar pat
                varIsVar <- ASTRead.isVar v
                if patIsVar && varIsVar then do
                    oldLen <- getLayer @SpanLength v
                    ASTModify.renameVar v $ convert name
                    Code.replaceAllUses v oldLen name
                    deleteSubtree pat
                else do
                    ref      <- ASTRead.getASTPointer nid
                    Just beg <- Code.getOffsetRelativeToFile ref
                    varLen   <- getLayer @SpanLength v
                    patLen   <- getLayer @SpanLength pat
                    vEdge    <- ASTRead.getVarEdge nid
                    replaceSource pat $ generalize vEdge
                    Code.gossipLengthsChangedBy (patLen - varLen) ref
                    void $ Code.applyDiff beg (beg + varLen) name
            runAliasAnalysis
        resendCode loc

dumpGraphViz :: GraphLocation -> Empire ()
dumpGraphViz loc = withGraph loc $ return ()


data UnsupportedOperation = UnsupportedOperation deriving Show

instance Exception UnsupportedOperation where
    fromException = astExceptionFromException
    toException   = astExceptionToException

withGraph :: GraphLocation -> Command Graph a -> Empire a
withGraph gl act = withBreadcrumb gl act (throwM UnsupportedOperation)

withUnit :: GraphLocation -> Command ClsGraph a -> Empire a
withUnit gl act = withBreadcrumb gl (throwM UnsupportedOperation) act

-- withBreadcrumb
--     :: GraphLocation -> Command Graph a -> Command ClsGraph a -> Empire a
-- withBreadcrumb gl = withLibrary (gl ^. GraphLocation.filePath)
--     .: zoomBreadcrumb (gl ^. GraphLocation.breadcrumb)


fileImportPaths :: MonadIO m => FilePath -> m (Map.Map IR.Qualified FilePath)
fileImportPaths file = liftIO $ do
    filePath        <- Path.parseAbsFile file
    currentProjPath <- Package.packageRootForFile filePath
    libs            <- Package.packageImportPaths currentProjPath
    srcs            <- for (snd <$> libs) $ \libPath -> do
        p <- Path.parseAbsDir libPath
        fmap Path.toFilePath . Bimap.toMapR <$> Package.findPackageSources p
    pure $ Map.unions srcs

openLibrary :: FilePath -> Text -> Empire Library
openLibrary file mod = do
    visibleImports <- fileImportPaths file
    let pathToOpen = visibleImports ^. at (convertVia @String mod)
    case pathToOpen of
        Just path -> openFile path
        _         -> error $ "openLibrary: " <> show mod

getLibrary :: FilePath -> Text -> Empire Library
getLibrary file mod = do
    activeModules <- use $ Graph.userState . activeFiles
    let libOpened = find (\a -> a ^. Library.name == Just mod) $ Map.elems activeModules
    case libOpened of
        Just lib -> return lib
        _        -> openLibrary file mod

afterRedirect :: Breadcrumb BreadcrumbItem -> (Maybe BreadcrumbItem, Breadcrumb BreadcrumbItem)
afterRedirect bc =
            let (end, rest) = span (\a -> isNothing $ a ^? _Redirection)
                            . reverse
                            . coerce $ bc
            in case rest of
                []              -> (Nothing, bc)
                (redirection:_) -> (Just redirection, coerce $ reverse end)

resolveRedirection :: GraphLocation -> Empire GraphLocation
resolveRedirection loc@(GraphLocation file breadcrumb@(Breadcrumb bc)) =
    case afterRedirect breadcrumb of
        (Nothing, b) -> return loc
        (Just (Redirection nodeId tgt), bc) -> case tgt of
            Breadcrumb.Function mod fun -> do
                lib <- getLibrary file mod
                let funs = lib ^. Library.body . Graph.clsFuns
                    funGraph = find (\a -> a ^. _2 . Graph._FunctionDefinition . Graph.funName == convert fun) $ Map.toList funs
                case funGraph of
                    Just (funId, _) -> return $
                        GraphLocation (lib ^. Library.path) (coerce $ Definition funId : coerce bc)
                    _               -> error $ "resolveRedirection1: " <> show funs
            Breadcrumb.Method mod cls met -> do
                lib <- getLibrary file mod
                let funs = lib ^. Library.body . Graph.clsFuns :: Map NodeId Graph.TopLevelGraph
                    funGraph = find (\a -> a ^. _2 . Graph._ClassDefinition . Graph.className == convert cls) $ Map.toList funs
                case funGraph of
                    Just (funId, clsGraph) -> do
                        let fun = find (\a -> a ^. _2 . Graph.funName == convert met) $ Map.toList $ clsGraph ^?! Graph._ClassDefinition . Graph.classMethods
                        case fun of
                            Just (funId2, _) -> return $
                                GraphLocation (lib ^. Library.path) (coerce $ Definition funId : Definition funId2 : coerce bc)
                            _                -> error $ "resolveRedirection2: " <> show funs
                    _ -> error $ "resolveRedirection3: " <> show bc


withBreadcrumb :: GraphLocation -> Command Graph.Graph a -> Command Graph.ClsGraph a -> Empire a
withBreadcrumb (GraphLocation file breadcrumb) actG actC = do
    let processClassBreadcrumb f mod cls met bc = do
            let funs = f ^. Library.body . Graph.clsFuns :: Map NodeId Graph.TopLevelGraph
                funGraph = find (\a -> a ^. _2 . Graph._ClassDefinition . Graph.className == convert cls) $ Map.toList funs
            case funGraph of
                Just (clsId, clsGraph) -> do
                    let fun = find (\a -> a ^. _2 . Graph.funName == convert met) $ Map.toList $ clsGraph ^?! Graph._ClassDefinition . Graph.classMethods
                    case fun of
                        Just (funId, _) -> Library.withLibrary (f ^. Library.path) $
                            zoomBreadcrumb (coerce $ Definition clsId : Definition funId : coerce bc) actG actC
                        _ -> error $ "fun not found: "
                            <> show (clsGraph ^.. Graph._ClassDefinition . Graph.classMethods . traverse . Graph.funName)
                            <> " " <> show mod
                            <> " " <> show cls
                            <> " " <> show met
                            <> " " <> show clsGraph
                _ -> throwM $ BH.BreadcrumbDoesNotExistException breadcrumb
        processFunctionBreadcrumb f mod fun bc = do
            let funs = f ^. Library.body . Graph.clsFuns
                funGraph = find (\a -> a ^. _2 . Graph._FunctionDefinition . Graph.funName == convert fun) $ Map.toList funs
            case funGraph of
                Just (funId, _) -> Library.withLibrary (f ^. Library.path) $
                    zoomBreadcrumb (coerce $ Definition funId : coerce bc) actG actC
                _ -> throwM $ BH.BreadcrumbDoesNotExistException breadcrumb
        ensureModOpened mod redirection = do
            active        <- use $ Graph.userState . activeFiles
            let libOpened  = find (\a -> a ^. Library.name == Just mod) $ Map.elems active
            case libOpened of
                Just f -> pure f
                _      -> do
                    visibleImports <- fileImportPaths file
                    let pathToOpen = visibleImports ^. at (convertVia @String mod)
                    case pathToOpen of
                        Just path -> openFile path >> ensureModOpened mod redirection
                        _         -> error $
                            "unknown path to open: " <>
                            show visibleImports <>
                            " " <> show redirection
    case afterRedirect breadcrumb of
        (Nothing, b) -> Library.withLibrary file $ zoomBreadcrumb breadcrumb actG actC
        (Just red@(Redirection nodeId tgt), bc) -> case tgt of
            Breadcrumb.Method mod cls met -> do
                f <- ensureModOpened mod red
                processClassBreadcrumb f mod cls met bc
            Breadcrumb.Function mod fun -> do
                f <- ensureModOpened mod red
                processFunctionBreadcrumb f mod fun bc

dumpMetadata :: FilePath -> Empire [MarkerNodeMeta]
dumpMetadata file = do
    funs <- withUnit (GraphLocation.top file) $
        fmap Map.keys . use $ Graph.userState . Graph.clsFuns
    let gl fun = GraphLocation file $ Breadcrumb [Breadcrumb.Definition fun]
    metas <- forM funs $ \fun -> withGraph (gl fun) $ runASTOp $ do
        root       <- ASTRead.getCurrentBody
        oldMetas   <- extractMarkedMetasAndIds root
        pure [ MarkerNodeMeta marker meta
            | (marker, (Just meta, _)) <- oldMetas ]
    pure $ concat metas

addMetadataToCode :: FilePath -> Empire Text
addMetadataToCode file = do
    metadata <- FileMetadata <$> dumpMetadata file
    let metadataJSON
            = (TL.toStrict . Aeson.encodeToLazyText . Aeson.toJSON)
                metadata
        metadataJSONWithHeader = Lexer.mkMetadata (Text.cons ' ' metadataJSON)
    withUnit (GraphLocation.top file) $ do
        code <- use $ Graph.userState . Graph.code
        let metadataJSONWithHeaderAndOffset
                = Text.cons '\n' metadataJSONWithHeader
        pure $ Text.concat [code, metadataJSONWithHeaderAndOffset]

parseMetadata :: MonadIO m => Text -> m FileMetadata
parseMetadata meta =
    let metaPrefix = "### META "
        json       = Text.drop (Text.length metaPrefix) meta
        metadata   = Aeson.eitherDecodeStrict' $ Text.encodeUtf8 json
    in case metadata of
        Right fm  -> pure fm
        Left  _   -> pure (FileMetadata mempty)

readMetadata' :: ClassOp FileMetadata
readMetadata' = do
    unit     <- use Graph.clsClass
    metaRef  <- ASTRead.getMetadataRef unit
    case metaRef of
        Just meta' -> do
            metaStart <- Code.functionBlockStartRef meta'
            LeftSpacedSpan (SpacedSpan _off len)
                <- view CodeSpan.realSpan <$> getLayer @CodeSpan meta'
            code <- Code.getAt metaStart (metaStart + len)
            parseMetadata code
        _ -> pure $ FileMetadata mempty

readMetadata :: FilePath -> Empire FileMetadata
readMetadata file = withUnit (GraphLocation.top file) $ runASTOp readMetadata'

extractMarkedMetasAndIds
    :: NodeRef -> ASTOp g [(Word64, (Maybe NodeMeta, Maybe NodeId))]
extractMarkedMetasAndIds root = matchExpr root $ \case
    Marked m e -> do
        meta    <- AST.readMeta root
        marker  <- ASTBreadcrumb.getMarker =<< source m
        expr    <- source e
        rest    <- extractMarkedMetasAndIds expr
        var     <- ASTRead.isVar expr
        nidExpr <- ASTRead.getNodeId expr
        nidRoot <- ASTRead.getNodeId root
        let outId = if var then nidRoot else nidExpr <|> nidRoot
        pure $ (marker, (meta, outId)) : rest
    _ -> concat <$> (mapM (extractMarkedMetasAndIds <=< source) =<< inputs root)

stripMetadata :: Text -> Text
stripMetadata text = if lexerStream == code
    then text
    else flip Text.append "\n" $ Text.stripEnd $ convert withoutMeta where
        lexerStream  = Lexer.evalDefLexer (convert text)
        code = takeWhile
            (\(Lexer.Token _ _ s) -> isNothing $ Lexer.matchMetadata s)
            lexerStream
        textTree = SpanTree.buildSpanTree
            (convert text)
            $ code <> [Lexer.Token 0 0 Lexer.ETX]
        withoutMeta = SpanTree.foldlSpans
            (\t (Spanned _ t1) -> t <> t1)
            mempty
            textTree

removeMetadataNode :: ClassOp ()
removeMetadataNode = do
    unit   <- use Graph.clsClass
    klass' <- ASTRead.classFromUnit unit
    newLinks <- matchExpr klass' $ \case
        ClsASG _ _ _ _ funs'' -> do
            funs <- ptrListToList funs''
            let fromFunction f = source f >>= \f' -> matchExpr f' $ \case
                    Metadata{} -> pure Nothing
                    _          -> pure $ Just f
            catMaybes <$> mapM fromFunction funs
    Just (klass'' :: Expr (ClsASG)) <- narrowTerm klass'
    l <- PtrList.fromList (coerce newLinks)
    IR.UniTermRecord a <- Layer.read @IR.Model klass''
    let a' = a & IR.decls_Record .~ l
    void $ Layer.write @IR.Model klass'' $ IR.UniTermRecord a'

markFunctions :: NodeRef -> ClassOp ()
markFunctions unit = let
    markASGFunction f fun = do
        newMarker <- getNextTopLevelMarker
        funStart  <- Code.functionBlockStartRef f
        Code.insertAt funStart (Code.makeMarker newMarker)
        marker    <- IR.marker newMarker
        markedFun <- IR.marked' marker (generalize f)
        Graph.clsCodeMarkers . at newMarker ?= markedFun
        LeftSpacedSpan (SpacedSpan off prevLen) <- view CodeSpan.realSpan <$> getLayer @CodeSpan f
        let markerLength = convert $ Text.length $ Code.makeMarker newMarker
        putLayer @CodeSpan marker $ CodeSpan.mkRealSpan (LeftSpacedSpan (SpacedSpan 0 markerLength))
        putLayer @CodeSpan markedFun $ CodeSpan.mkRealSpan (LeftSpacedSpan (SpacedSpan off prevLen))
        putLayer @CodeSpan f $ CodeSpan.mkRealSpan (LeftSpacedSpan (SpacedSpan 0 prevLen))
        asgLink <- getASGRootedFunctionLink fun
        replaceSource (coerce markedFun) (coerce asgLink)
        Code.gossipLengthsChangedByCls markerLength markedFun
    in matchExpr unit $ \case
        ClsASG _ _ _ _ funs' -> do
            funs <- map generalize <$> ptrListToList funs'
            for_ funs $ \fun -> source fun >>= \asgFun ->
                ASTRead.cutThroughDoc asgFun >>= \f -> matchExpr f $ \case
                    ASGFunction{} -> markASGFunction f fun
                    ClsASG{}      -> markFunctions f
                    _             -> pure ()
        Unit{} -> ASTRead.classFromUnit unit >>= \klass' -> matchExpr klass' $ \case
            ClsASG _ _ _ _ funs' -> do
                funs <- map generalize <$> ptrListToList funs'
                for_ funs $ \fun -> source fun >>= \asgFun ->
                    ASTRead.cutThroughDoc asgFun >>= \f -> matchExpr f $ \case
                        ASGFunction{} -> markASGFunction f fun
                        ClsASG{}      -> markFunctions f
                        _             -> pure ()

getASGRootedFunctionLink :: EdgeRef -> ClassOp EdgeRef
getASGRootedFunctionLink link = source link >>= \ref -> matchExpr ref $ \case
    Documented _d e -> pure $ coerce e
    Marked     _m e -> pure $ coerce e
    _               -> pure link


getNextTopLevelMarker :: ClassOp Word64
getNextTopLevelMarker = do
    globalMarkers <- use Graph.clsCodeMarkers
    let highestIndex = Safe.maximumMay $ Map.keys globalMarkers
        newMarker    = maybe 0 succ highestIndex
    Code.invalidateMarker newMarker
    pure newMarker

prepareNodeCache :: GraphLocation -> Empire NodeCache
prepareNodeCache gl = do
    let file = gl ^. GraphLocation.filePath
        toGraphLocation fun
            = GraphLocation file $ Breadcrumb [Breadcrumb.Definition fun]
    (funs, topMarkers) <- withUnit (GraphLocation.top gl) $ do
        funs       <- use $ Graph.userState . Graph.clsFuns
        topMarkers <- runASTOp $ extractMarkedMetasAndIds =<< use Graph.clsClass
        pure (Map.keys funs, Map.fromList topMarkers)
    oldMetasAndIds
        <- forM funs $ \fun -> withGraph (toGraphLocation fun) $ runASTOp $ do
            root       <- ASTRead.getCurrentBody
            oldMetas   <- extractMarkedMetasAndIds root
            pure $ Map.fromList oldMetas
    previousPortMappings
        <- forM funs $ \fun -> withGraph (toGraphLocation fun) $ runASTOp $ do
            hierarchy <- use Graph.breadcrumbHierarchy

            let lamItems = BH.getLamItems hierarchy
                elems    = lamItemToMapping ((fun, Nothing), hierarchy)
                            : map lamItemToMapping lamItems
            pure $ Map.fromList elems
    let previousNodeIds = Map.unions
            $ (Map.mapMaybe snd topMarkers)
            : (Map.mapMaybe snd <$> oldMetasAndIds)
        previousNodeMetas = Map.unions
            $ (Map.mapMaybe fst topMarkers)
            : (Map.mapMaybe fst <$> oldMetasAndIds)
    pure $ NodeCache
        previousNodeIds
        previousNodeMetas
        (Map.unions previousPortMappings)

lamItemToMapping
    :: ((NodeId, Maybe Int), BH.LamItem)
    -> ((NodeId, Maybe Int), (NodeId, NodeId))
lamItemToMapping (idArg, BH.LamItem portMapping _ _) = (idArg, portMapping)



getNodeMeta :: GraphLocation -> NodeId -> Empire (Maybe NodeMeta)
getNodeMeta loc = withGraph loc . runASTOp . AST.getNodeMeta

setNodeMeta :: GraphLocation -> NodeId -> NodeMeta -> Empire ()
setNodeMeta gl nodeId newMeta = withBreadcrumb
    gl
    (runASTOp $ setNodeMetaGraph nodeId newMeta)
    (setNodeMetaFun nodeId newMeta)

setNodePosition :: GraphLocation -> NodeId -> Position -> Empire ()
setNodePosition loc nodeId newPos = do
    oldMeta <- fromMaybe def <$> getNodeMeta loc nodeId
    void .setNodeMeta loc nodeId $ oldMeta & NodeMeta.position .~ newPos

setNodeMetaGraph :: NodeId -> NodeMeta -> GraphOp ()
setNodeMetaGraph nodeId newMeta = ASTRead.getASTRef nodeId >>= \ref ->
    void $ AST.writeMeta ref newMeta

setNodeMetaFun :: NodeId -> NodeMeta -> Command ClsGraph ()
setNodeMetaFun nodeId newMeta = runASTOp $ do
    f <- ASTRead.getFunByNodeId nodeId
    void $ AST.writeMeta f newMeta

setNodePositionAST :: NodeId -> Position -> GraphOp ()
setNodePositionAST nodeId newPos = do
    ref     <- ASTRead.getASTRef nodeId
    oldMeta <- fromMaybe def <$> AST.readMeta ref
    AST.writeMeta ref $ oldMeta & NodeMeta.position .~ newPos

setNodePositionCls :: NodeId -> Position -> ClassOp ()
setNodePositionCls nodeId newPos = do
    f       <- ASTRead.getFunByNodeId nodeId
    oldMeta <- fromMaybe def <$> AST.readMeta f
    AST.writeMeta f $ oldMeta & NodeMeta.position .~ newPos


autolayout :: GraphLocation -> Empire ()
autolayout gl = do
    children <- withGraph gl $ runASTOp $ do
        children <- uses Graph.breadcrumbHierarchy (view BH.children)
        needLayout <- fmap catMaybes $ forM (Map.keys children) $ \nid -> do
            meta <- AST.getNodeMeta nid
            pure $ if meta /= def then Nothing else Just nid
        autolayoutNodesAST needLayout
        pure children
    let toBreadcrumb (k,v) = case v of
            BH.LambdaChild{}                -> [Breadcrumb.Lambda k]
            BH.ExprChild (BH.ExprItem pc _) -> map
                (Breadcrumb.Arg k)
                (Map.keys pc)
        next = concatMap toBreadcrumb $ Map.assocs children
    traverse_ (\a -> autolayout (gl |> a)) next

autolayoutNodes :: GraphLocation -> [NodeId] -> Empire ()
autolayoutNodes gl nids = withBreadcrumb
    gl
    (runASTOp $ autolayoutNodesAST nids)
    (runASTOp $ autolayoutNodesCls nids)

autolayoutTopLevel :: GraphLocation -> Empire ()
autolayoutTopLevel gl = withUnit gl $ runASTOp $ do
    clsFuns    <- use Graph.clsFuns
    needLayout <- fmap catMaybes $ forM (Map.assocs clsFuns) $ \(nid, fun) -> do
        f    <- ASTRead.getFunByNodeId nid
        meta <- AST.readMeta f
        let fileOffset = fun ^?! Graph._FunctionDefinition . Graph.funGraph . Graph.fileOffset
        pure $ if meta /= def then Nothing else Just (nid, fileOffset)

    let sortedNeedLayout = sortOn snd needLayout
        positions    = map (Position.fromTuple . (,0)) [0,gapBetweenNodes..]
        autolayouted = zipWith
            (\(nid, _) pos -> (nid,pos))
            sortedNeedLayout
            positions
    traverse_ (uncurry setNodePositionCls) autolayouted

autolayoutNodesAST :: [NodeId] -> GraphOp ()
autolayoutNodesAST nids = timeIt "autolayoutNodes" $ do
    nodes <- GraphBuilder.buildNodesForAutolayout <!!> "buildNodesForAutolayout"
    conns <- GraphBuilder.buildConnections        <!!> "buildConnections"
    traverse_
        (uncurry setNodePositionAST)
        (Autolayout.autolayoutNodes nids nodes conns) <!!> "setNodePositionsAST"

autolayoutNodesCls :: [NodeId] -> ClassOp ()
autolayoutNodesCls nids = GraphBuilder.buildNodesForAutolayoutCls >>= \nodes ->
    traverse_
        (uncurry setNodePositionCls) 
        $ Autolayout.autolayoutNodes nids nodes mempty


substituteCodeFromPoints :: FilePath -> [TextDiff] -> Empire ()
substituteCodeFromPoints path (breakDiffs -> diffs) = do
    let gl = GraphLocation.top path
    changes <- withUnit gl $ do
        oldCode <- use Graph.code
        let noMarkers    = Code.removeMarkers oldCode
            toDelta (TextDiff range code _) = case range of
                Just (start, end) ->
                    ( Code.pointToDelta start noMarkers
                    , Code.pointToDelta end noMarkers
                    , code)
                _ -> (0, fromIntegral $ Text.length noMarkers, code)
            viewToReal c = case Text.uncons c of
                Nothing        -> Code.viewDeltasToRealBeforeMarker
                Just (char, _) -> if isSpace char
                    then Code.viewDeltasToRealBeforeMarker
                    else Code.viewDeltasToReal
            toRealDelta (a,b,c) = let (a', b') = (viewToReal c) oldCode (a,b)
                in (a', b', c)
        pure $ map (toRealDelta . toDelta) diffs
    substituteCode path changes

-- | removeMarker removes marker at given position, assuming that marker
--   consists of '«', non-zero number of digits, and '»'.
removeMarker :: Text -> Int -> Text
removeMarker code markerPos =
    let (before, after) = Text.splitAt markerPos code
        dropMarker t =
            let (markerStart, rest) =
                    fromMaybe (Lexer.markerBegin, after) $ Text.uncons t
            in if markerStart == Lexer.markerBegin
                then
                    let numberDropped      = Text.dropWhile isDigit rest
                        (markerEnd, rest') = fromMaybe (Lexer.markerEnd, after)
                            $ Text.uncons numberDropped
                    in if markerEnd == Lexer.markerEnd
                        then rest'
                        else after
                else error $ "marker start is wrong: " <> [markerStart]
    in Text.concat [before, dropMarker after]

-- | This function computes offsets of each token from the beginning
--   of the file and stores them in _offset field of Token
cumulativeOffsetStream :: [Lexer.Token a] -> [Lexer.Token a]
cumulativeOffsetStream tokens = scanl1 f tokens where
    f (Lexer.Token prevSpan accOffset _) (Lexer.Token span offset lexeme)
        = Lexer.Token (span+offset) (accOffset + prevSpan) lexeme

indentFromOffsets :: Delta -> Delta -> Delta
indentFromOffsets prevOffset nextOffset =
    let eolSpan = fromIntegral $ length ("\n" :: String)
    in nextOffset - prevOffset - eolSpan

-- | Takes a pair of consecutive tokens and determines if a marker
--   is placed in a proper position. If the second token is not a marker
--   or if it seems to be correctly placed, `Nothing` is returned.
--   If marker is determined to be incorrectly placed, `Just offset`
--   is returned, where offset is taken from the second token.
--   This function assumes that Tokens have cumulative offset inside
--   them, so offset returned is offset from the beginning of the code.
--
--   Marker is thought to be wrongly placed if it's directly preceded
--   by anything else than:
--       - beginning of code
--       - end of line (if token offset is greater than block)
--       - block start (:)
isWrongMarker
    :: (Delta, (Lexer.Token Lexer.Symbol, Lexer.Token Lexer.Symbol))
    -> Maybe Delta
isWrongMarker tokens
    | (blockIndent, (Lexer.Token _ precOffset preceding,
       Lexer.Token _ currOffset (Lexer.Marker{}))) <- tokens =
        case preceding of
            Lexer.EOL        ->
                let indent  = indentFromOffsets precOffset currOffset
                in  if indent > blockIndent
                    then Just currOffset
                    else Nothing
            Lexer.STX        -> Nothing
            Lexer.BlockStart -> Nothing
            _                -> Just currOffset
    | otherwise = Nothing

determineIndentation
    :: (Delta, (Lexer.Token Lexer.Symbol, Lexer.Token Lexer.Symbol))
    -> (Lexer.Token Lexer.Symbol, Lexer.Token Lexer.Symbol)
    -> (Delta, (Lexer.Token Lexer.Symbol, Lexer.Token Lexer.Symbol))
determineIndentation (blockIndent, _) tokens
    | (Lexer.Token precSpan _ Lexer.BlockStart,
       Lexer.Token precSpanAndOffset _ Lexer.EOL) <- tokens =
        let indent = precSpanAndOffset - precSpan
        in  if indent > blockIndent
            then (indent, tokens)
            else (blockIndent, tokens)
    | (Lexer.Token _ precOffset Lexer.EOL,
       Lexer.Token _ nextOffset next) <- tokens =
        case next of
            Lexer.EOL -> (blockIndent, tokens)
            _         ->
                let indent = indentFromOffsets precOffset nextOffset
                in  if indent == 0 || indent > blockIndent
                    then (blockIndent, tokens)
                    else (indent, tokens)
    | otherwise = (blockIndent, tokens)


sanitizeMarkers :: Text -> Text
sanitizeMarkers text = let
    removeErroneousMarkers markers code
        = foldl' removeMarker code (reverse $ sort markers)
    lexerStream      = Lexer.evalDefLexer (convert text)
    cumulativeStream = cumulativeOffsetStream lexerStream
    markersIndices   = findIndices (== Lexer.markerBegin) $ toList text
    tokensForMarkers = fmap (\a -> (a, findToken cumulativeStream a))
        $ coerce markersIndices
    findToken stream index = find (\t -> t ^. Lexer.offset == index) stream
    erroneousMarkers =
        [ a | (a, Nothing) <- tokensForMarkers] <> wrongMarkers
    precedingTokens  = zip cumulativeStream $ tail cumulativeStream
    tokensWithIndent =
        case precedingTokens of
            []     -> []
            (x:xs) ->
                let noIndent = 0
                in scanl determineIndentation (noIndent, x) xs
    wrongMarkers     = catMaybes $ fmap isWrongMarker tokensWithIndent
    in if null erroneousMarkers
        then text
        else removeErroneousMarkers (coerce erroneousMarkers) text


substituteCode :: FilePath -> [(Delta, Delta, Text)] -> Empire ()
substituteCode path changes = do
    let gl = GraphLocation.top path
    newCode <- sanitizeMarkers <$> withUnit gl (Code.applyMany changes)
    handle
        (\(e :: SomeException)
            -> withUnit gl $ Graph.userState . Graph.clsParseError ?= e)
        $ do
            withUnit gl $ Graph.code .= newCode
            reloadCode gl newCode

loadCode :: GraphLocation -> Text -> Empire ()
loadCode gl code = do
    let topGl = GraphLocation.top gl
        file  = gl ^. GraphLocation.filePath
        libraryBody
            = Graph.userState . Empire.activeFiles . at file . traverse . Library.body
    (unit, grSt, scSt, exprMap) <- liftIO $ ASTParse.runProperParser code
    Graph.pmState . Graph.pmScheduler    .= scSt
    Graph.pmState . Graph.pmStage        .= grSt
    libraryBody   . Graph.clsClass       .= unit
    libraryBody   . Graph.clsCodeMarkers .= coerce exprMap
    libraryBody   . Graph.code           .= code
    libraryBody   . Graph.clsFuns        .= Map.empty

    (codeHadMeta, prevParseError) <- withUnit topGl $ do
        prevParseError <- use $ Graph.userState . Graph.clsParseError
        Graph.userState . Graph.clsParseError .= Nothing
        fileMetadata <- FileMetadata.toList <$> runASTOp readMetadata'
        let savedNodeMetas 
                = Map.fromList $ map FileMetadata.toTuple fileMetadata
        Graph.userState . Graph.nodeCache . nodeMetaMap
            %= (\cache -> Map.union cache savedNodeMetas)
        runASTOp $ do
            let codeWithoutMeta = stripMetadata code
            Graph.code .= codeWithoutMeta
            metaRef <- ASTRead.getMetadataRef unit
            removeMetadataNode
            for_ metaRef deepDelete
            pure (codeWithoutMeta /= code, prevParseError)
    when (codeHadMeta && isJust prevParseError) $ resendCode topGl
    functions <- withUnit topGl $ do
        klass <- use $ Graph.userState . Graph.clsClass
        runASTOp $ do
            markFunctions klass
            funs <- ASTRead.unitDefinitions klass
            forM funs $ \f -> ASTRead.cutThroughDoc f >>= \fun ->
                matchExpr fun $ \case
                    Marked m _e -> do
                        marker <- ASTBreadcrumb.getMarker =<< source m
                        uuid   <- use $ Graph.nodeCache . nodeIdMap . at marker
                        pure (uuid, f)
                    _ -> do
                        pure (Nothing, f)
    for_ functions $ \(lastUUID, fun) -> do
        uuid <- withLibrary file $ fst <$> makeGraph fun lastUUID
        let glToAutolayout = gl & GraphLocation.breadcrumb
                .~ Breadcrumb [Definition uuid]
        -- void $ autolayout glToAutolayout
        return ()
    return ()
    -- void $ autolayoutTopLevel topGl


reloadCode :: GraphLocation -> Text -> Empire ()
reloadCode gl code = do
    nodeCache <- prepareNodeCache gl
    withUnit (GraphLocation.top gl)
        $ Graph.userState . Graph.nodeCache .= nodeCache
    loadCode gl code

breakDiffs :: [TextDiff] -> [TextDiff]
breakDiffs diffs = go [] diffs where
    go acc [] = reverse acc
    go acc (d@(TextDiff range code cursor):list) =
        case Text.span isSpace code of
            (prefix, suffix)
                | Text.null prefix -> go (d:acc) list
                | otherwise        -> let
                        rangeEnd   = fromJust (fmap snd range)
                        newRange   = Just (rangeEnd, rangeEnd)
                        whitespace = TextDiff range prefix cursor
                        onlyCode   = TextDiff newRange suffix cursor
                    in go (onlyCode:whitespace:acc) list

resendCode :: GraphLocation -> Empire ()
resendCode gl = resendCodeWithCursor gl Nothing

resendCodeWithCursor :: GraphLocation -> Maybe Point -> Empire ()
resendCodeWithCursor gl cursor = getCode gl >>= \code ->
    Publisher.notifyCodeUpdate (gl ^. GraphLocation.filePath) code cursor

getCode :: GraphLocation -> Empire Text
getCode gl
    = Code.removeMarkers <$> withUnit (GraphLocation.top gl) (use Graph.code)

openFile :: FilePath -> Empire Library
openFile path = do
    code <- liftIO (Text.readFile path) <!!> "readFile"
    modName <- handle (\(_e::SomeException) -> return Nothing) $ Just <$> Typecheck.filePathToQualName path
    lib <- Library.createLibrary (convertVia @String <$> modName) path  <!!> "createLibrary"
    let loc = GraphLocation path $ Breadcrumb []
    withUnit loc (Graph.code .= code)
    result <- try $ do
        loadCode loc code <!!> "loadCode"
        withUnit loc $ Graph.userState . Graph.clsParseError .= Nothing
    case result of
        Left e -> withUnit loc $ Graph.userState . Graph.clsParseError ?= e
        _      -> return ()
    return lib

typecheck :: GraphLocation -> Empire ()
typecheck loc = withTC' loc False (return ()) (return ())

putIntoHierarchy :: NodeId -> NodeRef -> GraphOp ()
putIntoHierarchy nodeId marked = do
    let nodeItem = BH.ExprItem Map.empty marked
    Graph.breadcrumbHierarchy . BH.children . at nodeId ?= BH.ExprChild nodeItem

putChildrenIntoHierarchy :: NodeId -> NodeRef -> GraphOp ()
putChildrenIntoHierarchy uuid expr = do
    target       <- ASTRead.getASTTarget uuid
    marked       <- ASTRead.getASTRef uuid
    item         <- prepareChild marked target
    Graph.breadcrumbHierarchy . BH.children . ix uuid .= item

copyMeta :: NodeRef -> NodeRef -> GraphOp ()
copyMeta donor recipient = do
    meta <- AST.readMeta donor
    for_ meta $ AST.writeMeta recipient

markNode :: NodeId -> GraphOp ()
markNode nodeId = do
    var <- ASTRead.getASTMarkerPosition nodeId
    ASTBuilder.attachNodeMarkers nodeId [] var


getNodeMetas :: GraphLocation -> [NodeLoc] -> Empire [Maybe (NodeLoc, NodeMeta)]
getNodeMetas loc nids
    | GraphLocation f (Breadcrumb []) <- loc = withUnit loc $ runASTOp $ do
        clsFuns    <- use Graph.clsFuns
        forM (Map.assocs clsFuns) $ \(id, fun) -> do
            case find (\n -> convert n == id) nids of
                Just nl -> do
                    f     <- ASTRead.getFunByNodeId id
                    fmap (nl,) <$> AST.readMeta f
                _       -> return Nothing
    | otherwise = withGraph loc $ runASTOp $ do
        kids <- uses Graph.breadcrumbHierarchy (view BH.children)
        forM (Map.keys kids) $ \id -> do
            case find (\n -> convert n == id) nids of
                Just nl -> do
                    fmap (nl,) <$> AST.getNodeMeta id
                _       -> return Nothing

printMarkedExpression :: NodeRef -> GraphOp Text
printMarkedExpression ref = do
    exprMap <- getExprMap
    realRef <- matchExpr ref $ \case
        Marked _m expr -> source expr
        _                 -> return ref
    expr    <- Text.pack <$> ASTPrint.printExpression realRef
    let markers = Map.keys $ Map.filter (== ref) exprMap
        marker  = case markers of
            (index:_) -> Text.pack $ "«" <> show index <> "»"
            _         -> ""
    return $ Text.concat [marker, expr]

data Sidebar = SidebarInput | SidebarOutput | NotSidebar
    deriving Eq

isSidebar :: NodeId -> GraphOp Sidebar
isSidebar nodeId = do
    (input, output) <- GraphBuilder.getEdgePortMapping
    return $ if | input  == nodeId -> SidebarInput
                | output == nodeId -> SidebarOutput
                | otherwise        -> NotSidebar

isInput :: NodeId -> GraphOp Bool
isInput nodeId = (== SidebarInput) <$> isSidebar nodeId

isOutput :: NodeId -> GraphOp Bool
isOutput nodeId = (== SidebarOutput) <$> isSidebar nodeId

functionLocation :: GraphLocation -> GraphLocation
functionLocation (GraphLocation file (Breadcrumb b))
    | ((Breadcrumb.Definition f) : _) <- b = GraphLocation file (Breadcrumb [Breadcrumb.Definition f])
    | otherwise = GraphLocation file (Breadcrumb [])

previousOffset :: NodeRef -> GraphOp Delta
previousOffset ref = do
    parents <- getLayer @IRSuccs ref
    p <- Mutable.toList parents
    case p of
        [] -> return mempty
        [parent] -> do
            inputs <- mapM source =<< inputs =<< target parent
            let lefts = takeWhile (/= ref) inputs
            spans  <- mapM readCodeSpan lefts
            let LeftSpacedSpan (SpacedSpan leftOff leftLen) = mconcat spans
            offset <- previousOffset =<< target parent
            LeftSpacedSpan (SpacedSpan o _) <- readCodeSpan =<< target parent
            return (leftOff + offset + o + leftLen)

readRangeProper :: NodeRef -> GraphOp (LeftSpacedSpan Delta)
readRangeProper ref = do
    refSpan@(LeftSpacedSpan (SpacedSpan off len)) <- readCodeSpan ref
    moreOffset <- previousOffset ref
    let properOffset = off + moreOffset
        properSpan   = leftSpacedSpan properOffset len
    return properSpan

readRange :: NodeRef -> GraphOp (Int, Int)
readRange ref = do
    LeftSpacedSpan (SpacedSpan offset len) <- readRangeProper ref
    fileOffset <- fromMaybe 0 <$> Code.getOffsetRelativeToFile ref
    return (fromIntegral (fileOffset), fromIntegral (fileOffset + len))

readCodeSpan :: NodeRef -> GraphOp (LeftSpacedSpan Delta)
readCodeSpan ref = view CodeSpan.realSpan <$> getLayer @CodeSpan ref

setCodeSpan :: NodeRef -> LeftSpacedSpan Delta -> GraphOp ()
setCodeSpan ref s = putLayer @CodeSpan ref $ CodeSpan.mkRealSpan s

getNodeIdForMarker :: Int -> GraphOp (Maybe NodeId)
getNodeIdForMarker index = do
    exprMap      <- getExprMap
    let exprMap' :: Map.Map Graph.MarkerId NodeRef
        exprMap' = coerce exprMap
        ref      = Map.lookup (fromIntegral index) exprMap'
    case ref of
        Nothing -> return Nothing
        Just r  -> matchExpr r $ \case
            Marked _m expr -> do
                expr'     <- source expr
                nodeId    <- ASTRead.getNodeId expr'
                return nodeId

markerCodeSpan :: GraphLocation -> Int -> Empire (Int, Int)
markerCodeSpan loc index = withGraph loc $ runASTOp $ do
    exprMap      <- getExprMap
    let exprMap' :: Map.Map Graph.MarkerId NodeRef
        exprMap' = coerce exprMap
        Just ref = Map.lookup (fromIntegral index) exprMap'
    readRange ref


unindent :: Int -> Text -> Text
unindent offset code = Text.unlines $ map (Text.drop offset) $ Text.lines code

data ImpossibleToInsert = ImpossibleToCollapse
    deriving (Show)

instance Exception ImpossibleToInsert where
    fromException = astExceptionFromException
    toException = astExceptionToException

findRefToInsertAfter :: Set NodeRef -> Set NodeRef -> NodeRef -> GraphOp (Maybe NodeRef)
findRefToInsertAfter beforeNodes afterNodes ref = do
    if Set.null beforeNodes
      then return $ Just ref
      else matchExpr ref $ \case
          Seq l r -> do
              right <- source r
              if Set.member right afterNodes
                then throwM ImpossibleToCollapse
                else findRefToInsertAfter (Set.delete right beforeNodes) afterNodes =<< source l
          _ -> if Set.member ref afterNodes
                 then throwM ImpossibleToCollapse
                 else return Nothing

insertCodeBeforeFunction :: GraphLocation -> Text -> Empire Text
insertCodeBeforeFunction loc@(GraphLocation file _) codeToInsert = do
    let nodeId = topLevelFunctionID loc
    withUnit (GraphLocation file def) $ runASTOp $ do
        ref <- ASTRead.getFunByNodeId nodeId
        fo <- Code.functionBlockStartRef ref
        Code.insertAt fo (Text.snoc (Text.snoc codeToInsert '\n') '\n')

insertCodeBetween :: [NodeId] -> [NodeId] -> Text -> GraphOp Text
insertCodeBetween beforeNodes afterNodes codeToInsert = do
    beforeRefs <- fmap Set.fromList $ forM beforeNodes ASTRead.getASTRef
    afterRefs  <- fmap Set.fromList $ forM afterNodes  ASTRead.getASTRef
    topSeq     <- ASTRead.getCurrentBody
    output     <- getCurrentFunctionOutput
    refToInsertAfter <- findRefToInsertAfter (Set.insert output beforeRefs) afterRefs topSeq
    insertPos        <- case refToInsertAfter of
        Nothing -> do
            len <- getLayer @SpanLength output
            (+len) <$> Code.getCurrentBlockBeginning
        Just r  -> do
            Just beg <- Code.getOffsetRelativeToFile r
            len      <- getLayer @SpanLength r
            return $ beg + len
    Code.insertAt insertPos codeToInsert

generateCollapsedDefCode :: Text -> [OutPortRef] -> [OutPortRef] -> [NodeId] -> GraphOp (Text, Text, Maybe Text, Position)
generateCollapsedDefCode defName inputs' outputs bodyIds = do
    (inputSidebar, _) <- GraphBuilder.getEdgePortMapping
    inputNames <- fmap (map (view _2) . sortOn fst) $ forM inputs' $ \(OutPortRef (convert -> nodeId) pid) -> do
        position <- if nodeId == inputSidebar then return def
                                              else fmap (view NodeMeta.position) <$> AST.getNodeMeta nodeId
        name     <- ASTRead.getASTOutForPort nodeId pid >>= ASTRead.getVarName
        return (position, name)
    outputNames <- forM outputs $ \(OutPortRef (convert -> nodeId) pid) ->
        ASTRead.getASTOutForPort nodeId pid >>= ASTRead.getVarName
    let singleOutput = case outputs of
            [a] -> Just $ a ^. PortRef.srcNodeId
            _   -> Nothing
    singleOutputMeta <- forM singleOutput AST.getNodeMeta
    let singleOutputPosition = fmap (view NodeMeta.position) (join singleOutputMeta)
    bodyMetas <- mapM AST.getNodeMeta bodyIds
    let bodyPositions = sortOn (view Position.x) $ map (view NodeMeta.position) $ catMaybes bodyMetas
        rightmostPosition = last bodyPositions
    codeBegs <- fmap (sortOn fst) $ forM bodyIds $ \nid -> do
        ref     <- ASTRead.getASTPointer nid
        Just cb <- Code.getOffsetRelativeToFile ref
        return (cb, ref)
    currentIndentation <- Code.getCurrentIndentationLength
    let indentBy i l = "\n" <> Text.replicate (fromIntegral i) " " <> l
        bodyIndented = indentBy Code.defaultIndentationLength
        retIndented  = indentBy currentIndentation
    newCodeBlockBody <- fmap Text.concat $ forM codeBegs $ \(beg, ref) -> do
        len  <- getLayer @SpanLength ref
        code <- Code.getAt beg (beg + len)
        return $ bodyIndented code
    let header =  "def "
               <> Text.unwords (defName : fmap convert inputNames)
               <> ":"
    returnBody <- case outputNames of
        []  -> do
            let lastNode = snd $ unsafeLast codeBegs
            handle (\(_::NotUnifyException) -> return Nothing) (Just <$> (ASTRead.getVarNode lastNode >>= Code.getCodeOf))
        [a] -> return $ Just $ convert a
        _   -> return $ Just $ "(" <> Text.intercalate ", " (convert <$> outputNames) <> ")"
    let returnLine = case returnBody of
            Just n -> bodyIndented n
            _      -> ""
    let defCode = header <> newCodeBlockBody <> returnLine
    let useLine = retIndented $ maybe "" (<> " = ") returnBody
                              <> Text.unwords (defName : fmap convert inputNames)
    return (defCode, useLine, returnBody, fromMaybe rightmostPosition singleOutputPosition)

topLevelFunctionID :: GraphLocation -> NodeId
topLevelFunctionID (GraphLocation _ (Breadcrumb (Breadcrumb.Definition nodeId:_))) = nodeId

collapseToFunction :: GraphLocation -> [NodeId] -> Empire ()
collapseToFunction loc@(GraphLocation file _) nids = do
    nodes <- getNodes (GraphLocation file def)
    when (null nids) $ throwM ImpossibleToCollapse
    let names   = Set.fromList $ mapMaybe (view Node.name) nodes
        newName = generateNewFunctionName names "func"
    (defCode, useVarName, outputPosition) <- withGraph loc $ runASTOp $ do
        let ids = Set.fromList nids
        connections       <- GraphBuilder.buildConnections
        (inputSidebar, _) <- GraphBuilder.getEdgePortMapping
        let srcInIds = flip Set.member ids . view PortRef.srcNodeId . fst
            dstInIds = flip Set.member ids . view PortRef.dstNodeId . snd
            inConns  = filter (\x -> dstInIds x && not (srcInIds x)) connections
            inputs'  = nub $ fst <$> inConns
            outConns = filter (\x -> srcInIds x && not (dstInIds x)) connections
        outConns' <- filterM (\a -> not <$> isOutput (view PortRef.dstNodeId $ snd a)) outConns
        let outputs  = nub $ fst <$> outConns'
            useSites = outConns' ^.. traverse . _2 . PortRef.dstNodeId
        (defCode, useCode, useVarName, outputPosition) <- generateCollapsedDefCode newName inputs' outputs nids
        let inputsNodeIds = List.delete inputSidebar $ map (view PortRef.srcNodeId) inputs'
        insertCodeBetween useSites inputsNodeIds useCode
        return (defCode, useVarName, outputPosition)
    code <- insertCodeBeforeFunction loc defCode
    reloadCode  loc code
    typecheckWithRecompute (GraphLocation file def)
    removeNodes loc nids
    withGraph loc $ runASTOp $ do
        nodes' <- GraphBuilder.buildNodes
        let funUseNodes = filter (\n -> n ^. Node.name == useVarName) nodes'
        case funUseNodes of
            [a] -> setNodePositionAST (a ^. Node.nodeId) outputPosition
            _   -> return ()

prepareCopy :: GraphLocation -> [NodeId] -> Empire String
prepareCopy loc@(GraphLocation _ (Breadcrumb [])) nodeIds = withUnit loc $ do
    clipboard <- runASTOp $ do
        starts  <- mapM Code.functionBlockStart nodeIds
        lengths <- do
            funs  <- use Graph.clsFuns
            let names       = map (\a -> (a, Map.lookup a funs)) nodeIds
                nonExistent = filter (isNothing . snd) names
            forM nonExistent $ \(nid, _) ->
                throwM $ BH.BreadcrumbDoesNotExistException (Breadcrumb [Breadcrumb.Definition nid])
            refs <- mapM ASTRead.getFunByNodeId [ nid | (nid, Just (view (Graph._FunctionDefinition . Graph.funName) -> _name)) <- names]
            forM refs $ \ref -> do
                LeftSpacedSpan (SpacedSpan _off len) <- view CodeSpan.realSpan <$> getLayer @CodeSpan ref
                pure $ fromIntegral len
        codes <- mapM
            (\(start, len) -> Code.removeMarkers <$> Code.getAt start (start + len)) $
            zip starts lengths
        pure $ Text.intercalate "\n" codes
    pure $ Text.unpack clipboard
prepareCopy loc nodeIds = withGraph loc $ do
    codes <- runASTOp $ forM nodeIds $ \nid -> do
        ref     <- ASTRead.getASTPointer nid
        code    <- Code.removeMarkers <$> Code.getCodeOf ref
        pure code
    pure $ Text.unpack $ Text.intercalate "\n" codes

moveToOrigin :: [MarkerNodeMeta] -> [MarkerNodeMeta]
moveToOrigin metas' = map (\(MarkerNodeMeta m me) -> MarkerNodeMeta m (me & NodeMeta.position %~ Position.move (coerce (Position.rescale leftTopCorner (-1))))) metas'
    where
        leftTopCorner = fromMaybe (Position.fromTuple (0,0))
                      $ Position.leftTopPoint
                      $ map (\mnm -> FileMetadata.meta mnm ^. NodeMeta.position) metas'

indent :: Int -> Text -> Text
indent offset (Text.lines -> lines) =
    Text.unlines $ map (\line -> Text.concat [Text.replicate offset " ", line]) lines
indent _      code = code

data B = Break | NoBreak deriving Show

exprBreaker :: [Text] -> [B] -> [Text]
exprBreaker _  []     = []
exprBreaker [] _      = []
exprBreaker (l:ls) bs = go [l] ls bs
    where
        go acc [] _ = reverse acc
        go (acc:accs) (ln:lns) (b:breaks) = case b of
            Break -> go (ln:acc:accs) lns breaks
            NoBreak -> go ((Text.stripEnd $ Text.unlines [acc, ln]):accs) lns breaks

paste :: GraphLocation -> Position -> String -> Empire ()
paste loc@(GraphLocation file (Breadcrumb [])) position (Text.pack -> code) = do
    newCode <- withUnit loc $ runASTOp $ do
        unit  <- use Graph.clsClass
        funs  <- ASTRead.unitDefinitions unit
        funStarts <- forM funs $ \fun -> do
            xFun <- view (NodeMeta.position . Position.x) <$> (fromMaybe def <$> AST.readMeta fun)
            if xFun < position ^. Position.x then return Nothing else do
                funStart <- Code.functionBlockStartRef fun
                return $ Just funStart
        let cleanCode = Code.removeMarkers code
        let spacedCode = cleanCode <> "\n"
        case Safe.headMay (catMaybes funStarts) of
            Just codePosition -> Code.applyDiff codePosition codePosition spacedCode
            _                 -> do
                unitSpan <- getLayer @CodeSpan unit
                let endOfFile = view (CodeSpan.realSpan . Span.length) unitSpan
                Code.applyDiff endOfFile endOfFile $ Text.cons '\n' cleanCode
    reloadCode loc newCode
    resendCode loc
paste loc position (Text.pack -> text) = do
    newCode <- withGraph loc $ runASTOp $ do
        indentation <- fromIntegral <$> Code.getCurrentIndentationLength
        oldSeq             <- ASTRead.getCurrentBody
        nodes              <- AST.readSeq oldSeq
        nodesAndMetas      <- mapM (\n -> (n,) <$> AST.readMeta n) nodes
        let nodesWithMetas =  mapMaybe (\(n,m) -> (n,) <$> m) nodesAndMetas
        nearestNode        <- findPreviousNodeInSequence oldSeq
            (def & NodeMeta.position .~ position) nodesWithMetas
        let text' = Code.removeMarkers text
            code  = "\n" <> Text.stripEnd (indent indentation text')
        case nearestNode of
            Just ref -> do
                Just beg <- Code.getAnyBeginningOf ref
                len <- getLayer @SpanLength ref
                Code.applyDiff (beg+len) (beg+len) code
            _        -> do
                beg <- Code.getCurrentBlockBeginning
                Code.applyDiff beg beg $ text' <> "\n" <> Text.replicate indentation " "
    reloadCode loc newCode
    typecheck loc
    resendCode loc

includeWhitespace :: Text -> (Delta, Delta) -> (Delta, Delta)
includeWhitespace c (s, e) = (newStart, e)
    where
        prefix = Text.take (fromIntegral s) c
        whitespaceBefore = Text.takeWhileEnd isSeparator prefix
        newStart = s - fromIntegral (if Text.length whitespaceBefore `rem` 4 == 0 then Text.length whitespaceBefore else 0)

copyText :: GraphLocation -> [Range] -> Empire Text
copyText (GraphLocation file _) ranges = do
    withUnit (GraphLocation file (Breadcrumb [])) $ do
        oldCode <- use $ Graph.userState . Graph.code
        let markedRanges = map rangeToSpan ranges
        let codeWithoutMarkers = Code.removeMarkers oldCode
        let getAt (fromIntegral -> from) (fromIntegral -> to) = do
                return $ Text.take (to - from) $ Text.drop from codeWithoutMarkers
        codes <- forM markedRanges $ \(s, e) -> getAt s e
        let code                   = Text.concat codes
        return code

rangeToSpan :: Range -> (Delta, Delta)
rangeToSpan (Range s e) = (fromIntegral s, fromIntegral e)

rangeToMarked :: Text -> Range -> (Delta, Delta)
rangeToMarked code range' = (start, end)
    where
        span         = rangeToSpan range'
        (start, end) = Code.viewDeltasToRealBeforeMarker code span

pasteText :: GraphLocation -> [Range] -> [Text] -> Empire Text
pasteText loc ranges (Text.concat -> text) = do
    let topLoc = GraphLocation.top loc
    res <- withUnit topLoc $ do
        runASTOp $ forM (Safe.headMay ranges) $ \range -> do
            code <- use Graph.code
            let (start, end) = rangeToMarked code range
                cleanText    = Code.removeMarkers text
            code' <- Code.applyDiff start end cleanText
            let endPosition = start + fromIntegral (Text.length cleanText)
                cursorPos   = Code.deltaToPoint endPosition code'
            pure (code', cursorPos)
    case res of
        Just (newCode, cursorPos) -> do
            reloadCode topLoc newCode `catch`
                \(e::ASTParse.SomeParserException) -> do
                    withUnit topLoc $ do
                        Graph.userState . Graph.code .= newCode
                        Graph.userState . Graph.clsParseError ?= toException e
            typecheck loc `catch` \(e::BH.BreadcrumbDoesNotExistException) ->
                -- if after reloading, our loc no longer exists, ignore error
                pure ()
            resendCodeWithCursor topLoc (Just cursorPos)
            pure newCode
        _ -> pure mempty

nativeModuleName :: Text
nativeModuleName = "Native"

getImportsInFile :: ClassOp [Text]
getImportsInFile = do
    let matchUnit unit = matchExpr unit $ \(Unit imps _ _) ->
            matchImports =<< source imps
        matchImports imps = matchExpr imps $ \(ImportHub imps') ->
            mapM matchImport =<< mapM source =<< ptrListToList imps'
        matchImport imp = matchExpr imp $ \case
            Import absolute _ -> matchAbsolute =<< source absolute
            _                 -> pure Nothing
        matchAbsolute a = matchExpr a $ \case
            ImportSrc (Term.Absolute n) -> pure . Just . nameToText $ convert n
            _                           -> pure Nothing
    unit    <- use Graph.clsClass
    imports <- matchUnit unit
    return $ catMaybes imports

getAvailableImports :: GraphLocation -> Empire (Set LibraryName)
getAvailableImports gl = withUnit pureGl mkImports where
    pureGl = GraphLocation (gl ^. GraphLocation.filePath) mempty
    implicitImports = [nativeModuleName, "Std.Base"]
    mkImports = fromList . (implicitImports <>) <$> runASTOp getImportsInFile

classToHints :: Class.Class -> ClassHints
classToHints (Class.Class constructors methods _)
    = ClassHints constructorsHints methodsHints where
        getDocumentation  = fromMaybe mempty . view Def.documentation
        constructorsHints = ((, mempty) . convert) <$> Map.keys constructors
        methodsHints      = (convert *** getDocumentation) <$>
            filter (isPublicMethod . fst) (Map.toList $ unwrap methods)

isPublicMethod :: IR.Name -> Bool
isPublicMethod (nameToString -> n) = Safe.headMay n /= Just '_'

importsToHints :: Unit.Unit -> LibraryHints
importsToHints (Unit.Unit definitions classes)
    = LibraryHints funHints $ Map.mapKeys convert classHints where
        funHints   = (convert *** (fromMaybe "" . view Def.documentation))
            <$> Map.toList (unwrap definitions)
        classHints = (classToHints . view Def.documented) <$> classes

data ModuleCompilationException = ModuleCompilationException ModLoader.UnitLoadingError
    deriving (Show)

instance Exception ModuleCompilationException where
    toException = astExceptionToException
    fromException = astExceptionFromException

-- filterPrimMethods :: Module.Imports -> Module.Imports
-- filterPrimMethods = id
-- filterPrimMethods (Module.Imports classes funs) = Module.Imports classes properFuns
--     where
--         properFuns = Map.filterWithKey (\k _ -> not $ isPrimMethod k) funs
--         isPrimMethod (nameToString -> n) = "prim" `List.isPrefixOf` n || n == "#uminus#"

qualNameToText :: IR.Qualified -> Text
qualNameToText = convertVia @String

getImportPaths :: GraphLocation -> IO [FilePath]
getImportPaths (GraphLocation file _) = do
    currentProjPath <- Package.packageRootForFile =<< Path.parseAbsFile file
    importPaths     <- Package.packageImportPaths currentProjPath
    return $ map (view _2) importPaths

getSearcherHints :: GraphLocation -> Empire LibrariesHintsMap
getSearcherHints loc = do
    importPaths     <- liftIO $ getImportPaths loc
    availableSource <- liftIO $ forM importPaths $ \path -> do
        sources <- Package.findPackageSources =<< Path.parseAbsDir path
        return $ Bimap.toMapR sources
    let union = Map.map (Path.toFilePath) $ Map.unions availableSource
    -- importsMVar <- view modules
    -- cmpModules  <- liftIO $ readMVar importsMVar
    res         <- try $ liftScheduler $ do
        ModLoader.initHC
        (_fin, stdUnitRef) <- Std.stdlib @Stage
        Scheduler.registerAttr @Unit.UnitRefsMap
        Scheduler.setAttr @Unit.UnitRefsMap $ wrap $ Map.singleton "Std.Primitive" stdUnitRef
        forM (Map.keys union) $ ModLoader.loadUnit def union []
        refsMap <- Scheduler.getAttr @Unit.UnitRefsMap
        units <- flip Map.traverseWithKey (unwrap refsMap) $ \name unitRef -> case unitRef ^. Unit.root of
            Unit.Graph termUnit   -> UnitMapper.mapUnit name termUnit
            Unit.Precompiled unit -> return unit
        return units
    case res of
        Left exc    -> throwM $ ModuleCompilationException exc
        Right units -> do
            -- Lifted.tryPutMVar importsMVar units
            return $ Map.fromList
                   $ map (\(a, b) -> (qualNameToText a, importsToHints b))
                   $ Map.toList units


reloadInterpreter :: GraphLocation -> Empire ()
reloadInterpreter = runInterpreter

startInterpreter :: GraphLocation -> Empire ()
startInterpreter loc = do
    Graph.userState . activeInterpreter .= True
    Publisher.notifyInterpreterUpdate "Interpreter running"
    runInterpreter loc

pauseInterpreter :: GraphLocation -> Empire ()
pauseInterpreter loc = do
    Graph.userState . activeInterpreter .= False
    Publisher.notifyInterpreterUpdate "Interpreter stopped"
    withTC' loc False (return ()) (return ())

-- internal

getName :: GraphLocation -> NodeId -> Empire (Maybe Text)
getName loc nid = withGraph' loc (runASTOp $ GraphBuilder.getNodeName nid) $
    use (Graph.userState . Graph.clsFuns . ix nid . Graph._FunctionDefinition . Graph.funName . packed . re _Just)

generateNodeName :: NodeRef -> GraphOp Text
generateNodeName = ASTPrint.genNodeBaseName >=> generateNodeNameFromBase

generateNodeNameFromBase :: Text -> GraphOp Text
generateNodeNameFromBase base = do
    ids   <- uses Graph.breadcrumbHierarchy BH.topLevelIDs
    names <- Set.fromList . catMaybes <$> mapM GraphBuilder.getNodeName ids
    return $ generateNewFunctionName names base

generateNewFunctionName :: Set Text -> Text -> Text
generateNewFunctionName forbiddenNames base =
    let allPossibleNames = zipWith (<>) (repeat base) (convert . show <$> [1..])
        Just newName     = find (not . flip Set.member forbiddenNames) allPossibleNames
    in newName

runTC :: GraphLocation -> Bool -> Bool -> Bool -> Empire ()
runTC loc flush interpret recompute = do
    newLoc@(GraphLocation newFile _) <- resolveRedirection loc
    Just g <- preuse $ Graph.userState . activeFiles . at newFile . _Just . Library.body
    let root = g ^. Graph.clsClass
    rooted <- runASTOp $ Store.serializeWithRedirectMap root
    Publisher.requestTC newLoc loc g rooted flush interpret recompute

typecheckWithRecompute :: GraphLocation -> Empire ()
typecheckWithRecompute loc = runTC loc True True True

runInterpreter :: GraphLocation -> Empire ()
runInterpreter loc = runTC loc True True False

withTC' :: GraphLocation -> Bool -> Command Graph a -> Command ClsGraph a -> Empire a
withTC' loc@(GraphLocation file bs) flush actG actC = do
    res       <- withBreadcrumb loc actG actC
    interpret <- use $ Graph.userState . activeInterpreter
    runTC loc flush interpret False
    return res

withTCUnit :: GraphLocation -> Bool -> Command ClsGraph a -> Empire a
withTCUnit loc flush cmd = withTC' loc flush (throwM UnsupportedOperation) cmd

withTC :: GraphLocation -> Bool -> Command Graph a -> Empire a
withTC loc flush actG = withTC' loc flush actG (throwM UnsupportedOperation)

withGraph' :: GraphLocation -> Command Graph a -> Command ClsGraph a -> Empire a
withGraph' gl actG actC = withBreadcrumb gl actG actC

getOutEdges :: NodeId -> GraphOp [InPortRef]
getOutEdges nodeId = do
    edges <- GraphBuilder.buildConnections
    let filtered = filter (\(opr, _) -> opr ^. PortRef.srcNodeLoc == convert nodeId) edges
    return $ view _2 <$> filtered

disconnectPort :: InPortRef -> GraphOp ()
disconnectPort (InPortRef (NodeLoc _ dstNodeId) dstPort) = case dstPort of
    []        -> setToNothing dstNodeId
    _         -> removeInternalConnection dstNodeId dstPort

setToNothing :: NodeId -> GraphOp ()
setToNothing dst = do
    (_, out) <- GraphBuilder.getEdgePortMapping
    let disconnectOutputEdge = out == dst
        nothingExpr          = "None"
    nothing <- generalize <$> IR.cons (convertVia @String nothingExpr) []
    putLayer @SpanLength nothing $ convert $ Text.length nothingExpr
    if disconnectOutputEdge then setOutputTo nothing else do
        dstTarget <- ASTRead.getASTTarget dst
        dstBeg    <- Code.getASTTargetBeginning dst
        oldLen    <- getLayer @SpanLength dstTarget
        Code.applyDiff dstBeg (dstBeg + oldLen) nothingExpr
        GraphUtils.rewireNode dst nothing
        let lenDiff = fromIntegral (Text.length nothingExpr) - oldLen
        dstPointer <- ASTRead.getASTPointer dst
        Code.gossipLengthsChangedBy lenDiff dstPointer

removeInternalConnection :: NodeId -> InPortId -> GraphOp ()
removeInternalConnection nodeId port = do
    dstAst <- ASTRead.getTargetEdge nodeId
    beg    <- Code.getASTTargetBeginning nodeId
    ASTBuilder.removeArgument dstAst beg port

makeInternalConnection :: NodeRef -> NodeId -> InPortId -> GraphOp ()
makeInternalConnection srcAst dst inPort = do
    dstBeg <- Code.getASTTargetBeginning dst
    dstAst <- ASTRead.getTargetEdge dst
    ASTBuilder.makeConnection dstAst dstBeg inPort srcAst

makeWhole :: NodeRef -> NodeId -> GraphOp ()
makeWhole srcAst dst = do
    (_, out) <- GraphBuilder.getEdgePortMapping
    let connectToOutputEdge = out == dst
    if connectToOutputEdge then setOutputTo srcAst else do
        dstTarget <- ASTRead.getASTTarget dst
        dstBeg    <- Code.getASTTargetBeginning dst
        oldLen    <- getLayer @SpanLength dstTarget
        newExpr   <- ASTPrint.printFullExpression srcAst
        Code.applyDiff dstBeg (dstBeg + oldLen) newExpr
        GraphUtils.rewireNode dst srcAst
        let lenDiff = fromIntegral (Text.length newExpr) - oldLen
        dstPointer <- ASTRead.getASTPointer dst
        Code.gossipLengthsChangedBy lenDiff dstPointer

prepareGraphError :: SomeException -> IO (ErrorAPI.Error ErrorAPI.GraphError)
prepareGraphError e | Just (BH.BreadcrumbDoesNotExistException content) <- fromException e = pure $ ErrorAPI.Error ErrorAPI.BreadcrumbDoesNotExist . convert $ show content
                    | otherwise                                                            = pure . ErrorAPI.Error ErrorAPI.OtherGraphError        . convert =<< prettyException e

prettyException :: Exception e => e -> IO String
prettyException e = do
    stack <- whoCreated e
    return $ displayException e ++ "\n" ++ renderStack stack

prepareLunaError :: SomeException -> IO (ErrorAPI.Error ErrorAPI.LunaError)
prepareLunaError e = do
    err <- prepareGraphError e
    case err of
        ErrorAPI.Error ErrorAPI.OtherGraphError _ -> (ErrorAPI.Error ErrorAPI.OtherLunaError . convert) <$> prettyException e
        ErrorAPI.Error tpe content                -> return $ ErrorAPI.Error (ErrorAPI.Graph tpe) content

