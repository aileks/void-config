install_emacs() {
  local features
  if [[ -x /usr/local/bin/emacs ]]; then
    features=$(/usr/local/bin/emacs --batch -Q --eval '(princ system-configuration-features)')
    if [[ " $features " == *' PGTK '* && " $features " == *' NATIVE_COMP '* ]]; then
      printf 'emacs already built with PGTK and native compilation\n'
      return
    fi
  fi

  local emacs_version=30.2
  local source_dir=$target_home/src/emacs-$emacs_version
  if [[ ! -d $source_dir ]]; then
    run as_user git clone --depth 1 -b "emacs-$emacs_version" https://github.com/emacs-mirror/emacs.git "$source_dir"
  fi

  run as_user bash -e -c '
    cd "$1"
    ./autogen.sh
    ./configure --prefix=/usr/local --with-pgtk --without-x --with-cairo \
      --with-harfbuzz --with-native-compilation --with-json --with-tree-sitter \
      --with-modules --with-rsvg --with-webp --with-gif --with-jpeg --with-png
  ' bash "$source_dir"
  run as_user make -C "$source_dir" clean
  run as_user make -C "$source_dir" -j"$(nproc)"
  run make -C "$source_dir" install
}
