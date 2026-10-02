#!/usr/bin/env bash

set -Eeuo pipefail

repo=$(readlink -f -- "${BASH_SOURCE[0]}")
repo=${repo%/*}

source "$repo/src/lib.sh"
source "$repo/src/packages.sh"
source "$repo/src/custom-packages.sh"
source "$repo/src/system-config.sh"
source "$repo/src/emacs.sh"
source "$repo/src/user-tools.sh"
source "$repo/src/user-settings.sh"

preflight() {
  local booted_root

  [[ $(. /etc/os-release 2>/dev/null && echo "$ID") == void ]] || fail 'This installer requires Void Linux.'
  command -v xbps-install >/dev/null 2>&1 || fail 'xbps-install not found.'

  booted_root=$(stat -Lc '%d:%i' /proc/1/root 2>/dev/null || true)
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
  (($# == 0)) || fail 'Usage: ./install.sh'

  if [[ ${DOTFILES_USER_SETUP:-} != 1 ]] && ((EUID != 0)); then
    if command -v doas >/dev/null 2>&1; then
      exec doas -- "$repo/install.sh"
    elif command -v sudo >/dev/null 2>&1; then
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

  [[ -r $repo/home/.config/doom/init.el ]] || fail 'The Doom configuration submodule is incomplete.'

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
