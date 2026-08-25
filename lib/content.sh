#!/usr/bin/env bash

# shellcheck shell=bash
# Consumed by the main setup summary.
# shellcheck disable=SC2034

vpb_sync_repository() {
    local name=$1 url=$2 destination=$3
    if [[ -d "$destination/.git" ]]; then
        info "Updating $name."
        run git -C "$destination" pull --ff-only --depth 1
    elif [[ -e "$destination" ]]; then
        warn "$destination exists but is not a Git checkout; leaving it unchanged."
        return 1
    else
        info "Downloading $name."
        run git clone --filter=blob:none --depth 1 "$url" "$destination"
    fi
}

vpb_download_resolver_file() {
    local name=$1 url=$2 destination=$3 temp
    info "Refreshing $name."
    if [[ "${VPB_DRY_RUN:-0}" == 1 ]]; then
        run curl --fail --location --proto '=https' "$url" --output "$destination"
        return
    fi
    temp=$(mktemp "$VPB_CACHE_HOME/resolvers.XXXXXX")
    curl --fail --silent --show-error --location --proto '=https' "$url" --output "$temp"
    if ! awk '/^[0-9a-fA-F:.]+$/ {valid += 1} END {exit valid < 5}' "$temp"; then
        rm -f "$temp"
        error "$name did not contain enough valid resolver addresses."
        return 1
    fi
    install -m 0644 "$temp" "$destination"
    rm -f "$temp"
}

vpb_sync_content() {
    local profile=$1 failures=0
    section "Wordlists and resolver data"
    run mkdir -p "$VPB_WORDLISTS_DIR"

    if [[ -x "$VPB_BIN_DIR/nuclei" ]]; then
        info "Refreshing Nuclei's community templates."
        run "$VPB_BIN_DIR/nuclei" -update-templates || ((failures += 1))
    fi

    vpb_download_resolver_file \
        resolvers \
        'https://raw.githubusercontent.com/trickest/resolvers/main/resolvers.txt' \
        "$VPB_WORDLISTS_DIR/resolvers.txt" || ((failures += 1))
    vpb_download_resolver_file \
        trusted-resolvers \
        'https://raw.githubusercontent.com/trickest/resolvers/main/resolvers-trusted.txt' \
        "$VPB_WORDLISTS_DIR/resolvers-trusted.txt" || ((failures += 1))

    if [[ "$profile" == bug-hunter || "$profile" == advanced ]]; then
        vpb_sync_repository SecLists \
            'https://github.com/danielmiessler/SecLists.git' \
            "$VPB_WORDLISTS_DIR/SecLists" || ((failures += 1))
        vpb_sync_repository GF-Patterns \
            'https://github.com/1ndianl33t/Gf-Patterns.git' \
            "$VPB_WORDLISTS_DIR/Gf-Patterns" || ((failures += 1))
        if [[ "${VPB_DRY_RUN:-0}" != 1 && -d "$VPB_WORDLISTS_DIR/Gf-Patterns" ]]; then
            mkdir -p "$HOME/.gf"
            find "$VPB_WORDLISTS_DIR/Gf-Patterns" -maxdepth 1 -type f -name '*.json' -exec cp -n {} "$HOME/.gf/" \;
        fi
    fi

    if [[ "$profile" == advanced ]]; then
        vpb_sync_repository PayloadsAllTheThings \
            'https://github.com/swisskyrepo/PayloadsAllTheThings.git' \
            "$VPB_WORDLISTS_DIR/PayloadsAllTheThings" || ((failures += 1))
        vpb_sync_repository fuzzDicts \
            'https://github.com/TheKingOfDuck/fuzzDicts.git' \
            "$VPB_WORDLISTS_DIR/fuzzDicts" || ((failures += 1))
    fi

    VPB_CONTENT_FAILURES=$failures
}
