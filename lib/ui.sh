#!/usr/bin/env bash

# shellcheck shell=bash
# The banner and shell snippets intentionally use literal dollar signs.
# shellcheck disable=SC2016

VPB_COLOR=0
if [[ -t 2 && -z "${NO_COLOR:-}" ]]; then
    VPB_COLOR=1
fi

if (( VPB_COLOR )); then
    VPB_CYAN=$'\033[0;36m'
    VPB_GREEN=$'\033[0;32m'
    VPB_YELLOW=$'\033[0;33m'
    VPB_RED=$'\033[0;31m'
    VPB_BOLD=$'\033[1m'
    VPB_RESET=$'\033[0m'
else
    VPB_CYAN=""
    VPB_GREEN=""
    VPB_YELLOW=""
    VPB_RED=""
    VPB_BOLD=""
    VPB_RESET=""
fi

vpb_log_line() {
    local level=$1 color=$2
    shift 2
    local line
    printf -v line '%s[%s]%s %s' "$color" "$level" "$VPB_RESET" "$*"
    printf '%s\n' "$line" >&2
    if [[ -n "${VPB_LOG_FILE:-}" ]]; then
        printf '[%s] [%s] %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$level" "$*" >>"$VPB_LOG_FILE"
    fi
}

info()    { vpb_log_line INFO "$VPB_CYAN" "$@"; }
success() { vpb_log_line OK "$VPB_GREEN" "$@"; }
warn()    { vpb_log_line WARN "$VPB_YELLOW" "$@"; }
error()   { vpb_log_line ERROR "$VPB_RED" "$@"; }

die() {
    error "$@"
    exit 1
}

section() {
    printf '\n%s%s%s\n' "$VPB_BOLD" "$*" "$VPB_RESET" >&2
}

show_banner() {
    [[ "${VPB_QUIET:-0}" == 1 ]] && return
    printf '%s%s' "$VPB_CYAN" "$VPB_BOLD" >&2
    printf '%s\n' \
        ' __     ______  ____    ____            _     _       ' \
        ' \ \   / /  _ \/ ___|  | __ ) _   _  __| | __| |_   _ ' \
        '  \ \ / /| |_) \___ \  |  _ \| | | |/ _` |/ _` | | | |' \
        '   \ V / |  __/ ___) | | |_) | |_| | (_| | (_| | |_| |' \
        '    \_/  |_|   |____/  |____/ \__,_|\__,_|\__,_|\__, |' \
        '                                                |___/ '
    printf '              CodeJavu security workspace\n%s' "$VPB_RESET" >&2
}

confirm() {
    local prompt=${1:-Continue?}
    [[ "${VPB_ASSUME_YES:-0}" == 1 ]] && return 0
    [[ "${VPB_NON_INTERACTIVE:-0}" == 1 ]] && die "Confirmation required in non-interactive mode; pass --yes."

    local answer
    if [[ -r /dev/tty ]]; then
        read -r -p "$prompt [Y/n] " answer </dev/tty || return 1
    else
        read -r -p "$prompt [Y/n] " answer || return 1
    fi
    [[ -z "$answer" || "$answer" =~ ^[Yy]([Ee][Ss])?$ ]]
}

shell_join() {
    local output="" arg quoted
    for arg in "$@"; do
        printf -v quoted '%q' "$arg"
        output+="${output:+ }${quoted}"
    done
    printf '%s' "$output"
}

run() {
    if [[ "${VPB_DRY_RUN:-0}" == 1 ]]; then
        printf '  DRY-RUN  %s\n' "$(shell_join "$@")" >&2
        return 0
    fi
    "$@"
}
