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
import re
import sys
import warnings
from requests.packages.urllib3.exceptions import InsecureRequestWarning

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

# to get around ssl-inspection we do not care vor certificate errors
with warnings.catch_warnings():
    warnings.filterwarnings("ignore", category=InsecureRequestWarning)
    try:
        response = requests.get(url, verify=False)
        response.raise_for_status()
        html = response.text

        for word in site_blocked_words:
            if re.search(word, html):
              site_works = False
              if print_debug:
                print(f'{word} found on {url}')
            else:
              if print_debug:
                print(f'{word} not found on {url}')


    except requests.exceptions.HTTPError as errh:
      if print_debug:
        print ("HTTP Error:",errh)
    except requests.exceptions.ConnectionError as errc:
      if print_debug:
        print ("Error Connecting:",errc)
    except requests.exceptions.Timeout as errt:
      if print_debug:
        print ("Timeout Error:",errt)
    except requests.exceptions.RequestException as err:
      if print_debug:
        print ("Something went wrong",err)

print("SITE_TEST:" + fqdn + "=" + str(site_works))

