#!/usr/bin/env bash

# shellcheck shell=bash
# Cross-module globals are intentionally assigned here.
# shellcheck disable=SC2016,SC2034

vpb_init_paths() {
    : "${VPB_CONFIG_HOME:=${XDG_CONFIG_HOME:-$HOME/.config}/vpsbuddy}"
    : "${VPB_DATA_HOME:=${XDG_DATA_HOME:-$HOME/.local/share}/vpsbuddy}"
    : "${VPB_STATE_HOME:=${XDG_STATE_HOME:-$HOME/.local/state}/vpsbuddy}"
    : "${VPB_CACHE_HOME:=${XDG_CACHE_HOME:-$HOME/.cache}/vpsbuddy}"

    : "${VPB_BIN_DIR:=$HOME/.local/bin}"
    : "${VPB_TOOLS_DIR:=$HOME/tools}"
    : "${VPB_WORDLISTS_DIR:=$HOME/wordlists}"
    : "${VPB_WORKSPACES_DIR:=$HOME/engagements}"

    VPB_CONFIG_FILE="$VPB_CONFIG_HOME/config"
    VPB_TOOL_STATE="$VPB_STATE_HOME/tools.tsv"
    VPB_LOCK_FILE="$VPB_STATE_HOME/versions.lock"
}

vpb_normalize_path() {
    local value=$1
    [[ "$value" != *$'\n'* && "$value" != *'='* ]] || die "Paths cannot contain newlines or '='."
    value=${value/#\~/$HOME}
    if [[ "$value" == /* ]]; then
        printf '%s' "$value"
    else
        printf '%s/%s' "$PWD" "$value"
    fi
}

vpb_read_config() {
    [[ -f "$VPB_CONFIG_FILE" ]] || return 0
    local key value
    while IFS='=' read -r key value; do
        [[ -z "$key" || "$key" == \#* ]] && continue
        case "$key" in
            bin_dir) VPB_BIN_DIR=$value ;;
            tools_dir) VPB_TOOLS_DIR=$value ;;
            wordlists_dir) VPB_WORDLISTS_DIR=$value ;;
            workspaces_dir) VPB_WORKSPACES_DIR=$value ;;
            profile) VPB_SAVED_PROFILE=$value ;;
            content)
                case "$value" in 0|1) VPB_SAVED_CONTENT=$value ;; esac
                ;;
        esac
    done <"$VPB_CONFIG_FILE"
}

vpb_save_config() {
    [[ "${VPB_DRY_RUN:-0}" == 1 ]] && return 0
    mkdir -p "$VPB_CONFIG_HOME"
    local temp
    temp=$(mktemp "$VPB_CONFIG_HOME/config.XXXXXX")
    chmod 600 "$temp"
    {
        printf '# Managed by VPS Buddy. Values are literal paths, not shell code.\n'
        printf 'profile=%s\n' "${VPB_PROFILE:-${VPB_SAVED_PROFILE:-bug-hunter}}"
        printf 'content=%s\n' "${VPB_SYNC_CONTENT:-${VPB_SAVED_CONTENT:-1}}"
        printf 'bin_dir=%s\n' "$VPB_BIN_DIR"
        printf 'tools_dir=%s\n' "$VPB_TOOLS_DIR"
        printf 'wordlists_dir=%s\n' "$VPB_WORDLISTS_DIR"
        printf 'workspaces_dir=%s\n' "$VPB_WORKSPACES_DIR"
    } >"$temp"
    mv "$temp" "$VPB_CONFIG_FILE"
}

vpb_prepare_dirs() {
    [[ "${VPB_DRY_RUN:-0}" == 1 ]] && return 0
    mkdir -p \
        "$VPB_CONFIG_HOME" "$VPB_DATA_HOME" "$VPB_STATE_HOME" "$VPB_CACHE_HOME" \
        "$VPB_BIN_DIR" "$VPB_TOOLS_DIR" "$VPB_WORDLISTS_DIR" "$VPB_WORKSPACES_DIR"
    chmod 700 "$VPB_CONFIG_HOME" "$VPB_STATE_HOME"
    local directory
    for directory in "$VPB_CONFIG_HOME" "$VPB_DATA_HOME" "$VPB_STATE_HOME" "$VPB_CACHE_HOME" "$VPB_BIN_DIR" "$VPB_TOOLS_DIR" "$VPB_WORDLISTS_DIR" "$VPB_WORKSPACES_DIR"; do
        [[ -w "$directory" ]] || die "Directory is not writable: $directory"
    done
    touch "$VPB_TOOL_STATE" "$VPB_LOCK_FILE"
    chmod 600 "$VPB_TOOL_STATE" "$VPB_LOCK_FILE"
}

vpb_init_log() {
    [[ "${VPB_DRY_RUN:-0}" == 1 ]] && return 0
    mkdir -p "$VPB_STATE_HOME/logs"
    VPB_LOG_FILE="$VPB_STATE_HOME/logs/$(date -u +'%Y%m%dT%H%M%SZ')-$$.log"
    touch "$VPB_LOG_FILE"
    chmod 600 "$VPB_LOG_FILE"
}

vpb_print_config() {
    printf 'profile=%s\n' "${VPB_SAVED_PROFILE:-not-set}"
    printf 'content=%s\n' "${VPB_SAVED_CONTENT:-not-set}"
    printf 'bin_dir=%s\n' "$VPB_BIN_DIR"
    printf 'tools_dir=%s\n' "$VPB_TOOLS_DIR"
    printf 'wordlists_dir=%s\n' "$VPB_WORDLISTS_DIR"
    printf 'workspaces_dir=%s\n' "$VPB_WORKSPACES_DIR"
    printf 'config=%s\n' "$VPB_CONFIG_FILE"
    printf 'state=%s\n' "$VPB_STATE_HOME"
}

vpb_configure_shell_path() {
    VPB_PATH_RELOAD_NEEDED=0
    vpb_path_contains "$VPB_BIN_DIR" "${VPB_ORIGINAL_PATH:-$PATH}" && return 0
    if [[ "$VPB_BIN_DIR" != "$HOME/.local/bin" ]]; then
        warn "$VPB_BIN_DIR is not in PATH; add it to your shell configuration."
        export PATH="$VPB_BIN_DIR:$PATH"
        return 0
    fi

    local marker='# VPS Buddy user binaries' path_line='export PATH="$HOME/.local/bin:$PATH"' profile
    local -a profiles=("$HOME/.profile")
    case "${SHELL:-}" in
        */bash) profiles+=("$HOME/.bashrc") ;;
        */zsh) profiles+=("$HOME/.zshrc") ;;
    esac
    if [[ "${VPB_DRY_RUN:-0}" == 1 ]]; then
        for profile in "${profiles[@]}"; do
            run printf '%s -> %s\n' "$path_line" "$profile"
        done
        return 0
    fi
    for profile in "${profiles[@]}"; do
        touch "$profile"
        if ! grep -Fq "$path_line" "$profile"; then
            {
                printf '\n%s\n' "$marker"
                printf '%s\n' "$path_line"
            } >>"$profile"
        fi
    done
    export PATH="$VPB_BIN_DIR:$PATH"
    VPB_PATH_RELOAD_NEEDED=1
}
