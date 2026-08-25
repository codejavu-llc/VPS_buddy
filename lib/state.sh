#!/usr/bin/env bash

# shellcheck shell=bash

vpb_state_has() {
    local name=$1
    [[ -f "$VPB_TOOL_STATE" ]] && awk -F '\t' -v tool="$name" '$1 == tool && $4 == "ok" {found=1} END {exit !found}' "$VPB_TOOL_STATE"
}

vpb_state_knows() {
    local name=$1
    [[ -f "$VPB_TOOL_STATE" ]] && awk -F '\t' -v tool="$name" '$1 == tool {found=1} END {exit !found}' "$VPB_TOOL_STATE"
}

vpb_state_version() {
    local name=$1
    [[ -f "$VPB_TOOL_STATE" ]] || return 1
    awk -F '\t' -v tool="$name" '$1 == tool && $4 == "ok" {value=$3} END {if (value != "") print value; else exit 1}' "$VPB_TOOL_STATE"
}

vpb_state_status() {
    local name=$1
    [[ -f "$VPB_TOOL_STATE" ]] || return 1
    awk -F '\t' -v tool="$name" '$1 == tool {value=$4} END {if (value != "") print value; else exit 1}' "$VPB_TOOL_STATE"
}

vpb_state_record() {
    local name=$1 installer=$2 version=$3 status=$4
    [[ "${VPB_DRY_RUN:-0}" == 1 ]] && return 0
    local temp
    temp=$(mktemp "$VPB_STATE_HOME/tools.XXXXXX")
    awk -F '\t' -v tool="$name" '$1 != tool' "$VPB_TOOL_STATE" >"$temp" 2>/dev/null || true
    printf '%s\t%s\t%s\t%s\t%s\n' "$name" "$installer" "$version" "$status" "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" >>"$temp"
    chmod 600 "$temp"
    mv "$temp" "$VPB_TOOL_STATE"
}

vpb_state_record_failure() {
    local name=$1 installer=$2 version=$3
    if vpb_state_has "$name"; then
        warn "$name was not updated; the previously working installation remains active."
        return 0
    fi
    vpb_state_record "$name" "$installer" "$version" failed
}

vpb_lock_record() {
    local name=$1 source=$2 version=$3
    [[ "${VPB_DRY_RUN:-0}" == 1 ]] && return 0
    local temp
    temp=$(mktemp "$VPB_STATE_HOME/lock.XXXXXX")
    awk -F '\t' -v tool="$name" '$1 != tool' "$VPB_LOCK_FILE" >"$temp" 2>/dev/null || true
    printf '%s\t%s\t%s\n' "$name" "$source" "$version" >>"$temp"
    chmod 600 "$temp"
    mv "$temp" "$VPB_LOCK_FILE"
}

vpb_lock_remove() {
    local name=$1 temp
    [[ -f "$VPB_LOCK_FILE" ]] || return 0
    temp=$(mktemp "$VPB_STATE_HOME/lock.XXXXXX")
    awk -F '\t' -v tool="$name" '$1 != tool' "$VPB_LOCK_FILE" >"$temp"
    chmod 600 "$temp"
    mv "$temp" "$VPB_LOCK_FILE"
}

vpb_state_remove() {
    local name=$1 temp
    [[ -f "$VPB_TOOL_STATE" ]] || return 0
    temp=$(mktemp "$VPB_STATE_HOME/tools.XXXXXX")
    awk -F '\t' -v tool="$name" '$1 != tool' "$VPB_TOOL_STATE" >"$temp"
    chmod 600 "$temp"
    mv "$temp" "$VPB_TOOL_STATE"
}

vpb_actual_go_version() {
    local binary=$1 version
    version=$("${VPB_GO_CMD:-go}" version -m "$binary" 2>/dev/null | awk '$1 == "mod" {print $3; exit}')
    printf '%s' "${version:-unknown}"
}

vpb_status_table() {
    printf '%-20s %-10s %-14s %s\n' TOOL INSTALLER VERSION STATUS
    printf '%-20s %-10s %-14s %s\n' '--------------------' '----------' '--------------' '--------'
    local name _description _profiles installer _source version _size status actual
    while IFS='|' read -r name _description _profiles installer _source version _size; do
        [[ -z "$name" || "$name" == \#* ]] && continue
        actual=$(vpb_state_version "$name" 2>/dev/null || printf '%s' '-')
        status=missing
        command -v "$name" >/dev/null 2>&1 && status=ready
        printf '%-20s %-10s %-14s %s\n' "$name" "$installer" "$actual" "$status"
    done <"$VPB_MANIFEST"
}
