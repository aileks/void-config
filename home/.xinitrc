#!/usr/bin/env bash

set -Eeuo pipefail

export PATH="$HOME/.local/bin:$PATH"
export QT_QPA_PLATFORMTHEME=qt6ct
export XDG_CURRENT_DESKTOP=xmonad
export XDG_SESSION_TYPE=x11
export XCURSOR_THEME=Adwaita
export XCURSOR_SIZE=24
export LIBVA_DRIVER_NAME=nvidia
export NVD_BACKEND=direct
export __GLX_VENDOR_LIBRARY_NAME=nvidia
export MOZ_DISABLE_RDD_SANDBOX=1

xrdb -merge "$HOME/.Xresources"

exec dbus-run-session -- xmonad
