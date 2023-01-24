#!/usr/bin/python3
##############################################################################################################
# DESC: zabbix checker, test if google safesearch is enabled
###############################################################################################################
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

# due ssl inspection enabled, we want to avoid ssl errors
import requests
from requests.exceptions import SSLError
import urllib3
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

import socket
import dns.resolver

# print debug messages
debug_output = False
# url to test
google_dns = "www.google.com"
# safesearch test request
ss_url = "https://" + google_dns + "/search?q=test"
# safesearch response url
ss_url_safesearch_response = "safe%3Dactive"
# google safesearch ips
safesearch_ip_range = ["216.239.38.120", "216.239.38.119"]

# query google for safesearch settings
try:
  response = requests.get(ss_url, verify=False)
  if debug_output:
    print("debug: response.url: " + response.url)
except SSLError as e:
  print("Suppressed SSL Error:", e)


# check if the safe search parameter is present in the response
safe_search_param = ss_url_safesearch_response in response.url
if debug_output:
  print("debug: safe_search_param: " + str(safe_search_param))

# check the IP address of the Google search server
google_search_ip = socket.gethostbyname(google_dns)
if debug_output:
  print("debug: google_search_ip: " + google_search_ip)

# check if the IP address of the Google search server is in the SafeSearch IP range
is_safesearch_ip = google_search_ip in safesearch_ip_range
if debug_output:
  print("debug: is_safesearch_ip: " + str(is_safesearch_ip))

# combine the checks and print the result
if safe_search_param or is_safesearch_ip:
    print("SAFESEARCH_GOOGLE:RESTRICTED")
else:
    print("SAFESEARCH_GOOGLE:OPEN")

