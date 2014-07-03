---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------

module Flowbox.Interpreter.Session.Data.CallPointPath where

import           Flowbox.Interpreter.Session.Data.CallPoint (CallPoint)
import qualified Flowbox.Interpreter.Session.Data.CallPoint as CallPoint
import           Flowbox.Prelude



type CallPointPath  = [CallPoint]


toVarName :: CallPointPath -> String
toVarName = concatMap gen where
    gen callPoint = "_" ++ show (callPoint ^. CallPoint.libraryID)
                 ++ "_" ++ show (callPoint ^. CallPoint.nodeID)

