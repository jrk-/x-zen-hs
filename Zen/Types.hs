{-# OPTIONS_GHC -Wall -fno-warn-orphans #-}

{-# LANGUAGE ExistentialQuantification #-}

module Types
    ( module Types
    , module Lens
    ) where

import Data.Word
import Graphics.XHB
import Control.Monad.State
import Control.Monad.Reader
import Control.Monad.Writer
import qualified Data.Map as M

import Lens

instance Eq ButtonIndex where
    l == r = (toValue l :: Word8) == (toValue r :: Word8)

instance Ord ButtonIndex where
    compare l r = compare (toValue l :: Word8) (toValue r :: Word8)

type ClientWindow = WINDOW

data ConnectionSetup = ConnectionSetup
    { _connection :: Connection
    , _root :: ClientWindow
    }

connection :: Lens ConnectionSetup Connection
connection = lens _connection (\v d -> d { _connection = v })

root :: Lens ConnectionSetup ClientWindow
root = lens _root (\v d -> d { _root = v })

withConnection :: (Connection -> Z a) -> Z a
withConnection f = asksL connection >>= f

withRoot :: (ClientWindow -> Z a) -> Z a
withRoot f = asksL root >>= f

data Position = Position
    { _x :: Int
    , _y :: Int
    }
    deriving (Eq, Read, Show)

x :: Lens Position Int
x = lens _x (\v d -> d { _x = v })

y :: Lens Position Int
y = lens _y (\v d -> d { _y = v })

data Dimension = Dimension
    { _width :: Word
    , _height :: Word
    }
    deriving (Eq, Read, Show)

width :: Lens Dimension Word
width = lens _width (\v d -> d { _width = v })

height :: Lens Dimension Word
height = lens _height (\v d -> d { _height = v })

data Geometry = Geometry
    { _position :: Position
    , _dimension :: Dimension
    }
    deriving (Eq, Read, Show)

position :: Lens Geometry Position
position = lens _position (\v d -> d { _position = v })

dimension :: Lens Geometry Dimension
dimension = lens _dimension (\v d -> d { _dimension = v })

data Client = Client
    { _xid :: ClientWindow
    , _geometry :: Geometry
    }
    deriving (Eq, Show)

xid :: Lens Client ClientWindow
xid = lens _xid (\v d -> d { _xid = v })

geometry :: Lens Client Geometry
geometry = lens _geometry (\v d -> d { _geometry = v })

data Queue = Queue
    { _clients :: [Client]
    }

clients :: Lens Queue [Client]
clients = lens _clients (\v d -> d { _clients = v })


data EventHandler b = forall a . Event a => EventHandler (a -> b)

type ButtonPressHandler = M.Map ButtonIndex (ButtonPressEvent -> Z ())
type ButtonReleaseHandler = M.Map ButtonIndex (ButtonReleaseEvent -> Z ())

data Config = Config
    { _modMask :: ModMask
    , _borderWidth :: Word
    , _normalBorderColor :: Word32
    , _focusedBorderColor :: Word32
    , _selectionBorderColor :: Word32
    , _eventHandler :: [EventHandler (Z Bool)] -- TODO: STACK!!! -> pushHandler, popHandler
    , _buttonPressHandler :: ButtonPressHandler
    , _buttonReleaseHandler :: ButtonReleaseHandler
    }

modMask :: Lens Config ModMask
modMask = lens _modMask (\v d -> d { _modMask = v })

borderWidth :: Lens Config Word
borderWidth = lens _borderWidth (\v d -> d { _borderWidth = v })

normalBorderColor :: Lens Config Word32
normalBorderColor = lens _normalBorderColor (\v d -> d { _normalBorderColor = v })

focusedBorderColor :: Lens Config Word32
focusedBorderColor = lens _focusedBorderColor (\v d -> d { _focusedBorderColor = v })

selectionBorderColor :: Lens Config Word32
selectionBorderColor = lens _selectionBorderColor (\v d -> d { _selectionBorderColor = v })

eventHandler :: Lens Config [EventHandler (Z Bool)]
eventHandler = lens _eventHandler (\v d -> d { _eventHandler = v })

buttonPressHandler :: Lens Config ButtonPressHandler
buttonPressHandler = lens _buttonPressHandler (\v d -> d { _buttonPressHandler = v })

buttonReleaseHandler :: Lens Config ButtonReleaseHandler
buttonReleaseHandler = lens _buttonReleaseHandler (\v d -> d { _buttonReleaseHandler = v })

data Core = Core
    { _config :: Config
    , _queue :: Queue
    , _pointer :: Position
    }

config :: Lens Core Config
config = lens _config (\v d -> d { _config = v })

queue :: Lens Core Queue
queue = lens _queue (\v d -> d { _queue = v })

pointer :: Lens Core Position
pointer = lens _pointer (\v d -> d { _pointer = v })

type ZCore = StateT Core (ReaderT ConnectionSetup IO)
type Z = WriterT [String] ZCore
