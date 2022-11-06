#!/usr/bin/env bash

set -e

TRIVY_VERSION=${1:-"0.34.0"}
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

function trivy_inst() {
  curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin v${TRIVY_VERSION}
}

if [ -f "${MARKER_FILE}" ]; then
  echo "Marker file found:"
  cat "${MARKER_FILE}"
  # shellcheck source=/dev/null
  source "${MARKER_FILE}"
fi

if [ "${TRIVY_ALREADY_INSTALLED}" != "true" ]; then
  check_packages \
    ca-certificates \
    curl
  trivy_inst
  TRIVY_ALREADY_INSTALLED="true"
fi

if [ ! -d "$MARKER_FILE_DIR" ]; then
  mkdir -p "$MARKER_FILE_DIR"
fi

echo -e "\
    TRIVY_ALREADY_INSTALLED=${TRIVY_ALREADY_INSTALLED}" >"${MARKER_FILE}"
