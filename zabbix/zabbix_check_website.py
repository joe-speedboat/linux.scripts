#!/usr/bin/python3
##############################################################################################################
# DESC: zabbix checker, test if website gets blocked or not
###############################################################################################################
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

import requests
from requests.exceptions import SSLError
import re
import sys
import warnings
import urllib3
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)


# print debug information
print_debug = False

if len(sys.argv) < 2:
  sys.exit("ERROR: we need fqdn as arg")

# test if site gets blocked by some service
# fqdn = 'www.pornhub.com'
fqdn = sys.argv[1]

url = 'https://' + fqdn
site_blocked_words = ['dnswatch.watchguard.com', ' denied by ']

# as default, we assume site is not blocked, and we invert if any of the words get found
site_works = True

# to get around ssl-inspection we do not care for certificate errors
try:
  response = requests.get(url, verify=False)
  html = response.text

  for word in site_blocked_words:
    if re.search(word, html):
      site_works = False
      if print_debug:
        print(f'{word} found on {url}')
    else:
      if print_debug:
        print(f'{word} not found on {url}')

except SSLError as e:
  print("Suppressed SSL Error:", e)

print("SITE-" + fqdn + ":" + str(site_works))


