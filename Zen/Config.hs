-- vim:sw=4:sts=4:ts=4

module Config where

import Data.Map as M
import Graphics.XHB
import Graphics.X11.Types -- hiding (Connection, EventMask)

import Log
import Lens
import Types hiding (Move, Resize, Lower, Raise, pointer)

import Base
import Core (KeyEventHandler(..), CoreConfig(..))
import qualified Core as C
import qualified Queue as Q
import Button
import SnapResist

import XcbView

coreConfig :: CoreConfig
coreConfig = CoreConfig $ M.fromList
    [ (([], xK_Tab), C.defaultKeyEventHandler
        { press = const $ toLog "xK_Tab press"
        }
      )
    ]

core :: ControllerComponent
core = C.core coreConfig

buttons :: ButtonConfig
buttons = ButtonConfig $ M.fromList
    [ (([],             ButtonIndex1), Move)
    , (([],             ButtonIndex2), Resize)
    , (([],             ButtonIndex3), Lower)
    , (([ModMaskShift], ButtonIndex3), Raise)
    ]

pointer :: ControllerComponent
pointer = pointerComponent buttons

snapResist :: ControllerComponent
snapResist = snapResistComponent

defaultConfig :: Config
defaultConfig = Config
    { _modMask = [ModMask1]
    , _borderWidth = 3
    , _normalBorderColor = 0x00a0a0a0
    , _focusedBorderColor = 0x00ffce28
    , _selectionBorderColor = 0x00ff0000

    , _viewComponents = [xcbView]
    , _controllerComponents = [base, core, pointer, snapResist]
    }
