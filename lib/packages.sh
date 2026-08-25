#!/usr/bin/env bash

# shellcheck shell=bash
# VPB_PIPX_CMD is consumed by the installer module.
# shellcheck disable=SC2034

vpb_privileged_prefix() {
    VPB_PRIVILEGED=()
    if (( EUID == 0 )); then
        return
    fi
    if ! command -v sudo >/dev/null 2>&1; then
        [[ "${VPB_DRY_RUN:-0}" == 1 ]] && { VPB_PRIVILEGED=(sudo); return; }
        die "System packages require sudo. Install sudo or run the setup as root."
    fi
    VPB_PRIVILEGED=(sudo)
}

vpb_install_system_packages() {
    section "System dependencies"
    vpb_privileged_prefix

    local -a packages command
    case "$VPB_PACKAGE_MANAGER" in
        apt)
            packages=(ca-certificates curl git jq tar gzip unzip make gcc libc6-dev libpcap-dev pkg-config python3 python3-venv tmux ripgrep dnsutils nmap)
            run "${VPB_PRIVILEGED[@]}" apt-get update -qq
            command=("${VPB_PRIVILEGED[@]}" env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends)
            ;;
        dnf)
            packages=(ca-certificates curl git jq tar gzip unzip make gcc glibc-devel libpcap-devel pkgconf-pkg-config python3 tmux ripgrep bind-utils nmap)
            command=("${VPB_PRIVILEGED[@]}" dnf install -y)
            ;;
        pacman)
            packages=(ca-certificates curl git jq tar gzip unzip make gcc libpcap pkgconf python tmux ripgrep bind nmap)
            run "${VPB_PRIVILEGED[@]}" pacman -Sy --noconfirm
            command=("${VPB_PRIVILEGED[@]}" pacman -S --needed --noconfirm)
            ;;
        apk)
            packages=(ca-certificates coreutils curl git jq tar gzip unzip make gcc musl-dev libpcap-dev pkgconf python3 py3-pip tmux ripgrep bind-tools nmap)
            command=("${VPB_PRIVILEGED[@]}" apk add --no-cache)
            ;;
        zypper)
            packages=(ca-certificates curl git jq tar gzip unzip make gcc glibc-devel libpcap-devel pkg-config python3 tmux ripgrep bind-utils nmap)
            command=("${VPB_PRIVILEGED[@]}" zypper --non-interactive install)
            ;;
        *) die "Unsupported package manager: $VPB_PACKAGE_MANAGER" ;;
    esac

    run "${command[@]}" "${packages[@]}"
    success "System dependencies are ready."
}

vpb_install_profile_packages() {
    local profile=$1 browser_package=''
    [[ "$profile" == bug-hunter || "$profile" == advanced ]] || return 0

    case "$VPB_PACKAGE_MANAGER" in
        apt)
            if [[ "$VPB_DISTRO_ID" == ubuntu ]]; then
                browser_package=chromium-browser
            else
                browser_package=chromium
            fi
            ;;
        dnf|pacman|apk|zypper) browser_package=chromium ;;
    esac
    [[ -n "$browser_package" ]] || return 0

    if command -v chromium >/dev/null 2>&1 || command -v chromium-browser >/dev/null 2>&1; then
        info "A Chromium-compatible browser is already available."
        return 0
    fi

    info "Installing $browser_package for screenshot tooling."
    case "$VPB_PACKAGE_MANAGER" in
        apt) run "${VPB_PRIVILEGED[@]}" env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$browser_package" ;;
        dnf) run "${VPB_PRIVILEGED[@]}" dnf install -y "$browser_package" ;;
        pacman) run "${VPB_PRIVILEGED[@]}" pacman -S --needed --noconfirm "$browser_package" ;;
        apk) run "${VPB_PRIVILEGED[@]}" apk add --no-cache "$browser_package" ;;
        zypper) run "${VPB_PRIVILEGED[@]}" zypper --non-interactive install "$browser_package" ;;
    esac
}

vpb_ensure_pipx() {
    if command -v pipx >/dev/null 2>&1; then
        VPB_PIPX_CMD=$(command -v pipx)
        return
    fi

    local bootstrap="$VPB_DATA_HOME/runtime/pipx"
    if [[ -x "$bootstrap/bin/pipx" ]]; then
        VPB_PIPX_CMD="$bootstrap/bin/pipx"
        return
    fi

    info "Installing an isolated pipx runtime."
    if [[ "${VPB_DRY_RUN:-0}" == 1 ]]; then
        run python3 -m venv "$bootstrap"
        run "$bootstrap/bin/python" -m pip install --upgrade pip pipx
        VPB_PIPX_CMD="$bootstrap/bin/pipx"
        return
    fi
    mkdir -p "$(dirname "$bootstrap")"
    python3 -m venv "$bootstrap"
    "$bootstrap/bin/python" -m pip install --disable-pip-version-check --upgrade pip pipx
    VPB_PIPX_CMD="$bootstrap/bin/pipx"
}
