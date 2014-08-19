---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------

module Luna.Data.Graph.Node.OutputName (
    fix,
    fixEmpty,
    fixEmpty',
    generate,
) where

import qualified Data.Char as Char
import qualified Data.List as List

import           Luna.Data.Graph.Node (Node)
import qualified Luna.Data.Graph.Node as Node
import           Flowbox.Prelude



generate :: String -> Int -> String
generate base num = mangle base ++ "Result" ++ show num


fixEmpty :: Node -> Node.ID -> Node
fixEmpty node nodeID = case node ^. Node.outputName of
    "" -> fix node nodeID
    _  -> node


fixEmpty' :: (Node.ID, Node) -> (Node.ID, Node)
fixEmpty' (nodeID, node) =
    (nodeID, fixEmpty node nodeID)

--FIXME[wd]: nazwe zmienic na ensureProperName lub cos co mowi co to robi
fix :: Node -> Node.ID ->Node
fix node nodeID = newNode where
    expr    = node ^. Node.expr
    newNode = node &  Node.outputName .~ generate expr nodeID


mangle :: String -> String
mangle name = case List.takeWhile Char.isAlphaNum name of
    f:alphaNum -> if Char.isDigit f
                     then 'r' : f : alphaNum
                     else Char.toLower f : alphaNum
    []         -> "node"
