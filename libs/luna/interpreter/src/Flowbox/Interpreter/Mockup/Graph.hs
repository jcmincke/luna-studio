
---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Flowbox Team <contact@flowbox.io>, 2014
-- Proprietary and confidential
-- Unauthorized copying of this file, via any medium is strictly prohibited
---------------------------------------------------------------------------
module Flowbox.Interpreter.Mockup.Graph
( module Flowbox.Interpreter.Mockup.Graph
, module X
)
where

import Flowbox.Data.Graph              as X
import Flowbox.Interpreter.Mockup.Node (Node)
import Flowbox.Prelude


data Dependency = Dependency deriving (Read, Show)


type CodeGraph = Graph Node Dependency
