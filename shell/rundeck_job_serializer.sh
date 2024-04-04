#!/bin/bash

# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

#########################################################################################
# This script is used to serialize Rundeck jobs on a single node setup.
# It takes one argument: start, stop, help, --help, or -h.
# The start argument begins the job serialization, the stop argument ends it,
# and the help arguments display a help message.
#########################################################################################
### SETUP INSTRUCTIONS ###
# copy to /usr/local/bin/rundeck_job_serializer.sh on rundeck server
# chmod u=rw,g=rx,o-rwx /usr/local/bin/rundeck_job_serializer.sh
# chown root.rundeck /usr/local/bin/rundeck_job_serializer.sh
# add to beginnging of your rundeck job:
#   Local Command, Run a command locally on the server 
#     /usr/local/bin/rundeck_job_serializer.sh start
# then do all the main jobs as needed
#   here add error handler: Local Command, /usr/local/bin/rundeck_job_serializer.sh stop
# add to end of your rundeck job:
#   Local Command, Run a command locally on the server
#     /usr/local/bin/rundeck_job_serializer.sh stop
# Tab:Other
#   Multiple Executions: True
#   Limit Multiple Executions: 3 (up to you)
#   Note: if job is running about 10min, job_max_wait with 1h is save, 50% space
#########################################################################################

# args
# arg1: The command to execute. Can be start, stop, help, --help, or -h.
arg1=$1

# log function
# Logs a message with a given priority. If the priority is "error", the script exits.
# priority: The priority of the message. Can be any string, but "error" has special behavior.
# message: The message to log.
function log() {
    priority="$1"
    shift
    message="$@"
    echo "$(date +%Y.%m.%d_%H:%S) [$job_exec_id]:$priority $message"
    logger "[$job_exec_id]:$priority $message"
    if [ "$priority" == "error" ]; then
        exit 1
    fi
}

# help function
function display_help() {
    log "Usage: $0 {start|stop|help|--help|-h}"
    log
    log "start   - Start the job serialization"
    log "stop    - Stop the job serialization"
    log "help    - Display this help message"
    log "--help  - Display this help message"
    log "-h      - Display this help message"
    log
    exit 1
}

# arg handler
case "$arg1" in
    start) ;;
    stop) ;;
    help|--help|-h) display_help ;;
    *) log "error" "Invalid argument: $arg1"; display_help ;;
esac

# vars
job_name_id="${RD_JOB_NAME}_${RD_JOB_ID}"
job_exec_id="$RD_JOB_EXECID"
job_start_epoch=$(date +%s)
TMPF="/tmp/$job_name_id"
job_max_wait=3600
job_loop_wait=15

# logic for arg1 start
if [ "$arg1" == "start" ]; then
  if [ -f "$TMPF" ]; then
    if [ ! -w "$TMPF" ]; then
      log "error" "File $TMPF is not writable"
    fi
    log "info" "File $TMPF found, entering wait loop with job_start_epoch $job_start_epoch, job_max_wait $job_max_wait, job_loop_wait $job_loop_wait"
    while [ $(($(date +%s) - $job_start_epoch)) -lt $job_max_wait ] && [ -f "$TMPF" ]; do
      log "info" "Waiting for $job_loop_wait seconds"
      sleep $job_loop_wait
    done
    if [ ! -f "$TMPF" ]; then
      log "info" "File $TMPF not found, ending wait loop"
    fi
    if [ -f "$TMPF" ]; then
      log "info" "Wait time exceeded, removing file $TMPF"
      rm $TMPF
    else
      log "info" "File $TMPF not found, creating it with current timestamp"
      echo $(date +%s) > $TMPF
    fi
  else
    log "info" "File $TMPF not found, creating it with start epoch $job_start_epoch"
    echo $job_start_epoch > $TMPF
  fi
fi

# logic for arg1 stop
if [ "$arg1" == "stop" ]; then
  log "info" "Removing file $TMPF"
  rm -f $TMPF
fi

# general
log "info" "Job $job_name_id $arg1 at $(date)"

