#!/usr/bin/env bash

set -Eeuo pipefail

(
  umask 077
  backup_state_directory=${XDG_STATE_HOME:-$HOME/.local/state}/home-backup
  mkdir -p "$backup_state_directory"
  printf '%s\n' "$DBUS_SESSION_BUS_ADDRESS" >"$backup_state_directory/session-bus-address"
)

xset b off
xset dpms 0 0 900
xset r rate 250 50
setxkbmap custom
xwallpaper --zoom "$HOME/.dotfiles/wallpaper/wallpaper.png"

pipewire &
/usr/libexec/polkit-gnome-authentication-agent-1 &
dunst &
voxtype-session &
blueman-applet &
playerctld daemon &
gnome-keyring-daemon --start --components=secrets,pkcs11 &
xss-lock --transfer-sleep-lock -- lock-session &
openrgb --noautoconnect -p NRGB &
localsend &
/opt/Bitwarden/bitwarden &
emacs --daemon &
xautolock -time 10 -locker lock-session -notify 30 -notifier 'notify-send -t 2000 -a xautolock "Locking in 30 seconds"' &
