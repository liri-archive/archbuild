#!/usr/bin/env python3
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

import sys
import os
import shutil

ARCH_LINUX_MIRROR = 'https://mirrors.lug.mtu.edu/archlinux'
ARCH_LINUX_ARCH = 'x86_64'


class CommandError(Exception):
    """
    Exception raised when a command has failed.
    """
    pass


def download_file(url, dest_path):
    """
    Download file from `url` into `dest_path` destination location.
    """
    import requests
    import shutil
    r = requests.get(url, stream=True)
    if r.status_code == 200:
        with open(dest_path, 'wb') as f:
            total = r.headers.get('Content-Length')
            print('Downloading %s' % url)
            if total is None:
                r.raw.decode_content = True
                shutil.copyfileobj(r.raw, f)
            else:
                total = int(total)
                written = 0
                for data in r.iter_content(chunk_size=4096):
                    f.write(data)
                    written += len(data)
                    done = int(50 * written / total)
                    sys.stdout.write('\r[{}{}]'.format('=' * done, ' ' * (50 - done)))
                    sys.stdout.flush()
                sys.stdout.write('\n')
            return True
    return False


def find_iso():
    """
    Find an Arch Linux bootstrap ISO published in the last month, download
    the tarball and return its filename.
    """
    import calendar
    import datetime
    today = datetime.date.today()
    one_month_ago = today - datetime.timedelta(days=calendar.monthrange(today.year, today.month)[1])
    dates = [one_month_ago + datetime.timedelta(days=x) for x in range((today - one_month_ago).days + 1)]
    print('Searching for last archive...')
    for date in dates:
        iso_date = date.strftime('%Y.%m.%d')
        archive_filename = 'archlinux-bootstrap-{}-{}.tar.gz'.format(iso_date, ARCH_LINUX_ARCH)
        url = '{}/iso/{}/{}'.format(ARCH_LINUX_MIRROR, iso_date, archive_filename)
        if download_file(url, archive_filename):
            return archive_filename
    return None


def replace_in_file(filename, search, replace):
    """
    Replace `search` with `replace` on file `filename`.
    """
    with open(filename, 'r') as f:
        filedata = f.read()
    filedata = filedata.replace(search, replace)
    with open(filename, 'w') as f:
        f.write(filedata)


def append_to_file(filename, text):
    """
    Append `text` to file `filename`.
    """
    with open(filename, 'a') as f:
        f.write(text)


def setup_dev(root_dir):
    """
    Create a static /dev directory for containers.
    """
    dev_dir = os.path.join(root_dir, 'dev')
    devices = {
        'null': {'mode': 666, 'args': 'c 1 3'},
        'zero': {'mode': 666, 'args': 'c 1 5'},
        'random': {'mode': 666, 'args': 'c 1 8'},
        'urandom': {'mode': 666, 'args': 'c 1 9'},
        'tty': {'mode': 666, 'args': 'c 5 0'},
        'console': {'mode': 600, 'args': 'c 5 1'},
        'tty0': {'mode': 666, 'args': 'c 4 0'},
        'full': {'mode': 666, 'args': 'c 1 7'},
        'initctl': {'mode': 600, 'args': 'p'},
        'ptmx': {'mode': 666, 'args': 'c 5 2'},
    }
    shutil.rmtree(dev_dir)
    os.makedirs(dev_dir)
    os.system('mkdir -m 755 {}'.format(os.path.join(dev_dir, 'pts')))
    os.system('mkdir -m 1777 {}'.format(os.path.join(dev_dir, 'shm')))
    os.symlink('/proc/self/fd', os.path.join(dev_dir, 'fd'))
    for device in devices:
        os.system('mknod -m {mode} {path}/{name} {args}'.format(name=device, path=dev_dir, mode=devices[device]['mode'], args=devices[device]['args']))


def setup_rootfs(archive_filename, nameserver=None, nosignedpackages=False, addliriosrepo=False):
    """
    Set OS root up uncompressing the `archive_filename` tar archive.
    """
    import tarfile
    # Remove previously unpacked tar
    root_dir = 'root.' + ARCH_LINUX_ARCH
    if os.path.exists(root_dir):
        shutil.rmtree(root_dir)
    # Extract base archive
    print('Extracting {} into {}'.format(archive_filename, root_dir))
    tar = tarfile.open(archive_filename, 'r')
    tar.extractall()
    tar.close()
    pacmanconf_filename = os.path.join(root_dir, 'etc', 'pacman.conf')
    mirror_filename = os.path.join(root_dir, 'etc', 'pacman.d', 'mirrorlist')
    # Do not require signed packages
    if nosignedpackages is True:
        replace_in_file(pacmanconf_filename, 'SigLevel    = Required DatabaseOptional', 'SigLevel = Never')
    # Add Liri OS repository
    if addliriosrepo is True:
        append_to_file(pacmanconf_filename, '\n[liri-unstable]\nSigLevel = Optional TrustAll\nServer = https://repo.liri.io/archlinux/unstable/$arch\n')
    # Add mirror
    append_to_file(mirror_filename, 'Server = {}/$repo/os/$arch\n'.format(ARCH_LINUX_MIRROR))
    # Add Google nameserver to resolv.conf
    if nameserver is not None:
        resolvconf_filename = os.path.join(root_dir, 'etc', 'resolv.conf')
        append_to_file(resolvconf_filename, 'nameserver 8.8.8.8')
    # Setup /dev
    setup_dev(root_dir)


if __name__ == '__main__':
    import argparse

    parser = argparse.ArgumentParser(description='Create Arch Linux base container')
    parser.add_argument('--arch', dest='arch', type=str,
                        help='architecture (default: %s)' % ARCH_LINUX_ARCH)
    parser.add_argument('--mirror', dest='mirror', type=str,
                        help='alternative Arch Linux mirror (default: %s)' % ARCH_LINUX_MIRROR)
    parser.add_argument('--archive', dest='archive', type=str,
                        help='use this archive instead of downloading a new one')
    parser.add_argument('--nameserver', dest='nameserver', type=str,
                        help='use an alternative nameserver')
    parser.add_argument('--siglevel-never', dest='nosignedpackages', action='store_true',
                        help='do not require packages to be signed')
    parser.add_argument('--lirios-repo', dest='addliriosrepo', action='store_true',
                        help='add the Liri OS repository')

    args = parser.parse_args()

    if args.arch:
        ARCH_LINUX_ARCH = args.arch
    if args.mirror:
        ARCH_LINUX_MIRROR = args.mirror
    if args.archive:
        archive_filename = args.archive
    else:
        archive_filename = find_iso()
    if archive_filename:
        setup_rootfs(archive_filename, nameserver=args.nameserver,
                     nosignedpackages=args.nosignedpackages,
                     addliriosrepo=args.addliriosrepo)
    else:
        print('Unable to find an Arch Linux ISO!', file=sys.stderr)
        sys.exit(1)
