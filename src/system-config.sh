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

install_xkb() {
  local xkb_dir
  xkb_dir=$(readlink -e /usr/share/X11/xkb)
  install_system_file "$repo/desktop/xkb/symbols/custom" "$xkb_dir/symbols/custom"
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

  if ! getent group i2c >/dev/null; then
    run groupadd --system i2c
  fi

  if [[ " $(id -nG "$target_user") " != *' i2c '* ]]; then
    run usermod -aG i2c "$target_user"
  fi

  if ! getent group uinput >/dev/null; then
    run groupadd --system uinput
  fi

  if [[ " $(id -nG "$target_user") " != *' uinput '* ]]; then
    run usermod -aG uinput "$target_user"
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
  ' /etc/nsswitch.conf >"$work/nsswitch.conf" || fail 'Expected a hosts lookup containing files in /etc/nsswitch.conf.'
  install_system_file "$work/nsswitch.conf" /etc/nsswitch.conf
}

configure_pipewire() {
  local source target

  run install -d -m 755 /etc/pipewire/pipewire.conf.d /etc/alsa/conf.d
  for source in /usr/share/examples/wireplumber/10-wireplumber.conf /usr/share/examples/pipewire/20-pipewire-pulse.conf; do
    [[ -f $source ]] || fail "Missing PipeWire example config: $source"
    target=/etc/pipewire/pipewire.conf.d/${source##*/}
    if [[ ! -L $target ]]; then
      run ln -s "$source" "$target"
    fi
  done

  for source in /usr/share/alsa/alsa.conf.d/50-pipewire.conf /usr/share/alsa/alsa.conf.d/99-pipewire-default.conf; do
    [[ -f $source ]] || fail "Missing PipeWire ALSA config: $source"
    target=/etc/alsa/conf.d/${source##*/}
    if [[ ! -L $target ]]; then
      run ln -s "$source" "$target"
    fi
  done
}

enable_services() {
  local service
  local services=(dbus elogind NetworkManager cronie bluetoothd cupsd avahi-daemon)

  for service in "${services[@]}"; do
    run ln -sfn "/etc/sv/$service" "/var/service/$service"
  done
}
