install_emacs() {
  if [[ -x /usr/local/bin/emacs ]] && ldd /usr/local/bin/emacs 2>/dev/null | grep -q libgccjit; then
    printf 'emacs already built with native compilation\n'
    return
  fi

  local emacs_version=30.2
  local source_dir=$target_home/src/emacs-$emacs_version
  if [[ ! -d $source_dir ]]; then
    run as_user git clone --depth 1 -b "emacs-$emacs_version" https://github.com/emacs-mirror/emacs.git "$source_dir"
  fi

  run as_user bash -c "cd '$source_dir' && ./autogen.sh"
  run as_user bash -c "cd '$source_dir' && ./configure --prefix=/usr/local --with-x-toolkit=gtk3 --with-cairo --with-harfbuzz --with-xft --with-native-compilation --with-json --with-tree-sitter --with-modules --with-rsvg --with-webp --with-gif --with-jpeg --with-png --with-xinput2"
  run as_user make -C "$source_dir" -j"$(nproc)"
  run make -C "$source_dir" install
}
