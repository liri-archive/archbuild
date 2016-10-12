#!/bin/bash

set -e -u

sed -i 's/#\(en_US\.UTF-8\)/\1/' /etc/locale.gen
locale-gen

ln -sf /usr/share/zoneinfo/UTC /etc/localtime

usermod -s /usr/bin/zsh root
cp -aT /etc/skel/ /root/
chmod 700 /root

if ! getent passwd liveuser ; then
    useradd -c 'Live User' -m -G wheel -U liveuser
fi
passwd -d liveuser

sed -i 's/#\(PermitRootLogin \).\+/\1yes/' /etc/ssh/sshd_config
sed -i "s/#Server/Server/g" /etc/pacman.d/mirrorlist
sed -i 's/#\(Storage=\)auto/\1volatile/' /etc/systemd/journald.conf

sed -i 's/#\(HandleSuspendKey=\)suspend/\1ignore/' /etc/systemd/logind.conf
sed -i 's/#\(HandleHibernateKey=\)hibernate/\1ignore/' /etc/systemd/logind.conf
sed -i 's/#\(HandleLidSwitch=\)suspend/\1ignore/' /etc/systemd/logind.conf

sed -i 's/hosts: files dns myhostname/hosts: files mdns_minimal [NOTFOUND=return] dns myhostname/' /etc/nsswitch.conf

systemctl enable pacman-init.service choose-mirror.service
systemctl enable acpid.service avahi-daemon.service accounts-daemon.service upower.service NetworkManager.service sddm.service
systemctl disable systemd-networkd.service systemd-resolved.service
systemctl set-default graphical.target

plymouth-set-default-theme lirios
