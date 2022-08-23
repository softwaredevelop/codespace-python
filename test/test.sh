#!/usr/bin/env bash

SCRIPT_FOLDER_NAME=$(dirname $0)
cd ${SCRIPT_FOLDER_NAME} || exit

# shellcheck source=/dev/null
source test-utils.sh codespace

if [ "${ID_OS}" = "ubuntu" ]; then
  package_list_debian="apt-utils \
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
  checkOSPackages "common-os-packages" ${package_list_debian}
elif [ "${ID_OS}" = "alpine" ]; then
  package_list_alpine="ca-certificates \
        curl \
        dpkg \
        git \
        libc6-compat \
        shadow \
        sudo"
  checkOSPackages "common-os-packages" ${package_list_alpine}
fi
check "non-root-user" non_root_user
check "hadolint" hadolint --version
check "shfmt" shfmt --version
check "shellcheck" shellcheck --version
check "editorconfig" ec --version
check "trivy" trivy --version

reportResults
