#!/usr/bin/env bash

set -e

PYTHON_VERSION=${1:-"latest"} # "system" else "latest"
USERNAME=${2:-"automatic"}
PYTHON_INSTALL_PATH=${3:-"/usr/local/python"}
UPDATE_RC=${4:-"true"}
export PIPX_HOME=${5:-"/usr/local/python"} # "/usr/local/py-utils"
INSTALL_PYTHON_TOOLS=${6:-"true"}

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

if [ "$(id -u)" -ne 0 ]; then
  echo -e 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
  exit 1
fi

rm -f /etc/profile.d/00-restore-env.sh
echo "export PATH=${PATH//$(sh -lc 'echo $PATH')/\$PATH}" >/etc/profile.d/00-restore-env.sh
chmod +x /etc/profile.d/00-restore-env.sh

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

function apt_get_update_if_needed() {
  if [[ -d "/var/lib/apt/lists" && $(ls /var/lib/apt/lists/ | wc -l) -eq 0 ]]; then
    apt-get update
  fi
}

function check_packages() {
  if ! dpkg --status "$@" >/dev/null 2>&1; then
    apt_get_update_if_needed
    apt-get install --no-install-recommends --assume-yes "$@"
  fi
}

function install_from_source() {
  if [ -d "${PYTHON_INSTALL_PATH}" ]; then
    echo "(!) Path ${PYTHON_INSTALL_PATH} already exists. Remove this existing path or select a different one."
    exit 1
  fi
  check_packages \
    ca-certificates \
    curl \
    gcc \
    gdb \
    git \
    gnupg2 \
    libgdbm-compat-dev \
    libgdbm-dev \
    libncurses5-dev \
    libssl-dev \
    lzma \
    lzma-dev \
    make \
    tar \
    tk-dev \
    zlib1g-dev \
    dirmngr \
    libbz2-dev \
    libffi-dev \
    liblzma-dev \
    libreadline-dev \
    libreadline6-dev \
    libsqlite3-dev \
    libxml2-dev \
    libxmlsec1-dev \
    uuid-dev \
    xz-utils # g++ \

  find_version_from_git_tags PYTHON_VERSION "https://github.com/python/cpython"

  mkdir -p /tmp/python-src "${PYTHON_INSTALL_PATH}"
  cd /tmp/python-src
  local tgz_filename="Python-${PYTHON_VERSION}.tgz"
  local tgz_url="https://www.python.org/ftp/python/${PYTHON_VERSION}/${tgz_filename}"
  curl -sSL -o "/tmp/python-src/${tgz_filename}" "${tgz_url}"

  cp /etc/ssl/openssl.cnf /tmp/python-src/
  sed -i -E 's/MinProtocol[=\ ]+.*/MinProtocol = TLSv1.0/g' /tmp/python-src/openssl.cnf
  export OPENSSL_CONF=/tmp/python-src/openssl.cnf

  tar -xzf "/tmp/python-src/${tgz_filename}" -C "/tmp/python-src" --strip-components=1
  ./configure --prefix="${PYTHON_INSTALL_PATH}" --with-ensurepip=install
  make -j 8
  make install
  cd /tmp
  rm -rf /tmp/python-src ${GNUPGHOME} /tmp/vscdc-settings.env
  chown -R ${USERNAME} "${PYTHON_INSTALL_PATH}"
  ln -s ${PYTHON_INSTALL_PATH}/bin/python3 ${PYTHON_INSTALL_PATH}/bin/python
  ln -s ${PYTHON_INSTALL_PATH}/bin/pip3 ${PYTHON_INSTALL_PATH}/bin/pip
  ln -s ${PYTHON_INSTALL_PATH}/bin/idle3 ${PYTHON_INSTALL_PATH}/bin/idle
  ln -s ${PYTHON_INSTALL_PATH}/bin/pydoc3 ${PYTHON_INSTALL_PATH}/bin/pydoc
  ln -s ${PYTHON_INSTALL_PATH}/bin/python3-config ${PYTHON_INSTALL_PATH}/bin/python-config
}

function find_version_from_git_tags() {
  local variable_name=$1
  local requested_version=${!variable_name}
  if [ "${requested_version}" = "none" ]; then return; fi
  local repository=$2
  local prefix=${3:-"tags/v"}
  local separator=${4:-"."}
  local last_part_optional=${5:-"false"}
  if [ "$(echo "${requested_version}" | grep -o "." | wc -l)" != "2" ]; then
    local escaped_separator=${separator//./\\.}
    local last_part
    if [ "${last_part_optional}" = "true" ]; then
      last_part="(${escaped_separator}[0-9]+)?"
    else
      last_part="${escaped_separator}[0-9]+"
    fi
    local regex="${prefix}\\K[0-9]+${escaped_separator}[0-9]+${last_part}$"
    local version_list
    version_list="$(git ls-remote --tags ${repository} | grep -oP "${regex}" | tr -d ' ' | tr "${separator}" "." | sort -rV)"
    if [ "${requested_version}" = "latest" ] || [ "${requested_version}" = "current" ] || [ "${requested_version}" = "lts" ]; then
      declare -g ${variable_name}="$(echo "${version_list}" | head -n 1)"
    else
      set +e
      declare -g ${variable_name}="$(echo "${version_list}" | grep -E -m 1 "^${requested_version//./\\.}([\\.\\s]|$)")"
      set -e
    fi
  fi
  if [ -z "${!variable_name}" ] || ! echo "${version_list}" | grep "^${!variable_name//./\\.}$" >/dev/null 2>&1; then
    echo -e "Invalid ${variable_name} value: ${requested_version}\nValid values:\n${version_list}" >&2
    exit 1
  fi
  echo "${variable_name}=${!variable_name}"
}

updaterc() {
  if [ "${UPDATE_RC}" = "true" ]; then
    if [[ "$(cat /etc/bash.bashrc)" != *"$1"* ]]; then
      echo -e "$1" >>/etc/bash.bashrc
    fi
  fi
}

export DEBIAN_FRONTEND=noninteractive

if [ "${PYTHON_VERSION}" != "none" ]; then
  if [ ${PYTHON_VERSION} = "system" ]; then
    check_packages \
      python3 \
      python3-dev \
      python3-doc \
      python3-pip \
      python3-tk \
      python3-venv
    PYTHON_INSTALL_PATH="/usr"
    should_install_from_source=false
  else
    should_install_from_source=true
  fi
  if [ "${should_install_from_source}" = "true" ]; then
    install_from_source
  fi
  updaterc "if [[ \"\${PATH}\" != *\"${PYTHON_INSTALL_PATH}/bin\"* ]]; then export PATH=${PYTHON_INSTALL_PATH}/bin:\${PATH}; fi"
fi

if [ "${INSTALL_PYTHON_TOOLS}" != "true" ]; then
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

if [ ${PYTHON_VERSION} != "system" ]; then
  ${PYTHON_INSTALL_PATH}/bin/python3 -m pip install --no-cache-dir --upgrade pip
fi

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
