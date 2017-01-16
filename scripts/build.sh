#!/bin/bash

# Avoid any encoding problems
export LANG=C

shopt -s extglob

# check if messages are to be printed using color
unset ALL_OFF BOLD BLUE GREEN RED YELLOW
if [[ -t 2 ]]; then
    # prefer terminal safe colored and bold text when tput is supported
    if tput setaf 0 &>/dev/null; then
        ALL_OFF="$(tput sgr0)"
        BOLD="$(tput bold)"
        BLUE="${BOLD}$(tput setaf 4)"
        GREEN="${BOLD}$(tput setaf 2)"
        RED="${BOLD}$(tput setaf 1)"
        YELLOW="${BOLD}$(tput setaf 3)"
    else
        ALL_OFF="\e[1;0m"
        BOLD="\e[1;1m"
        BLUE="${BOLD}\e[1;34m"
        GREEN="${BOLD}\e[1;32m"
        RED="${BOLD}\e[1;31m"
        YELLOW="${BOLD}\e[1;33m"
    fi
fi
readonly ALL_OFF BOLD BLUE GREEN RED YELLOW

plain() {
        local mesg=$1; shift
        printf "${BOLD}    ${mesg}${ALL_OFF}\n" "$@" >&2
}

msg() {
        local mesg=$1; shift
        printf "${GREEN}==>${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
}

msg2() {
        local mesg=$1; shift
        printf "${BLUE}  ->${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
}

warning() {
        local mesg=$1; shift
        printf "${YELLOW}==> WARNING:${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
}

error() {
    local mesg=$1; shift
    printf "${RED}==> ERROR:${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
}

stat_busy() {
    local mesg=$1; shift
    printf "${GREEN}==>${ALL_OFF}${BOLD} ${mesg}...${ALL_OFF}" >&2
}

stat_done() {
    printf "${BOLD}done${ALL_OFF}\n" >&2
}

abort() {
    error 'Aborting...'
}

trap_abort() {
    trap - EXIT INT QUIT TERM HUP
    abort
}

trap_exit() {
    local r=$?
    trap - EXIT INT QUIT TERM HUP
}

die() {
    (( $# )) && error "$@"
}

trap 'trap_abort' INT QUIT TERM HUP
trap 'trap_exit' EXIT

##
#  usage : lock( $fd, $file, $message )
##
lock() {
    eval "exec $1>"'"$2"'
    if ! flock -n $1; then
        stat_busy "$3"
        flock $1
        stat_done
    fi
}

##
#  usage : slock( $fd, $file, $message )
##
slock() {
    eval "exec $1>"'"$2"'
    if ! flock -sn $1; then
        stat_busy "$3"
        flock -s $1
        stat_done
    fi
}

##
# usage: getpkver( $pkgbuild )
##
getpkgver() {
    pkgbuild=$1

    if [ -z "$pkgbuild" ]; then
        return 1
    fi

    basedir=`readlink -f $(dirname $pkgbuild)`
    srcdir="$basedir/src"

    source $pkgbuild

    if [ "`type -t pkgver`" = 'function' ]; then
        cd $srcdir
        ver=$(pkgver)

        if [ -z "$ver" ]; then
            echo "?"
        else
            echo $ver
        fi
    else
        echo $pkgver
    fi
}

##
# usage: getpkgrel( $pkgbuild )
##
getpkgrel() {
    pkgbuild=$1

    if [ -z "$pkgbuild" ]; then
        return 1
    fi

    basedir=`readlink -f $(dirname $pkgbuild)`
    srcdir="$basedir/src"

    source $pkgbuild

    echo $pkgrel
}

##
# usage: should_build_package()
##
should_build_package() {
    # Get package version
    local _pkgver=$(getpkgver PKGBUILD)
    if [ "$_pkgver" = "?" ]; then
        echo "Unable to determine package version!"
        return 1
    fi

    source PKGBUILD

    local _arch=x86_64
    if [ ${#arch[@]} -eq 1 ]; then
        _arch=$arch
    fi

    for pkg in "${pkgname[@]}"; do
        PKGDEST=/repo find_cached_package $pkg ${_pkgver}-${pkgrel:-1} $_arch
        if [ $? -eq 0 ]; then
            return 1
        fi
    done

    return 0
}

##
# usage: sync_packages()
##
sync_repo() {
    source PKGBUILD

    for pkg in "${pkgname[@]}"; do
        repo-remove /repo/liri-unstable.db.tar.gz $pkg
        rm -f /repo/${pkg}-*.pkg.tar?(.?z)

        mv ${pkg}-*.pkg.tar?(.?z) /repo
        (cd /repo; repo-add liri-unstable.db.tar.gz ${pkg}-*.pkg.tar?(.?z))
    done
}

##
# usage: pkgver_equal( $pkgver1, $pkgver2 )
##
pkgver_equal() {
    local left right

    if [[ $1 = *-* && $2 = *-* ]]; then
        # if both versions have a pkgrel, then they must be an exact match
        [[ $1 = "$2" ]]
    else
        # otherwise, trim any pkgrel and compare the bare version.
        [[ ${1%%-*} = "${2%%-*}" ]]
    fi
}

##
#  usage: find_cached_package( $pkgname, $pkgver, $arch )
#
#    $pkgver can be supplied with or without a pkgrel appended.
#    If not supplied, any pkgrel will be matched.
##
find_cached_package() {
    local searchdirs=("$PWD" "$PKGDEST") results=()
    local targetname=$1 targetver=$2 targetarch=$3
    local dir pkg pkgbasename pkgparts name ver rel arch size r results

    for dir in "${searchdirs[@]}"; do
        [[ -d $dir ]] || continue

        for pkg in "$dir"/*.pkg.tar?(.?z); do
            [[ -f $pkg ]] || continue

            # avoid adding duplicates of the same inode
            for r in "${results[@]}"; do
                [[ $r -ef $pkg ]] && continue 2
            done

            # split apart package filename into parts
            pkgbasename=${pkg##*/}
            pkgbasename=${pkgbasename%.pkg.tar?(.?z)}

            arch=${pkgbasename##*-}
            pkgbasename=${pkgbasename%-"$arch"}

            rel=${pkgbasename##*-}
            pkgbasename=${pkgbasename%-"$rel"}

            ver=${pkgbasename##*-}
            name=${pkgbasename%-"$ver"}

            if [[ $targetname = "$name" && $targetarch = "$arch" ]] &&
                        pkgver_equal "$targetver" "$ver-$rel"; then
                results+=("$pkg")
            fi
        done
    done

    case ${#results[*]} in
        0)
            return 1
            ;;
        1)
            printf '%s\n' "$results"
            return 0
            ;;
        *)
            error 'Multiple packages found:'
            printf '\t%s\n' "${results[@]}" >&2
            return 1
    esac
}

# Update packages index
pacman -Sy

# Fetch sources and update pkgver for git packages
msg "Refreshing package..."
/bin/entrypoint -c "makepkg --noconfirm -od" || exit $?

# Build only if we don't have a previous build
should_build_package
if [ $? -eq 0 ]; then
    set -e

    msg "Building package..."
    /bin/entrypoint -c "makepkg --noconfirm -s"
    sync_repo
fi
