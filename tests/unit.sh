#!/usr/bin/env bash

# Globals are consumed by sourced modules.
# shellcheck disable=SC2034
set -Eeuo pipefail
IFS=$'\n\t'

ROOT=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)
VPB_MANIFEST="$ROOT/manifests/tools.tsv"
VPB_DRY_RUN=0

# shellcheck source=/dev/null
source "$ROOT/lib/ui.sh"
# shellcheck source=/dev/null
source "$ROOT/lib/platform.sh"
# shellcheck source=/dev/null
source "$ROOT/lib/state.sh"
# shellcheck source=/dev/null
source "$ROOT/lib/installers.sh"

failures=0

assert_equal() {
    local expected=$1 actual=$2 label=$3
    if [[ "$expected" != "$actual" ]]; then
        printf 'not ok - %s (expected %s, got %s)\n' "$label" "$expected" "$actual"
        ((failures += 1))
    else
        printf 'ok - %s\n' "$label"
    fi
}

assert_success() {
    local label=$1
    shift
    if "$@"; then
        printf 'ok - %s\n' "$label"
    else
        printf 'not ok - %s\n' "$label"
        ((failures += 1))
    fi
}

assert_success 'equal versions compare' version_ge 1.24.0 1.24.0
assert_success 'newer version compares' version_ge 1.25.1 1.24.0
if version_ge 1.23.9 1.24.0; then
    printf 'not ok - older version rejected\n'
    ((failures += 1))
else
    printf 'ok - older version rejected\n'
fi

assert_equal 7 "$(vpb_profile_tool_count essential)" 'essential tool count'
assert_equal 34 "$(vpb_profile_tool_count bug-hunter)" 'bug-hunter tool count'
assert_equal 41 "$(vpb_profile_tool_count advanced)" 'advanced tool count'
assert_success 'valid profile accepted' vpb_profile_valid bug-hunter
if vpb_profile_valid everything; then
    printf 'not ok - invalid profile rejected\n'
    ((failures += 1))
else
    printf 'ok - invalid profile rejected\n'
fi

TEMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/vpsbuddy-unit.XXXXXX")
trap 'rm -rf -- "$TEMP_ROOT"' EXIT
VPB_STATE_HOME="$TEMP_ROOT/state"
VPB_TOOL_STATE="$VPB_STATE_HOME/tools.tsv"
VPB_LOCK_FILE="$VPB_STATE_HOME/versions.lock"
mkdir -p "$VPB_STATE_HOME"
touch "$VPB_TOOL_STATE" "$VPB_LOCK_FILE"

vpb_state_record nuclei go v3.0.0 ok
assert_success 'state records installed tool' vpb_state_has nuclei
assert_equal v3.0.0 "$(vpb_state_version nuclei)" 'state returns version'
vpb_state_record nuclei go v3.1.0 ok
assert_equal 1 "$(awk -F '\t' '$1 == "nuclei" {count += 1} END {print count}' "$VPB_TOOL_STATE")" 'state update is atomic replacement'
assert_equal v3.1.0 "$(vpb_state_version nuclei)" 'state version updates'
vpb_state_record_failure nuclei go v3.2.0
assert_equal v3.1.0 "$(vpb_state_version nuclei)" 'failed update preserves working version'
vpb_state_remove nuclei
if vpb_state_has nuclei; then
    printf 'not ok - state removes tool\n'
    ((failures += 1))
else
    printf 'ok - state removes tool\n'
fi

if ((failures)); then
    printf '%s unit test(s) failed\n' "$failures" >&2
    exit 1
fi
printf 'All unit tests passed.\n'
