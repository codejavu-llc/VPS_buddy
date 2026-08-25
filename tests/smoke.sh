#!/usr/bin/env bash

set -Eeuo pipefail

ROOT=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)
TEMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/vpsbuddy-smoke.XXXXXX")
trap 'rm -rf -- "$TEMP_ROOT"' EXIT

export HOME="$TEMP_ROOT/home"
export XDG_CONFIG_HOME="$TEMP_ROOT/config"
export XDG_DATA_HOME="$TEMP_ROOT/data"
export XDG_STATE_HOME="$TEMP_ROOT/state"
export XDG_CACHE_HOME="$TEMP_ROOT/cache"
mkdir -p "$HOME"

"$ROOT/vpsbuddy" version | grep -Fx 'VPS Buddy 3.0.0'
"$ROOT/vpsbuddy" help | grep -Fq 'vpsbuddy setup'
"$ROOT/vpsbuddy" tools list --profile essential | grep -Fq nuclei
"$ROOT/vpsbuddy" setup --profile essential --dry-run --yes --no-wordlists --no-system-packages >/dev/null

if [[ -n "$(find "$TEMP_ROOT" -mindepth 1 -type f -print)" ]]; then
    printf 'Dry-run unexpectedly created a file.\n' >&2
    exit 1
fi

printf 'Smoke tests passed.\n'
