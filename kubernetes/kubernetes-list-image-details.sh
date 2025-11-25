#!/usr/bin/env bash
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>
# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt

# ---------------------------------------------------------------
# List every Deployment and StatefulSet container with:
#   NAMESPACE  KIND  OBJECT-NAME  CONTAINER  IMAGE  PULL-POLICY
#
# Requirements:
#   * kubectl (configured for your cluster)
#   * jq     (JSON processor)
# ---------------------------------------------------------------

set -euo pipefail

# ---------- Header ----------
printf "%-20s %-12s %-30s %-20s %-50s %-15s\n" \
  "NAMESPACE" "KIND" "NAME" "CONTAINER" "IMAGE" "PULL-POLICY"
printf "%-20s %-12s %-30s %-20s %-50s %-15s\n" \
  "----------" "----" "----" "----------" "-----" "-----------"

# ---------- Core logic ----------
# 1. Grab Deployments + StatefulSets from *all* namespaces as JSON
# 2. Use jq to turn the JSON into a TAB‑separated stream (real newlines)
# 3. Feed that stream directly into a while‑read loop for pretty printing
kubectl get deployments,statefulsets -A -o json |
jq -r '
  .items[]
  | . as $obj
  | $obj.spec.template.spec.containers[]
  | [
      $obj.metadata.namespace,
      $obj.kind,
      $obj.metadata.name,
      .name,
      .image,
      (.imagePullPolicy // "IfNotPresent")
    ]
  | @tsv
' |
while IFS=$'\t' read -r ns kind name container image pull; do
  printf "%-20s %-12s %-30s %-20s %-50s %-15s\n" \
    "$ns" "$kind" "$name" "$container" "$image" "$pull"
done

