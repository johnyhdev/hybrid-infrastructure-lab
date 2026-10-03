#!/usr/bin/env bash

set -euo pipefail

RESOURCE_GROUP="rg-hybrid-infra-lab"
OUTPUT="inventory/generated/azure.yml"

mkdir -p "$(dirname "$OUTPUT")"

CM_IP="$(
  az vm list-ip-addresses \
    --resource-group "$RESOURCE_GROUP" \
    --name vm-cm-01 \
    --query "[0].virtualMachine.network.privateIpAddresses[0]" \
    -o tsv
)"

WORKLOAD_IP="$(
  az vm list-ip-addresses \
    --resource-group "$RESOURCE_GROUP" \
    --name vm-workload-01 \
    --query "[0].virtualMachine.network.privateIpAddresses[0]" \
    -o tsv
)"

cat > "$OUTPUT" <<EOF
all:
  children:

    control:
      hosts:
        vm-cm-01:
          ansible_host: ${CM_IP}

    workload:
      hosts:
        vm-workload-01:
          ansible_host: ${WORKLOAD_IP}
EOF

echo "Inventory generated:"
cat "$OUTPUT"
