#!/usr/bin/env bash

set -e

SHFMT_VERSION=${1:-"3.5.1"}
SCRIPT=("${BASH_SOURCE[@]}")
SCRIPT_PATH="${SCRIPT##*/}"
SCRIPT_NAME="${SCRIPT_PATH%.*}"
MARKER_FILE="/usr/local/etc/codespace-markers/${SCRIPT_NAME}"
MARKER_FILE_DIR=$(dirname "${MARKER_FILE}")

if [ "$(id -u)" -ne 0 ]; then
  echo -e 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
  exit 1
fi

function check_packages() {
  if ! apk info --installed "$@" >/dev/null 2>&1; then
    apk update
    apk add --no-cache --latest "$@"
  fi
}

function shfmt_inst() {
  case "$OSTYPE" in
  linux-*)
    OS=linux
    ;;
  esac
  machine=$(uname -m)
  case "$machine" in
  x86_64)
    ARCH=amd64
    ;;
  esac
  curl -O -L -C - https://github.com/mvdan/sh/releases/download/v$SHFMT_VERSION/shfmt_v"$SHFMT_VERSION"_"$OS"_"$ARCH" &&
    mv shfmt_v"$SHFMT_VERSION"_"$OS"_"$ARCH" /usr/local/bin/shfmt &&
    chmod +x /usr/local/bin/shfmt &&
    chown root /usr/local/bin/shfmt &&
    chgrp root /usr/local/bin/shfmt
}

if [ -f "${MARKER_FILE}" ]; then
  echo "Marker file found:"
  cat "${MARKER_FILE}"
  # shellcheck source=/dev/null
  source "${MARKER_FILE}"
fi

if [ "${SHFMT_ALREADY_INSTALLED}" != "true" ]; then
  check_packages \
    ca-certificates \
    curl
  shfmt_inst
  SHFMT_ALREADY_INSTALLED="true"
fi

if [ ! -d "$MARKER_FILE_DIR" ]; then
  mkdir -p "$MARKER_FILE_DIR"
fi

echo -e "\
    SHFMT_ALREADY_INSTALLED=${SHFMT_ALREADY_INSTALLED}" >"${MARKER_FILE}"
