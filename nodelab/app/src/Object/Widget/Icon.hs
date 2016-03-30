module Object.Widget.Icon where

import            Utils.PreludePlus
import            Utils.Vector
import Data.Aeson (ToJSON)
import Style.Types
import qualified Style.Group as Style

import            Object.Widget


data Icon = Icon { _position   :: Vector2 Double
                 , _size      :: Vector2 Double
                 , _shader    :: Text
                 } deriving (Eq, Show, Typeable, Generic)


makeLenses ''Icon
instance ToJSON Icon

create :: Text -> Icon
create = Icon def def

instance IsDisplayObject Icon where
    widgetPosition = position
    widgetSize     = size
    widgetVisible  = to $ const True