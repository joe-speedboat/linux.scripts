#!/bin/bash
#########################################################################################
# DESC: geoip fence for ufw with ipsets
#########################################################################################
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

COUNTRIES='ch'
LOCAL_SN='10.0.0.0/8 172.16.0.0/12 192.168.0.0/16'

IP_LIST='whitelist'
URL='https://www.ipdeny.com/ipblocks/data/aggregated'

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/bin:/sbin
TMP=/var/tmp/ipblocks
rm -rf $TMP
mkdir -p $TMP
cd $TMP

test -x /etc/ufw/after.init && /etc/ufw/after.init stop
echo "INFO: prepare $IP_LIST ipset"
ipset destroy $IP_LIST 2>/dev/null
# ipset -N $IP_LIST iphash 2>/dev/null
ipset -exist create $IP_LIST hash:net family inet hashsize 32768 maxelem 1000000

for cc in $COUNTRIES
do
  echo "   INFO: Download $URL/$cc-aggregated.zone "
  wget -q "$URL/$cc-aggregated.zone" -O - >> $TMP/all.txt
  if [ $? -eq 0 ]
  then
    echo "   INFO: Downloaded $URL/$cc-aggregated.zone "
  else
    echo "   ERROR: Download $URL/$cc-aggregated.zone failed"
    exit 1
  fi
done

echo "INFO: read collection file into $IP_LIST ipset"
cat $TMP/all.txt | while read cidr
do
   echo "INFO: add country cidr $cidr to $IP_LIST ipset"
   ipset -A $IP_LIST $cidr
done

for sn in $LOCAL_SN
do
   echo "INFO: add subnet $sn to $IP_LIST ipset"
   ipset -A $IP_LIST $sn
done

LCOUNT="$(ipset save $IP_LIST | wc -l)"
if [ $LCOUNT -gt 3 ]
then
   ipset save $IP_LIST > /etc/ipset.$IP_LIST
   echo "INFO: IPSet $IP_LIST updated with $LCOUNT entries and saved to /etc/ipset.$IP_LIST"
   logger -p cron.notice "INFO: IPSet $IP_LIST updated with $LCOUNT entries"
else
    echo "   ERROR: IPSet $IP_LIST has only $LCOUNT entries"
    exit 1
fi




echo "# bitbull ubuntu 18.04 ipset whitelist service
[Unit]
Description=ipset persistancy service
DefaultDependencies=no
Requires=ufw.service
Before=network.target
Before=ufw.service
ConditionFileNotEmpty=/etc/ipset.$IP_LIST
 
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/sbin/ipset restore -f -! /etc/ipset.$IP_LIST
 
# save on service stop, system shutdown etc.
ExecStop=/sbin/ipset save $IP_LIST -f /etc/ipsets.$IP_LIST
 
[Install]
WantedBy=multi-user.target
 
RequiredBy=ufw.service
" > /etc/systemd/system/ipset-persistent.service

systemctl daemon-reload
systemctl restart ipset-persistent
systemctl enable ipset-persistent


test -f /etc/ufw/after.init.orig || cp -av /etc/ufw/after.init /etc/ufw/after.init.orig
cat << EOF >/etc/ufw/after.init
#!/bin/sh
set -e

case "\$1" in
start)
    iptables -A ufw-before-input -m set ! --match-set $IP_LIST src -j DROP
    iptables -A ufw-before-input -m set ! --match-set $IP_LIST src -j LOG --log-prefix "[UFW BLOCK ALL EXCEPT $IP_LIST] "
    iptables -D ufw-before-input -j ufw-user-input
    iptables -A ufw-before-input -j ufw-user-input
    ;;
stop)
    iptables -D ufw-before-input -m set ! --match-set $IP_LIST src -j DROP
    iptables -D ufw-before-input -m set ! --match-set $IP_LIST src -j LOG --log-prefix "[UFW BLOCK ALL EXCEPT $IP_LIST] "
    ;;
status)
    # optional
    ;;
flush-all)
    # optional
    ;;
*)
    echo "'\$1' not supported"
    echo "Usage: after.init {start|stop|flush-all|status}"
    ;;
esac
EOF

chmod 755 /etc/ufw/after.init
/etc/ufw/after.init start
systemctl enable ufw 2>&1
ufw --force enable 2>&1

