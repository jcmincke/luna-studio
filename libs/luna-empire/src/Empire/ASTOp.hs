{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE ConstraintKinds #-}

module Empire.ASTOp where

import           Prologue                               hiding (Num)

import           Control.Monad.Error                    (ErrorT, MonadError, runErrorT)
import           Data.Proxy
import           Data.Graph.Model.Class                 (ELEMENT (..))
import           Empire.Data.AST                        (AST, ASTEdge, ASTNode, NodeRef, EdgeRef)
import           Empire.API.Data.NodeMeta               (NodeMeta)
import           Empire.Empire                          (Command, Error, empire)
import           Data.Construction                      (Destructor, Unregister)
import           Data.Graph.Builder                     (MonadBuilder)
import           Data.Graph.Builders                    (Connectible)
import           Luna.Syntax.Model.Network.Builder.Term (TermBuilder, NetLayers, NetworkBuilderT, runNetworkBuilderT)
import           Luna.Syntax.Model.Network.Term         (Raw)
import           Luna.Syntax.AST.Term                   (Acc, App, Blank, Match, Var)
import           Luna.Syntax.Model.Layer                ((:<:))
import qualified Luna.Syntax.AST.Lit                    as Lit
import           Type.Inference

type ASTOp m = ( MonadIO m
               , MonadFix m
               , MonadError Error m
               , Destructor m NodeRef
               , Unregister m EdgeRef
               , MonadBuilder AST m
               , TermBuilder Blank      m NodeRef
               , TermBuilder Lit.Number m NodeRef
               , TermBuilder Lit.String m NodeRef
               , TermBuilder Acc        m NodeRef
               , TermBuilder App        m NodeRef
               , TermBuilder Match      m NodeRef
               , TermBuilder Var        m NodeRef
               , Connectible NodeRef NodeRef m
               )

runGraph :: NetworkBuilderT AST m (KnownTypeT ELEMENT NodeRef n) => ErrorT Error m a -> AST -> n (Either Error a, AST)
runGraph cmd g = runInferenceT ELEMENT (Proxy :: Proxy NodeRef)
               $ runNetworkBuilderT g
               $ runErrorT cmd

runASTOp :: NetworkBuilderT AST m (KnownTypeT ELEMENT NodeRef IO) => ErrorT Error m a -> Command AST a
runASTOp = empire . const . runGraph
