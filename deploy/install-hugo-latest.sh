#!/usr/bin/env bash
set -euo pipefail

# Install Hugo Extended (latest) on Ubuntu/Debian (or other Linux)
# Matches CI: peaceiris/actions-hugo uses `hugo-version: latest` with `extended: true`.

echo "[hugo-install] Detecting architecture..."
ARCH=$(uname -m)
case "$ARCH" in
  x86_64|amd64)
    PKG_ARCH="linux-amd64"
    DEB_ARCH="Linux-64bit"
    ;;
  aarch64|arm64)
    PKG_ARCH="linux-arm64"
    DEB_ARCH="Linux-ARM64"
    ;;
  *)
    echo "Unsupported architecture: $ARCH" >&2
    echo "Supported: x86_64/amd64, aarch64/arm64" >&2
    exit 1
    ;;
esac

need_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "Missing required command: $1" >&2; exit 1; }; }
need_cmd curl
need_cmd tar

echo "[hugo-install] Fetching latest Hugo release tag..."
# Try GitHub API first, fallback to redirect method
LATEST_TAG=$(curl -fsSL https://api.github.com/repos/gohugoio/hugo/releases/latest | grep -m1 '"tag_name"' | cut -d '"' -f4 || true)
if [[ -z "${LATEST_TAG:-}" ]]; then
  # Fallback: follow redirect to extract tag
  REDIR=$(curl -fsSLI -o /dev/null -w '%{redirect_url}' https://github.com/gohugoio/hugo/releases/latest || true)
  LATEST_TAG=${REDIR##*/}
fi

if [[ -z "${LATEST_TAG:-}" ]]; then
  echo "[hugo-install] Failed to resolve latest tag" >&2
  exit 1
fi

VER=${LATEST_TAG#v}
echo "[hugo-install] Latest tag: $LATEST_TAG (version: $VER)"

TMPDIR=$(mktemp -d)
cleanup() { rm -rf "$TMPDIR"; }
trap cleanup EXIT

# Prefer tar.gz to avoid dpkg deps
TAR_NAME="hugo_extended_${VER}_${PKG_ARCH}.tar.gz"
URL="https://github.com/gohugoio/hugo/releases/download/${LATEST_TAG}/${TAR_NAME}"

echo "[hugo-install] Downloading: $URL"
curl -fsSL "$URL" -o "$TMPDIR/$TAR_NAME"

echo "[hugo-install] Extracting hugo binary..."
tar -xz -C "$TMPDIR" -f "$TMPDIR/$TAR_NAME" hugo

echo "[hugo-install] Installing to /usr/local/bin (sudo may be required)"
sudo install -m 0755 "$TMPDIR/hugo" /usr/local/bin/hugo

echo "[hugo-install] Verifying installation..."
if ! command -v hugo >/dev/null 2>&1; then
  echo "[hugo-install] hugo not found after install" >&2
  exit 1
fi

HUGO_VER_OUTPUT=$(hugo version || true)
echo "[hugo-install] $(echo "$HUGO_VER_OUTPUT" | head -1)"

if ! echo "$HUGO_VER_OUTPUT" | grep -qi "Extended"; then
  echo "[hugo-install] Warning: Installed Hugo does not report 'Extended' variant." >&2
  echo "This build may not support SCSS/SASS. Consider using the .deb installer if needed." >&2
fi

echo "[hugo-install] Done."

