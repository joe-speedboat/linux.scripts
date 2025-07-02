#!/bin/bash
# DATE: 2025.06.04
# Rundeck Version: 5.11.1.20250415
# Rundeck CLI Version: 2.0.8
# OS Tested: Rocky Linux 9.5

# DESC: Enable SCM plugin if disabled for all projects
# WORKAROUND FOR BUG: https://github.com/rundeck/rundeck/issues/8119

### AUTH CONFIG IN BASHRC: $HOME/.bashrc
#   https://docs.rundeck.com/docs/rd-cli/configuration.html
#   create user md5 password hash: echo -n super_secret_password | md5sum | cut -d' '  -f1
#   local user is stored in: /etc/rundeck/realm.propertiesgrep 'Grails application running at' /var/log/rundeck/service.log
#   
#export RD_URL="http://localhost:4440"
#export RD_USER=admin
#export RD_PASSWORD=super_secret_password

PROJECT_EXCLUDE='project_with_no_scm|other_excluded_project'

rd projects list >/dev/null 2>&1
if [ $? -ne 0 ]
then
  echo "ERROR: rd comand not working, try "rd projects list" as rundeck user on cli and fix"
  exit 1
fi

rd projects list | egrep -v '^#|^$' | egrep -v "$PROJECT_EXCLUDE" | while read project
do
  echo "DEBUG: Testing SCM Status for Project $project"
   rd projects scm status --project="$project" --integration=export >/dev/null 2>&1
   SCM_STATUS_RC=$?
   echo "   SCM_STATUS_RC=$SCM_STATUS_RC"
   if [ $SCM_STATUS_RC -eq 2 ]
   then
     echo "WARNING: Enabling SCM for project $project"
     logger -t rundeck-cli "WARNING: Enabling SCM for project $project"
     rd projects scm enable --type git-export --project="$project" -i export
   else
     echo "INFO: SCM is already enabled for project $project, nothing to do"
   fi
done
