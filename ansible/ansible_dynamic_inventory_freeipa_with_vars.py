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
import argparse
import json
import urllib3
import re
from os import environ as env
from sys import exit

# We don't need warnings
urllib3.disable_warnings()

def get_args():
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

def get_client(server, user, password):
    client = Client(
        server,
        version='2.228',
        verify_ssl=False
    )
    client.login(
        user,
        password
    )
    return client

def extract_vars(description):
    vars_match = re.search(r'vars:\s*({.*})', description)
    if vars_match:
        return json.loads(vars_match.group(1))
    return {}

def get_host_vars(client, host):
    result = client._request(
        'host_show',
        host,
        {'all': True, 'raw': False}
    )['result']
    if 'usercertificate' in result:
        del result['usercertificate']
    if 'description' in result:
        description = result['description'][0]
        return extract_vars(description)
    return {}

def get_group_members(hostgroup):
    members = []
    if 'member_host' in hostgroup:
        members = [host for host in hostgroup['member_host']]
    return members

def get_group_children(hostgroup):
    children = []
    if 'member_hostgroup' in hostgroup:
        children = hostgroup['member_hostgroup']
    return children

def get_group_vars(description):
    vars_match = re.search(r'vars:\s*({.*})', description)
    if vars_match:
        return json.loads(vars_match.group(1))
    return {}

def get_hostgroup_vars(client, hostgroup):
    result = client._request(
        'hostgroup_show',
        hostgroup,
        {'all': True, 'raw': False}
    )['result']
    group_vars = {}
    if 'description' in result:
        description = result['description'][0]
        group_vars.update(get_group_vars(description))
        if 'member_hostgroup' in result:
            for child_hostgroup in result['member_hostgroup']:
                child_vars = get_hostgroup_vars(client, child_hostgroup)
                group_vars.update(child_vars)
    return group_vars

def get_inventory(client):
    inventory = {}
    hostvars = {}
    result = client._request(
        'hostgroup_find',
        '',
        {'all': True, 'raw': False}
    )['result']
    for hostgroup in result:
        group_vars = get_hostgroup_vars(client, hostgroup['cn'][0])
        inventory[hostgroup['cn'][0]] = {
            'hosts': get_group_members(hostgroup),
            'children': get_group_children(hostgroup),
            'vars': group_vars
        }
        # Merge group vars with parent group vars, giving precedence to group vars
        parent = hostgroup.get('ipahostgroupmemberof', [])
        while parent:
            parent_group = parent.pop(0).split('=', 1)[1]
            if parent_group in inventory:
                parent_vars = inventory[parent_group].get('vars', {})
                parent = parent + inventory[parent_group].get('ipahostgroupmemberof', [])
                parent_vars.update(group_vars)
                group_vars = parent_vars
        for host in inventory[hostgroup['cn'][0]]['hosts']:
            if host not in hostvars:
                hostvars[host] = {}
            host_vars = get_host_vars(client, host)
            # Merge host vars with group vars, giving precedence to host vars
            merged_vars = group_vars.copy()
            merged_vars.update(host_vars)
            hostvars[host].update(merged_vars)

    inventory['_meta'] = {'hostvars': hostvars}
    return json.dumps(inventory, indent=1, sort_keys=True)



def main():
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

    client = get_client(freeipaserver, freeipauser, freeipapassword)

    if args.host:
        result_vars = get_host_vars(client, args.host)
        print(json.dumps(result_vars, indent=1))
    elif args.list:
        inv_string = get_inventory(client)
        print(inv_string)
    else:
        # For debugging
        print("%s:%s@%s" %
              (freeipauser, freeipapassword, freeipaserver))

if __name__ == '__main__':
    main()

