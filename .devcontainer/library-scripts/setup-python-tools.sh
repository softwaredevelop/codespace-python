#!/usr/bin/env bash

set -e

PYTHON=${1:-"/usr/local/python/bin/python3"}  # "/usr/local/bin/python" or "/usr/local/python/bin/python3"
PYTHON_INSTALL_PATH=${2:-"/usr/local/python"} # "/usr/local/" or "/usr/local/python"
USERNAME=${3-"automatic"}
INSTALL_PIPX_TOOLS=${4:-"true"}
export PIPX_HOME=${5:-"/usr/local/pipx"} # "/usr/local/py-utils" "/usr/local/share/pipx"
UPDATE_RC=${6:-"true"}

DEFAULT_UTILS=(
  "autopep8"
  "bandit"
  # "black"
  "flake8"
  # "isort"
  "mypy"
  "pycodestyle"
  "pydocstyle"
  "pylint"
  "pytest"
  "twine"
  "yapf"
)

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

updaterc() {
  if [ "${UPDATE_RC}" = "true" ]; then
    if [[ "$(cat /etc/bash.bashrc)" != *"$1"* ]]; then
      echo -e "$1" >>/etc/bash.bashrc
    fi
  fi
}

export DEBIAN_FRONTEND=noninteractive

if ! ${PYTHON} --version >/dev/null; then
  echo "You need to install Python before installing packages"
  exit 1
fi

installPythonPackage "pip" "latest"
installPythonPackage "setuptools" "latest"
installPythonPackage "art" "latest"
installPythonPackage "nox" "latest"

if [ "${INSTALL_PIPX_TOOLS}" != "true" ]; then
  exit 0
fi

export PIPX_BIN_DIR="${PIPX_HOME}/bin"
export PATH="${PYTHON_INSTALL_PATH}/bin:${PIPX_BIN_DIR}:${PATH}"

if ! grep -e '^pipx:' </etc/group >/dev/null 2>&1; then
  groupadd --system pipx
fi
usermod --append --groups pipx ${USERNAME}
umask 0002
mkdir --parents ${PIPX_BIN_DIR}
chown :pipx ${PIPX_HOME} ${PIPX_BIN_DIR}
chmod g+s ${PIPX_HOME} ${PIPX_BIN_DIR}

export PYTHONUSERBASE=/tmp/pip-tmp
export PIP_CACHE_DIR=/tmp/pip-tmp/cache
pipx_path=""
if ! type pipx >/dev/null 2>&1; then
  pip3 install --disable-pip-version-check --no-cache-dir --user pipx 2>&1
  /tmp/pip-tmp/bin/pipx install --pip-args=--no-cache-dir pipx
  pipx_path=$PYTHONUSERBASE"/bin/"
fi
for util in "${DEFAULT_UTILS[@]}"; do
  if ! type ${util} >/dev/null 2>&1; then
    ${pipx_path}pipx install --system-site-packages --pip-args '--no-cache-dir --force-reinstall' ${util}
  else
    echo "${util} already installed. Skipping."
  fi
done
rm -rf /tmp/pip-tmp

updaterc "$(
  cat <<EOF
export PIPX_HOME="${PIPX_HOME}"
export PIPX_BIN_DIR="${PIPX_BIN_DIR}"
if [[ "\${PATH}" != *"\${PIPX_BIN_DIR}"* ]]; then export PATH="\${PATH}:\${PIPX_BIN_DIR}"; fi
EOF
)"
