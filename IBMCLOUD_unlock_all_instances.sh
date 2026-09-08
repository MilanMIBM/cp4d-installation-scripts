#!/usr/bin/env bash
set -euo pipefail

RG="${1:-}"
DRY="${2:-}"

if [ -z "$RG" ]; then
  echo "usage: $0 RESOURCE_GROUP_ID [--dry-run]" >&2
  exit 2
fi

locked=$(ibmcloud resource instances --all-pages --output JSON -q \
  | jq -r --arg rg "$RG" '.[] | select(.resource_group_id==$rg and .locked==true) | "\(.id)|\(.name)|\(.region_id)"')

if [ -z "$locked" ]; then
  echo "No locked instances in resource group $RG"
  exit 0
fi

rc=0
while IFS='|' read -r id name region; do
  if [ "$DRY" = "--dry-run" ]; then
    echo "[dry-run] would unlock $name ($region)"
    continue
  fi
  if ibmcloud resource service-instance-unlock "$id" --force -q; then
    echo "unlocked $name ($region)"
  else
    echo "FAILED $name ($region)" >&2
    rc=1
  fi
done <<< "$locked"

exit $rc


#---

# ibmcloud resource instances --all-pages --output JSON -q \
#   | jq -r --arg rg "$RG" '.[] | select(.resource_group_id==$rg and .locked==true) | .id' \
#   | while read -r id; do
#       echo "unlocking $id"
#       ibmcloud resource service-instance-unlock "$id" --force -q
#     done