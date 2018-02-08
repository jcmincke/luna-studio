{-# LANGUAGE OverloadedStrings #-}

module NodeEditor.Event.Source
    ( AddHandler(..)
    , atomHandler
    , movementHandler
    , sceneResizeHandler
    , viewHandler
    , webSocketHandler
    ) where

import           Common.Prelude                    hiding (on)

import           GHCJS.Prim                        (fromJSString)

import qualified Common.Batch.Connector.Connection as BatchConnection
import qualified JS.Atom                           as Atom
import qualified JS.Scene                          as Scene
import qualified JS.View                           as View
import qualified NodeEditor.Event.Connection       as Connection
import           NodeEditor.Event.Event            (Event (Connection, UI))
import           NodeEditor.Event.UI               (UIEvent (AppEvent))
import qualified NodeEditor.React.Event.App        as App
import qualified WebSocket                         as WebSocket


data AddHandler a = AddHandler ((a -> IO ()) -> IO (IO ()))

atomHandler :: AddHandler Event
atomHandler = AddHandler Atom.onEvent

sceneResizeHandler :: AddHandler Event
sceneResizeHandler = AddHandler $ \h ->
    Scene.onSceneResize $ h $ UI $ AppEvent App.Resize

movementHandler :: AddHandler Event
movementHandler = AddHandler $ \h ->
    Scene.onMovement $ h . UI . AppEvent . App.Movement

viewHandler :: AddHandler Event
viewHandler = AddHandler View.onEvent

webSocketHandler :: WebSocket.WebSocket -> AddHandler Event
webSocketHandler conn = AddHandler $ \h -> do
    void $ WebSocket.onOpen conn $
        h $ Connection Connection.Opened
    void $ WebSocket.onMessage conn $ \event -> do
        payloadJS <- WebSocket.getData event
        let payload = fromJSString payloadJS
        -- liftIO $ putStrLn $ "payload len " <> show (length payload)
        let frame = BatchConnection.deserialize payload
        mapM_ (h . Connection . Connection.Message) $ frame ^. BatchConnection.messages
    void $ WebSocket.onClose conn $ \event -> do
        code <- WebSocket.getCode event
        h $ Connection $ Connection.Closed code
    WebSocket.onError conn $
        h $ Connection Connection.Error
