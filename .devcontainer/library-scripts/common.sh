#!/usr/bin/env bash

set -e

UPGRADE_PACKAGES=${1:-"true"}
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

rm -f /etc/profile.d/00-restore-env.sh
echo "export PATH=${PATH//$(sh -lc 'echo $PATH')/\$PATH}" >/etc/profile.d/00-restore-env.sh
chmod +x /etc/profile.d/00-restore-env.sh

function apt_get_update_if_needed() {
  if [ ! -d "/var/lib/apt/lists" ] || [ "$(ls /var/lib/apt/lists/ | wc -l)" -eq 0 ]; then
    apt-get update
  fi
}

if [ -f "${MARKER_FILE}" ]; then
  echo "Marker file found:"
  cat "${MARKER_FILE}"
  # shellcheck source=/dev/null
  source "${MARKER_FILE}"
fi

if [ "${PACKAGES_ALREADY_INSTALLED}" != "true" ] && [ "${CONTAINER_OS}" = "debian" ]; then
  export DEBIAN_FRONTEND=noninteractive
  package_list="apt-utils \
        apt-transport-https \
        ca-certificates \
        curl \
        git \
        gnupg \
        locales \
        lsb-release \
        sudo \
        wget \
        xz-utils"
  apt_get_update_if_needed
  if [[ -n $(apt-cache --names-only search ^libssl3$) ]]; then
    package_list="${package_list} libssl3"
  fi
  libssl_package=$(dpkg-query -f '${db:Status-Abbrev}\t${binary:Package}\n' -W 'libssl1*' 2>&1 || echo '')
  libssl_package_inst=$(echo "$libssl_package" | grep -o 'libssl1\(\.[0-9]\)*' | uniq | sort | wc -l)
  if [ "$libssl_package_inst" -eq 0 ]; then
    if [[ -n $(apt-cache --names-only search ^libssl1.1$) ]]; then
      package_list="${package_list} libssl1.1"
    elif [[ -n $(apt-cache --names-only search ^libssl1.0.2$) ]]; then
      package_list="${package_list} libssl1.0.2"
    elif [[ -n $(apt-cache --names-only search ^libssl1.0.0$) ]]; then
      package_list="${package_list} libssl1.0.0"
    fi
  fi
  apt-get install --no-install-recommends --assume-yes ${package_list}
  PACKAGES_ALREADY_INSTALLED="true"
elif [ "${PACKAGES_ALREADY_INSTALLED}" != "true" ] && [ "${CONTAINER_OS}" = "alpine" ]; then
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

if [ "${UPGRADE_PACKAGES}" = "true" ] && [ "${CONTAINER_OS}" = "debian" ]; then
  apt_get_update_if_needed
  apt-get upgrade --no-install-recommends --assume-yes
  apt-get autoremove
  apt-get clean
  rm -rf /var/lib/apt/lists/*
elif [ "${UPGRADE_PACKAGES}" = "true" ] && [ "${CONTAINER_OS}" = "alpine" ]; then
  apk update
  apk upgrade --no-cache
  rm -rf /var/lib/apt/lists/*
fi

if [ ! -d "$MARKER_FILE_DIR" ]; then
  mkdir -p "$MARKER_FILE_DIR"
fi

echo -e "\
    PACKAGES_ALREADY_INSTALLED=${PACKAGES_ALREADY_INSTALLED}" >"${MARKER_FILE}"
