#!/usr/bin/env bash

set -e

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
  if [ ! -d "/var/lib/apt/lists" ] || [ "$(ls /var/lib/apt/lists/ | wc -l)" -eq 0 ]; then
    apt-get update
  fi
}

function check_packages() {
  if ! dpkg --status "$@" >/dev/null 2>&1; then
    apt_get_update_if_needed
    apt-get install --no-install-recommends --assume-yes "$@"
  fi
}

function trivy_inst() {
  wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add - >/dev/null 2>&1
  echo deb https://aquasecurity.github.io/trivy-repo/deb "$(lsb_release -sc)" main | sudo tee -a /etc/apt/sources.list.d/trivy.list
  apt-get update
  apt-get install --no-install-recommends --assume-yes \
    trivy
}

if [ -f "${MARKER_FILE}" ]; then
  echo "Marker file found:"
  cat "${MARKER_FILE}"
  # shellcheck source=/dev/null
  source "${MARKER_FILE}"
fi

export DEBIAN_FRONTEND=noninteractive

if [ "${TRIVY_ALREADY_INSTALLED}" != "true" ]; then
  check_packages \
    apt-transport-https \
    gnupg \
    lsb-release \
    wget
  trivy_inst

  TRIVY_ALREADY_INSTALLED="true"
fi

if [ ! -d "$MARKER_FILE_DIR" ]; then
  mkdir -p "$MARKER_FILE_DIR"
fi

echo -e "\
    TRIVY_ALREADY_INSTALLED=${TRIVY_ALREADY_INSTALLED}" >"${MARKER_FILE}"
