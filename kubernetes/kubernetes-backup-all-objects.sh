#!/bin/bash

# Configuration
BACKUP_DIR="$HOME/backup/k8s"
KEEP_GEN=14  # Number of backups to retain
TIMESTAMP=$(date +"%Y%m%d-%H%M")
CURRENT_BACKUP="$BACKUP_DIR/$TIMESTAMP"

# Create backup directory
mkdir -p "$CURRENT_BACKUP"

echo "Starting Kubernetes backup: $CURRENT_BACKUP"

# Function to export Kubernetes objects
backup_objects() {
    local namespace="$1"
    local resource_type="$2"
    
    # Get list of all objects of the resource type in the namespace
    kubectl get "$resource_type" -n "$namespace" --no-headers -o custom-columns=":metadata.name" | while read -r obj_name; do
        echo "Backing up $namespace/$resource_type/$obj_name"
        kubectl get "$resource_type" "$obj_name" -n "$namespace" -o yaml > "$CURRENT_BACKUP/$namespace/$resource_type-$obj_name.yml"
    done
}

# Get a list of all namespaces
namespaces=$(kubectl get namespaces --no-headers -o custom-columns=":metadata.name")

# Get a list of all custom resource definitions (CRDs)
crds=$(kubectl get crds --no-headers -o custom-columns=":metadata.name")

# Iterate over each namespace and export objects
for ns in $namespaces; do
    mkdir -p "$CURRENT_BACKUP/$ns"
    
    # Get all default Kubernetes objects
    resources=$(kubectl api-resources --namespaced=true --verbs=list -o name)
    
    for res in $resources; do
        backup_objects "$ns" "$res"
    done
done

# Backup cluster-wide objects (not tied to a namespace)
mkdir -p "$CURRENT_BACKUP/clusterwide"

for crd in $crds; do
    echo "Backing up CRD: $crd"
    kubectl get "$crd" -A -o yaml > "$CURRENT_BACKUP/clusterwide/$crd.yml"
done

# Cleanup old backups - Keep only last $KEEP_GEN generations
cd "$BACKUP_DIR"
ls -d */ | sort -r | tail -n +$((KEEP_GEN + 1)) | xargs rm -rf

echo "Backup completed: $CURRENT_BACKUP"

