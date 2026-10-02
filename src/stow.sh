install_stow() {
  local target

  command -v stow >/dev/null 2>&1 || fail 'stow is not installed (xbps-install stow)'

  run mkdir -p -- "$target_home/.local/bin" "$data_home/applications"
  for target in \
    "$target_home"/.config/gtk-{3,4}.0/{settings.ini,gtk.css} \
    "$target_home"/.config/qt6ct/colors/dustveil.conf; do
    if [[ -f $target && ! -L $target ]]; then
      run mv -T -- "$target" "$target.backup.$stamp"
    fi
  done
  run stow --dir="$repo" --target="$target_home" --no-folding partial
  run stow --dir="$repo" --target="$target_home" home
}
