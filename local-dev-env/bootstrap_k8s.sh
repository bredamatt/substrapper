#!/bin/bash

# Create registry if it doesn't exist
reg_name='kind-registry'
reg_port='5000'
running="$(docker inspect -f '{{.State.Running}}' "${reg_name}" 2>/dev/null || true)"
if [ "${running}" != 'true' ]; then
  docker run -d --restart=always -p "127.0.0.1:${reg_port}:5000" --name "${reg_name}" registry:2
fi

# Create cluster
echo "Creating Kind cluster"
kind create cluster --config=kind_config.yaml

# Connect local registry to kind network
echo "Connecting registry to kind network" 
docker network connect "kind" "${reg_name}" || true

# Configure the local registry in the kind cluster
echo "Configuring the local registry in the kind cluster"
kubectl apply -f local_registry_cm.yaml
