#!/usr/bin/env bash
#
# Installs the latest Kesami release into /Applications.
#
#   curl -fsSL https://raw.githubusercontent.com/xenxorowdy/kesami-releases/main/install.sh | bash
#
# Kesami is not notarized by Apple, so macOS may still show a security
# warning on first launch. This script does not disable Gatekeeper, change
# SIP, or remove quarantine attributes.
#
# Environment overrides:
#   KESAMI_REPO         GitHub repo to install from (default xenxorowdy/kesami-releases)
#   KESAMI_INSTALL_DIR  Where to put Kesami.app (default /Applications)

set -euo pipefail

REPO="${KESAMI_REPO:-xenxorowdy/kesami-releases}"
INSTALL_DIR="${KESAMI_INSTALL_DIR:-/Applications}"
APP_NAME="Kesami"

WORK_DIR=""
MOUNT_POINT=""

say() { printf '==> %s\n' "$*"; }
fail() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

cleanup() {
    if [ -n "$MOUNT_POINT" ] && [ -d "$MOUNT_POINT" ]; then
        hdiutil detach "$MOUNT_POINT" -quiet >/dev/null 2>&1 || hdiutil detach "$MOUNT_POINT" -force -quiet >/dev/null 2>&1 || true
    fi
    if [ -n "$WORK_DIR" ] && [ -d "$WORK_DIR" ]; then
        rm -rf "$WORK_DIR"
    fi
}

need() {
    command -v "$1" >/dev/null 2>&1 || fail "'$1' is required but was not found."
}

detect_arch() {
    local arch
    arch="$(uname -m)"
    if [ "$arch" = "x86_64" ] && [ "$(sysctl -in sysctl.proc_translated 2>/dev/null)" = "1" ]; then
        arch="arm64"
    fi
    case "$arch" in
        arm64) echo "arm64" ;;
        x86_64) echo "x64" ;;
        *) fail "Unsupported CPU architecture: $arch" ;;
    esac
}

pick_asset() {
    local arch="$1" urls="$2" ext url
    for ext in dmg zip; do
        if [ "$arch" = "arm64" ]; then
            url="$(grep -E -- "-arm64(-mac)?\.${ext}$" <<<"$urls" | head -n 1 || true)"
        else
            url="$(grep -E -- "-x64(-mac)?\.${ext}$" <<<"$urls" | head -n 1 || true)"
            [ -n "$url" ] || url="$(grep -E "\.${ext}$" <<<"$urls" | grep -vE -- "-(arm64|universal)(-mac)?\.${ext}$" | head -n 1 || true)"
        fi
        [ -n "$url" ] || url="$(grep -E -- "-universal(-mac)?\.${ext}$" <<<"$urls" | head -n 1 || true)"
        if [ -n "$url" ]; then
            echo "$url"
            return 0
        fi
    done
    return 1
}

as_admin() {
    if [ -w "$INSTALL_DIR" ]; then
        "$@"
    else
        sudo "$@"
    fi
}

main() {
    [ "$(uname -s)" = "Darwin" ] || fail "Kesami is a macOS app; this installer only runs on macOS."
    for tool in curl hdiutil ditto codesign grep sed; do need "$tool"; done
    [ -d "$INSTALL_DIR" ] || fail "Install folder $INSTALL_DIR does not exist."

    local arch release urls url tag file source_app target staged backup
    arch="$(detect_arch)"

    say "Looking up the latest Kesami release"
    release="$(curl -fsSL -H 'Accept: application/vnd.github+json' "https://api.github.com/repos/${REPO}/releases/latest" 2>/dev/null)" ||
        fail "Could not reach GitHub for ${REPO}. Check your internet connection, or wait a few minutes if GitHub is rate-limiting you."
    tag="$(grep -m 1 -o '"tag_name": *"[^"]*"' <<<"$release" | sed 's/.*"\([^"]*\)"$/\1/' || true)"
    urls="$(grep -o '"browser_download_url": *"[^"]*"' <<<"$release" | sed 's/.*"\([^"]*\)"$/\1/' | grep -vE '\.blockmap$' || true)"
    [ -n "$urls" ] || fail "The latest release${tag:+ ($tag)} has no downloadable files yet."

    url="$(pick_asset "$arch" "$urls")" || {
        if [ "$arch" = "x64" ]; then
            fail "Kesami${tag:+ $tag} currently only supports Apple Silicon Macs (M1 or newer). There is no Intel build yet."
        fi
        fail "No macOS download for $arch was found in release${tag:+ $tag}."
    }

    WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/kesami-install.XXXXXX")"
    trap cleanup EXIT
    trap 'exit 130' INT TERM
    file="$WORK_DIR/${url##*/}"

    say "Downloading ${url##*/}${tag:+ ($tag)}"
    curl -fL --progress-bar -o "$file" "$url" || fail "Download failed. Please try again."

    case "$file" in
        *.dmg)
            MOUNT_POINT="$WORK_DIR/mount"
            mkdir -p "$MOUNT_POINT"
            hdiutil attach "$file" -nobrowse -readonly -noautoopen -mountpoint "$MOUNT_POINT" -quiet ||
                fail "Could not open the disk image. The download may be corrupted; please try again."
            source_app="$MOUNT_POINT/$APP_NAME.app"
            ;;
        *.zip)
            ditto -x -k "$file" "$WORK_DIR/unzipped" || fail "Could not extract the zip. The download may be corrupted; please try again."
            source_app="$WORK_DIR/unzipped/$APP_NAME.app"
            ;;
    esac
    [ -d "$source_app" ] || fail "$APP_NAME.app was not found inside ${url##*/}."
    codesign --verify --deep --strict "$source_app" >/dev/null 2>&1 ||
        fail "The downloaded app failed its integrity check. Please try again; if it keeps failing, report it at https://github.com/${REPO}/issues."

    target="$INSTALL_DIR/$APP_NAME.app"
    if pgrep -f "$target/Contents/MacOS/" >/dev/null 2>&1; then
        fail "$APP_NAME is running. Quit it (menu bar icon → Quit) and run this installer again."
    fi

    if [ ! -w "$INSTALL_DIR" ]; then
        say "Administrator permission is needed to write to $INSTALL_DIR"
    fi

    staged="$INSTALL_DIR/.$APP_NAME.app.installing-$$"
    backup="$INSTALL_DIR/.$APP_NAME.app.previous-$$"
    say "Installing to $target"
    as_admin rm -rf "$staged"
    as_admin ditto "$source_app" "$staged" || {
        as_admin rm -rf "$staged"
        fail "Could not copy $APP_NAME into $INSTALL_DIR."
    }
    if [ -e "$target" ]; then
        as_admin mv "$target" "$backup" || {
            as_admin rm -rf "$staged"
            fail "Could not replace the existing $target."
        }
    fi
    if ! as_admin mv "$staged" "$target"; then
        [ -e "$backup" ] && as_admin mv "$backup" "$target"
        as_admin rm -rf "$staged"
        fail "Could not finish installing; your previous version was restored."
    fi
    [ -e "$backup" ] && as_admin rm -rf "$backup"

    say "$APP_NAME${tag:+ $tag} is installed in $INSTALL_DIR."
    cat <<EOF

Open it from Applications or Spotlight.

Kesami is not notarized by Apple. If macOS says it cannot verify the app,
open System Settings → Privacy & Security, scroll down, and click
"Open Anyway" next to the Kesami message. You only need to do this once.
EOF
}

main "$@"
