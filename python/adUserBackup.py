#!/usr/bin/python3.6
# Backup AD Users into a YAML file

# Copyright (c) Chris Ruettimann <chris@bitbull.ch>
# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt


import yaml
import sys
from ldap3 import Server, Connection, ALL, SUBTREE, SAFE_SYNC
from getpass import getpass

AD_SERVER = 'domain.local'
AD_BIND_USER = 'bind@domain.local'
AD_BIND_PASSWORD = 'my.bind.pw'
AD_SEARCH_BASE = 'dc=domain,dc=local'
AD_USER_BACKUP_FILE = '/etc/git/backup.ad_backup/domain_user.yml'
# AD_USER_ATTRIBUTES = '*'
AD_USER_ATTRIBUTES = ['accountExpires', 'cn', 'department', 'displayName', 'distinguishedName', 'givenName', 'mail', 'memberOf', 'mobile', 'name', 'sAMAccountName', 'sn', 'telephoneNumber', 'title', 'userPrincipalName', 'whenCreated']

def get_ldaps_connection(AD_SERVER, AD_BIND_USER, AD_BIND_PASSWORD):
    server = Server(AD_SERVER, use_ssl=True, get_info=ALL)
    connection = Connection(server, user=AD_BIND_USER, password=AD_BIND_PASSWORD, client_strategy=SAFE_SYNC, auto_bind=True)
    return connection

def get_all_users(connection):
    result = connection.search(search_base=AD_SEARCH_BASE, search_filter='(objectclass=person)', search_scope=SUBTREE, attributes=AD_USER_ATTRIBUTES)
    # print('Search result:', result)
    entries = {}
    for item in result:
        if isinstance(item, list):
            for i in item:
                if i['type'] == 'searchResEntry':
                    # Use userPrincipalName as the key, and the rest of the attributes as the value
                    userPrincipalName = i['attributes'].get('userPrincipalName')
                    if userPrincipalName:
                        entries[userPrincipalName] = dict(i['attributes'])
    # print('Entries:', entries)
    return entries

def write_to_yaml(data, AD_USER_BACKUP_FILE):
    with open(AD_USER_BACKUP_FILE, 'w') as outfile:
        yaml.dump(data, outfile, default_flow_style=False)

def main():
    try:
        print('Connecting to LDAPS server...')
        connection = get_ldaps_connection(AD_SERVER, AD_BIND_USER, AD_BIND_PASSWORD)
        print('Connected to LDAPS server')
        
        print('Fetching users...')
        entries = get_all_users(connection)
        print(f'Fetched {len(entries)} users')
        
        print('Writing users to ' + AD_USER_BACKUP_FILE)
        write_to_yaml(entries, AD_USER_BACKUP_FILE)
        print('Done')
    except Exception as e:
        print(f'Error: {e}', file=sys.stderr)

if __name__ == "__main__":
    main()
