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

version_output=$("$ROOT/vpsbuddy" version)
help_output=$("$ROOT/vpsbuddy" help)
tools_output=$("$ROOT/vpsbuddy" tools list --profile essential)
grep -Fxq 'VPS Buddy 3.0.0' <<<"$version_output"
grep -Fq 'vpsbuddy setup' <<<"$help_output"
grep -Fq nuclei <<<"$tools_output"
"$ROOT/vpsbuddy" setup --profile essential --dry-run --yes --no-wordlists --no-system-packages >/dev/null

for managed_path in \
    "$XDG_CONFIG_HOME/vpsbuddy" \
    "$XDG_DATA_HOME/vpsbuddy" \
    "$XDG_STATE_HOME/vpsbuddy" \
    "$XDG_CACHE_HOME/vpsbuddy" \
    "$HOME/.local/bin" \
    "$HOME/.profile" \
    "$HOME/.bashrc" \
    "$HOME/.zshrc"; do
    if [[ -e "$managed_path" ]]; then
        printf 'Dry-run unexpectedly created %s.\n' "$managed_path" >&2
        exit 1
    fi
done

printf 'Smoke tests passed.\n'
