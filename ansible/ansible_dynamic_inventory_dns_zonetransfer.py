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
import os
from datetime import datetime, timedelta
cache_file = os.path.join(os.path.expanduser("~"), ".ansible_inventory_cache")
config_file = "/etc/ansible/ansible_dynamic_inventory_dns_zonetransfer.conf"

###### THIS MAY GO TO CONFIG FILE ###############################
# how long to keep the cache file
cache_timeout=3600
ns_server_ip='127.0.0.1'
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

#inventory_group_vars={
#"access_switch": { "ansible_network_os": "community.network.ce", "ansible_become": False, "ansible_connection": "ansible.netcommon.network_cli", "ansible_network_cli_ssh_type": "paramiko" },
#"pop_router": { "ansible_network_os": "community.network.ce", "ansible_become": False, "ansible_connection": "ansible.netcommon.network_cli", "ansible_network_cli_ssh_type": "paramiko" }
#}
#####################################################################
# source config file if ther is any
try:
    with open(config_file) as f:
        exec(f.read(), locals(), globals())
except FileNotFoundError:
    pass

def generate_inventory_data():
  inventory_group_vars={}
  inventory = { "_meta": {"hostvars": {} }}

  def dns_zone_xfer(address):
    results = []
    try:
      zone = dns.zone.from_xfr(dns.query.xfr(ns_server_ip, address))
      for host in zone:
        try:
          # ignore all cname results, A-rec query is buggy
          dns.resolver.resolve(str(host), 'CNAME')
          # print('-')
        except:
          results.append(str(host).lower())
          #print('+')
    except Exception as e:
      print("ERROR: NS {} refused zone transfer!".format(ns_server_ip))
      exit(1)
    return(results)

  zone_records = dns_zone_xfer(ns_zone)

  for inventory_group in inventory_pattern:
    regex = re.compile(inventory_pattern[inventory_group])
    hosts = list(filter(regex.match, zone_records))
    if inventory_group in inventory_group_vars:
      json_add = {inventory_group: {"hosts": hosts, "vars": inventory_group_vars[inventory_group] } }
    else:
      json_add = {inventory_group: {"hosts": hosts, "vars": {} } }
    inventory.update(json_add)
  return inventory


def cache_is_valid(cache_file, cache_timeout):
    if not os.path.isfile(cache_file):
        return False
    mtime = os.path.getmtime(cache_file)
    current_time = datetime.now().timestamp()
    if (current_time - mtime) > cache_timeout:
        return False
    return True

if cache_is_valid(cache_file, cache_timeout):
    try:
        with open(cache_file, "r") as f:
            try:
                inventory_data = json.loads(f.read())
            except json.decoder.JSONDecodeError:
                inventory_data = generate_inventory_data()
                with open(cache_file, "w") as f:
                    f.write(json.dumps(inventory_data))
    except FileNotFoundError:
        inventory_data = generate_inventory_data()
        with open(cache_file, "w") as f:
            f.write(json.dumps(inventory_data))
else:
    inventory_data = generate_inventory_data()
    with open(cache_file, "w") as f:
        f.write(json.dumps(inventory_data))


print(json.dumps(inventory_data))
