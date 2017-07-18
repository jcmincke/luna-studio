{-# LANGUAGE NoMonomorphismRestriction #-}
{-# LANGUAGE OverloadedStrings         #-}
{-# LANGUAGE QuasiQuotes               #-}
{-# LANGUAGE ScopedTypeVariables       #-}
{-# LANGUAGE TupleSections             #-}

module FileModuleSpec (spec) where

import           Data.List                      (find)
import qualified Data.Map                       as Map
import qualified Data.Set                       as Set
import qualified Data.Text                      as Text
import           Empire.ASTOp                   (runASTOp)
import           Empire.ASTOps.Parse            (SomeParserException)
import qualified Empire.Commands.AST            as AST
import qualified Empire.Commands.Code           as Code
import qualified Empire.Commands.Graph          as Graph
import qualified Empire.Commands.GraphBuilder   as GraphBuilder
import qualified Empire.Commands.Library        as Library
import qualified Empire.Data.BreadcrumbHierarchy as BH
import qualified Empire.Data.Graph              as Graph
import           LunaStudio.Data.Breadcrumb     (Breadcrumb (..), BreadcrumbItem (..))
import qualified LunaStudio.Data.Breadcrumb     as Breadcrumb
import qualified LunaStudio.Data.Graph          as APIGraph
import           LunaStudio.Data.Constants      (gapBetweenNodes)
import           LunaStudio.Data.GraphLocation  (GraphLocation (..))
import qualified LunaStudio.Data.Node           as Node
import           LunaStudio.Data.NodeMeta       (NodeMeta(..))
import qualified LunaStudio.Data.NodeMeta       as NodeMeta
import qualified LunaStudio.Data.Port           as Port
import           LunaStudio.Data.PortRef        (AnyPortRef(..))
import qualified LunaStudio.Data.Position       as Position
import           LunaStudio.Data.TypeRep        (TypeRep(TStar))
import           LunaStudio.Data.Port           (Port(..), PortState(..))
import           LunaStudio.Data.PortDefault    (PortDefault(..))

import           Luna.Prelude                   (forM, normalizeQQ)
import           Empire.Empire
import           Empire.Prelude

import           Test.Hspec                     (Expectation, Spec, around, describe, expectationFailure, it, parallel, shouldBe, shouldMatchList,
                                                 shouldNotBe, shouldSatisfy, shouldStartWith, shouldThrow, xit)

import           EmpireUtils

import           Text.RawString.QQ              (r)


multiFunCode = [r|def foo:
    5

def bar:
    "bar"

def main:
    print bar
|]

codeWithImport = [r|import Std

def foo:
    5

def bar:
    "bar"

def main:
    print bar
|]

atXPos = ($ def) . (NodeMeta.position . Position.x .~)

specifyCodeChange :: Text -> Text -> (GraphLocation -> Empire a) -> CommunicationEnv -> Expectation
specifyCodeChange initialCode expectedCode act env = do
    let normalize = Text.pack . normalizeQQ . Text.unpack
    actualCode <- evalEmp env $ do
        Library.createLibrary Nothing "TestPath"
        let loc = GraphLocation "TestPath" $ Breadcrumb []
        Graph.loadCode loc $ normalize initialCode
        [main] <- filter (\n -> n ^. Node.name == Just "main") <$> Graph.getNodes loc
        let loc' = GraphLocation "TestPath" $ Breadcrumb [Definition (main ^. Node.nodeId)]
        act loc'
        Text.pack <$> Graph.getCode loc'
    Text.strip actualCode `shouldBe` normalize expectedCode


spec :: Spec
spec = around withChannels $ parallel $ do
    describe "multi-module files" $ do
        it "shows functions at file top-level" $ \env -> do
            nodes <- evalEmp env $ do
                Library.createLibrary Nothing "TestPath"
                let loc = GraphLocation "TestPath" $ Breadcrumb []
                Graph.loadCode loc multiFunCode
                nodes <- Graph.getNodes loc
                return nodes
            length nodes `shouldBe` 3
            -- nodes are layouted in a left-to-right manner
            let uniquePositions = Set.toList $ Set.fromList $ map (view (Node.nodeMeta . NodeMeta.position . Position.x)) nodes
            length uniquePositions `shouldBe` 3
        it "adds function at top-level with arguments" $ \env -> do
            u1 <- mkUUID
            (nodes, code) <- evalEmp env $ do
                Library.createLibrary Nothing "TestPath"
                let loc = GraphLocation "TestPath" $ Breadcrumb []
                Graph.loadCode loc multiFunCode
                Graph.addNode loc u1 "def quux a b c" def
                (,) <$> Graph.getNodes loc <*> Graph.getCode loc
            length nodes `shouldBe` 4
            find (\n -> n ^. Node.name == Just "quux") nodes `shouldSatisfy` isJust
            normalizeQQ code `shouldBe` normalizeQQ [r|
                def quux a b c:
                    None

                def foo:
                    5

                def bar:
                    "bar"

                def main:
                    print bar
                |]
        it "adds function at top-level as third function" $ \env -> do
            u1 <- mkUUID
            (nodes, code) <- evalEmp env $ do
                Library.createLibrary Nothing "TestPath"
                let loc = GraphLocation "TestPath" $ Breadcrumb []
                Graph.loadCode loc multiFunCode
                Graph.addNode loc u1 "def quux" $ set NodeMeta.position (Position.fromTuple (200,0)) def
                (,) <$> Graph.getNodes loc <*> Graph.getCode loc
            length nodes `shouldBe` 4
            find (\n -> n ^. Node.name == Just "quux") nodes `shouldSatisfy` isJust
            normalizeQQ code `shouldBe` normalizeQQ [r|
                def foo:
                    5

                def bar:
                    "bar"

                def quux:
                    None

                def main:
                    print bar
                |]
        it "adds function at top-level as last function" $ \env -> do
            u1 <- mkUUID
            (nodes, code) <- evalEmp env $ do
                Library.createLibrary Nothing "TestPath"
                let loc = GraphLocation "TestPath" $ Breadcrumb []
                Graph.loadCode loc multiFunCode
                Graph.addNode loc u1 "def quux" $ set NodeMeta.position (Position.fromTuple (500,0)) def
                (,) <$> Graph.getNodes loc <*> Graph.getCode loc
            length nodes `shouldBe` 4
            find (\n -> n ^. Node.name == Just "quux") nodes `shouldSatisfy` isJust
            normalizeQQ code `shouldBe` normalizeQQ [r|
                def foo:
                    5

                def bar:
                    "bar"

                def main:
                    print bar

                def quux:
                    None
                |]
        it "adds function at top-level as def" $ \env -> do
            u1 <- mkUUID
            (nodes, code) <- evalEmp env $ do
                Library.createLibrary Nothing "TestPath"
                let loc = GraphLocation "TestPath" $ Breadcrumb []
                Graph.loadCode loc multiFunCode
                Graph.addNode loc u1 "def quux" def
                (,) <$> Graph.getNodes loc <*> Graph.getCode loc
            length nodes `shouldBe` 4
            find (\n -> n ^. Node.name == Just "quux") nodes `shouldSatisfy` isJust
            normalizeQQ code `shouldBe` normalizeQQ [r|
                def quux:
                    None

                def foo:
                    5

                def bar:
                    "bar"

                def main:
                    print bar
                |]
        it "enters just added function" $ \env -> do
            u1 <- mkUUID
            graph <- evalEmp env $ do
                Library.createLibrary Nothing "TestPath"
                let loc = GraphLocation "TestPath" $ Breadcrumb []
                Graph.loadCode loc multiFunCode
                n <- Graph.addNode loc u1 "def quux" def
                Graph.getGraph (GraphLocation "TestPath" (Breadcrumb [Definition (n ^. Node.nodeId)]))
            length (graph ^. APIGraph.nodes) `shouldBe` 0
            let Just (Node.OutputSidebar _ ports) = graph ^. APIGraph.outputSidebar
            toListOf traverse ports `shouldBe` [Port [] "output" TStar (WithDefault (Expression "None"))]
        it "removes function at top-level" $ \env -> do
            (nodes, code) <- evalEmp env $ do
                Library.createLibrary Nothing "TestPath"
                let loc = GraphLocation "TestPath" $ Breadcrumb []
                Graph.loadCode loc multiFunCode
                nodes <- Graph.getNodes loc
                let Just bar = find (\n -> n ^. Node.name == Just "bar") nodes
                Graph.removeNodes loc [bar ^. Node.nodeId]
                (,) <$> Graph.getNodes loc <*> Graph.getCode loc
            find (\n -> n ^. Node.name == Just "main") nodes `shouldSatisfy` isJust
            find (\n -> n ^. Node.name == Just "foo") nodes `shouldSatisfy` isJust
            find (\n -> n ^. Node.name == Just "bar") nodes `shouldSatisfy` isNothing
            normalizeQQ code `shouldBe` normalizeQQ [r|
                def foo:
                    5

                def main:
                    print bar
                |]
        it "renames function at top-level" $ \env -> do
            (nodes, code) <- evalEmp env $ do
                Library.createLibrary Nothing "TestPath"
                let loc = GraphLocation "TestPath" $ Breadcrumb []
                Graph.loadCode loc multiFunCode
                nodes <- Graph.getNodes loc
                let Just bar = find (\n -> n ^. Node.name == Just "bar") nodes
                Graph.renameNode loc (bar ^. Node.nodeId) "qwerty"
                (,) <$> Graph.getNodes loc <*> Graph.getCode loc
            find (\n -> n ^. Node.name == Just "qwerty") nodes `shouldSatisfy` isJust
            find (\n -> n ^. Node.name == Just "bar") nodes `shouldSatisfy` isNothing
            normalizeQQ code `shouldBe` normalizeQQ [r|
                def foo:
                    5

                def qwerty:
                    "bar"

                def main:
                    print bar
                |]
        it "renames function at top-level and inserts a node" $ \env -> do
            u1 <- mkUUID
            (nodes, code) <- evalEmp env $ do
                Library.createLibrary Nothing "TestPath"
                let loc = GraphLocation "TestPath" $ Breadcrumb []
                Graph.loadCode loc multiFunCode
                nodes <- Graph.getNodes loc
                let Just bar = find (\n -> n ^. Node.name == Just "bar") nodes
                Graph.renameNode loc (bar ^. Node.nodeId) "qwerty"
                Graph.addNode (loc |>= bar ^. Node.nodeId) u1 "1" (atXPos (-10))
                (,) <$> Graph.getNodes loc <*> Graph.getCode loc
            find (\n -> n ^. Node.name == Just "qwerty") nodes `shouldSatisfy` isJust
            find (\n -> n ^. Node.name == Just "bar") nodes `shouldSatisfy` isNothing
            normalizeQQ code `shouldBe` normalizeQQ [r|
                def foo:
                    5

                def qwerty:
                    node1 = 1
                    "bar"

                def main:
                    print bar
                |]
        it "renames function at top-level and inserts a node in another function" $ \env -> do
            u1 <- mkUUID
            (nodes, code) <- evalEmp env $ do
                Library.createLibrary Nothing "TestPath"
                let loc = GraphLocation "TestPath" $ Breadcrumb []
                Graph.loadCode loc multiFunCode
                nodes <- Graph.getNodes loc
                let Just bar = find (\n -> n ^. Node.name == Just "bar") nodes
                let Just main = find (\n -> n ^. Node.name == Just "main") nodes
                Graph.renameNode loc (bar ^. Node.nodeId) "qwerty"
                Graph.addNode (loc |>= main ^. Node.nodeId) u1 "1" (atXPos (-10))
                (,) <$> Graph.getNodes loc <*> Graph.getCode loc
            normalizeQQ code `shouldBe` normalizeQQ [r|
                def foo:
                    5

                def qwerty:
                    "bar"

                def main:
                    node1 = 1
                    print bar
                |]
        it "fails at renaming function to illegal name" $ \env -> do
            (nodes, code) <- evalEmp env $ do
                Library.createLibrary Nothing "TestPath"
                let loc = GraphLocation "TestPath" $ Breadcrumb []
                Graph.loadCode loc multiFunCode
                nodes <- Graph.getNodes loc
                let Just bar = find (\n -> n ^. Node.name == Just "bar") nodes
                Graph.renameNode loc (bar ^. Node.nodeId) ")" `catch` (\(_e :: SomeParserException) -> return ())
                (,) <$> Graph.getNodes loc <*> Graph.getCode loc
            find (\n -> n ^. Node.name == Just "bar") nodes `shouldSatisfy` isJust
            normalizeQQ code `shouldBe` normalizeQQ [r|
                def foo:
                    5

                def bar:
                    "bar"

                def main:
                    print bar
                |]
        it "adds and removes function" $ \env -> do
            u1 <- mkUUID
            (nodes, code) <- evalEmp env $ do
                Library.createLibrary Nothing "TestPath"
                let loc = GraphLocation "TestPath" $ Breadcrumb []
                Graph.loadCode loc multiFunCode
                n <- Graph.addNode loc u1 "def quux" def
                Graph.removeNodes loc [n ^. Node.nodeId]
                (,) <$> Graph.getNodes loc <*> Graph.getCode loc
            find (\n -> n ^. Node.name == Just "main") nodes `shouldSatisfy` isJust
            find (\n -> n ^. Node.name == Just "foo") nodes `shouldSatisfy` isJust
            find (\n -> n ^. Node.name == Just "bar") nodes `shouldSatisfy` isJust
            find (\n -> n ^. Node.name == Just "quux") nodes `shouldSatisfy` isNothing
            normalizeQQ code `shouldBe` normalizeQQ multiFunCode
        it "decodes breadcrumbs in function" $ \env -> do
            let code = Text.pack $ normalizeQQ $ [r|
                    def main:
                        «0»pi = 3.14
                        «1»foo = a: b:
                            «5»lala = 17.0
                            «12»buzz = x: y:
                                «9»x * y
                            «6»pi = 3.14
                            «7»n = buzz a lala
                            «8»m = buzz b pi
                            «11»m + n
                    |]
            Breadcrumb location <- evalEmp env $ do
                Library.createLibrary Nothing "TestPath"
                let loc = GraphLocation "TestPath" $ Breadcrumb []
                Graph.loadCode loc code
                [main] <- Graph.getNodes loc
                let loc' = GraphLocation "TestPath" $ Breadcrumb [Definition (main ^. Node.nodeId)]
                nodes <- Graph.getNodes loc'
                let Just foo = find (\n -> n ^. Node.name == Just "foo") nodes
                let loc'' = GraphLocation "TestPath" $ Breadcrumb [Definition (main ^. Node.nodeId), Lambda (foo ^. Node.nodeId)]
                Graph.decodeLocation loc''
            let names = map (view Breadcrumb.name) location
            names `shouldBe` ["main", "foo"]
        it "decodes breadcrumbs in function 2" $ \env -> do
            let code = Text.pack $ normalizeQQ $ [r|
                    def main:
                        «0»pi = 3.14
                        «1»foo = a: b:
                            «5»lala = 17.0
                            «12»buzz = x: y:
                                «9»x * y
                            «6»pi = 3.14
                            «7»n = buzz a lala
                            «8»m = buzz b pi
                            «11»m + n
                    |]
            Breadcrumb location <- evalEmp env $ do
                Library.createLibrary Nothing "TestPath"
                let loc = GraphLocation "TestPath" $ Breadcrumb []
                Graph.loadCode loc code
                [main] <- Graph.getNodes loc
                let loc' = GraphLocation "TestPath" $ Breadcrumb [Definition (main ^. Node.nodeId)]
                nodes <- Graph.getNodes loc'
                let Just foo = find (\n -> n ^. Node.name == Just "foo") nodes
                let loc'' = GraphLocation "TestPath" $ Breadcrumb [Definition (main ^. Node.nodeId), Lambda (foo ^. Node.nodeId)]
                nodes <- Graph.getNodes loc''
                let Just buzz = find (\n -> n ^. Node.name == Just "buzz") nodes
                let loc''' = GraphLocation "TestPath" $ Breadcrumb [Definition (main ^. Node.nodeId), Lambda (foo ^. Node.nodeId), Lambda (buzz ^. Node.nodeId)]
                Graph.decodeLocation loc'''
            let names = map (view Breadcrumb.name) location
            names `shouldBe` ["main", "foo", "buzz"]
        it "does not crash on substitute with multiple functions" $ \env -> do
            evalEmp env $ do
                Library.createLibrary Nothing "TestPath"
                let loc = GraphLocation "TestPath" $ Breadcrumb []
                Graph.loadCode loc multiFunCode
                Graph.substituteCode "TestPath" 13 14 "10" (Just 14)
        it "shows proper function offsets without imports" $ \env -> do
            offsets <- evalEmp env $ do
                Library.createLibrary Nothing "TestPath"
                let loc = GraphLocation "TestPath" $ Breadcrumb []
                Graph.loadCode loc multiFunCode
                funIds <- (map (view Node.nodeId)) <$> Graph.getNodes loc
                Graph.withUnit loc $ runASTOp $ forM funIds $ Code.functionBlockStart
            sort offsets `shouldBe` [0, 19, 42]
        it "shows proper function offsets with imports" $ \env -> do
            offsets <- evalEmp env $ do
                Library.createLibrary Nothing "TestPath"
                let loc = GraphLocation "TestPath" $ Breadcrumb []
                Graph.loadCode loc codeWithImport
                funIds <- (map (view Node.nodeId)) <$> Graph.getNodes loc
                Graph.withUnit loc $ runASTOp $ forM funIds $ Code.functionBlockStart
            sort offsets `shouldBe` [12, 31, 54]
        it "adds node in a function with at least two nodes" $
            let initialCode = [r|
                    def foo:
                        «0»5
                    def bar:
                        «1»"bar"
                    def main:
                        «2»c = 4
                        «3»print bar
                    |]
                expectedCode = [r|
                    def foo:
                        5
                    def bar:
                        "bar"
                    def main:
                        node1 = 5
                        c = 4
                        print bar
                    |]
            in specifyCodeChange initialCode expectedCode $ \loc -> do
                u1 <- mkUUID
                Graph.addNode loc u1 "5" (atXPos (-50))
        it "adds node in a function with at least two nodes in a file without markers" $
            let initialCode = [r|
                    def foo:
                        5
                    def bar:
                        "bar"
                    def main:
                        c = 4
                        print bar
                    |]
                expectedCode = [r|
                    def foo:
                        5
                    def bar:
                        "bar"
                    def main:
                        node1 = 5
                        c = 4
                        print bar
                    |]
            in specifyCodeChange initialCode expectedCode $ \loc -> do
                u1 <- mkUUID
                Graph.addNode loc u1 "5" (atXPos (-50))
        it "adds node in a function with one node" $
            let initialCode = [r|
                    def foo:
                        «0»5
                    def bar:
                        «1»"bar"
                    def main:
                        «2»print bar
                    |]
                expectedCode = [r|
                    def foo:
                        5
                    def bar:
                        "bar"
                    def main:
                        node1 = 5
                        print bar
                    |]
            in specifyCodeChange initialCode expectedCode $ \loc -> do
                u1 <- mkUUID
                Graph.addNode loc u1 "5" (atXPos (-50))
        it "adds node in two functions" $ \env -> do
            code <- evalEmp env $ do
                Library.createLibrary Nothing "TestPath"
                let loc = GraphLocation "TestPath" $ Breadcrumb []
                Graph.loadCode loc multiFunCode
                nodes <- Graph.getNodes loc
                let Just foo = view Node.nodeId <$> find (\n -> n ^. Node.name == Just "foo") nodes
                u1 <- mkUUID
                Graph.addNode (loc |>= foo) u1 "5" (atXPos (-10))
                funIds <- (map (view Node.nodeId)) <$> Graph.getNodes loc
                let Just bar = view Node.nodeId <$> find (\n -> n ^. Node.name == Just "bar") nodes
                u2 <- mkUUID
                Graph.addNode (loc |>= bar) u2 "1" (atXPos (-10))
                Graph.withUnit loc $ use Graph.code
            normalizeQQ (Text.unpack code) `shouldBe` normalizeQQ [r|
                def foo:
                    «3»node1 = 5
                    «0»5
                def bar:
                    «4»node1 = 1
                    «1»"bar"
                def main:
                    «2»print bar
                |]
        it "adds node after connecting to output" $ \env -> do
            code <- evalEmp env $ do
                Library.createLibrary Nothing "TestPath"
                let loc = GraphLocation "TestPath" $ Breadcrumb []
                Graph.loadCode loc multiFunCode
                nodes <- Graph.getNodes loc
                let Just bar = view Node.nodeId <$> find (\n -> n ^. Node.name == Just "bar") nodes
                u1 <- mkUUID
                Graph.addNode (loc |>= bar) u1 "5" (atXPos 10)
                APIGraph.Graph _ _ _ (Just output) _ <- Graph.getGraph (loc |>= bar)
                Graph.connect (loc |>= bar) (outPortRef u1 []) (InPortRef' $ inPortRef (output ^. Node.nodeId) [])
                u2 <- mkUUID
                Graph.addNode (loc |>= bar) u2 "1" (atXPos (-20))
                Graph.withUnit loc $ use Graph.code
            normalizeQQ (Text.unpack code) `shouldBe` normalizeQQ [r|
                    def foo:
                        «0»5

                    def bar:
                        «4»node2 = 1
                        «1»"bar"
                        «3»node1 = 5
                        node1

                    def main:
                        «2»print bar
                |]
        it "updates block end after connecting to output" $ \env -> do
            (blockEnd, code) <- evalEmp env $ do
                Library.createLibrary Nothing "TestPath"
                let loc = GraphLocation "TestPath" $ Breadcrumb []
                Graph.loadCode loc multiFunCode
                nodes <- Graph.getNodes loc
                let Just bar = view Node.nodeId <$> find (\n -> n ^. Node.name == Just "bar") nodes
                u1 <- mkUUID
                Graph.addNode (loc |>= bar) u1 "5" (atXPos 10)
                APIGraph.Graph _ _ _ (Just output) _ <- Graph.getGraph (loc |>= bar)
                Graph.connect (loc |>= bar) (outPortRef u1 []) (InPortRef' $ inPortRef (output ^. Node.nodeId) [])
                blockEnd <- Graph.withGraph (loc |>= bar) $ runASTOp $ Code.getCurrentBlockEnd
                code <- Graph.withUnit loc $ use Graph.code
                return (blockEnd, code)
            blockEnd `shouldBe` 67
            normalizeQQ (Text.unpack code) `shouldBe` normalizeQQ [r|
                    def foo:
                        «0»5

                    def bar:
                        «1»"bar"
                        «3»node1 = 5
                        node1

                    def main:
                        «2»print bar
                |]
        it "maintains proper block start info after adding node" $ \env -> do
            (starts, code) <- evalEmp env $ do
                Library.createLibrary Nothing "TestPath"
                let loc = GraphLocation "TestPath" $ Breadcrumb []
                Graph.loadCode loc multiFunCode
                nodes <- Graph.getNodes loc
                let Just foo = view Node.nodeId <$> find (\n -> n ^. Node.name == Just "foo") nodes
                u1 <- mkUUID
                Graph.addNode (loc |>= foo) u1 "5" (atXPos (-10))
                funIds <- (map (view Node.nodeId)) <$> Graph.getNodes loc
                starts <- Graph.withUnit loc $ runASTOp $ forM funIds $ Code.functionBlockStart
                code <- Graph.getCode loc
                return (starts, code)
            normalizeQQ code `shouldBe` normalizeQQ [r|
                def foo:
                    node1 = 5
                    5

                def bar:
                    "bar"

                def main:
                    print bar
                |]
            starts `shouldMatchList` [0, 36, 59]
        it "maintains proper function file offsets after adding node" $ \env -> do
            (offsets, code) <- evalEmp env $ do
                Library.createLibrary Nothing "TestPath"
                let loc = GraphLocation "TestPath" $ Breadcrumb []
                Graph.loadCode loc multiFunCode
                nodes <- Graph.getNodes loc
                let Just foo = view Node.nodeId <$> find (\n -> n ^. Node.name == Just "foo") nodes
                u1 <- mkUUID
                Graph.addNode (loc |>= foo) u1 "5" (atXPos (-10))
                funIds <- (map (view Node.nodeId)) <$> Graph.getNodes loc
                offsets <- Graph.withUnit loc $ do
                    funs <- use Graph.clsFuns
                    return $ map (\(n,g) -> (n, g ^. Graph.fileOffset)) $ Map.elems funs
                code <- Graph.getCode loc
                return (offsets, code)
            offsets `shouldMatchList` [("foo",0), ("bar",36), ("main",59)]
        it "maintains proper function file offsets after adding a function" $ \env -> do
            (offsets, code) <- evalEmp env $ do
                Library.createLibrary Nothing "TestPath"
                let loc = GraphLocation "TestPath" $ Breadcrumb []
                Graph.loadCode loc multiFunCode
                nodes <- Graph.getNodes loc
                let Just foo = view Node.nodeId <$> find (\n -> n ^. Node.name == Just "foo") nodes
                u1 <- mkUUID
                Graph.addNode loc u1 "def aaa" (atXPos $ 1.5 * gapBetweenNodes)
                funIds <- (map (view Node.nodeId)) <$> Graph.getNodes loc
                offsets <- Graph.withUnit loc $ do
                    funs <- use Graph.clsFuns
                    return $ map (\(n,g) -> (n, g ^. Graph.fileOffset)) $ Map.elems funs
                code <- Graph.getCode loc
                return (offsets, code)
            offsets `shouldMatchList` [("foo",0), ("bar",19), ("aaa",42), ("main",61)]
        it "maintains proper function file offsets after removing a function" $ \env -> do
            (offsets, code) <- evalEmp env $ do
                Library.createLibrary Nothing "TestPath"
                let loc = GraphLocation "TestPath" $ Breadcrumb []
                Graph.loadCode loc multiFunCode
                nodes <- Graph.getNodes loc
                let Just bar = view Node.nodeId <$> find (\n -> n ^. Node.name == Just "bar") nodes
                Graph.removeNodes loc [bar]
                funIds <- (map (view Node.nodeId)) <$> Graph.getNodes loc
                offsets <- Graph.withUnit loc $ do
                    funs <- use Graph.clsFuns
                    return $ map (\(n,g) -> (n, g ^. Graph.fileOffset)) $ Map.elems funs
                code <- Graph.getCode loc
                return (offsets, code)
            offsets `shouldMatchList` [("foo",0), ("main",19)]
        it "maintains proper function file offsets after renaming a function" $ \env -> do
            u1 <- mkUUID
            (offsets, code) <- evalEmp env $ do
                Library.createLibrary Nothing "TestPath"
                let loc = GraphLocation "TestPath" $ Breadcrumb []
                Graph.loadCode loc multiFunCode
                nodes <- Graph.getNodes loc
                let Just bar = find (\n -> n ^. Node.name == Just "bar") nodes
                Graph.renameNode loc (bar ^. Node.nodeId) "qwerty"
                funIds <- (map (view Node.nodeId)) <$> Graph.getNodes loc
                offsets <- Graph.withUnit loc $ do
                    funs <- use Graph.clsFuns
                    return $ map (\(n,g) -> (n, g ^. Graph.fileOffset)) $ Map.elems funs
                code <- Graph.getCode loc
                return (offsets, code)
            offsets `shouldMatchList` [("foo", 0), ("qwerty", 19), ("main", 45)]