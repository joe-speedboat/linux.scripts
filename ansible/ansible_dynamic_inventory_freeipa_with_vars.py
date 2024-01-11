#!/usr/bin/env python3.8
# This script uses the FreeIPA API to create an Ansible dynamic directory
# This is a shell script version of freeipa-api-inv.py
#
# DEPENDENCIES: before this script will work with AWX or Tower
# the python_freeipa module has to be installed
#
# Add this to your Docker image
# RUN pip install python_freeipa
#
# Set the following variables:
# freeipaserver : the FQDN of the FreeIPA/RHIdM server
# freeipauser : an unprivileged user account for connecting to the API
# freeipapassword : password for freeipauser

# description field of hosts and host_groups can be used to inject variables into ansible inventory, eg:
# vars: { "var1": "val1", "list1": [ "item1", "item2" ], "dict1": { "key1": "val1", "key2": "val2" } }
from python_freeipa import Client
from argparse import ArgumentParser
import json
import urllib3
import re
from os import environ as env
from sys import exit
import fcntl
import time
import contextlib
from concurrent.futures import ThreadPoolExecutor

import os
import time

read_vars_from_desc = False
cache_timeout = 3600
cache_file = os.path.join(os.path.expanduser("~"), ".ansible_freeipa_inventory_cache")
lock_file = os.path.join(os.path.expanduser("~"), ".ansible_freeipa_inventory.lock")
do_debug = False

# We don't need warnings
urllib3.disable_warnings()

def get_args():
    if do_debug:
        print(f"{time.time()}: Starting get_args()")
    parser = ArgumentParser(description="AWX FreeIPA API dynamic host inventory")
    parser.add_argument(
        '--list',
        default=False,
        dest="list",
        action="store_true",
        help="Produce a JSON consumable grouping of servers for Ansible"
    )
    parser.add_argument(
        '--host',
        default=None,
        dest="host",
        help="Generate additional host specific details for given host for Ansible"
    )
    parser.add_argument(
        '-u',
        '--user',
        default=None,
        dest="user",
        help="username to log into FreeIPA API"
    )
    parser.add_argument(
        '-w',
        '--password',
        default=None,
        dest="password",
        help="password to log into FreeIPA API"
    )
    parser.add_argument(
        '-s',
        '--server',
        default=None,
        dest="server",
        help="hostname of FreeIPA server"
    )
    parser.add_argument(
        '--ipa-version',
        default='2.228',
        dest="ipaversion",
        help="version of FreeIPA server"
    )
    return parser.parse_args()

# Function to create a client instance and authenticate with FreeIPA API
def get_client(server, user, password, ipaversion):
    if do_debug:
        print(f"{time.time()}: Starting get_client()")
    client = Client(
        server,
        version=ipaversion,
        verify_ssl=False
    )
    client.login(
        user,
        password
    )
    if do_debug:
        print(f"{time.time()}: Logged in to FreeIPA server")
    return client

# Function to extract variables from the description field
def extract_vars(description):
    if do_debug:
        print(f"{time.time()}: Starting extract_vars()")
    if read_vars_from_desc:
        vars_match = re.search(r'vars:\s*({.*})', description)
        if vars_match:
            return json.loads(vars_match.group(1))
    return {}

# Function to get host-specific variables
def get_host_vars(client, host):
    if do_debug:
        print(f"{time.time()}: Starting get_host_vars()")
    result = client._request(
        'host_show',
        host,
        {'all': True, 'raw': False}
    )['result']
    if 'usercertificate' in result:
        del result['usercertificate']
    if read_vars_from_desc:
        if 'description' in result:
            description = result['description'][0]
            return extract_vars(description)
    return {}

# Function to get hostgroup variables
def get_hostgroup_vars(client, hostgroup):
    if do_debug:
        print(f"{time.time()}: Starting get_hostgroup_vars()")
    result = client._request(
        'hostgroup_show',
        hostgroup,
        {'all': True, 'raw': False}
    )['result']
    group_vars = {}
    if read_vars_from_desc:
        if 'description' in result:
            description = result['description'][0]
            group_vars.update(extract_vars(description))
            if 'member_hostgroup' in result:
                print(f"{time.time()}: Starting to iterate over child hostgroups in get_hostgroup_vars()")
                for child_hostgroup in result['member_hostgroup']:
                    print(f"{time.time()}: Processing child hostgroup {child_hostgroup}")
                    child_vars = get_hostgroup_vars(client, child_hostgroup)
                    group_vars.update(child_vars)
    return group_vars

# Function to get inventory
def get_cache():
    if do_debug:
        print(f"{time.time()}: Starting get_cache()")
    if os.path.exists(cache_file):
        if time.time() - os.path.getmtime(cache_file) < cache_timeout:
            with open(cache_file, 'r') as f:
                return f.read()
    return None

def update_cache(data):
    if do_debug:
        print(f"{time.time()}: Starting update_cache()")
    with open(cache_file, 'w') as f:
        f.write(data)

def get_inventory(client):
    if do_debug:
        print(f"{time.time()}: Starting get_inventory()")
    result = client._request(
        'hostgroup_find',
        '',
        {'all': True, 'raw': False}
    )['result']

    all_hosts = set(host['fqdn'][0] for host in client._request('host_find', '', {'all': False, 'raw': False})['result'])

    inventory = {}
    def process_hostgroup(hostgroup):
        if do_debug:
            print(f"{time.time()}: Processing hostgroup {hostgroup['cn'][0]}")
        hosts = hostgroup.get('member_host', [])
        inventory[hostgroup['cn'][0]] = {
            'hosts': hosts,
            'children': hostgroup.get('member_hostgroup', []),
            'vars': get_hostgroup_vars(client, hostgroup['cn'][0]) if read_vars_from_desc else {}
        }
        all_hosts -= set(hosts)

    if do_debug:
        print(f"{time.time()}: Starting to iterate over hostgroups in get_inventory()")
    with ThreadPoolExecutor() as executor:
        executor.map(process_hostgroup, result)



    hostvars = {}
    for hostgroup in result:
        group_vars = get_hostgroup_vars(client, hostgroup['cn'][0])

        if do_debug:
            print(f"{time.time()}: Starting to iterate over hosts in get_host_vars()")
        for host in hostgroup.get('member_host', []):
            if do_debug:
                print(f"{time.time()}: Processing host {host}")
            if host not in hostvars:
                hostvars[host] = {}
            if read_vars_from_desc:
                host_vars = get_host_vars(client, host)
                # Merge host vars with group vars, giving precedence to host vars
                merged_vars = group_vars.copy()
                merged_vars.update(host_vars)
                hostvars[host].update(merged_vars)

    inventory['_meta'] = {'hostvars': hostvars}
    if do_debug:
        print(f"{time.time()}: Finished building inventory")
    return json.dumps(inventory, indent=1, sort_keys=True)



# Main function
@contextlib.contextmanager
def LockFile(file_path):
    lock_file = open(file_path, "w")
    try:
        for i in range(60):
            try:
                fcntl.lockf(lock_file, fcntl.LOCK_EX | fcntl.LOCK_NB)
                break
            except IOError:
                if i == 59:  # If this was the last attempt
                    exit("Another instance of the script is already running. Exiting.")
                time.sleep(1)
        yield
    finally:
        fcntl.lockf(lock_file, fcntl.LOCK_UN)

def main():
    if do_debug:
        print(f"{time.time()}: Starting main()")
    with LockFile(lock_file):
        args = get_args()

    freeipaserver = None
    freeipauser = None
    freeipapassword = None

    if 'freeipaserver' in env:
        freeipaserver = env['freeipaserver']

    if 'freeipauser' in env:
        freeipauser = env['freeipauser']

    if 'freeipapassword' in env:
        freeipapassword = env['freeipapassword']

    if args.server:
        freeipaserver = args.server

    if args.user:
        freeipauser = args.user

    if args.password:
        freeipapassword = args.password

    if not freeipaserver:
        exit("HALT: No FreeIPA server set")

    if not freeipauser:
        exit("HALT: No FreeIPA user set")

    if not freeipapassword:
        exit("HALT: No FreeIPA password set")

    client = get_client(freeipaserver, freeipauser, freeipapassword, args.ipaversion)

    cache = get_cache()
    if cache:
        print(cache)
    else:
        if args.host:
            if read_vars_from_desc:
                result_vars = get_host_vars(client, args.host)
                result = json.dumps(result_vars, indent=1)
            else:
                result = {}
        elif args.list:
            result = get_inventory(client)
        else:
            # For debugging
            result = f"{freeipauser}:{freeipapassword}@{freeipaserver}"
        if do_debug:
            print(f"{time.time()}: Updating cache")
        update_cache(result)
        print(result)
        if do_debug:
            print(f"{time.time()}: Finished printing result")


if __name__ == '__main__':
    main()

