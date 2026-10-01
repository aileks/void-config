custom_packages=(
  localsend
  onlyoffice-desktopeditors
  bitwarden-desktop
  voxtype
  xmonad
)

install_custom_packages() {
  local void_packages=$target_home/void-packages
  local repository=$void_packages/hostdir/binpkgs
  local package template
  local -a missing=()

  for package in "${custom_packages[@]}"; do
    xbps-query "$package" >/dev/null 2>&1 || missing+=("$package")
  done

  if ((${#missing[@]} > 0)); then
    if [[ ! -d $void_packages ]]; then
      run as_user git clone --depth 1 https://github.com/void-linux/void-packages.git "$void_packages"
    fi

    for template in "$repo"/templates/*/; do
      template=${template%/}
      run as_user rsync -a "$template/" "$void_packages/srcpkgs/${template##*/}/"
    done

    run as_user "$void_packages/xbps-src" binary-bootstrap
    for package in "${missing[@]}"; do
      run as_user "$void_packages/xbps-src" pkg "$package"
    done
  fi

  printf 'repository=%s\n' "$repository" >"$work/xbps-dotfiles.conf"
  install_system_file "$work/xbps-dotfiles.conf" /etc/xbps.d/10-dotfiles-repository.conf 644

  if ((${#missing[@]} > 0)); then
    run xbps-install -y --repository "$repository" "${missing[@]}"
  fi
  run xbps-pkgdb -m repolock "${custom_packages[@]}"
}
