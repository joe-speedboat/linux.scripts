#!/usr/bin/python3.6
# Backup AD Group Membership in direct (unested) relation

# Copyright (c) Chris Ruettimann <chris@bitbull.ch>
# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

import sys
import ldap

encoding = 'utf-8'
AD_SERVERS = [ '1.1.1.1', '2.2.2.2']
AD_USER_BASEDN = "dc=domain,dc=local"
AD_GROUP_BASEDN = "dc=domain,dc=local"
AD_USER_FILTER = '(&(objectClass=USER)(sAMAccountName={username}))'
AD_GROUP_FILTER = '(&(objectClass=GROUP)(cn={group_name}))'
AD_BIND_USER = 'bind@domain.local'
AD_BIND_PWD = 'secret!'
DL_DN="dc=domain,dc=local"



# ldap connection -----------------------------------------
def ad_auth(username=AD_BIND_USER, password=AD_BIND_PWD, address=AD_SERVERS[0]):
  conn = ldap.initialize('ldap://' + address)
  conn.protocol_version = 3
  conn.set_option(ldap.OPT_REFERRALS, 0)

  result = True

  try:
    conn.simple_bind_s(username, password)
    #print "Succesfully authenticated"
  except ldap.INVALID_CREDENTIALS:
    return "Invalid credentials", False
  except ldap.SERVER_DOWN:
    return "Server down", False
  except ldap.LDAPError as e:
    if type(e.message) == dict and 'desc' in e.message:
      return "Other LDAP error: " + e.message['desc'], False
    else:
      return "Other LDAP error: " + e, False
  return conn, result

# get stuff by name -----------------------------------------
def get_dn_by_username(username, ad_conn, basedn=AD_USER_BASEDN):
  return_dn = ''
  ad_filter = AD_USER_FILTER.replace('{username}', username)
  results = ad_conn.search_s(basedn, ldap.SCOPE_SUBTREE, ad_filter)
  if results:
    for dn, others in results:
      return_dn = dn
      return(return_dn)

def get_dn_by_groupname(group_name, basedn=AD_GROUP_BASEDN):
  return_dn = ''
  ad_filter = AD_GROUP_FILTER.replace('{group_name}', group_name)
  results = ad_conn.search_s(basedn, ldap.SCOPE_SUBTREE, ad_filter)
  if results:
    for dn, others in results:
      if dn:
        return_dn = dn
      return return_dn

# get stuff by dn -----------------------------------------

def get_group_by_dn(dn, ad_conn):
  group = ''
  result = ad_conn.search_s(dn, ldap.SCOPE_BASE,'(&(objectClass=group)(objectCategory=group)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))')
  if result:
    for dn, attrb in result:
      if 'name' in attrb and attrb['name']:
        group = attrb['name'][0]
        break
  return group

def get_groups_by_dn(dn, ad_conn):
  groups = []
  result = ad_conn.search_s(dn, ldap.SCOPE_SUBTREE,'(&(objectClass=group)(objectCategory=group)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))')
  if result:
    for dn, attrb in result:
      if 'name' in attrb and attrb['name']:
        groups.append((attrb['name'][0]).decode(encoding))
  return groups

# get group members (nested) ------------------------------
def get_group_members(group_name, ad_conn, basedn=AD_USER_BASEDN):
  members = []
  ad_filter = AD_GROUP_FILTER.replace('{group_name}', group_name)
  result = ad_conn.search_s(basedn, ldap.SCOPE_SUBTREE, ad_filter)
  if result:
    if len(result[0]) >= 2 and 'member' in result[0][1]:
      members_tmp = result[0][1]['member']
      for m in members_tmp:
                                group = get_group_by_dn(m, ad_conn)
                                if group:
                                        group_members = get_group_members(group, ad_conn)
                                        members = members + group_members
                                else:
                                        members.append(m.decode(encoding))
  return members

# get group members (direct) ------------------------------
def get_group_members_direct(group_name, ad_conn, basedn=AD_USER_BASEDN):
        members = []
        ad_filter = AD_GROUP_FILTER.replace('{group_name}', group_name)
        result = ad_conn.search_s(basedn, ldap.SCOPE_SUBTREE, ad_filter)
        if result:
          if len(result[0]) >= 2 and 'member' in result[0][1]:
            members_tmp = result[0][1]['member']
            for m in members_tmp:
              members.append(m.decode(encoding))
            return members




if __name__ == "__main__":
  ad_conn, result = ad_auth()
  groups = get_groups_by_dn(DL_DN, ad_conn)
  for group_name in groups:
      print(get_dn_by_groupname(group_name))
      group_members = get_group_members_direct(group_name, ad_conn)
      if group_members:
          for group_member in group_members:
              print("          " + group_member)

