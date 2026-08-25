#!/usr/bin/env bash

set -Eeuo pipefail

ROOT=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)
MANIFEST="$ROOT/manifests/tools.tsv"

awk -F '|' '
    /^#/ || NF == 0 { next }
    NF != 7 { printf "line %d: expected 7 fields, got %d\n", NR, NF > "/dev/stderr"; failures++ }
    $1 !~ /^[a-z0-9][a-z0-9-]*$/ { printf "line %d: invalid tool name\n", NR > "/dev/stderr"; failures++ }
    $4 !~ /^(go|pipx|source|github-release)$/ { printf "line %d: unsupported installer\n", NR > "/dev/stderr"; failures++ }
    $6 == "" { printf "line %d: missing version\n", NR > "/dev/stderr"; failures++ }
    $7 !~ /^[0-9]+$/ { printf "line %d: invalid size\n", NR > "/dev/stderr"; failures++ }
    seen[$1]++ { printf "line %d: duplicate tool %s\n", NR, $1 > "/dev/stderr"; failures++ }
    END { exit failures > 0 }
' "$MANIFEST"

printf 'Manifest is valid.\n'
