#!/bin/bash
#
# This file is part of Liri.
#
# Copyright (C) 2017 Pier Luigi Fiorini <pierluigi.fiorini@gmail.com>
#
# $BEGIN_LICENSE:GPL3+$
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# $END_LICENSE$
#

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

# Setup locale
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
echo en_US.UTF-8 UTF-8 >> /etc/locale.gen
locale-gen
