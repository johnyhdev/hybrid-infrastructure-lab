#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")"

echo "========================================"
echo "Generating Azure inventory"
echo "========================================"

./inventory/generate_inventory.sh

echo
echo "========================================"
echo "Checking Workload Nodes Connectivity"
echo "========================================"

# Cấu hình retry: tối đa 15 lần, mỗi lần cách nhau 10 giây (tổng thời gian chờ ~2.5 phút)
MAX_RETRIES=15
RETRY_COUNT=0

until ansible all \
  -i inventory/generated/azure.yml \
  --private-key ~/.ssh/vm-cm-workload \
  -m ping -o >/dev/null 2>&1; do

  RETRY_COUNT=$((RETRY_COUNT + 1))
  if [ "$RETRY_COUNT" -ge "$MAX_RETRIES" ]; then
    echo "ERROR: Workload nodes are not reachable after $((MAX_RETRIES * 10)) seconds."
    exit 1
  fi

  echo "Workload nodes are not ready yet. Retrying in 10s ($RETRY_COUNT/$MAX_RETRIES)..."
  sleep 10
done

echo "All Workload nodes are online and ready!"

echo
echo "========================================"
echo "Running Ansible"
echo "========================================"

ansible-playbook \
  -i inventory/generated/azure.yml \
  playbooks/site.yml \
  --private-key ~/.ssh/vm-cm-workload