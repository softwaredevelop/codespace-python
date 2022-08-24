#!/usr/bin/env bash

set -e

SHELLCHECK_VERSION=${1:-"0.8.0"}
CONTAINER_OS=${2:-"alpine"}
SCRIPT=("${BASH_SOURCE[@]}")
SCRIPT_PATH="${SCRIPT##*/}"
SCRIPT_NAME="${SCRIPT_PATH%.*}"
MARKER_FILE="/usr/local/etc/codespace-markers/${SCRIPT_NAME}"
MARKER_FILE_DIR=$(dirname "${MARKER_FILE}")

if [ "$(id -u)" -ne 0 ]; then
  echo -e 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
  exit 1
fi

function apt_get_update_if_needed() {
  if [[ -d "/var/lib/apt/lists" && $(ls /var/lib/apt/lists/ | wc -l) -eq 0 ]]; then
    apt-get update
  fi
}

function check_packages() {
  if [ "${CONTAINER_OS}" = "debian" ]; then
    if ! dpkg --status "$@" >/dev/null 2>&1; then
      apt_get_update_if_needed
      apt-get install --no-install-recommends --assume-yes "$@"
    fi
  elif [ "${CONTAINER_OS}" = "alpine" ]; then
    if ! apk info --installed "$@" >/dev/null 2>&1; then
      apk update
      apk add --no-cache --latest "$@"
    fi
  fi
}

function shellcheck_inst() {
  case "$OSTYPE" in
  linux-*)
    OS=linux
    EXT=tar.xz
    ;;
  esac
  machine=$(uname -m)
  case "$machine" in
  x86_64)
    ARCH=x86_64
    ;;
  esac
  wget -c https://github.com/koalaman/shellcheck/releases/download/v"$SHELLCHECK_VERSION"/shellcheck-v"$SHELLCHECK_VERSION".$OS.$ARCH.$EXT &&
    tar -xf shellcheck-v"$SHELLCHECK_VERSION".$OS.$ARCH.$EXT --directory=/usr/local/bin/ --strip-components=1 --exclude=*.txt &&
    rm shellcheck-v"$SHELLCHECK_VERSION".$OS.$ARCH.$EXT &&
    chown root /usr/local/bin/shellcheck &&
    chgrp root /usr/local/bin/shellcheck
}

if [ -f "${MARKER_FILE}" ]; then
  echo "Marker file found:"
  cat "${MARKER_FILE}"
  # shellcheck source=/dev/null
  source "${MARKER_FILE}"
fi

if [ "${SHELLCHECK_ALREADY_INSTALLED}" != "true" ]; then
  if [ "${CONTAINER_OS}" = "debian" ]; then
    check_packages \
      wget \
      xz-utils
  fi
  shellcheck_inst
  SHELLCHECK_ALREADY_INSTALLED="true"
fi

if [ ! -d "$MARKER_FILE_DIR" ]; then
  mkdir -p "$MARKER_FILE_DIR"
fi

echo -e "\
    SHELLCHECK_ALREADY_INSTALLED=${SHELLCHECK_ALREADY_INSTALLED}" >"${MARKER_FILE}"
