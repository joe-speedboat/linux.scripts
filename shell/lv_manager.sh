#!/bin/bash
# DESC: print lvm usage and expand logical volumes on RHEL and Ubuntu


# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt


if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

function print_help() {
    echo "$(basename $0): a shell script that can expand logical volumes and grow its underlying filesystems to new settings"
    echo "Options:"
    echo "-h|--help                  : print help info"
    echo "-s|--show                  : print formatted output of vgs, lvs and df"
    echo "-a|--align                 : rescan and align sda3 partition and PV to new disk size (after VM disk grow)"
    echo "-g <lv_path> <size to add> : grow a lv and its filesystem"
    echo "    <lv_path>     : absolute lv name (/dev/VG0/root)"
    echo "    <size to add> : size to add (1g)"
    echo "Examples:"
    echo "   $(basename $0) -s"
    echo "   $(basename $0) -g /dev/vg0/lvname 5g"
    echo "   $(basename $0) -a"
}

function align_disk() {
    echo "WARNING: You are about to modify the data disk."
    echo "Please make a snapshot first, then hit <ENTER> to continue or <CTRL>+<C> to exit."
    read
    echo "Rescanning SCSI bus for sda..."
    echo 1 > /sys/class/block/sda/device/rescan 2>&1 | sed 's/^/   /'
    echo "Aligning partition sda3 to 100% using parted..."
    parted -s -f /dev/sda resizepart 3 100% yes 2>&1 | sed 's/^/   /' | grep -v -e 'Warning: Not all of the space available to /dev/sda' -e 'Fixing, due to --fix'
    echo "Resizing PV on /dev/sda3..."
    pvresize /dev/sda3 2>&1 | sed 's/^/   /'
    echo ""
    echo "SHOW CURRENT STATE:"
    show
    echo ""
    echo "IMPORTANT: Please reboot the VM before you left for best practice and to ensure all changes are persistent."
}

function show() {
    echo "Volume Group Usage:"
    vg_name_length=$(vgs --noheadings --separator " " | awk '{print length($1)}' | sort -nr | head -n 1)
    header_length=$(echo -n "NAME" | wc -c)
    max_length=$(($vg_name_length>$header_length?$vg_name_length:$header_length))
    max_length=$(($max_length<10?10:$max_length))
    max_length=$(($max_length<10?10:$max_length))
    printf "%-${max_length}s %-10s %-10s\n" "NAME" "SIZE(GB)" "FREE(GB)"
    vgs --units=g --noheadings --nosuffix | awk -v len=$max_length '{printf "%-"len"s %-10.2f %-10.2f\n", $1, $6, $7}'
    echo ""
    echo "Logical Volume Usage:"
    max_lv_name_length=$(lvs --noheadings --separator " " | awk '{print length("/dev/"$2"/"$1)}' | sort -nr | head -n 1)
    header_length=$(echo -n "NAME" | wc -c)
    max_length=$(($max_lv_name_length>$header_length?$max_lv_name_length:$header_length))
    max_length=$(($max_length<10?10:$max_length))
    printf "   %-${max_length}s %-6s %-12s %-12s %-12s\n" "NAME" "FS" "LV_SIZE(GB)" "FS_SIZE(GB)" "FS_USED(GB)"
    lvs --noheadings --separator " " | while read lv vg rest; do
        lv_name_length=$(echo "/dev/$vg/$lv" | wc -c)
        fs_type=$(lsblk -no FSTYPE "/dev/$vg/$lv")
        lv_size=$(lvs --noheadings --units=g --nosuffix -o lv_size "/dev/$vg/$lv" | awk '{printf "%.2f", $1}')
        if [ "$fs_type" == "swap" ]; then
            fs_size=$lv_size
            fs_used="N/A"
            printf "   %-${max_lv_name_length}s %-6s %-12.2f %-12.2f %-10s\n" "/dev/$vg/$lv" "$fs_type" "$lv_size" "$fs_size" "$fs_used"
        else
            fs_size=$(df -BM --output=size "/dev/$vg/$lv" | tail -n1 | awk '{printf "%.2f", $1/1024}')
            fs_used=$(df -BM --output=used "/dev/$vg/$lv" | tail -n1 | awk '{printf "%.2f", $1/1024}')
            lv_size_rounded=$(printf "%.0f" $lv_size)
            fs_size_rounded=$(printf "%.0f" $fs_size)
            printf "   %-${max_lv_name_length}s %-6s %-12.2f %-12.2f %-10s\n" "/dev/$vg/$lv" "$fs_type" "$lv_size" "$fs_size" "$fs_used"
        fi
    done
}

function grow() {
    lv_name=$1
    size_to_add=$2
    echo "GROW LOGICAL VOLUME: $lv_name"
    echo "   execute: lvextend -L+$size_to_add $lv_name"
    lvextend -L+$size_to_add $lv_name 2>&1 | sed 's/^/   /'
    fs_type=$(blkid -o value -s TYPE $lv_name)
    echo "GROW FILESYSTEM:"
    if [ "$fs_type" == "xfs" ]; then
        echo "   execute: xfs_growfs $lv_name"
        xfs_growfs $lv_name 2>&1 | sed 's/^/   /'
    elif [ "$fs_type" == "ext4" ]; then
        echo "   execute: resize2fs $lv_name"
        resize2fs $lv_name 2>&1 | sed 's/^/   /'
    elif [ "$fs_type" == "swap" ]; then
        echo "   execute: swapoff $lv_name"
        swapoff $lv_name 2>&1 | sed 's/^/   /'
        echo "   execute: mkswap $lv_name"
        mkswap $lv_name 2>&1 | sed 's/^/   /'
        echo "   execute: swapon $lv_name"
        swapon $lv_name 2>&1 | sed 's/^/   /'
    fi
}

if [ $# -eq 0 ]; then
    print_help
else
    while (( "$#" )); do
        case "$1" in
            -h|--help)
                if [ "$#" -ne 1 ]; then
                    print_help
                    exit 1
                fi
                print_help
                shift
                ;;
            -s|--show)
                if [ "$#" -ne 1 ]; then
                    print_help
                    exit 1
                fi
                show
                shift
                ;;
            -g|--grow)
                if [ "$#" -ne 3 ]; then
                    print_help
                    exit 1
                fi
                lv_name=$2
                size_to_add=$3
                if ! lvs $lv_name > /dev/null 2>&1; then
                    print_help
                    exit 1
                fi
                if ! [[ $size_to_add =~ ^[0-9]+[gm]$ ]]; then
                    print_help
                    exit 1
                fi
                grow $lv_name $size_to_add
                shift 3
                ;;
            -a|--align)
                if [ "$#" -ne 1 ]; then
                    print_help
                    exit 1
                fi
                align_disk
                shift
                ;;
            *)
                print_help
                shift
                ;;
        esac
    done
fi
