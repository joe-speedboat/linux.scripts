#!/bin/python
# DESC: bulk export/import helper for cleaning up VMs in vRealize Automation 6.x + 7.x (tested in vRA 7.1)
# $Author: chris $
# $Revision: 1.4 $
# $RCSfile: vra7-bulk-export-import-cleaner.py,v $

# Copyright (c) Chris Ruettimann <chris@bitbull.ch>
# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

# Why:
# When upgrading vRA6 to vRA7, all bulk imported VMs can not get decomissioned, because of broken blueprints
# We assume, this is why we (probably all of us) missed to register VMware.VirtualCenter.OperatingSystem as a custom property in vRA6
# So in many cases, it is needed to migrate/cleanup vCenter VMs in vRA
# To make this more handy and get around the bugs I mentioned below, I started writing this script.

# Usage:
#   1) bulk export all managed VMs with custom properties from within vRA
#   2) unregister VMs you want to clean up from vRA with cloud client: vra machines forceunregister --name <VM-NAME>
#   3) wait 10 minutes, check vRA logs
#   4) run datacollection > inventory from within vRA
#   5) bulk export unmanaged VMs from within vRA
#   6) place both csv files in same directory as this script
#   7) adjust this to vars to match the files: bulkExportUnManaged, bulkExportManaged
#   8) chmod 700 bulk-import-cleaner.py ; ./bulk-import-cleaner.py > new-bulk-import.csv
#   9) run bulk import with the new csv file (test with few VMs first)
#
#   NOTE:
#   To match the right blueprint, component, vm.os, you must modify:
#       - the dictionary: vmTypeDic
#       - the code to match your needs
#           I use all vm-names starting with w are windows
#           Everything else is linux
#
#   IMPORTANT we have 2 bugs with EHC 4.1.1:
#       - there is a bug in bulk export/import that exports some props with + for space, but does not translate + into space when importing
#           I observed that at least in: 
#               VirtualMachine.DiskN.StorageReservationPolicy   -> after export/import, spaces are replaced by +
#               VirtualMachine.Imported.Notes                   -> after export/import, spaces are replaced by +, special chars are replaced by ascii chars eg: %40 ...
#       - with EHC 4.1.1 export/import as described in vRA documentation does result in broken vcacVMs, this VMs are not able to add cpu, storage, ... by reconfiguration from within vRA
#               this is does not work: https://docs.vmware.com/en/vRealize-Automation/7.1/com.vmware.vrealize.automation.doc/GUID-67219495-49B7-45A8-9D1E-C6837E6FFC03.html
#               eg: - Customer increased disk in vRA
#                   - Configurations get applied successfully in vCenter
#                   - in VRA, VM get stuck in state reconfigure failed, waiting to retry
#                   - vRA error msg: ...An item with the same key has already been added...
#         All the affected VMs got bulk exported/imported with all the properties, now this VMs are broken
#         First test: bulk export 1 vm, unregister, bulk import with minimal settings --> vm can now reconfigure its HW !!!!
#
#         THIS SCRIPT IS WRITTEN TO GET AROUND THE PROBLEMS I MENTIONED ABOVE


import re
import uuid
import urllib2


bulkExportUnManaged='unmanaged.csv'
bulkExportManaged='Bulk Export 9302017 15222 PM UTC+0200.csv'
doDebug = False


# https://docs.vmware.com/en/vRealize-Automation/7.1/rn/vrealize-automation-71-release-notes.html
# you have to match this values somewhere, see example below in prog
vmTypeDic = { # CompositeBlueprintName / CompositeBlueprintComponentName / VMware.VirtualCenter.OperatingSystem
        'w2012':['Windows2012R2Migrated','Machine','windows8Server64Guest'],
        'rhel6':['RHEL6Migrated','Machine','rhel6_64Guest'],
        'linux':['LinuxMigrated','Machine','otherGuest64']
        }
vmPropKeep = [ # keep this properties as they are
        'EHCExternalWFStubs.BuildingMachine',
        'EHCExternalWFStubs.DisposingMachine.DP',
        'epc.backup.servicelevels',
        'VirtualMachine.Network0.Address',
        ]
vmPropCleanup = [ # cleanup ascii chars and + in this fields, then add them
        'VirtualMachine.Disk0.StorageReservationPolicy',
        'machine.user.EmailAddress'
        ]
vmPropAdd = [ # add this properties to every bulk import vm
        ',Extensibility.Lifecycle.Properties.VMPSMasterWorkflow32.BuildingMachine,*,NOP',
        ',Extensibility.Lifecycle.Properties.VMSMasterWorkflow32.BuildingMachine,__*.*,NOP',
        ',Extensibility.Lifecycle.Properties.VMSMasterWorkflow32.MachineProvisioned,__*.*,NOP',
        ',Extensibility.Lifecycle.Properties.VMSMasterWorkflow32.UnprovisionMachine,__*.*,NOP',
        ]


# ---------- MAIN PROGRAM ----------
f = open(bulkExportManaged, "r")
lines = f.read().split("\n") # "\r\n" if needed
for line in lines:
    line = line.rstrip(',\n\r') # remove that characters from end of csv line
    if line.startswith("Yes") or line.startswith("No"): # we are only interested in this lines
        bulkVmBase = ''
        cols = line.split(",")
        vmDoImport              = cols.pop(0) # pull out the mandatory properties
        vmName                  = cols.pop(0)
        vmId                    = cols.pop(0)
        vmRes                   = cols.pop(0)
        vmDs                    = cols.pop(0)
        vmDeploymentName        = cols.pop(0)
        vmBlueprint             = cols.pop(0)
        vmBlueprintComponent    = cols.pop(0)
        vmOwner                 = cols.pop(0)
        if len(cols) % 3 != 0:  # check if properties are divisible by 3, use modula for that
            raise "ERROR: ",vmName," has bad formated properties, need tripple sets"
        if vmName.lower().startswith("w"): # customize: all windows vms start with w
            vmType = 'w2012'
            vmBlueprint = vmTypeDic[vmType][0]
            vmBlueprintComponent = vmTypeDic[vmType][1]
            vmwVcOs = vmTypeDic[vmType][2]
        else:                              # everything else uses linux blueprint
            vmType = 'rhel6'
            vmBlueprint = vmTypeDic[vmType][0]
            vmBlueprintComponent = vmTypeDic[vmType][1]
            vmwVcOs = vmTypeDic[vmType][2]
        bulkVmOpt = ',VMware.VirtualCenter.OperatingSystem,'+vmwVcOs+',NOP'
        if doDebug:
            print "   ---"
            print "   defined VMware.VirtualCenter.OperatingSystem: ",vmwVcOs
            print "   changed vmBlueprint: ",vmBlueprint
            print "   changed vmBlueprintComponent: ",vmBlueprintComponent
        vmDeploymentName = vmName +"-"+ str(uuid.uuid4()).split("-")[0]
        if doDebug:
            print "   changed vmDeploymentName: ",vmDeploymentName
        while len(cols) > 3:
            vmPropName = cols.pop(0)
            vmPropVal  = cols.pop(0)
            vmPropAtt  = cols.pop(0)
            if doDebug:
                print "   vmPropName: ",vmPropName," / vmPropVal: ",vmPropVal," / vmPropAtt: ",vmPropAtt
            if vmPropName in vmPropCleanup:
                vmPropVal = urllib2.unquote(vmPropVal)  # cleanup the acii chars
                vmPropVal = vmPropVal.replace('+', ' ') # this is a vmware thing, ugly
                vmPropVal = vmPropVal.replace(',', ' ') # avoid that within csv, it would break it
                bulkVmOpt = bulkVmOpt+','+vmPropName+','+vmPropVal+','+vmPropAtt
            if vmPropName in vmPropKeep:
                bulkVmOpt = bulkVmOpt+','+vmPropName+','+vmPropVal+','+vmPropAtt
        for vmProp in vmPropAdd:   # add the mandatory fileds to all the bulk imports
            bulkVmOpt = bulkVmOpt+vmProp

        unManaged = file(bulkExportUnManaged)
        for line in unManaged:
            if 'Yes,'+vmName+',' in line:
                vmId = line.split(",")[2]
                vmDoImport = 'Yes'
                if doDebug:
                    print "   changed vmId: ",vmId
                break
            else:
                vmDoImport = 'No'
        if doDebug:
            print "   changed vmDoImport: ",vmDoImport

        bulkVmBase = vmDoImport+','+vmName+','+vmId+','+vmRes+','+vmDs+','+vmDeploymentName+','+vmBlueprint+','+vmBlueprintComponent+','+vmOwner
        if doDebug:
            print "   bulkVmBase: ",bulkVmBase
            print "   bulkVmOpt: ",bulkVmOpt
        print bulkVmBase+bulkVmOpt


# Import--Yes or No, Virtual Machine Name, Virtual Machine ID, Host Reservation (Name or ID), Host To Storage (Name or ID), Deployment Name, Blueprint ID, Component Blueprint ID, Owner Name[, Property Name, Property Value, (H|N)(E|O)(R|P)]* Where (H|N) - Hidden/Not Hidden; (E|O) - Encrypted/Not Encrypted; (R|P)

################################################################################
# $Log: vra7-bulk-export-import-cleaner.py,v $
# Revision 1.4  2017/10/10 12:03:45  chris
# added VirtualMachine.Network0.Address to the imported fields, since one NIC is always present
#
# Revision 1.3  2017/10/09 17:19:42  chris
# explanation, why this script is needed for bulk import cleanups
#
# Revision 1.2  2017/10/08 08:50:39  chris
# typo, had 2 , after mandatory fields
#
# Revision 1.1  2017/10/08 08:36:09  chris
# Initial revision
#

