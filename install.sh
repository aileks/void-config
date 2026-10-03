#!/usr/bin/env bash

set -Eeuo pipefail

repo=$(readlink -f -- "${BASH_SOURCE[0]}")
repo=${repo%/*}

fail() {
  printf '%s\n' "$*" >&2
  exit 1
}

select_user() {
  local account

  if ((EUID == 0)); then
    target_user=${SUDO_USER:-}
    [[ -n $target_user ]] || target_user=$(stat -c %U -- "$repo")
  else
    target_user=$(id -un)
  fi

  [[ -n $target_user && $target_user != root ]] || fail 'Could not determine the desktop account to install for.'
  account=$(getent passwd "$target_user") || fail "No such account: $target_user"
  IFS=: read -r target_user _ target_uid _ _ target_home _ <<< "$account"
  [[ $target_uid != 0 && $target_home == /* && -d $target_home ]] || fail 'The desktop account must have an existing home directory and a nonzero UID.'

  config_home=$target_home/.config
  data_home=$target_home/.local/share
}

run() {
  printf '+'
  printf ' %q' "$@"
  printf '\n'
  "$@"
}

as_user() {
  runuser -u "$target_user" -- env -i \
    HOME="$target_home" USER="$target_user" LOGNAME="$target_user" \
    PATH="$target_home/.local/bin:/usr/local/bin:/usr/bin:/bin" \
    XDG_CONFIG_HOME="$config_home" XDG_DATA_HOME="$data_home" \
    LANG="${LANG:-C.UTF-8}" TERM="${TERM:-dumb}" "$@"
}

check_system_target() {
  local target=$1 parent=$1

  while [[ $parent != / ]]; do
    [[ ! -L $parent ]] || fail "Refusing system symlink: $parent"
    if [[ $parent != "$target" && -e $parent && ! -d $parent ]]; then
      fail "Expected a directory at $parent. Preserve its contents in a directory before rerunning."
    fi

    parent=${parent%/*}
    [[ -n $parent ]] || parent=/
  done

  [[ ! -d $target ]] || fail "Expected a file at $target."
}

install_system_file() {
  local source=$1 target=$2 mode=${3:-644}

  check_system_target "$target"

  if [[ -f $target ]] && cmp -s -- "$source" "$target"; then
    if [[ $(stat -c '%u:%g:%a' "$target") != "0:0:$mode" ]]; then
      run chown root:root -- "$target"
      run chmod "$mode" -- "$target"
    fi
    return
  fi

  if [[ -e $target ]]; then
    run install -d -m 700 -- "/var/backups/dotfiles/$stamp${target%/*}"
    run cp -a -- "$target" "/var/backups/dotfiles/$stamp$target"
  fi

  run install -D -o root -g root -m "$mode" -- "$source" "$target"
}

install_packages() {
  local device class vendor
  local -a packages=(
    7zip
    adwaita-fonts
    adwaita-icon-theme
    alsa-pipewire
    alsa-utils
    avahi
    base-devel
    bash-completion
    bat
    blueman
    bluez
    btop
    bubblewrap
    cairo-devel
    clang
    cmake
    cronie
    cups
    curl
    dbus-elogind
    dconf
    ddcutil
    dnsmasq
    doasedit
    dunst
    elogind
    fastfetch
    fd
    ffmpeg6
    ffmpegthumbnailer
    firefox
    fontconfig
    fontconfig-devel
    foot
    freetype-devel
    fzf
    giflib-devel
    git
    gnome-keyring
    gnutls-devel
    gpu-screen-recorder
    grim
    gsettings-desktop-schemas
    gst-libav
    gst-plugins-bad1
    gst-plugins-base1
    gst-plugins-good1
    gst-plugins-ugly1
    gtk+3-devel
    gvfs
    harfbuzz-devel
    hunspell
    hunspell-en
    ImageMagick
    imv
    jansson-devel
    jq
    keyutils
    libgccjit-devel
    libjpeg-turbo-devel
    libnotify
    libpng-devel
    librsvg-devel
    libspa-bluetooth
    libva-utils
    libvterm
    libwebp-devel
    libxcrypt-devel
    libxml2-devel
    lidm
    linux-firmware
    mangowc
    mpv
    mpv-mpris
    ncdu2
    ncurses-devel
    network-manager-applet
    NetworkManager
    nnn
    nodejs
    noto-fonts-cjk
    noto-fonts-emoji
    noto-fonts-ttf
    nss-mdns
    nvtop
    opendoas
    openrgb
    papirus-icon-theme
    pcmanfm
    pinentry
    pipewire
    playerctl
    polkit-elogind
    polkit-gnome
    psmisc
    pulseaudio-utils
    qalculate-gtk
    qt6-wayland
    qt6ct
    ripgrep
    rofi
    rsync
    shfmt
    Signal-Desktop
    slurp
    stow
    swaybg
    swayidle
    swaylock
    tesseract-ocr
    tesseract-ocr-eng
    trash-cli
    tree
    tree-sitter-cli
    tree-sitter-devel
    tumbler
    uv
    Waybar
    wget
    wiremix
    wireplumber-elogind
    wl-clipboard
    wtype
    xarchiver
    xdg-desktop-portal
    xdg-desktop-portal-gtk
    xdg-desktop-portal-wlr
    xdg-user-dirs
    xdg-utils
    xkeyboard-config
    xorg-server-xwayland
    xtools
    zathura
    zathura-pdf-mupdf
    zip
    zoxide
  )

  run xbps-install -Sy void-repo-nonfree

  for device in /sys/bus/pci/devices/*; do
    read -r class < "$device/class" 2> /dev/null || continue
    [[ $class == 0x0300* || $class == 0x0302* ]] || continue
    read -r vendor < "$device/vendor" 2> /dev/null || continue
    if [[ $vendor == 0x10de ]]; then
      packages+=(nvidia nvidia-vaapi-driver)
      break
    fi
  done

  run xbps-install -Sy "${packages[@]}"
}

install_custom_packages() {
  local void_packages=$target_home/void-packages
  local repository=$void_packages/hostdir/binpkgs
  local package template
  local -a custom_packages=() missing=()

  for template in "$repo"/templates/*/; do
    template=${template%/}
    package=${template##*/}
    custom_packages+=("$package")
    xbps-query "$package" > /dev/null 2>&1 || missing+=("$package")
  done

  if ((${#missing[@]} > 0)); then
    if [[ ! -d $void_packages ]]; then
      run as_user git clone --depth 1 https://github.com/void-linux/void-packages.git "$void_packages"
    fi

    run as_user "$void_packages/xbps-src" binary-bootstrap
    for package in "${missing[@]}"; do
      run as_user rsync -a "$repo/templates/$package/" "$void_packages/srcpkgs/$package/"
      run as_user "$void_packages/xbps-src" pkg "$package"
    done
  fi

  printf 'repository=%s\n' "$repository" > "$work/xbps-dotfiles.conf"
  install_system_file "$work/xbps-dotfiles.conf" /etc/xbps.d/10-dotfiles-repository.conf 644

  if ((${#missing[@]} > 0)); then
    run xbps-install -y --repository "$repository" "${missing[@]}"
  fi
  run xbps-pkgdb -m repolock "${custom_packages[@]}"
}

install_system_config() {
  local source relative mode

  while IFS= read -r -d '' source; do
    relative=${source#"$repo/"}
    mode=644
    case $relative in
      etc/doas.conf) mode=400 ;;
    esac
    install_system_file "$source" "/$relative" "$mode"
  done < <(find "$repo/etc" -type f -print0 | sort -z)
}

configure_desktop_session() {
  local desktop_file=/usr/share/wayland-sessions/mango.desktop

  printf 'PATH=%s/.config/emacs/bin:%s/.local/bin:/usr/local/bin:/usr/bin:/bin\n' \
    "$target_home" "$target_home" > "$work/lidm.env"
  install_system_file "$work/lidm.env" /etc/lidm.env

  [[ -f $desktop_file ]] || fail 'MangoWC session file is missing.'
  sed -e 's/^Name=.*/Name=MangoWC/' -e 's/^Exec=.*/Exec=dbus-run-session -- mango/' \
    "$desktop_file" > "$work/mango.desktop"
  install_system_file "$work/mango.desktop" "$desktop_file"
}

configure_account() {
  local shell account

  shell=$(command -v bash || true)
  [[ -n $shell ]] || fail 'Bash was not installed.'
  shell=$(readlink -f "$shell")
  grep -Fxq "$shell" /etc/shells || fail "Bash is not listed in /etc/shells: $shell"
  account=$(getent passwd "$target_user") || fail "No such account: $target_user"
  if [[ ${account##*:} != "$shell" ]]; then
    run usermod -s "$shell" "$target_user"
  fi

  if ! getent group i2c > /dev/null; then
    run groupadd --system i2c
  fi

  if [[ " $(id -nG "$target_user") " != *' i2c '* ]]; then
    run usermod -aG i2c "$target_user"
  fi
}

configure_mdns() {
  awk '
    /^hosts:[[:space:]]/ {
      found=1
      if ($0 !~ /(^|[[:space:]])mdns(4|6)?(_minimal)?([[:space:]]|$)/) {
        if (!sub(/(^|[[:space:]])files([[:space:]]|$)/, " files mdns4_minimal [NOTFOUND=return] ")) exit 1
      }
    }
    { print }
    END { if (!found) exit 1 }
  ' /etc/nsswitch.conf > "$work/nsswitch.conf" || fail 'Expected a hosts lookup containing files in /etc/nsswitch.conf.'
  install_system_file "$work/nsswitch.conf" /etc/nsswitch.conf
}

configure_pipewire() {
  local source target

  run install -d -m 755 /etc/pipewire/pipewire.conf.d /etc/alsa/conf.d
  for source in \
    /usr/share/examples/wireplumber/10-wireplumber.conf \
    /usr/share/examples/pipewire/20-pipewire-pulse.conf \
    /usr/share/alsa/alsa.conf.d/50-pipewire.conf \
    /usr/share/alsa/alsa.conf.d/99-pipewire-default.conf; do
    [[ -f $source ]] || fail "Missing PipeWire example config: $source"
    target=/etc/alsa/conf.d/${source##*/}
    if [[ $source == /usr/share/examples/* ]]; then
      target=/etc/pipewire/pipewire.conf.d/${source##*/}
    fi
    if [[ ! -L $target ]]; then
      run ln -s "$source" "$target"
    fi
  done
}

enable_services() {
  local service
  local services=(dbus elogind NetworkManager cronie bluetoothd cupsd avahi-daemon lidm)

  for service in "${services[@]}"; do
    run ln -sfn "/etc/sv/$service" "/var/service/$service"
  done
}

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

  # shellcheck disable=SC2016
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

install_user_tools() {
  local work=$work/user-tools
  local name

  mkdir -p "$work"

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
      "$work/emoji-test.txt" > "$work/emojis.txt"
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

install_stow() {
  local target

  [[ -r $repo/config/doom/init.el ]] || fail 'The Doom configuration submodule is incomplete.'
  if [[ -L $config_home/doom ]]; then
    [[ $(readlink -f -- "$config_home/doom") == "$repo/config/doom" ]] || fail "Conflicting Doom link at $config_home/doom; preserve it elsewhere before linking."
  elif [[ -e $config_home/doom ]]; then
    fail "Conflicting Doom configuration at $config_home/doom; preserve it elsewhere before linking."
  fi

  run mkdir -p -- "$config_home" "$target_home/.local/bin" "$data_home/applications"
  for target in \
    "$target_home"/.config/gtk-{3,4}.0/{settings.ini,gtk.css} \
    "$target_home"/.config/qt6ct/colors/dustveil.conf \
    "$target_home"/.config/qt6ct/qss/dustveil.qss \
    "$target_home"/.config/qt6ct/assets/{check,down,indeterminate,radio,up}.svg; do
    if [[ -L $target && $(readlink -f -- "$target") == "$repo/config/${target#"$config_home/"}" ]]; then
      continue
    fi
    if [[ -f $target || -L $target ]]; then
      run mv -T -- "$target" "$target.backup.$stamp"
    fi
  done
  run stow --dir="$repo" --target="$config_home" --no-folding --ignore='^doom$' config
  run stow --dir="$repo" --target="$target_home/.local/bin" scripts
  run stow --dir="$repo" --target="$data_home/applications" applications
  run stow --dir="$repo" --target="$target_home" shell
  if [[ ! -L $config_home/doom ]]; then
    run ln -s -- "$repo/config/doom" "$config_home/doom"
  fi
}

install_doom() {
  local emacs_dir=$config_home/emacs

  if [[ ! -d $emacs_dir ]]; then
    git clone --depth 1 https://github.com/doomemacs/doomemacs.git "$work/doom-emacs"
    mv -T -- "$work/doom-emacs" "$emacs_dir"
    "$emacs_dir/bin/doom" install
    return
  fi

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

  if [[ -f $target ]] && cmp -s -- "$repo/desktop/mimeapps.list" "$target"; then
    return
  fi

  install -m 600 -- "$repo/desktop/mimeapps.list" "$target"
}

install_crontab() {
  local state_directory=${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles
  local current

  current=$(crontab -l 2> /dev/null) || true
  [[ $current != "$(< "$repo/desktop/crontab")" ]] || return 0

  if [[ -n $current ]]; then
    mkdir -p "$state_directory"
    printf '%s\n' "$current" > "$state_directory/crontab-$stamp"
  fi
  crontab "$repo/desktop/crontab"
}

setup_user_phase() {
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

preflight() {
  local booted_root

  [[ $(. /etc/os-release 2> /dev/null && echo "$ID") == void ]] || fail 'This installer requires Void Linux.'
  command -v xbps-install > /dev/null 2>&1 || fail 'xbps-install not found.'

  booted_root=$(stat -Lc '%d:%i' /proc/1/root 2> /dev/null || true)
  if [[ -n $booted_root && $(stat -Lc '%d:%i' /) != "$booted_root" ]]; then
    fail 'The target is not the booted root.'
  fi

  [[ $repo == "$target_home/"* && -d $repo/.git ]] || fail 'Keep a Git checkout inside the desktop user home before running this installer.'
  [[ $(stat -c %u "$repo") == "$target_uid" ]] || fail "The checkout must belong to $target_user."

  if [[ -e $config_home/emacs || -L $config_home/emacs ]]; then
    [[ -x $config_home/emacs/bin/doom && -d $config_home/emacs/.git ]] || fail "Incomplete or unrelated Emacs installation at $config_home/emacs; preserve it elsewhere before rerunning."
  fi
}

main() {
  if (($# > 1)) || [[ $# == 1 && ${1:-} != --link ]]; then
    fail 'Usage: ./install.sh [--link]'
  fi

  if [[ ${1:-} == --link ]]; then
    ((EUID != 0)) || fail 'Run ./install.sh --link as your desktop user.'
    select_user
    stamp=$(date -u +%Y%m%dT%H%M%SZ)-$$
    install_stow
    echo 'Dotfiles linked.'
    return
  fi

  if [[ ${DOTFILES_USER_SETUP:-} != 1 ]] && ((EUID != 0)); then
    if command -v doas > /dev/null 2>&1; then
      exec doas -- "$repo/install.sh"
    elif command -v sudo > /dev/null 2>&1; then
      exec sudo -- "$repo/install.sh"
    fi
    # shellcheck disable=SC2016
    exec su -s /bin/bash -c 'exec "$1"' root bash "$repo/install.sh"
  fi

  select_user
  stamp=$(date -u +%Y%m%dT%H%M%SZ)-$$
  work=$(mktemp -d -t dotfiles.XXXXXXXX)
  trap 'rm -rf -- "$work"' EXIT
  trap 'printf "Installation failed at line %s. Fix the error above and rerun the same command.\n" "$LINENO" >&2' ERR

  if [[ ${DOTFILES_USER_SETUP:-} == 1 ]]; then
    setup_user_phase
    return
  fi

  preflight

  run as_user git -C "$repo" submodule update --init --recursive

  [[ -r $repo/config/doom/init.el ]] || fail 'The Doom configuration submodule is incomplete.'

  install_system_config
  install_packages
  configure_desktop_session
  install_emacs
  install_custom_packages
  configure_account
  configure_mdns
  configure_pipewire
  run as_user env DOTFILES_USER_SETUP=1 "$repo/install.sh"

  doas -C /etc/doas.conf || fail 'doas rejected /etc/doas.conf.'
  enable_services

  echo 'Installation complete.'
}

main "$@"
