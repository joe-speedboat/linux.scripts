#!/bin/bash
# DESC: terminate kubernetes namespace, waiting for finalizers
# DOC: 
#   https://book.kubebuilder.io/reference/using-finalizers.html
#   https://medium.com/pareture/script-to-force-remove-kubernetes-namespace-finalizer-57b72bd9460d
# TESTED with OKD 4.8 and Kubernetes 1.21 (rke)
# Usage: kubernetes-terminate-namespace.sh namespace-to-remove



which kubectl >/dev/null || echo ERROR: kubectl missing
which jq >/dev/null || echo ERROR: jq missing

set -eou pipefail
namespace=$1
if [ -z "$namespace" ]
then
  echo "This script requires a namespace argument input. None found. Exiting."
  exit 1
fi
kubectl get namespace $namespace -o json | jq '.spec = {"finalizers":[]}' > rknf_tmp.json
kubectl proxy &
sleep 5
curl -H "Content-Type: application/json" -X PUT --data-binary @rknf_tmp.json http://localhost:8001/api/v1/namespaces/$namespace/finalize
pkill -9 -f "kubectl proxy"
rm rknf_tmp.json
