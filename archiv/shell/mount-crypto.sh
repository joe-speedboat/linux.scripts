#! /bin/bash
# DESC: script to handle encrypted disk (luks)
# $Author: chris $
# $Revision: 1.2 $
# $RCSfile: mount-crypto.sh,v $

# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

# SETUP:
# cryptsetup luksFormat --cipher aes-cbc-essiv:sha256 /dev/hda3
# cryptsetup luksOpen /dev/hda3 data
# mkfs.ext3 /dev/mapper/data
# cryptsetup luksClose /dev/mapper/data

CRYPTSETUP="/sbin/cryptsetup"
DEV="/dev/hda3"
MAPPER="data"
MOUNT="/data"

case $1 in
-m)     $CRYPTSETUP luksOpen $DEV $MAPPER
        mount /dev/mapper/$MAPPER $MOUNT
        ;;
-u)     umount $MOUNT
        $CRYPTSETUP luksClose $MAPPER
        ;;
stop)   umount $MOUNT
        $CRYPTSETUP luksClose $MAPPER
        ;;
-a)     $CRYPTSETUP -y luksAddKey $DEV
        ;;
-d)     if [[ -z "$2" ]] ; then
                echo "usage: -d <nr> - del key"
        else
                $CRYPTSETUP luksDelKey $DEV $2
        fi
        ;;
*)      echo "usage: -m - mount and open encrypted device"
        echo "       -u - umount and close encrypted device"
        echo "       -a - add key"
        echo "       -d <nr> - del key"
        ;;
esac

################################################################################
# $Log: mount-crypto.sh,v $
# Revision 1.2  2012/06/10 19:18:47  chris
# auto backup
#
# Revision 1.1  2010/01/17 20:40:14  chris
# Initial revision
#
