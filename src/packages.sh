packages=(
  linux-firmware NetworkManager network-manager-applet dnsmasq dbus-elogind elogind polkit-elogind opendoas
  avahi nss-mdns cups bluez blueman gst-plugins-base1 gst-plugins-good1 gst-plugins-bad1 gst-plugins-ugly1 xtools gst-libav 7zip tree
  bat psmisc fd fzf git jq shfmt ripgrep stow trash-cli unzip gsettings-desktop-schemas wget xdotool rsync zip zoxide btop
  fastfetch xorg-server xinit xauth xorg-apps xf86-input-libinput slop xkeyboard-config alsa-pipewire pipewire libspa-bluetooth maim
  wireplumber-elogind pulseaudio-utils xclip ghc xmobar trayer-srg alacritty alacritty-terminfo rofi xsecurelock xss-lock xwallpaper
  xautolock fontconfig fontconfig-devel nnn zathura zathura-pdf-mupdf mpv mpv-mpris gvfs pcmanfm
  dunst libnotify playerctl wiremix qalculate-gtk xarchiver ncdu2 nsxiv tumbler xdg-utils xdg-user-dirs polkit-gnome ffmpeg6
  xdg-desktop-portal-gtk ffmpegthumbnailer alsa-utils ddcutil libva-utils cronie tesseract-ocr tesseract-ocr-eng keyutils hunspell
  hunspell-en pinentry dconf gnome-keyring qt6ct papirus-icon-theme adwaita-icon-theme adwaita-fonts noto-fonts-ttf
  openrgb noto-fonts-cjk noto-fonts-emoji Signal-Desktop freetype-devel imlib2-devel pkg-config libX11-devel libXcursor-devel
  libXext-devel libXft-devel cmake libXinerama-devel libXrandr-devel libXrender-devel libxcb-devel libxcrypt-devel xcb-util-devel clang
  make bubblewrap ImageMagick libvterm tree-sitter-cli libgccjit-devel jansson-devel tree-sitter-devel gtk+3-devel cairo-devel
  harfbuzz-devel giflib-devel libjpeg-turbo-devel libpng-devel librsvg-devel libwebp-devel libxml2-devel gnutls-devel texinfo autoconf
  automake libXpm-devel ncurses-devel gpu-screen-recorder doasedit firefox dotool python3-gobject python3-cairo uv nodejs
)

install_packages() {
  install_missing void-repo-nonfree

  if [[ $gpu_vendor == nvidia ]]; then
    packages+=(nvidia nvidia-vaapi-driver)
  fi

  install_missing "${packages[@]}"
}
