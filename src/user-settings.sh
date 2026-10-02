install_doom() {
  local emacs_dir=${XDG_CONFIG_HOME:-$HOME/.config}/emacs

  if [[ ! -d $emacs_dir ]]; then
    git clone --depth 1 https://github.com/doomemacs/doomemacs.git "$work/doom-emacs"
    mv -T -- "$work/doom-emacs" "$emacs_dir"
    "$emacs_dir/bin/doom" install
    return
  fi

  [[ -f ${XDG_CONFIG_HOME:-$HOME/.config}/doom/init.el ]] || {
    echo 'Doom config has no init.el yet; skipping sync.' >&2
    return 0
  }

  "$emacs_dir/bin/doom" sync
}

apply_gsettings() {
  run dbus-run-session -- bash -e -c "
    gsettings set org.gnome.desktop.interface color-scheme prefer-dark
    gsettings set org.gnome.desktop.interface gtk-theme Dustveil-Dark
    gsettings set org.gnome.desktop.interface icon-theme Papirus-Dark
    gsettings set org.gnome.desktop.interface cursor-theme Adwaita
    gsettings set org.gnome.desktop.interface cursor-size 24
    gsettings set org.gnome.desktop.interface font-name 'Adwaita Sans 11'
    gsettings set org.gnome.desktop.interface monospace-font-name 'Iosevka Nerd Font 11'
    gsettings set org.gnome.desktop.interface font-antialiasing rgba
    gsettings set org.gnome.desktop.interface font-hinting slight
    gsettings set org.gnome.desktop.interface font-rgba-order rgb
    gsettings set org.gnome.desktop.interface font-rendering manual
    gsettings set org.gnome.desktop.interface clock-format 24h
    gsettings set org.gnome.desktop.wm.preferences button-layout ''
    gsettings set org.gnome.desktop.wm.preferences audible-bell false
    gsettings set org.gnome.desktop.sound event-sounds false
    gsettings set org.gnome.desktop.sound input-feedback-sounds false
  "
}

setup_mime() {
  local target=$config_home/mimeapps.list

  if [[ -f $target ]] && cmp -s -- "$repo/desktop/xdg/mimeapps.list" "$target"; then
    return
  fi

  if [[ -e $target || -L $target ]]; then
    mv -T -- "$target" "$target.backup.$stamp"
  fi
  install -m 600 -- "$repo/desktop/xdg/mimeapps.list" "$target"
}

install_crontab() {
  local state_directory=${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles
  local current

  current=$(crontab -l 2>/dev/null) || true
  [[ $current != "$(<"$repo/desktop/cron/crontab")" ]] || return 0

  if [[ -n $current ]]; then
    mkdir -p "$state_directory"
    printf '%s\n' "$current" >"$state_directory/crontab-$stamp"
  fi
  crontab "$repo/desktop/cron/crontab"
}

setup_user_phase() {
  export PATH="$target_home/.local/bin:$PATH"
  export NPM_CONFIG_PREFIX="$target_home/.local"
  export XDG_RUNTIME_DIR="$work/runtime"
  install -d -m 700 "$XDG_RUNTIME_DIR"

  install_stow
  install_user_tools
  install_doom
  apply_gsettings

  run xdg-user-dirs-update
  setup_mime
  run bat cache --build
  install_crontab
}
