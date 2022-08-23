#!/usr/bin/env bash

set -e

UPGRADE_PACKAGES=${1:-"true"}
SCRIPT=("${BASH_SOURCE[@]}")
SCRIPT_PATH="${SCRIPT##*/}"
SCRIPT_NAME="${SCRIPT_PATH%.*}"
MARKER_FILE="/usr/local/etc/codespace-markers/${SCRIPT_NAME}"
MARKER_FILE_DIR=$(dirname "${MARKER_FILE}")

if [ "$(id -u)" -ne 0 ]; then
  echo -e 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
  exit 1
fi

rm -f /etc/profile.d/00-restore-env.sh
echo "export PATH=${PATH//$(sh -lc 'echo $PATH')/\$PATH}" >/etc/profile.d/00-restore-env.sh
chmod +x /etc/profile.d/00-restore-env.sh

if [ -f "${MARKER_FILE}" ]; then
  echo "Marker file found:"
  cat "${MARKER_FILE}"
  # shellcheck source=/dev/null
  source "${MARKER_FILE}"
fi

if [ "${PACKAGES_ALREADY_INSTALLED}" != "true" ]; then
  package_list="ca-certificates \
        curl \
        dpkg \
        git \
        libc6-compat \
        shadow \
        sudo"
  apk update
  apk add --no-cache --latest ${package_list}
  PACKAGES_ALREADY_INSTALLED="true"
fi

if [ "${UPGRADE_PACKAGES}" = "true" ]; then
  apk update
  apk upgrade --no-cache
  rm -rf /var/lib/apt/lists/*
fi

if [ ! -d "$MARKER_FILE_DIR" ]; then
  mkdir -p "$MARKER_FILE_DIR"
fi

echo -e "\
    PACKAGES_ALREADY_INSTALLED=${PACKAGES_ALREADY_INSTALLED}" >"${MARKER_FILE}"
