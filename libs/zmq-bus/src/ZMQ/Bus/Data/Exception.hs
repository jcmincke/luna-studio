{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TemplateHaskell       #-}
{-# LANGUAGE TypeSynonymInstances  #-}

module ZMQ.Bus.Data.Exception where

import           Prologue



data Exception = Exception { _msg :: Maybe String }


makeLenses(''Exception)
