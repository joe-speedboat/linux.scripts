#!/bin/bash
# $RCSfile: drbd-split-brain-repair.sh,v $
# DESC: repair drbd splitbrain status on proxmox cluster, tested on v1.8
# $Revision: 1.2 $
# $Author: chris $
# SRC: /usr/local/sbin/drbd-split-brain-repair.sh

# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt



PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# primary drbd node (daten auf lokaler node werden gelöscht)
REMOTE="fatboy2-drbd"

DEBUG=1
# proxmox backup target
STORAGE="NAS"
# LVM VolumeGroup in DRBD
VG=drbdvg
# drbd Ressource (cat /etc/drbd.conf)
DRBD_RES=mirror0
# mail for backup reports
MAILTO="support@bitbull.ch"
# do we want a backup???? ... NOOOO !!!!! :)
BACKUP=0


### functions #################################################################

log(){
   [ "$1" = "err" ] && LEVEL=ERROR
   [ "$1" = "warn" ] && LEVEL=WARNING
   [ "$1" = "info" ]&& LEVEL=INFO
   [ "$1" = "debug" ]&& LEVEL=DEBUG
   shift
   logger -t $(basename $0) "$LEVEL: $*"
   [ $DEBUG -eq 1 ] && echo "$(date '+%Y.%m.%d %H:%M:%S') $(uname -n) $(basename $0)[$$]: $LEVEL: $*"
   [ "$LEVEL" = "ERROR" ] && echo "$(date '+%Y.%m.%d %H:%M:%S') $(uname -n) $(basename $0)[$$]: $LEVEL: $*"
   [ "$LEVEL" = "ERROR" ] && exit 1
   }

start_server(){
   SERVER=$1
   VMID="$(qm list | grep " $SERVER " | awk '{print $1}')"
   [ -e $VMID ] && return 1
   STATE="$(qm list | grep " $SERVER " | awk '{print $3}')"
   while [ "$STATE" = "stopped" ]
   do
      log info "exec: qm start $VMID"
      qm start $VMID
      sleep 15
      STATE="$(qm list | grep " $SERVER " | awk '{print $3}')"
   done
   }

stop_server(){
   SERVER=$1
   VMID="$(qm list | grep " $SERVER " | awk '{print $1}')"
   [ -e $VMID ] && return 1
   STATE="$(qm list | grep " $SERVER " | awk '{print $3}')"
   while [ "$STATE" = "running" ]
   do
      log info "exec: qm shutdown $VMID"
      qm shutdown $VMID
      sleep 15
      STATE="$(qm list | grep " $SERVER " | awk '{print $3}')"
   done
   }


backup_server(){
   SERVER=$1
   VMID="$(qm list | grep " $SERVER " | awk '{print $1}')"
   STATE="$(qm list | grep " $SERVER " | awk '{print $3}')"
   [ -e $VMID ] && return 1
   [ "$STATE" = "running" ] && return 1
   if [ $BACKUP -ne 0 ]
   then
      log info "exec: vzdump --quiet --snapshot --compress --storage $STORAGE --mailto $MAILTO $VMID"
      vzdump --quiet --snapshot --compress --storage $STORAGE --mailto $MAILTO $VMID
      log info backup done for $VMID 
   else
      log info "no backup for $VMID, backup is disabled"
   fi
   }


# allgemeines gebrabbel #######################################################
echo "
   ACHTUNG ACHTUNG ACHTUNG
   
   dies ist eine ganz gefährliche sache und sollte nur von jemandem 
   ausgeführt werden, der sich mit volgenden temen gut auskennd:
   - drbd 2 node setup
   - proxmox cluster
   - kvm virtualiserung
   - linux system administration

   stelle vor der ausführung folgendes sicher:
   - beide noden sind via ssh erreichbar
   - proxmox läuft einwandfrei
   - es wurden seit dem ausfall keine VMs umgezogen

   folgendes wird getan:
   - alle VMs auf der aktuellen node stoppen
   - alle VM disks (lvm) auf der aktuellen node nach $REMOTE kopieren
   - stoppen und nachfragen
   - alle VM configs der aktuellen node nach $REMOTE kopieren
   - alle VMs auf der remote Node starten
   - anleitung zum wiederherstellen des drbd clusters ausgeben

   weiter mit 3 x <ENTER>, abbruch mit <CTRL-C>
"
read stop
read stop
read stop

# benötigte pakete installieren ###############################################
apt-get -y install buffer >/dev/null
ssh $REMOTE 'apt-get -y install buffer >/dev/null'

### erst mal pingen, das sollte schon gehen ###################################
PRE=0
ping -c1 -w1 $REMOTE || PRE=1
if [ $PRE = 1 ]
then
   log err kann $REMOTE nicht anpingen
else
   log info netzwerk verbindung ist ok
fi

# testen ob es sich wirklich um eine split brain problem handelt ##############
PRE=0
cat /proc/drbd | grep -q 'ro:Primary/Unknown ds:UpToDate/DUnknown' || PRE=1
ssh $REMOTE "cat /proc/drbd" | grep -q 'ro:Primary/Unknown ds:UpToDate/DUnknown' || PRE=1
if [ $PRE = 1 ]
then
   log err drbd status ist falsch
else
   log info drbd status korrekt, split brain erkannt
fi

### feststellen ob die config passt ###########################################
vgs | grep -q $VG || log err "VG $VG nicht gefunden, pruefe config"
grep -q $STORAGE /etc/pve/storage.cfg || log err "Backup Storage $STORAGE nicht gefunden, pruefe config"


### erst mal backup machen ####################################################
qm list | grep -v BOOTDISK | awk '{print $2}' | while read MACHINE
do
   stop_server $MACHINE
   backup_server $MACHINE
done
   
### dann mal die disks auf eine seite schieben ################################
qm list 2>/dev/null | grep -v BOOTDISK | awk '{print $1}' | while read MACHINE
do 
   cat /etc/qemu-server/$MACHINE.conf | grep $MACHINE-disk- | cut -d: -f3 
done | while read DISK
do
   log info "uebertrage disk /dev/$VG/$DISK nach $REMOTE"
   dd if=/dev/$VG/$DISK | buffer -s 64k -S 10m | ssh root@$REMOTE "cat > /dev/$VG/$DISK"
done

### config der VMs nach $REMOTE kopieren und VMs starten ######################

echo "
   nun alle VM configs der aktuellen node nach $REMOTE kopieren 
   und danach die VMs starten???

   weiter mit 3 x <ENTER>, abbruch mit <CTRL-C>
   "
read x
read x
read x


tar cvfz /etc/qemu-server.$(date +%Y%m%d%H%M).tar.gz /etc/qemu-server
qm list 2>/dev/null | grep -v BOOTDISK | awk '{print $1}' | while read MACHINE
do
   log info "kopiere /etc/qemu-server/$MACHINE.conf nach $REMOTE"
   scp /etc/qemu-server/$MACHINE.conf $REMOTE:/etc/qemu-server/$MACHINE.conf
   rm -f /etc/qemu-server/$MACHINE.conf
   log info "starte $MACHINE auf $REMOTE"
   ssh -n $REMOTE "qm start $MACHINE"
done


echo "
   alle configs sind kopiert, nun sollte geprueft werden ob die images auf der
   ziel hardware angekommen und aktuell sind.

   danach kann der drbd cluster wie folgt wieder hergestellt werden:
   # lokal:  alle daten sind gelöscht
   # remote: enthält die aktuellen daten

   # die verbindung des drbd clusters trennen
   local:  drbdadm disconnect $DRBD_RES
   remote: drbdadm disconnect $DRBD_RES

   # lokalen node zum secondary herabstufen (fuer späteres überschreiben)
   local: qm list   # ---> alle VMs muessen gestoppt sein
   local: vgchange -a n $VG # ---> die VG freigeben
   local: drbdadm secondary $DRBD_RES

   # synchronisation anstossen (lokale daten werden nun gelöscht)
   local:  drbdadm -- --discard-my-data connect $DRBD_RES
   remote: drbdadm connect $DRBD_RES

   # lokale node wieder zum primary hochstufen (erst wenn synchronisation abgeschlossen ist)
   local: drbdadm primary $DRBD_RES

   das wars ...
"

###############################################################################
# $Log: drbd-split-brain-repair.sh,v $
# Revision 1.2  2012/06/10 19:18:51  chris
# auto backup
#
# Revision 1.1  2011/10/05 17:19:12  chris
# Initial revision
#
