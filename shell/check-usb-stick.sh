###############################################################################################################
# DESC: tool to analyze usb sticks or block devices for defects, can take long time
# $Author: chris $
# $Revision: 1.3 $
# $RCSfile: check-usb-stick.sh,v $
###############################################################################################################
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt



export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
rm -f /tmp/md5sum.log*

if [ "$USER" != "root" ]
then
   echo ERROR, $(basename $0) must be started as user root
   exit 1
fi

clear
echo "
   WARNING: Testing device will loose any data!
   
   Press CTRL-C to abort if you are unsure!
   "

read -p "   Name of device [eg: /dev/sdb]: " mydev

if [ ! -b "$mydev" ]
then
   echo ERROR: $mydev is not a block device
   exit 1
fi

mount | grep -q ${mydev}1 && umount ${mydev}1

# exit on any errors on comands below
set -e

mysize=$(fdisk -s $mydev | rev | cut -c4- | rev)

echo "
   Device $mydev has size of $mysize MB
   if this is wrong, press CTRL-C to abort
   or ENTER do continue
   "
read x


mysize=$(( $mysize - 10 ))

echo INFO: destroying partition table on $mydev
dd if=/dev/zero of=$mydev bs=1M count=1

echo INFO: create fat32 partition on $mydev
fdisk $mydev <<EOF
n
p



t
b
w
EOF

echo INFO: format FAT32 partition on ${mydev}1
mkfs.vfat -F32 ${mydev}1


test -d /tmp/$(basename $mydev) || mkdir /tmp/$(basename $mydev)
mount ${mydev}1 /tmp/$(basename $mydev)
cd /tmp/$(basename $mydev)

# now, do not exit on erros anymore
set +e

echo INFO: write 1 MB dummy files until disk is full and get md5sum of every written file
sleep 5

for i in $(seq $mysize)
do
   dd if=/dev/urandom of=dummy.$i bs=1M count=1
   md5sum dummy.$i | tee -a /tmp/md5sum.log
done
echo INFO: all dummy files are written, lets check md5sum of dummy files again
sleep 5

cd /tmp/$(basename $mydev)
for i in $(seq $mysize)
do
   md5sum dummy.$i | tee -a /tmp/md5sum.log2
done

diff /tmp/md5sum.log2 /tmp/md5sum.log
if [ $? -eq 0 ]
then
   echo INFO: YES, THIS DEVICE WORKS GREAT
else
   echo ERROR: NO, NOT ALL FILES ARE CONSISTENT, DO NOT USE THIS DEVICE
   echo NOTE: you can analyze the md5sum.log md5sum.log2 files to check what kind of failure it is
fi

cd
umount /tmp/$(basename $mydev)

################################################################################
# $Log: check-usb-stick.sh,v $
# Revision 1.3  2016/01/31 21:18:48  chris
# moved log file to /tmp/ to get results when usb drive is completly broken
#
# Revision 1.2  2014/11/02 12:14:24  chris
# free 10MB space for md5sum logs
#
# Revision 1.1  2014/11/02 12:01:16  chris
# Initial revision
#

