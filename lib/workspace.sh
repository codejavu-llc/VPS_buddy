#!/usr/bin/env bash

# shellcheck shell=bash

vpb_workspace_create() {
    local name=$1
    [[ "$name" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$ ]] || die "Workspace names may contain letters, numbers, dots, underscores, and dashes."
    local root="$VPB_WORKSPACES_DIR/$name"
    [[ ! -e "$root" ]] || die "Workspace already exists: $root"

    if [[ "${VPB_DRY_RUN:-0}" == 1 ]]; then
        run mkdir -p "$root"/{scope,raw,normalized,screenshots,findings,notes,logs}
        return
    fi
    mkdir -p "$root"/{scope,raw,normalized,screenshots,findings,notes,logs}
    chmod 700 "$root"
    printf '# One hostname, domain, IP, or CIDR per line.\n' >"$root/scope/allowed.txt"
    printf '# Explicit exclusions, one entry per line.\n' >"$root/scope/excluded.txt"
    {
        printf 'name: %s\n' "$name"
        printf 'created_at: %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
        printf 'authorization_confirmed: false\n'
        printf 'default_rate_limit: 50\n'
    } >"$root/workspace.yaml"
    cat >"$root/README.md" <<EOF
# $name

This workspace is intentionally inert. Add only authorized targets to
\`scope/allowed.txt\`, record exclusions, and set \`authorization_confirmed: true\`
only after verifying the program rules or receiving written permission.

- \`raw/\`: immutable command output
- \`normalized/\`: deduplicated and processed data
- \`screenshots/\`: visual evidence
- \`findings/\`: one directory per potential finding
- \`notes/\`: methodology and investigation notes
- \`logs/\`: commands and execution metadata
EOF
    success "Created $root"
}

vpb_workspace_list() {
    [[ -d "$VPB_WORKSPACES_DIR" ]] || return 0
    local directory
    for directory in "$VPB_WORKSPACES_DIR"/*; do
        if [[ -d "$directory" ]]; then
            basename "$directory"
        fi
    done | sort
}
