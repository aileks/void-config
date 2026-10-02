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
  IFS=: read -r target_user _ target_uid _ _ target_home _ <<<"$account"
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
