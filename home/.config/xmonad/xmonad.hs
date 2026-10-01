import System.Exit (exitSuccess)
import XMonad
import XMonad.Actions.Navigation2D
import XMonad.Hooks.EwmhDesktops (ewmh, ewmhFullscreen)
import XMonad.Hooks.ManageDocks
import XMonad.Hooks.ManageHelpers
import XMonad.Hooks.SetWMName (setWMName)
import XMonad.Hooks.StatusBar
import XMonad.Hooks.StatusBar.PP
import XMonad.Hooks.UrgencyHook (withUrgencyHook, NoUrgencyHook (NoUrgencyHook))
import XMonad.Hooks.InsertPosition
import XMonad.Layout.BinarySpacePartition (emptyBSP, ResizeDirectional (ExpandTowardsBy))
import XMonad.Layout.MultiToggle (mkToggle, single, Toggle (Toggle))
import XMonad.Layout.MultiToggle.Instances (StdTransformers (NBFULL))
import XMonad.Layout.Renamed (renamed, Rename (Replace))
import XMonad.Layout.ResizableTile
import XMonad.Layout.Spacing
import XMonad.Util.EZConfig (mkKeymap)
import XMonad.Util.SpawnOnce (spawnOnce)
import XMonad.Util.ClickableWorkspaces (clickablePP)
import qualified Data.Map.Strict as Map
import qualified XMonad.Util.ExtensibleState as XS
import qualified XMonad.StackSet as W
import HeldDictation (initializeDictation, startDictation, releaseDictation, cancelDictation)

main :: IO ()
main = xmonad
  . restoreBar
  . withSB desktopBar
  . withUrgencyHook NoUrgencyHook
  . withNavigation2DConfig def {defaultTiledNavigation = sideNavigation}
  . ewmhFullscreen
  . ewmh
  . docks
  . setupInsertPosition Below Newer
  $ def
    { terminal = "alacritty"
    , modMask = mod4Mask
    , borderWidth = 2
    , normalBorderColor = "#514942"
    , focusedBorderColor = "#978e86"
    , workspaces = map show [1 .. 7 :: Int]
    , layoutHook = desktopLayouts
    , manageHook = desktopRules <+> manageHook def
    , handleEventHook = releaseDictation
    , startupHook = initializeDictation
        >> spawn "xsetroot -xcf /usr/share/icons/Adwaita/cursors/left_ptr 24"
        >> spawnOnce "bash \"$HOME/.config/xmonad/autostart.sh\""
    , keys = \config -> mkKeymap config desktopKeys
    , mouseBindings = const $ Map.fromList
        [ ((mod4Mask, button1), \window -> focus window >> mouseMoveWindow window)
        , ((mod4Mask, button2), \window -> focus window >> toggleFloating window)
        , ((mod4Mask, button3), \window -> focus window >> mouseResizeWindow window)
        ]
    }

desktopLayouts = mkToggle (single NBFULL) $ avoidStruts
  $ named "Bsp" (gaps emptyBSP)
  ||| named "Tall" (gaps $ ResizableTall 1 (3 / 100) (1 / 2) [])
  ||| named "Max" (gaps Full)
  where
    named name = renamed [Replace name]
    -- Each window contributes 6px, giving 12px between windows and at screen edges.
    gaps layout = spacingRaw False (Border 6 6 6 6) True (Border 6 6 6 6) True layout

desktopRules :: ManageHook
desktopRules = composeAll
  [ isDialog --> doCenterFloat
  , isInProperty "_NET_WM_WINDOW_TYPE" "_NET_WM_WINDOW_TYPE_UTILITY" --> doFloat
  , isInProperty "_NET_WM_WINDOW_TYPE" "_NET_WM_WINDOW_TYPE_TOOLBAR" --> doFloat
  , isInProperty "_NET_WM_WINDOW_TYPE" "_NET_WM_WINDOW_TYPE_SPLASH" --> doFloat
  , className =? "firefox" <&&> resource =? "Places" --> doFloat
  , resource =? "nsxiv" --> doFloat
  , isFullscreen --> doFullFloat
  ] <+> composeAll [className =? application --> doFloat | application <-
    [ "Qalculate-gtk", "Blueman", "Bitwarden", "bitwarden", "Org.localsend.localsend_app"
    , "polkit-gnome", "xdg-desktop-portal-gtk", "Nm-connection-editor"
    ]]

desktopBar :: StatusBarConfig
desktopBar = statusBarProp "xmobar \"$HOME/.config/xmobar/xmobarrc\"" (clickablePP desktopPP)
  <> statusBarGeneric
    "trayer --edge top --align right --widthtype request --heighttype pixel --height 18 --padding 2 --iconspacing 2 --transparent true --alpha 0 --SetDockType true --SetPartialStrut false --distance 5 --distancefrom top --tint 0x090909"
    (pure ())

desktopPP :: PP
desktopPP = def
  { ppCurrent = xmobarColor "#090909" "#f3f3f3" . pad
  , ppVisible = xmobarColor "#f3f3f3" "" . pad
  , ppHidden = xmobarColor "#f3f3f3" "" . pad
  , ppHiddenNoWindows = xmobarColor "#514942" "" . pad
  , ppUrgent = xmobarColor "#aaa198" "" . pad
  , ppLayout = xmobarColor "#978e86" ""
  , ppTitle = xmobarColor "#f3f3f3" "" . shorten 60
  , ppTitleSanitize = xmobarStrip
  , ppSep = "  "
  , ppWsSep = ""
  }

newtype BarVisible = BarVisible Bool deriving (Read, Show)

instance ExtensionClass BarVisible where
  initialValue = BarVisible True
  extensionType = PersistentExtension

restoreBar :: XConfig layout -> XConfig layout
restoreBar config = config {startupHook = startupHook config >> restore}
  where
    restore = do
      BarVisible visible <- XS.get
      if visible then pure () else killAllStatusBars

toggleBar :: X ()
toggleBar = do
  BarVisible visible <- XS.get
  if visible then killAllStatusBars else startAllStatusBars
  refresh
  XS.put $ BarVisible (not visible)

currentLayout :: X String
currentLayout = gets $ description . W.layout . W.workspace . W.current . windowset

focusDirection :: Direction2D -> X ()
focusDirection direction = do
  name <- currentLayout
  if name `elem` ["Max", "Full"]
    then windows $ if direction `elem` [L, U] then W.focusUp else W.focusDown
    else windowGo direction False

moveDirection :: Direction2D -> X ()
moveDirection direction = do
  name <- currentLayout
  if name `elem` ["Bsp", "Tall"] then windowSwap direction False else pure ()

resizeDirection :: Direction2D -> X ()
resizeDirection direction = do
  name <- currentLayout
  case name of
    "Bsp" -> sendMessage $ ExpandTowardsBy direction (3 / 100)
    "Tall" -> case direction of
      L -> sendMessage Shrink
      R -> sendMessage Expand
      U -> sendMessage MirrorShrink
      D -> sendMessage MirrorExpand
    _ -> pure ()

toggleFloating :: Window -> X ()
toggleFloating window = do
  floating <- gets $ Map.member window . W.floating . windowset
  windows $ if floating then W.sink window else W.float window (W.RationalRect 0.15 0.15 0.7 0.7)

logout :: X ()
logout = cancelDictation >> killAllStatusBars >> io exitSuccess

restartDesktop :: X ()
restartDesktop = cancelDictation >> restart "xmonad" True

desktopKeys :: [(String, X ())]
desktopKeys =
  [ ("M-<Return>", spawn "alacritty")
  , ("M-<Space>", spawn "rofi -show drun")
  , ("M-x", spawn "emacsclient -c -a ''")
  , ("M-w", spawn "firefox")
  , ("M-s", spawn "signal-desktop")
  , ("M-e", spawn "alacritty -e open-nnn")
  , ("M-a", spawn "alacritty -e wiremix")
  , ("<F9>", startDictation)
  , ("M-o", spawn "region-ocr")
  , ("M-;", spawn "bemoji -n")
  , ("M-=", spawn "qalculate-gtk")
  , ("M-<Escape>", spawn "lock-session")
  , ("M-n", spawn "dnd-toggle")
  , ("M-C-S-n", spawn "dunstctl context")
  , ("M-S-p", spawn "power-menu")
  , ("M-r", spawn "screenrecord menu")
  , ("M-C-r", spawn "screenrecord stop")
  , ("M-<Print>", spawn "screenrecord region")
  , ("M-S-<Print>", spawn "screenrecord output")
  , ("<Print>", spawn "screenshot region")
  , ("C-<Print>", spawn "screenshot window")
  , ("S-<Print>", spawn "screenshot full")
  , ("M-b", toggleBar)
  , ("M-q", kill)
  , ("M-S-q", logout)
  , ("M-S-r", restartDesktop)
  , ("M-C-S-r", restartDesktop)
  , ("M-f", sendMessage $ Toggle NBFULL)
  , ("M-S-<Space>", withFocused toggleFloating)
  , ("M-S-f", withFocused toggleFloating)
  , ("M-S-b", sendMessage $ JumpToLayout "Bsp")
  , ("M-S-t", sendMessage $ JumpToLayout "Tall")
  , ("M-S-m", sendMessage $ JumpToLayout "Max")
  , ("M-<Tab>", sendMessage NextLayout)
  ]
  ++ concat
    [ [("M-" ++ key, focusDirection direction)
      , ("M-S-" ++ key, moveDirection direction)
      , ("M-C-" ++ key, resizeDirection direction)]
    | (key, direction) <- [("h", L), ("j", D), ("k", U), ("l", R)]
    ]
  ++ concat
    [ [("M-" ++ group, windows $ W.greedyView group)
      , ("M-S-" ++ group, windows $ W.shift group)]
    | group <- map show [1 .. 7 :: Int]
    ]
  ++ [(key, spawn command) | (key, command) <-
    [ ("<XF86AudioPlay>", "playerctl play-pause")
    , ("<XF86AudioPause>", "playerctl play-pause")
    , ("<XF86AudioNext>", "playerctl next")
    , ("<XF86AudioPrev>", "playerctl previous")
    , ("<XF86AudioRaiseVolume>", "audio sink up")
    , ("<XF86AudioLowerVolume>", "audio sink down")
    , ("<XF86AudioMute>", "audio sink mute")
    , ("<XF86AudioMicMute>", "audio source mute")
    , ("<XF86MonBrightnessUp>", "brightness up")
    , ("<XF86MonBrightnessDown>", "brightness down")
    ]]
