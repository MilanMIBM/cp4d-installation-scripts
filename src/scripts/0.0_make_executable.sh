#!/bin/bash
find "$(dirname "$0")" -name "*.sh" -exec chmod +x {} +

state=$(podman machine inspect --format '{{.State}}' 2>/dev/null)
echo "Podman machine state: ${state:-unknown}"

if [ "$state" != "running" ]; then
  podman machine start
fi
