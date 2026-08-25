#!/usr/bin/env bash

# shellcheck shell=bash

vpb_json_escape() {
    local value=${1:-}
    value=${value//\\/\\\\}
    value=${value//\"/\\\"}
    value=${value//$'\n'/\\n}
    value=${value//$'\r'/\\r}
    value=${value//$'\t'/\\t}
    printf '%s' "$value"
}

vpb_path_contains() {
    local directory=$1 search_path=${2:-$PATH}
    case ":$search_path:" in *":$directory:"*) return 0 ;; *) return 1 ;; esac
}

vpb_doctor() {
    local json=${1:-0} issues=0
    vpb_detect_platform
    vpb_detect_hardware

    local package_status=ok bin_status=ok disk_status=ok browser_status=not-required
    local expected_tools=0 ready_tools=0 missing_tools=0 name _description profiles _installer _source _version _size
    [[ "$VPB_PACKAGE_MANAGER" != unknown ]] || { package_status=missing; ((issues += 1)); }
    [[ -d "$VPB_BIN_DIR" && -w "$VPB_BIN_DIR" ]] || { bin_status=not-ready; ((issues += 1)); }
    vpb_path_contains "$VPB_BIN_DIR" "${VPB_ORIGINAL_PATH:-$PATH}" || { bin_status=not-in-path; ((issues += 1)); }
    (( VPB_DISK_FREE_GB >= 5 )) || { disk_status=low; ((issues += 1)); }

    if [[ -n "${VPB_SAVED_PROFILE:-}" ]] && vpb_profile_valid "$VPB_SAVED_PROFILE"; then
        while IFS='|' read -r name _description profiles _installer _source _version _size; do
            [[ -z "$name" || "$name" == \#* ]] && continue
            vpb_profile_contains "$profiles" "$VPB_SAVED_PROFILE" || continue
            ((expected_tools += 1))
            if [[ -x "$VPB_BIN_DIR/$name" ]] || command -v "$name" >/dev/null 2>&1; then
                ((ready_tools += 1))
            else
                ((missing_tools += 1))
            fi
        done <"$VPB_MANIFEST"
        issues=$((issues + missing_tools))
    fi

    if [[ -x "$VPB_BIN_DIR/gowitness" ]] || command -v gowitness >/dev/null 2>&1; then
        browser_status=missing
        if command -v chromium >/dev/null 2>&1 || command -v chromium-browser >/dev/null 2>&1 || command -v google-chrome >/dev/null 2>&1; then
            browser_status=ready
        else
            ((issues += 1))
        fi
    fi

    if [[ "$json" == 1 ]]; then
        printf '{\n'
        printf '  "version": "%s",\n' "$VPB_VERSION"
        printf '  "platform": {"distribution": "%s", "release": "%s", "architecture": "%s", "package_manager": "%s"},\n' \
            "$(vpb_json_escape "$VPB_DISTRO_ID")" "$(vpb_json_escape "$VPB_DISTRO_VERSION")" "$VPB_ARCH" "$VPB_PACKAGE_MANAGER"
        printf '  "hardware": {"class": "%s", "cpu": %s, "memory_mb": %s, "disk_free_gb": %s},\n' \
            "$VPB_HARDWARE_CLASS" "$VPB_CPU_COUNT" "$VPB_MEMORY_MB" "$VPB_DISK_FREE_GB"
        printf '  "checks": {"package_manager": "%s", "bin_directory": "%s", "disk": "%s"},\n' \
            "$package_status" "$bin_status" "$disk_status"
        printf '  "profile": {"name": "%s", "expected_tools": %s, "ready_tools": %s, "missing_tools": %s, "browser": "%s"},\n' \
            "$(vpb_json_escape "${VPB_SAVED_PROFILE:-not-set}")" "$expected_tools" "$ready_tools" "$missing_tools" "$browser_status"
        printf '  "healthy": %s\n' "$([[ $issues == 0 ]] && printf true || printf false)"
        printf '}\n'
    else
        show_banner
        section "System"
        printf '  Platform       %s\n' "$(vpb_platform_summary)"
        printf '  Package manager %s (%s)\n' "$VPB_PACKAGE_MANAGER" "$package_status"
        printf '  Binary directory %s (%s)\n' "$VPB_BIN_DIR" "$bin_status"
        printf '  Disk             %s\n' "$disk_status"
        printf '  Recommended      %s profile\n' "$VPB_RECOMMENDED_PROFILE"
        if (( expected_tools > 0 )); then
            printf '  Profile health   %s/%s tools ready\n' "$ready_tools" "$expected_tools"
        fi
        [[ "$browser_status" != not-required ]] && printf '  Screenshot browser %s\n' "$browser_status"
        printf '  State             %s\n' "$VPB_STATE_HOME"
        if (( issues == 0 )); then
            success "VPS Buddy is healthy."
        else
            warn "$issues issue(s) need attention."
            [[ "$bin_status" == not-in-path ]] && printf '  Add %s to PATH and restart your shell.\n' "$VPB_BIN_DIR"
        fi
    fi
    (( issues == 0 ))
}

vpb_status_json() {
    local first=1 name installer version status installed_at
    printf '{"version":"%s","profile":"%s","tools":[' \
        "$(vpb_json_escape "$VPB_VERSION")" "$(vpb_json_escape "${VPB_SAVED_PROFILE:-not-set}")"
    if [[ -f "$VPB_TOOL_STATE" ]]; then
        while IFS=$'\t' read -r name installer version status installed_at; do
            [[ -z "$name" ]] && continue
            (( first )) || printf ','
            first=0
            printf '{"name":"%s","installer":"%s","version":"%s","status":"%s","updated_at":"%s"}' \
                "$(vpb_json_escape "$name")" "$(vpb_json_escape "$installer")" "$(vpb_json_escape "$version")" \
                "$(vpb_json_escape "$status")" "$(vpb_json_escape "$installed_at")"
        done <"$VPB_TOOL_STATE"
    fi
    printf ']}\n'
}
