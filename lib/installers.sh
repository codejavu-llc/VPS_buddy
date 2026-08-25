#!/usr/bin/env bash

# shellcheck shell=bash
# Cross-module state is intentionally assigned here.
# shellcheck disable=SC2034

VPB_MIN_GO_VERSION=1.24.0

vpb_commit_binary() {
    local source=$1 name=$2 target_temp
    if [[ "${VPB_DRY_RUN:-0}" == 1 ]]; then
        run install -m 0755 "$source" "$VPB_BIN_DIR/$name"
        return
    fi
    target_temp=$(mktemp "$VPB_BIN_DIR/.${name}.XXXXXX")
    if ! install -m 0755 "$source" "$target_temp"; then
        rm -f "$target_temp"
        return 1
    fi
    mv "$target_temp" "$VPB_BIN_DIR/$name"
}

vpb_manifest_row() {
    local wanted=$1
    awk -F '|' -v tool="$wanted" '$1 == tool {print; exit}' "$VPB_MANIFEST"
}

vpb_manifest_has() {
    [[ -n "$(vpb_manifest_row "$1")" ]]
}

vpb_profile_valid() {
    case "$1" in essential|bug-hunter|advanced) return 0 ;; *) return 1 ;; esac
}

vpb_profile_label() {
    case "$1" in
        essential) printf 'Essential' ;;
        bug-hunter) printf 'Bug Hunter' ;;
        advanced) printf 'Advanced' ;;
    esac
}

vpb_profile_contains() {
    local profiles=$1 profile=$2
    [[ ",$profiles," == *",$profile,"* ]]
}

vpb_profile_tool_count() {
    local profile=$1 count=0 name description profiles installer source version size
    while IFS='|' read -r name description profiles installer source version size; do
        [[ -z "$name" || "$name" == \#* ]] && continue
        vpb_profile_contains "$profiles" "$profile" && ((count += 1))
    done <"$VPB_MANIFEST"
    printf '%s' "$count"
}

vpb_profile_size_mb() {
    local profile=$1 include_content=${2:-1} total=0 name description profiles installer source version size
    while IFS='|' read -r name description profiles installer source version size; do
        [[ -z "$name" || "$name" == \#* ]] && continue
        vpb_profile_contains "$profiles" "$profile" && ((total += size))
    done <"$VPB_MANIFEST"
    if [[ "$include_content" == 1 ]]; then
        case "$profile" in
            essential) ((total += 100)) ;;
            bug-hunter) ((total += 2100)) ;;
            advanced) ((total += 4800)) ;;
        esac
    fi
    printf '%s' "$total"
}

vpb_find_go() {
    local candidate version
    for candidate in "$VPB_DATA_HOME/runtime/go-current/bin/go" "$(command -v go 2>/dev/null || true)"; do
        [[ -n "$candidate" && -x "$candidate" ]] || continue
        version=$($candidate version 2>/dev/null | awk '{sub(/^go/, "", $3); print $3}')
        if [[ -n "$version" ]] && version_ge "$version" "$VPB_MIN_GO_VERSION"; then
            VPB_GO_CMD=$candidate
            export GOPATH="$VPB_DATA_HOME/go"
            export GOTOOLCHAIN=auto
            return 0
        fi
    done
    return 1
}

vpb_install_go() {
    if vpb_find_go; then
        info "Using $($VPB_GO_CMD version)."
        return
    fi

    section "Go toolchain"
    if [[ "${VPB_DRY_RUN:-0}" == 1 ]]; then
        run curl --fail --location --proto '=https' https://go.dev/dl/?mode=json
        info "Would install the current verified Go release for $VPB_ARCH."
        VPB_GO_CMD=go
        return
    fi

    command -v jq >/dev/null 2>&1 || die "jq is required to select a verified Go archive."
    local metadata archive_file sha version download_dir archive_path install_dir staging_dir
    metadata=$(curl --fail --silent --show-error --location --proto '=https' 'https://go.dev/dl/?mode=json')
    IFS=$'\t' read -r archive_file sha version < <(
        jq -r --arg arch "$VPB_ARCH" '.[] | select(.stable == true) | . as $release | .files[] | select(.os == "linux" and .arch == $arch and .kind == "archive") | [.filename, .sha256, $release.version] | @tsv' <<<"$metadata" | head -n1
    )
    [[ -n "$archive_file" && -n "$sha" && -n "$version" ]] || die "No stable Go archive is available for $VPB_ARCH."

    download_dir=$(mktemp -d "$VPB_CACHE_HOME/go.XXXXXX")
    archive_path="$download_dir/$archive_file"
    install_dir="$VPB_DATA_HOME/runtime/$version-${sha:0:12}"
    info "Downloading $version for $VPB_ARCH."
    curl --fail --show-error --location --proto '=https' "https://go.dev/dl/$archive_file" --output "$archive_path"
    printf '%s  %s\n' "$sha" "$archive_path" | sha256sum --check --status || die "Go archive checksum verification failed."

    staging_dir=$(mktemp -d "$VPB_DATA_HOME/runtime/.go-${version}.XXXXXX")
    tar -C "$staging_dir" --strip-components=1 -xzf "$archive_path"
    [[ -x "$staging_dir/bin/go" ]] || die "The verified Go archive did not contain the expected executable."
    if [[ ! -d "$install_dir" ]]; then
        mv "$staging_dir" "$install_dir"
    else
        rm -rf -- "$staging_dir"
    fi
    ln -sfn "$install_dir" "$VPB_DATA_HOME/runtime/go-current"
    rm -f "$archive_path"
    rmdir "$download_dir" 2>/dev/null || true
    VPB_GO_CMD="$VPB_DATA_HOME/runtime/go-current/bin/go"
    export GOPATH="$VPB_DATA_HOME/go"
    export GOTOOLCHAIN=auto
    success "Installed verified $version."
}

vpb_install_go_tool() {
    local name=$1 source=$2 requested=$3
    local build_dir binary actual
    if [[ "${VPB_DRY_RUN:-0}" == 1 ]]; then
        build_dir="$VPB_CACHE_HOME/build-$name"
    else
        build_dir=$(mktemp -d "$VPB_CACHE_HOME/build-${name}.XXXXXX")
    fi

    info "Installing $name."
    if [[ "${VPB_DRY_RUN:-0}" == 1 ]]; then
        run env GOBIN="$build_dir" GOMAXPROCS="$VPB_BUILD_JOBS" "$VPB_GO_CMD" install "$source@$requested"
        vpb_commit_binary "$build_dir/$name" "$name"
        return
    fi

    if ! env GOBIN="$build_dir" GOMAXPROCS="$VPB_BUILD_JOBS" "$VPB_GO_CMD" install "$source@$requested"; then
        error "$name failed to compile."
        vpb_state_record_failure "$name" go "$requested"
        rm -f "$build_dir/$name"
        rmdir "$build_dir" 2>/dev/null || true
        return 1
    fi
    binary="$build_dir/$name"
    if [[ ! -x "$binary" ]]; then
        error "$name built without the expected binary."
        vpb_state_record_failure "$name" go "$requested"
        return 1
    fi
    actual=$(vpb_actual_go_version "$binary")
    vpb_commit_binary "$binary" "$name"
    rm -f "$binary"
    rmdir "$build_dir" 2>/dev/null || true
    vpb_state_record "$name" go "$actual" ok
    vpb_lock_record "$name" "$source" "$actual"
    success "$name $actual"
}

vpb_install_pipx_tool() {
    local name=$1 source=$2 requested=$3 actual=unknown specification=$2
    [[ "$requested" == latest ]] || specification="$source==$requested"
    vpb_ensure_pipx
    info "Installing $name in an isolated Python environment."
    if [[ "${VPB_DRY_RUN:-0}" == 1 ]]; then
        run env PIPX_HOME="$VPB_DATA_HOME/pipx" PIPX_BIN_DIR="$VPB_BIN_DIR" "$VPB_PIPX_CMD" install --force "$specification"
        return
    fi

    if ! env PIPX_HOME="$VPB_DATA_HOME/pipx" PIPX_BIN_DIR="$VPB_BIN_DIR" "$VPB_PIPX_CMD" install --force "$specification"; then
        error "$name failed to install through pipx."
        vpb_state_record_failure "$name" pipx "$requested"
        return 1
    fi
    if [[ -x "$VPB_BIN_DIR/$name" ]]; then
        actual=$("$VPB_BIN_DIR/$name" --version 2>/dev/null | head -n1 | tr '\t ' '_' | cut -c1-40 || printf 'installed')
    fi
    [[ -n "$actual" ]] || actual=installed
    vpb_state_record "$name" pipx "$actual" ok
    vpb_lock_record "$name" "$source" "$actual"
    success "$name $actual"
}

vpb_install_github_release_tool() {
    local name=$1 source=$2 requested=$3
    local metadata tag version asset primary_asset alternate_asset release_arch checksum_asset asset_url checksum_url
    local metadata_url download_dir archive_path checksum_path expected archive_listing binary

    [[ "$source" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || {
        error "$name has an invalid GitHub repository identifier."
        vpb_state_record_failure "$name" github-release "$requested"
        return 1
    }

    info "Installing $name from its verified GitHub release."
    if [[ "$requested" == latest ]]; then
        metadata_url="https://api.github.com/repos/$source/releases/latest"
    else
        metadata_url="https://api.github.com/repos/$source/releases/tags/$requested"
    fi
    if [[ "${VPB_DRY_RUN:-0}" == 1 ]]; then
        run curl --fail --location --proto '=https' "$metadata_url"
        info "Would select and verify the $name release for linux/$VPB_ARCH."
        return
    fi

    command -v jq >/dev/null 2>&1 || {
        error "jq is required to select $name release artifacts."
        vpb_state_record_failure "$name" github-release "$requested"
        return 1
    }
    metadata=$(curl --fail --silent --show-error --location --proto '=https' "$metadata_url") || {
        error "$name release metadata could not be downloaded."
        vpb_state_record_failure "$name" github-release "$requested"
        return 1
    }

    tag=$(jq -r '.tag_name // empty' <<<"$metadata")
    [[ -n "$tag" ]] || {
        error "$name release metadata did not contain a tag."
        vpb_state_record_failure "$name" github-release "$requested"
        return 1
    }
    version=${tag#v}
    case "$VPB_ARCH" in
        amd64) release_arch=64bit ;;
        arm64) release_arch=ARM64 ;;
        armv6l) release_arch=ARM ;;
        386) release_arch=32bit ;;
        *) release_arch=$VPB_ARCH ;;
    esac
    primary_asset="${name}_${version}_linux_${VPB_ARCH}.tar.gz"
    alternate_asset="${name}_${version}_Linux-${release_arch}.tar.gz"
    asset=$(jq -r --arg primary "$primary_asset" --arg alternate "$alternate_asset" \
        '[.assets[] | select(.name == $primary or .name == $alternate)][0].name // empty' <<<"$metadata")
    checksum_asset="${name}_${version}_checksums.txt"
    asset_url=$(jq -r --arg name "$asset" '.assets[] | select(.name == $name) | .browser_download_url' <<<"$metadata")
    checksum_url=$(jq -r --arg name "$checksum_asset" '.assets[] | select(.name == $name) | .browser_download_url' <<<"$metadata")
    [[ -n "$asset_url" && -n "$checksum_url" ]] || {
        error "$name $tag does not provide verified linux/$VPB_ARCH artifacts."
        vpb_state_record_failure "$name" github-release "$tag"
        return 1
    }

    download_dir=$(mktemp -d "$VPB_CACHE_HOME/release-${name}.XXXXXX")
    archive_path="$download_dir/$asset"
    checksum_path="$download_dir/$checksum_asset"
    if ! curl --fail --show-error --location --proto '=https' "$asset_url" --output "$archive_path" ||
       ! curl --fail --show-error --location --proto '=https' "$checksum_url" --output "$checksum_path"; then
        error "$name $tag could not be downloaded."
        vpb_state_record_failure "$name" github-release "$tag"
        rm -rf -- "$download_dir"
        return 1
    fi
    expected=$(awk -v asset="$asset" '$2 == asset {print $1; exit}' "$checksum_path")
    if [[ ! "$expected" =~ ^[A-Fa-f0-9]{64}$ ]] ||
       ! printf '%s  %s\n' "$expected" "$archive_path" | sha256sum --check --status; then
        error "$name $tag checksum verification failed."
        vpb_state_record_failure "$name" github-release "$tag"
        rm -rf -- "$download_dir"
        return 1
    fi
    archive_listing=$(tar -tzf "$archive_path") || {
        error "$name $tag archive could not be read."
        vpb_state_record_failure "$name" github-release "$tag"
        rm -rf -- "$download_dir"
        return 1
    }
    if grep -Eq '(^/|(^|/)\.\.(/|$))' <<<"$archive_listing"; then
        error "$name $tag contains an unsafe archive path."
        vpb_state_record_failure "$name" github-release "$tag"
        rm -rf -- "$download_dir"
        return 1
    fi
    if ! tar -xzf "$archive_path" -C "$download_dir"; then
        error "$name $tag could not be extracted."
        vpb_state_record_failure "$name" github-release "$tag"
        rm -rf -- "$download_dir"
        return 1
    fi
    binary=$(find "$download_dir" -type f -name "$name" -print -quit)
    if [[ -z "$binary" || ! -x "$binary" ]]; then
        error "$name $tag did not contain the expected executable."
        vpb_state_record_failure "$name" github-release "$tag"
        rm -rf -- "$download_dir"
        return 1
    fi
    if ! vpb_commit_binary "$binary" "$name"; then
        error "$name $tag could not be committed to $VPB_BIN_DIR."
        vpb_state_record_failure "$name" github-release "$tag"
        rm -rf -- "$download_dir"
        return 1
    fi
    rm -rf -- "$download_dir"
    vpb_state_record "$name" github-release "$tag" ok
    vpb_lock_record "$name" "$source" "$tag"
    success "$name $tag"
}

vpb_install_source_tool() {
    local name=$1 source=$2 requested=$3 checkout actual
    checkout="$VPB_TOOLS_DIR/$name"
    info "Building $name from its maintained source repository."
    if [[ "${VPB_DRY_RUN:-0}" == 1 ]]; then
        run git clone --filter=blob:none --depth 1 --branch "$requested" "$source" "$checkout"
        run make -C "$checkout" -j "$VPB_BUILD_JOBS"
        vpb_commit_binary "$checkout/bin/$name" "$name"
        return
    fi

    if [[ -d "$checkout/.git" && -f "$checkout/.git/vpsbuddy-managed" ]]; then
        if ! git -C "$checkout" fetch --depth 1 origin "$requested" || ! git -C "$checkout" checkout --detach FETCH_HEAD; then
            error "$name source could not be updated safely."
            vpb_state_record_failure "$name" source "$requested"
            return 1
        fi
    elif [[ -e "$checkout" ]]; then
        error "$checkout exists but is not marked as VPS Buddy-managed; leaving it unchanged."
        vpb_state_record_failure "$name" source "$requested"
        return 1
    else
        if ! git clone --filter=blob:none --depth 1 --branch "$requested" "$source" "$checkout"; then
            error "$name source could not be downloaded."
            vpb_state_record_failure "$name" source "$requested"
            return 1
        fi
        touch "$checkout/.git/vpsbuddy-managed"
    fi
    if ! make -C "$checkout" -j "$VPB_BUILD_JOBS"; then
        error "$name failed to compile."
        vpb_state_record_failure "$name" source "$requested"
        return 1
    fi
    if [[ ! -x "$checkout/bin/$name" ]]; then
        error "$name compiled without the expected binary."
        vpb_state_record_failure "$name" source "$requested"
        return 1
    fi
    vpb_commit_binary "$checkout/bin/$name" "$name"
    actual=$(git -C "$checkout" rev-parse --short=12 HEAD)
    vpb_state_record "$name" source "$actual" ok
    vpb_lock_record "$name" "$source" "$actual"
    success "$name $actual"
}

vpb_install_tool() {
    local name=$1 force=${2:-0} row description profiles installer source version size
    row=$(vpb_manifest_row "$name")
    [[ -n "$row" ]] || { error "Unknown tool: $name"; return 1; }
    IFS='|' read -r name description profiles installer source version size <<<"$row"

    if [[ "$force" != 1 ]] && command -v "$name" >/dev/null 2>&1; then
        if vpb_state_has "$name"; then
            info "$name is already recorded and ready."
            return 0
        elif [[ "$(vpb_state_status "$name" 2>/dev/null || true)" != failed ]]; then
            info "$name is already available; leaving it unchanged."
            vpb_state_record "$name" external "$(command -v "$name")" ok
            return 0
        fi
        info "Retrying the previously failed $name installation."
    fi

    case "$installer" in
        go) vpb_install_go_tool "$name" "$source" "$version" ;;
        pipx) vpb_install_pipx_tool "$name" "$source" "$version" ;;
        github-release) vpb_install_github_release_tool "$name" "$source" "$version" ;;
        source) vpb_install_source_tool "$name" "$source" "$version" ;;
        *) error "No installer for $name ($installer)."; return 1 ;;
    esac
}

vpb_install_profile_tools() {
    local profile=$1 failures=0 name description profiles installer source version size
    section "Security tools"
    while IFS='|' read -r name description profiles installer source version size; do
        [[ -z "$name" || "$name" == \#* ]] && continue
        vpb_profile_contains "$profiles" "$profile" || continue
        vpb_install_tool "$name" 0 || ((failures += 1))
    done <"$VPB_MANIFEST"
    VPB_INSTALL_FAILURES=$failures
}

vpb_update_installed_tools() {
    local only=${1:-} failures=0 name installer current status installed_at
    [[ -s "$VPB_TOOL_STATE" ]] || die "No VPS Buddy tool state found. Run 'vpsbuddy setup' first."
    [[ -z "$only" ]] || vpb_state_knows "$only" || die "$only is not recorded in VPS Buddy state."
    while IFS=$'\t' read -r name installer current status installed_at; do
        [[ -z "$name" || "$status" != ok ]] && continue
        [[ -z "$only" || "$name" == "$only" ]] || continue
        if [[ "$installer" == external ]]; then
            info "Skipping externally managed $name."
            continue
        fi
        vpb_install_tool "$name" 1 || ((failures += 1))
    done <"$VPB_TOOL_STATE"
    (( failures == 0 )) || return 1
}

vpb_remove_tool() {
    local name=$1 row installer source version managed_installer
    row=$(vpb_manifest_row "$name")
    [[ -n "$row" ]] || die "Unknown tool: $name"
    IFS='|' read -r name _ _ installer source version _ <<<"$row"
    managed_installer=$(awk -F '\t' -v tool="$name" '$1 == tool && $4 == "ok" {value=$2} END {print value}' "$VPB_TOOL_STATE" 2>/dev/null || true)
    [[ -n "$managed_installer" ]] || die "$name is not recorded as a VPS Buddy-managed installation."
    [[ "$managed_installer" != external ]] || die "$name is managed externally and will not be removed."

    if [[ "$installer" == pipx ]]; then
        vpb_ensure_pipx
        run env PIPX_HOME="$VPB_DATA_HOME/pipx" PIPX_BIN_DIR="$VPB_BIN_DIR" "$VPB_PIPX_CMD" uninstall "$source"
    else
        run rm -f "$VPB_BIN_DIR/$name"
    fi
    vpb_state_remove "$name"
    vpb_lock_remove "$name"
    success "Removed VPS Buddy's $name installation."
}
