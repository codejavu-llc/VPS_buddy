#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

VPB_REPOSITORY=${VPB_REPOSITORY:-codejavu-llc/VPS_buddy}
VPB_REF=${VPB_REF:-stable}
VPB_PREFIX=${VPB_PREFIX:-$HOME/.local}
VPB_CLI_ONLY=0
VPB_FORCE_REMOTE=0
VPB_INSTALL_TEMP=""
VPB_SETUP_ARGS=()

installer_usage() {
    cat <<'EOF'
Install the VPS Buddy CLI and optionally configure this VPS.

Usage: install.sh [options] [-- setup-options]

  --cli-only        Install VPS Buddy without running setup
  --prefix DIR      CLI prefix (default: ~/.local)
  --ref REF         Release tag, stable, or main (default: stable)
  --remote          Fetch an archive even when run from a local checkout
  -y, --yes         Pass confirmation to VPS Buddy setup
  -h, --help        Show this help

Any other options are passed to `vpsbuddy setup`.
EOF
}

cleanup() {
    [[ -n "$VPB_INSTALL_TEMP" && -d "$VPB_INSTALL_TEMP" ]] || return 0
    rm -rf -- "$VPB_INSTALL_TEMP"
}
trap cleanup EXIT

while (($#)); do
    case "$1" in
        --cli-only) VPB_CLI_ONLY=1; shift ;;
        --remote) VPB_FORCE_REMOTE=1; shift ;;
        --prefix) [[ $# -ge 2 ]] || { printf 'install.sh: --prefix requires a directory\n' >&2; exit 1; }; VPB_PREFIX=$2; shift 2 ;;
        --ref) [[ $# -ge 2 ]] || { printf 'install.sh: --ref requires a value\n' >&2; exit 1; }; VPB_REF=$2; shift 2 ;;
        -h|--help) installer_usage; exit 0 ;;
        --) shift; VPB_SETUP_ARGS+=("$@"); break ;;
        *) VPB_SETUP_ARGS+=("$1"); shift ;;
    esac
done

SOURCE_DIR=""
if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]]; then
    SOURCE_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)
fi
if (( VPB_FORCE_REMOTE )) || [[ ! -f "$SOURCE_DIR/vpsbuddy" || ! -d "$SOURCE_DIR/lib" ]]; then
    command -v curl >/dev/null 2>&1 || { printf 'VPS Buddy requires curl for remote installation.\n' >&2; exit 1; }
    command -v tar >/dev/null 2>&1 || { printf 'VPS Buddy requires tar for remote installation.\n' >&2; exit 1; }
    VPB_INSTALL_TEMP=$(mktemp -d "${TMPDIR:-/tmp}/vpsbuddy-install.XXXXXX")
    ARCHIVE="$VPB_INSTALL_TEMP/source.tar.gz"
    CHECKSUM_URL=""
    if [[ "$VPB_REF" == stable ]]; then
        URL="https://github.com/$VPB_REPOSITORY/releases/latest/download/VPS-Buddy.tar.gz"
        CHECKSUM_URL="https://github.com/$VPB_REPOSITORY/releases/latest/download/VPS-Buddy.tar.gz.sha256"
    elif [[ "$VPB_REF" == main ]]; then
        URL="https://github.com/$VPB_REPOSITORY/archive/main.tar.gz"
        printf 'Warning: installing the development branch without a published release checksum.\n' >&2
    else
        URL="https://github.com/$VPB_REPOSITORY/releases/download/$VPB_REF/VPS-Buddy.tar.gz"
        CHECKSUM_URL="https://github.com/$VPB_REPOSITORY/releases/download/$VPB_REF/VPS-Buddy.tar.gz.sha256"
    fi
    printf 'Downloading VPS Buddy from %s (%s)...\n' "$VPB_REPOSITORY" "$VPB_REF"
    curl --fail --show-error --location --proto '=https' "$URL" --output "$ARCHIVE"
    EXPECTED_SHA=${VPB_ARCHIVE_SHA256:-}
    if [[ -z "$EXPECTED_SHA" && -n "$CHECKSUM_URL" ]]; then
        EXPECTED_SHA=$(curl --fail --silent --show-error --location --proto '=https' "$CHECKSUM_URL" | awk 'NR == 1 {print $1}')
    fi
    if [[ -n "$EXPECTED_SHA" ]]; then
        printf '%s  %s\n' "$EXPECTED_SHA" "$ARCHIVE" | sha256sum --check --status || {
            printf 'VPS Buddy archive checksum verification failed.\n' >&2
            exit 1
        }
    elif [[ "$VPB_REF" != main ]]; then
        printf 'A checksum was required but could not be retrieved.\n' >&2
        exit 1
    fi
    tar -xzf "$ARCHIVE" -C "$VPB_INSTALL_TEMP"
    SOURCE_ENTRY=$(find "$VPB_INSTALL_TEMP" -mindepth 2 -maxdepth 2 -type f -name vpsbuddy -print -quit)
    [[ -n "$SOURCE_ENTRY" ]] || { printf 'Downloaded archive has an unexpected layout.\n' >&2; exit 1; }
    SOURCE_DIR=$(dirname "$SOURCE_ENTRY")
    [[ -n "$SOURCE_DIR" && -f "$SOURCE_DIR/vpsbuddy" ]] || { printf 'Downloaded archive has an unexpected layout.\n' >&2; exit 1; }
fi

BIN_DIR="$VPB_PREFIX/bin"
RELEASES_DIR="$VPB_PREFIX/share/vpsbuddy/releases"
CURRENT_LINK="$VPB_PREFIX/share/vpsbuddy/current"
CLI_LINK="$BIN_DIR/vpsbuddy"
[[ ! -e "$CURRENT_LINK" || -L "$CURRENT_LINK" ]] || { printf '%s exists and is not a symlink; refusing to overwrite it.\n' "$CURRENT_LINK" >&2; exit 1; }
[[ ! -e "$CLI_LINK" || -L "$CLI_LINK" ]] || { printf '%s exists and is not a symlink; refusing to overwrite it.\n' "$CLI_LINK" >&2; exit 1; }
mkdir -p "$RELEASES_DIR" "$BIN_DIR"
APP_VERSION=$(awk -F= '$1 == "VPB_VERSION" {print $2; exit}' "$SOURCE_DIR/vpsbuddy")
[[ "$APP_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][A-Za-z0-9.-]+)?$ ]] || { printf 'The source contains an invalid application version.\n' >&2; exit 1; }
APP_DIR=$(mktemp -d "$RELEASES_DIR/$APP_VERSION-$(date -u +'%Y%m%d%H%M%S').XXXXXX")
mkdir -p "$APP_DIR/lib" "$APP_DIR/manifests"
cp "$SOURCE_DIR/vpsbuddy" "$SOURCE_DIR/VPS_buddy.sh" "$SOURCE_DIR/install.sh" "$APP_DIR/"
cp -R "$SOURCE_DIR/lib"/. "$APP_DIR/lib"/
cp -R "$SOURCE_DIR/manifests"/. "$APP_DIR/manifests"/
chmod 0755 "$APP_DIR/vpsbuddy" "$APP_DIR/VPS_buddy.sh" "$APP_DIR/install.sh"
ln -sfn "$APP_DIR" "$CURRENT_LINK"
ln -sfn "$CURRENT_LINK/vpsbuddy" "$CLI_LINK"

case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *)
        if [[ "$BIN_DIR" == "$HOME/.local/bin" ]]; then
            MARKER='# VPS Buddy user binaries'
            # This line is written literally into shell profiles.
            # shellcheck disable=SC2016
            PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'
            PROFILES=("$HOME/.profile")
            case "${SHELL:-}" in
                */bash) PROFILES+=("$HOME/.bashrc") ;;
                */zsh) PROFILES+=("$HOME/.zshrc") ;;
            esac
            for PROFILE in "${PROFILES[@]}"; do
                touch "$PROFILE"
                if ! grep -Fq "$PATH_LINE" "$PROFILE"; then
                    {
                        printf '\n%s\n' "$MARKER"
                        printf '%s\n' "$PATH_LINE"
                    } >>"$PROFILE"
                fi
            done
        else
            printf 'Add %s to PATH to use VPS Buddy from a new shell.\n' "$BIN_DIR"
        fi
        ;;
esac

printf 'Installed VPS Buddy at %s\n' "$BIN_DIR/vpsbuddy"
if (( VPB_CLI_ONLY == 0 )); then
    cleanup
    VPB_INSTALL_TEMP=""
    exec "$BIN_DIR/vpsbuddy" setup "${VPB_SETUP_ARGS[@]}"
fi
