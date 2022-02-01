#!/bin/python3
##############################################################################################################
# DESC: create dynamisc ansible inventory based on hostname patterns
###############################################################################################################
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

import dns.zone
import dns.resolver
import json
import re


ns_server_ip='10.1.99.10'
ns_zone='domain.local'
inventory_pattern={
"switch": '^[ac][s]-([a-z]|[a-z][a-z])-[a-z0-9][a-z0-9][a-z0-9]-[0-9][0-9]',
"access_switch": '^as-([a-z]|[a-z][a-z])-[a-z0-9][a-z0-9][a-z0-9]-[0-9][0-9]',
"core_switch": '^cs-([a-z]|[a-z][a-z])-[a-z0-9][a-z0-9][a-z0-9]-[0-9][0-9]',
"firewall_asa": '^fw-([a-z]|[a-z][a-z])-[a-z0-9][a-z0-9][a-z0-9]-[0-9][0-9]',
"firewall_wg": '^nfw-([a-z]|[a-z][a-z])-[a-z0-9][a-z0-9][a-z0-9]-[0-9][0-9]',
"wlan_controller": '^nwc-([a-z]|[a-z][a-z])-[a-z0-9][a-z0-9][a-z0-9]-[0-9][0-9]',
"wlan_ap": '^nap-.*-[0-9][0-9]',
"server_test": '^srv-t.*-[0-9][0-9]',
"server_prod": '^srv-p.*-[0-9][0-9]',
"ilo_boards": '^(ibmc|idrac)-(srv|srp)-.*-[0-9][0-9]'
}

# inventory_group_vars={
# "switch": { "myvar1": "myval1" },
# "firewall": { "myvar2": "myval2" },
# }
inventory_group_vars={}

inventory = { "_meta": {"hostvars": {} }}

def dns_zone_xfer(address):
  results = []
  try:
    zone = dns.zone.from_xfr(dns.query.xfr(ns_server_ip, address))
    for host in zone:
      try:
        # ignore all cname results, A-rec query is buggy
        dns.resolver.query(str(host), 'CNAME')
      except:
        results.append(str(host).lower())
  except Exception as e:
    print("ERROR: NS {} refused zone transfer!".format(ns_server_ip))
  return(results)

zone_records = dns_zone_xfer(ns_zone)

for inventory_group in inventory_pattern:
  # print(inventory_group, '->', inventory_pattern[inventory_group])
  regex = re.compile(inventory_pattern[inventory_group])
  hosts = list(filter(regex.match, zone_records))
  if inventory_group in inventory_group_vars:
    json_add = {inventory_group: {"hosts": hosts, "vars": inventory_group_vars[inventory_group] } }
  else:
    json_add = {inventory_group: {"hosts": hosts, "vars": {} } }
  inventory.update(json_add)

print(json.dumps(inventory))

