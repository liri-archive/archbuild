#!/bin/bash

set -e

# Update packages
pacman -Syu --noconfirm

# Update keys
pacman -S --noconfirm haveged procps-ng
haveged -w 1024
pacman-key --init
pkill haveged || /bin/true
pacman -Rs --noconfirm haveged
pacman-key --populate archlinux
pkill gpg-agent || /bin/true

# Install packages
pacman -S --noconfirm \
    sudo \
    sed \
    liri-shell-git \
    liri-wayland-git \
    liri-workspace-git \
    liri-settings-git \
    liri-files-git \
    liri-appcenter-git \
    liri-terminal-git \
    liri-wallpapers-git \
    liri-themes-git \
    xorg-server \
    mesa-libgl \
    phonon-qt5-gstreamer

# Setup locale
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
echo en_US.UTF-8 UTF-8 >> /etc/locale.gen
locale-gen

# Remove unnecessary files
rm -rf /README /usr/share/man/* /usr/share/info/* /usr/share/doc/* /usr/include/* /usr/lib/pkgconfig /usr/lib/cmake /var/lib/pacman

# Create the user
useradd -G wheel,video,input -ms /bin/bash lirios
echo "lirios:U6aMy0wojraho" | chpasswd -e
echo "lirios ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
mkdir /run/lirios && chown lirios:lirios /run/lirios && chmod 0700 /run/lirios
