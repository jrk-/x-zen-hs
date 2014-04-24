{-# OPTIONS_GHC -Wall -fno-warn-orphans #-}

import Data.Map (Map)
import qualified Data.Map as M
import qualified Data.List as L
import Control.Monad.State
import Control.Monad.Reader
import Control.Monad.Writer
import Control.Applicative
import Data.Time (getZonedTime)
import Graphics.XHB hiding (Setup)
import Graphics.X11.Types hiding (Connection)

import Log
import Util
-- import Core
import Types hiding (config)
-- import Config
-- import Setup hiding (config)
import Event
import Window

-- TODO:
-- Lenses for data structures
-- Free Monads for Layout
-- Use Word32 for xids & convert to from WINDOW, DRAWABLE, etc.
-- Use motionNotifyEvent_root_x instead of root_x_MotionNotifyEvent

-- IDEAS
-- Use Mod4 with lock after timeout


config :: Config
config = Config
    { _modMask = ModMask1
    , _borderWidth = 3
    , _normalBorderColor = 0x00a0a0a0
    , _focusedBorderColor = 0x00ffce28
    , _selectionBorderColor = 0x00ff0000

    , _keyPressHandler = M.fromList
        [ (xK_a, \e -> io $ print e) ]

    , _keyReleaseHandler = M.fromList
        [ (xK_a, \e -> io $ print e) ]

    , _buttonPressHandler = M.fromList
        [ (ButtonIndex1, \e -> do
                toLog "Press ButtonIndex1"
--                 let window = event_ButtonPressEvent e
--                     event_x = event_x_ButtonPressEvent e
--                     event_y = event_y_ButtonPressEvent e
--
--                 raise window
--                 pointer ^:= Position (fi event_x) (fi event_y)
--                 pushHandler $ EventHandler moveWindow
          )

        , (ButtonIndex2, \e -> do
                toLog "Press ButtonIndex2"
--                 let window = event_ButtonPressEvent e
--                     root_x = root_x_ButtonPressEvent e
--                     root_y = root_y_ButtonPressEvent e
--                     w' = fi . width_GetGeometryReply
--                     h' = fi . height_GetGeometryReply
--                     update g = modifyClient window $ modL (dimension <.> geometry)
--                                                    $ const $ Dimension (w' g) (h' g)
--
--                 raise window
--                 -- TODO: do this with event_{x,y} and save pointer position in client
--                 pointer ^:= Position (fi root_x) (fi root_y)
--                 void $ flip whenRight update =<< io . getReply =<<
--                     withConnection (io . flip getGeometry (convertXid window))
--                 pushHandler $ EventHandler resizeWindow
          )

        , (ButtonIndex3, \e -> do
                toLog "Press ButtonIndex3"
                -- let window = event_ButtonPressEvent e
                -- lower window
          )
        ]

    , _buttonReleaseHandler = M.fromList
        [ (ButtonIndex1, const $ do
            toLog "Release ButtonIndex1"
            -- popHandler
          )
        , (ButtonIndex3, const $ do
            toLog "Release ButtonIndex2")
        , (ButtonIndex2, const $ do
            toLog "Release ButtonIndex3"
            -- popHandler
          )
        ]
    }


core :: Core
core = Core
    { _queue = Queue [] Nothing []
    , _eventHandler =
        [ EventHandler handleMapRequest
        , EventHandler handleConfigureRequest
        , EventHandler handleCreateNotify
        , EventHandler handleDestroyNotify
        , EventHandler handleEnterNotify
        , EventHandler handleLeaveNotify
        , EventHandler handleButtonPress
        , EventHandler handleButtonRelease
        , EventHandler handleKeyPress
        , EventHandler handleKeyRelease
        ]
    }


main :: IO ()
main = connect >>= startup

startup :: Maybe Connection -> IO ()
startup Nothing = print "Got no connection!"
startup (Just c) = do
    -- ugly :/
    let mask = CWEventMask
        values = toMask [EventMaskSubstructureRedirect, EventMaskSubstructureNotify]
        valueparam = toValueParam [(mask, values)]
    changeWindowAttributes c (getRoot c) valueparam

    let min_keycode = min_keycode_Setup $ connectionSetup c
        max_keycode = max_keycode_Setup (connectionSetup c) - min_keycode + 1
    kbdmap <- keyboardMapping c =<< getKeyboardMapping c min_keycode max_keycode

    let setup = Setup config c (getRoot c) kbdmap M.empty

    grabKeys c config setup

    reply <- queryTree c (getRoot c) >>= getReply
    run setup =<< runReaderT (execStateT (execWriterT $ manage' reply) core) setup

    where
    run :: Setup -> Core -> IO ()
    run setup core' = do
        (logstr, core'') <- runReaderT (runStateT (execWriterT runCore) core') setup
        time <- getZonedTime
        putStrLn . (show time ++) . ("\n" ++) . unlines . map ("\t" ++) $ logstr
        run setup core''

    runCore :: Z ()
    runCore = connection $-> io . waitForEvent >>= dispatch

    manage' :: Either SomeError QueryTreeReply -> Z ()
    manage' (Left _) = return ()
    manage' (Right reply) = mapM_ manage $ children_QueryTreeReply reply

        -- time <- fmap show $ io getZonedTime
        -- io . putStrLn . (show time ++) . ("\n" ++) . unlines . map ("\t" ++)
--             =<< execWriterT (io (waitForEvent c) >>= dispatch)
--
--     c <- asksL connection
--
--     let mask = CWEventMask
--         values = toMask [EventMaskSubstructureRedirect, EventMaskSubstructureNotify]
--         valueparam = toValueParam [(mask, values)]
--     io $ changeWindowAttributes c (getRoot c) valueparam
--
--     void $ execWriterT $ do
--         C.grabKeys
--         withRoot (io . queryTree c) >>= lift . io . getReply >>= manage
--
--     -- Main loop
--     forever $ do
--         time <- fmap show $ io getZonedTime
--         io . putStrLn . (show time ++) . ("\n" ++) . unlines . map ("\t" ++)
--             =<< execWriterT (io (waitForEvent c) >>= dispatch)
--
--     where
--     manage (Left _) = return ()
--     manage (Right tree) = do
--         mapM_ C.grabButtons (children_QueryTreeReply tree)
--         mapM_ C.insertWindow (children_QueryTreeReply tree)

-- http://tronche.com/gui/x/xlib/input/XGetKeyboardMapping.html
-- http://cgit.freedesktop.org/~arnau/xcb-util/tree/keysyms/keysyms.c
-- -> xcb_key_symbols_get_keysym

keyboardMapping :: Connection -> Receipt GetKeyboardMappingReply
                -> IO (Map KEYCODE [KEYSYM])
keyboardMapping c receipt = keycodes' <$> getReply receipt
    where
    keycodes' (Left _) = M.empty
    keycodes' (Right reply) =
        let min_keycode = min_keycode_Setup $ connectionSetup c
            ks_per_kc = fi $ keysyms_per_keycode_GetKeyboardMappingReply reply
            keysyms = partition ks_per_kc $ keysyms_GetKeyboardMappingReply reply
        in M.fromList $ zip [min_keycode ..] keysyms

    partition :: Int -> [a] -> [[a]]
    partition _ [] = []
    partition n lst = take n lst : partition n (drop n lst)

grabKeys :: Connection -> Config -> Setup -> IO ()
grabKeys c conf setup = do
    -- let min_keycode = min_keycode_Setup $ connectionSetup c
    --     max_keycode = max_keycode_Setup $ connectionSetup c

    -- config ^. keyPressHandler
    -- config ^. keyReleaseHandler


    -- let numlock = join $ flip L.elemIndex modmap
    --  <$> (keysymToKeycode (fi xK_Num_Lock) kbdmap >>= \kc -> L.find (kc `elem`) modmap)
    --     capslock = join $ flip L.elemIndex modmap
    --  <$> (keysymToKeycode (fi xK_Caps_Lock) kbdmap >>= \kc -> L.find (kc `elem`) modmap)
    --     mask = map fromBit $ catMaybes [numlock, capslock]

    let kbdmap = setup ^. keyboardMap
    let keysyms = M.keys (conf ^. keyPressHandler)
            `L.union` M.keys (conf ^. keyReleaseHandler)

    forM_ keysyms $ \keysym -> do
        whenJust (keysymToKeycode (fi keysym) kbdmap) $ \keycode ->
            io $ grabKey c $ MkGrabKey True (getRoot c) [ModMaskAny] keycode
                                           GrabModeAsync GrabModeAsync

    -- rks <- M.keys <$> getsL (buttonReleaseHandler <.> config)
    -- forM_ (pbs `L.union` rbs) $ \button -> do

    -- kbdmap <- io (keyboardMapping c =<<
    --     getKeyboardMapping c min_keycode (max_keycode - min_keycode + 1))

    -- forM_ (map fi [xK_Alt_L]) $ \keysym -> do
    --     whenJust (keysymToKeycode keysym kbdmap) $ \keycode ->
    --         io $ grabKey c $ MkGrabKey True (getRoot c) [ModMaskAny] keycode
    --                                        GrabModeAsync GrabModeAsync

--     where
--     getModmap (Left _) = []
--     getModmap (Right reply) =
--         subLists (fi $ keycodes_per_modifier_GetModifierMappingReply reply)
--                  (keycodes_GetModifierMappingReply reply)
-- -}

