#!/usr/bin/env bash
# Download and start MediaMTX (RTSP server) if not already running.
# MediaMTX listens on :8554 (RTSP) and :8888 (HLS/HTTP).

set -e

MEDIAMTX_VERSION="1.9.3"
ARCH=$(uname -m)
OS=$(uname -s | tr '[:upper:]' '[:lower:]')

if [[ "$ARCH" == "arm64" || "$ARCH" == "aarch64" ]]; then
  ARCH_LABEL="arm64"
elif [[ "$ARCH" == "x86_64" ]]; then
  ARCH_LABEL="amd64"
else
  echo "Unsupported architecture: $ARCH"
  exit 1
fi

BIN_DIR="$(dirname "$0")/../.mediamtx"
BINARY="$BIN_DIR/mediamtx"

if [[ ! -f "$BINARY" ]]; then
  echo "Downloading MediaMTX v$MEDIAMTX_VERSION..."
  mkdir -p "$BIN_DIR"
  TARBALL="mediamtx_v${MEDIAMTX_VERSION}_${OS}_${ARCH_LABEL}.tar.gz"
  curl -L "https://github.com/bluenviron/mediamtx/releases/download/v${MEDIAMTX_VERSION}/${TARBALL}" \
    -o "$BIN_DIR/$TARBALL"
  tar -xzf "$BIN_DIR/$TARBALL" -C "$BIN_DIR"
  chmod +x "$BINARY"
  echo "MediaMTX downloaded."
fi

echo "Starting MediaMTX on RTSP :8554 ..."
exec "$BINARY"
