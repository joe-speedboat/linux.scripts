#!/bin/bash

# update-resources.sh
# -------------------
# This script provides a summary and update utility for Kubernetes Deployments and StatefulSets.
# - If the user enters "U", it will rollout restart all Deployments and StatefulSets (except those in kube-system).
# - Otherwise, it prints a summary of all Deployments and StatefulSets, and a status table of all pods
#   that are running or in CrashLoopBackOff, including their image pull policy.

set -e  # Exit immediately if a command exits with a non-zero status.

# Prompt user for update action
echo "Print \"U\" if you want to update all deployments and statefulsets:"
read -p "input: " input

if [ "$input" == "U" ]; then
  echo "UPDATE ALL RESOURCES, EXCEPT kube-system NAMESPACE:"
  # Get all deployments and statefulsets, skipping kube-system, and rollout restart each
  kubectl get deployments,statefulsets --all-namespaces -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,KIND:.kind' \
    | grep -v ^NAMESPACE | grep -v ^kube-system | while read ns name kind; do
      kubectl rollout restart "$kind/$name" -n "$ns"
    done
else
  echo "No Update executed, just show state"
fi
echo

# Print a summary table of all Deployments and StatefulSets and their images
echo "CURRENT RESOURCES:"
echo "--------------------------------------------------"
kubectl get deployments,statefulsets -A \
  -o jsonpath='{range .items[*]}{.kind}{"\t"}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{range .spec.template.spec.containers[*]}{.image}{" "}{end}{"\n"}{end}' \
  | column -t -N KIND,NAMESPACE,NAME,IMAGES

echo
# Print a status table of all pods that are running or in CrashLoopBackOff, with image pull policy
echo "POD STATUS:"
echo "--------------------------------------------------"
kubectl get pods -A -o json \
| jq -r '
  # Iterate over all pods
  .items[]
  # Select pods that are Running or have a container in CrashLoopBackOff
  | select(
      .status.phase == "Running"
      or
      any(.status.containerStatuses[]?;
          .state.waiting?.reason == "CrashLoopBackOff")
    )
  # Extract useful fields
  | .metadata.namespace as $ns
  | .metadata.name as $pod
  | .status.phase as $phase
  | .spec.containers as $specContainers
  # For each container status, print details if running or in CrashLoopBackOff
  | .status.containerStatuses[]?
  | select(
      .state.running
      or
      .state.waiting?.reason == "CrashLoopBackOff"
    )
  # Find the imagePullPolicy from the spec for this container
  | (
      $specContainers[]
      | select(.name == .name)
      | .imagePullPolicy
    ) as $pullPolicy
  # Output tab-separated fields for the table
  | "\($ns)\t\($pod)\t\($phase)\t\(.name)\t\(.image)\t\($pullPolicy)\t\(
      if .state.running then "Running"
      else .state.waiting.reason
      end
    )"
' | sort | uniq | column -t -N NAMESPACE,POD,PHASE,CONTAINER,IMAGE,PULL_POLICY,STATE


