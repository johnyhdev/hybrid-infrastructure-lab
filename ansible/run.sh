#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")"

echo "========================================"
echo "Generating Azure inventory"
echo "========================================"

./inventory/generate_inventory.sh

echo
echo "========================================"
echo "Running Ansible"
echo "========================================"

ansible-playbook \
  -i inventory/generated/azure.yml \
  playbooks/site.yml \
  --private-key ~/.ssh/vm-cm-workload