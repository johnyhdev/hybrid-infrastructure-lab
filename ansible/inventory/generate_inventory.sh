#!/usr/bin/env bash

set -euo pipefail

RESOURCE_GROUP="rg-hybrid-infra-lab"
OUTPUT="inventory/generated/azure.yml"

mkdir -p "$(dirname "$OUTPUT")"

# Tự động lấy danh sách tất cả các VM có tag role=control-manager
CM_VMS=$(az vm list \
  --resource-group "$RESOURCE_GROUP" \
  --query "[?tags.role=='control-manager'].{name:name, ip:privateIps}" \
  -o json)

# Tự động lấy danh sách tất cả các VM có tag role=workload
WORKLOAD_VMS=$(az vm list \
  --resource-group "$RESOURCE_GROUP" \
  --query "[?tags.role=='workload'].{name:name, ip:privateIps}" \
  -o json)

cat > "$OUTPUT" <<EOF
all:
  vars:
    ansible_user: azureadmin
    ansible_ssh_private_key_file: ~/.ssh/vm-cm-workload
    ansible_ssh_common_args: '-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
  children:
    control:
      hosts:
EOF

# Parse JSON và ghi các VM thuộc nhóm control vào inventory
echo "$CM_VMS" | jq -c '.[]' | while read -r vm; do
  NAME=$(echo "$vm" | jq -r '.name')
  IP=$(echo "$vm" | jq -r '.ip')
  cat >> "$OUTPUT" <<EOF
        ${NAME}:
          ansible_host: ${IP}
EOF
done

cat >> "$OUTPUT" <<EOF
    workload:
      hosts:
EOF

# Parse JSON và ghi các VM thuộc nhóm workload vào inventory
echo "$WORKLOAD_VMS" | jq -c '.[]' | while read -r vm; do
  NAME=$(echo "$vm" | jq -r '.name')
  IP=$(echo "$vm" | jq -r '.ip')
  cat >> "$OUTPUT" <<EOF
        ${NAME}:
          ansible_host: ${IP}
EOF
done

echo "Inventory generated:"
cat "$OUTPUT"