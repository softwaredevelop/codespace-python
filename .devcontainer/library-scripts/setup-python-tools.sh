#!/usr/bin/env bash

set -e

PYTHON=${1:-"/usr/local/python/bin/python3"}
USERNAME=${2-"automatic"}

if [ "${USERNAME}" = "automatic" ]; then
  USERNAME=""
  POSSIBLE_USERS=("codespace" "vscode" "$(awk -v val=1000 -F ":" '$3==val{print $1}' /etc/passwd)")
  for CURRENT_USER in "${POSSIBLE_USERS[@]}"; do
    if id -u "${CURRENT_USER}" >/dev/null 2>&1; then
      USERNAME=${CURRENT_USER}
      break
    fi
  done
  if [ "${USERNAME}" = "" ]; then
    USERNAME=root
  fi
elif [ "${USERNAME}" = "none" ] || ! id -u ${USERNAME} >/dev/null 2>&1; then
  USERNAME=root
fi

function installPythonPackage() {
  PACKAGE=${1:-""}
  VERSION=${2:-"latest"}
  if [ "${VERSION}" = "latest" ]; then
    sudoUserIf ${PYTHON} -m pip install --upgrade --no-cache-dir ${PACKAGE}
  else
    sudoUserIf ${PYTHON} -m pip install --upgrade --no-cache-dir ${PACKAGE}=="${VERSION}"
  fi
}

function sudoUserIf() {
  if [ "$(id -u)" -eq 0 ] && [ "${USERNAME}" != "root" ]; then
    sudo --user=${USERNAME} "$@"
  else
    "$@"
  fi
}

if ! ${PYTHON} --version >/dev/null; then
  echo "You need to install Python before installing packages"
  exit 1
fi

installPythonPackage "pip" "latest"
installPythonPackage "setuptools" "latest"
installPythonPackage "art" "latest"
