install_user_tools() {
  local work=$work/user-tools
  local name

  mkdir -p "$work" "$HOME/.local/bin" "$HOME/.local/libexec" "$data_home"

  for name in Iosevka IosevkaTerm; do
    if [[ -z $(fc-list ":family=$name Nerd Font" file) ]]; then
      curl -fL "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/$name.tar.xz" \
        -o "$work/$name.tar.xz"
      mkdir -p "$data_home/fonts/$name"
      tar xJf "$work/$name.tar.xz" -C "$data_home/fonts/$name"
    fi
  done
  run fc-cache

  run voxtype setup --download --model large-v3-turbo --no-post-install

  if [[ ! -x $HOME/.local/bin/bemoji || -L $HOME/.local/bin/bemoji ]]; then
    curl -fL https://raw.githubusercontent.com/marty-oehme/bemoji/791c7748cf0236f691b1874e79ebe434469c20a9/bemoji -o "$work/bemoji"
    install -b -m 755 "$work/bemoji" "$HOME/.local/bin/bemoji"
  fi

  mkdir -p "$data_home/bemoji"
  if [[ ! -s $data_home/bemoji/emojis.txt ]]; then
    curl -fL https://www.unicode.org/Public/17.0.0/emoji/emoji-test.txt \
      -o "$work/emoji-test.txt"
    sed -n 's/^.*; fully-qualified.*# \([^[:space:]]*\) [^[:space:]]* \(.*$\)/\1 \2/p' \
      "$work/emoji-test.txt" >"$work/emojis.txt"
    [[ -s $work/emojis.txt ]]
    install -m 644 "$work/emojis.txt" "$data_home/bemoji/emojis.txt"
  fi

  if [[ ! -f $config_home/mpv/scripts/modernz.lua || ! -f $config_home/mpv/fonts/modernz-icons.ttf ]]; then
    mkdir -p "$config_home/mpv/scripts" "$config_home/mpv/fonts"
    for name in modernz.lua modernz-icons.ttf; do
      curl -fL "https://raw.githubusercontent.com/Samillion/ModernZ/579897e8c974c380caa5017dc7b27a69123c1333/$name" -o "$work/$name"
    done
    install -b -m 644 "$work/modernz.lua" "$config_home/mpv/scripts/modernz.lua"
    install -b -m 644 "$work/modernz-icons.ttf" "$config_home/mpv/fonts/modernz-icons.ttf"
  fi

  if [[ ! -x $HOME/.local/bin/ruff ]]; then
    uv tool install --reinstall ruff
  fi

  if [[ ! -d $NPM_CONFIG_PREFIX/lib/node_modules/prettier ]]; then
    npm install -g prettier
  fi
}
