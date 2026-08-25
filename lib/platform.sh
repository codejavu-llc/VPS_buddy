#!/usr/bin/env bash

# shellcheck shell=bash
# Detection results are consumed by other modules and the CLI.
# shellcheck disable=SC2034

version_ge() {
    local left=${1#go} right=${2#go}
    [[ "$left" == "$right" ]] || [[ "$(printf '%s\n%s\n' "$right" "$left" | sort -V | tail -n1)" == "$left" ]]
}

vpb_detect_platform() {
    VPB_KERNEL=$(uname -s)
    [[ "$VPB_KERNEL" == Linux ]] || die "VPS Buddy currently supports Linux; detected $VPB_KERNEL."

    VPB_RAW_ARCH=$(uname -m)
    case "$VPB_RAW_ARCH" in
        x86_64|amd64) VPB_ARCH=amd64 ;;
        aarch64|arm64) VPB_ARCH=arm64 ;;
        armv7l|armhf) VPB_ARCH=armv6l ;;
        i386|i686) VPB_ARCH=386 ;;
        *) die "Unsupported CPU architecture: $VPB_RAW_ARCH" ;;
    esac

    VPB_DISTRO_ID=unknown
    VPB_DISTRO_NAME='Unknown Linux'
    VPB_DISTRO_VERSION=unknown
    if [[ -r /etc/os-release ]]; then
        # Distribution-owned data. Values are copied into normalized variables below.
        # shellcheck disable=SC1091
        source /etc/os-release
        VPB_DISTRO_ID=${ID:-unknown}
        VPB_DISTRO_NAME=${NAME:-Unknown Linux}
        VPB_DISTRO_VERSION=${VERSION_ID:-rolling}
    fi

    if command -v apt-get >/dev/null 2>&1; then
        VPB_PACKAGE_MANAGER=apt
    elif command -v dnf >/dev/null 2>&1; then
        VPB_PACKAGE_MANAGER=dnf
    elif command -v pacman >/dev/null 2>&1; then
        VPB_PACKAGE_MANAGER=pacman
    elif command -v apk >/dev/null 2>&1; then
        VPB_PACKAGE_MANAGER=apk
    elif command -v zypper >/dev/null 2>&1; then
        VPB_PACKAGE_MANAGER=zypper
    else
        VPB_PACKAGE_MANAGER=unknown
    fi

    VPB_VIRTUALIZATION=unknown
    if command -v systemd-detect-virt >/dev/null 2>&1; then
        VPB_VIRTUALIZATION=$(systemd-detect-virt 2>/dev/null || printf 'bare-metal')
    elif [[ -f /.dockerenv ]]; then
        VPB_VIRTUALIZATION=docker
    fi
}

vpb_detect_hardware() {
    VPB_CPU_COUNT=$(getconf _NPROCESSORS_ONLN 2>/dev/null || printf '1')
    [[ "$VPB_CPU_COUNT" =~ ^[0-9]+$ ]] || VPB_CPU_COUNT=1

    local memory_kb=0 disk_kb=0
    if [[ -r /proc/meminfo ]]; then
        memory_kb=$(awk '/^MemTotal:/ {print $2; exit}' /proc/meminfo)
    fi
    VPB_MEMORY_MB=$((memory_kb / 1024))
    disk_kb=$(df -Pk "$HOME" 2>/dev/null | awk 'NR==2 {print $4}')
    [[ "$disk_kb" =~ ^[0-9]+$ ]] || disk_kb=0
    VPB_DISK_FREE_GB=$((disk_kb / 1024 / 1024))

    if (( VPB_CPU_COUNT <= 1 || VPB_MEMORY_MB < 3500 || VPB_DISK_FREE_GB < 12 )); then
        VPB_HARDWARE_CLASS=tiny
        VPB_RECOMMENDED_PROFILE=essential
        VPB_BUILD_JOBS=1
    elif (( VPB_CPU_COUNT >= 8 && VPB_MEMORY_MB >= 8000 && VPB_DISK_FREE_GB >= 50 )); then
        VPB_HARDWARE_CLASS=power
        VPB_RECOMMENDED_PROFILE=advanced
        VPB_BUILD_JOBS=4
    else
        VPB_HARDWARE_CLASS=standard
        VPB_RECOMMENDED_PROFILE=bug-hunter
        VPB_BUILD_JOBS=$VPB_CPU_COUNT
        (( VPB_BUILD_JOBS > 3 )) && VPB_BUILD_JOBS=3
    fi
}

vpb_platform_summary() {
    printf '%s %s · %s · %s CPU · %s MB RAM · %s GB free · %s\n' \
        "$VPB_DISTRO_NAME" "$VPB_DISTRO_VERSION" "$VPB_ARCH" "$VPB_CPU_COUNT" \
        "$VPB_MEMORY_MB" "$VPB_DISK_FREE_GB" "$VPB_HARDWARE_CLASS"
}

vpb_require_supported_platform() {
    [[ "$VPB_PACKAGE_MANAGER" != unknown ]] || die "No supported package manager found. Run 'vpsbuddy doctor' for details."
    case "$VPB_ARCH" in
        amd64|arm64) ;;
        *) warn "$VPB_ARCH support is best-effort; some upstream tools may be unavailable." ;;
    esac
}
