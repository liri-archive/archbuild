FROM liri-docker-build.bintray.io/archlinux/devel
ADD pacman-repo.conf /tmp/pacman-repo.conf
ADD entrypoint /bin/entrypoint
RUN mkdir -p /build && \
    mkdir -p /repo && \
    cat /tmp/pacman-repo.conf >> /etc/pacman.conf && \
    rm -f /tmp/pacman-repo.conf && \
    sed -i -e 's,^#MAKEFLAGS=,MAKEFLAGS=,g' /etc/makepkg.conf && \
    pacman -Syu --noconfirm && \
    pacman-db-upgrade && \
    pacman -S --noconfirm git && \
    rm -f /var/cache/pacman/pkg/*.pkg.tar.* && \
    useradd -u 1000 -m builduser && \
    passwd -d builduser && \
    chown -R builduser /build && \
    echo "builduser ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/makepkg
VOLUME /build
VOLUME /repo
CMD ["/bin/entrypoint"]
