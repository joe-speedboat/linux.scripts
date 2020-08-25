#!/bin/bash
# DESC: useful function to see which git revision is currently in use

# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

git_rev ()
{
    d=`date +%Y%m%d`
    c=`git rev-list --full-history --all --abbrev-commit | wc -l | sed -e 's/^ *//'`
    h=`git rev-list --full-history --all --abbrev-commit | head -1`
    echo ${c}:${h}:${d}
}

