#!/usr/bin/env bash

# Compatibility entry point for VPS Buddy 2.x users.
set -Eeuo pipefail
SCRIPT_DIR=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)
exec "$SCRIPT_DIR/vpsbuddy" setup "$@"
