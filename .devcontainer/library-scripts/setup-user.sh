#!/usr/bin/env bash

set -e

USERNAME=${1:-"automatic"}
USER_UID=${2:-"automatic"}
USER_GID=${3:-"automatic"}
CONTAINER_OS=${4:-"alpine"}
SCRIPT=("${BASH_SOURCE[@]}")
SCRIPT_PATH="${SCRIPT##*/}"
SCRIPT_NAME="${SCRIPT_PATH%.*}"
MARKER_FILE="/usr/local/etc/codespace-markers/${SCRIPT_NAME}"
MARKER_FILE_DIR=$(dirname "${MARKER_FILE}")

if [ "$(id -u)" -ne 0 ]; then
  echo -e 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
  exit 1
fi

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
    USERNAME=codespace
  fi
elif [ "${USERNAME}" = "none" ]; then
  USERNAME=root
  USER_UID=0
  USER_GID=0
fi

if [ -f "${MARKER_FILE}" ]; then
  echo "Marker file found:"
  cat "${MARKER_FILE}"
  # shellcheck source=/dev/null
  source "${MARKER_FILE}"
fi

if [ "${CONTAINER_OS}" = "debian" ] && [ "${LOCALE_ALREADY_SET}" != "true" ] && ! grep -o -E '^\s*en_US.UTF-8\s+UTF-8' /etc/locale.gen >/dev/null; then
  echo "en_US.UTF-8 UTF-8" >>/etc/locale.gen
  locale-gen
  LOCALE_ALREADY_SET="true"
fi

group_name="${USERNAME}"
if id -u ${USERNAME} >/dev/null 2>&1; then
  if [ "${USER_GID}" != "automatic" ] && [ "$USER_GID" != "$(id -g $USERNAME)" ]; then
    group_name="$(id -gn $USERNAME)"
    groupmod --gid $USER_GID "${group_name}"
    usermod --gid $USER_GID $USERNAME
  fi
  if [ "${USER_UID}" != "automatic" ] && [ "$USER_UID" != "$(id -u $USERNAME)" ]; then
    usermod --uid $USER_UID $USERNAME
  fi
else
  if [ "${USER_GID}" = "automatic" ]; then
    groupadd $USERNAME
  else
    groupadd --gid $USER_GID $USERNAME
  fi
  if [ "${USER_UID}" = "automatic" ]; then
    useradd --gid $USER_GID --create-home $USERNAME --shell /bin/bash
  else
    useradd --gid $USER_GID --create-home $USERNAME --shell /bin/bash --uid $USER_UID
  fi
fi

if [ "${USERNAME}" != "root" ] && [ "${EXISTING_NON_ROOT_USER}" != "${USERNAME}" ]; then
  echo $USERNAME ALL=\(root\) NOPASSWD:ALL >/etc/sudoers.d/$USERNAME
  chmod 0440 /etc/sudoers.d/$USERNAME
  EXISTING_NON_ROOT_USER="${USERNAME}"
fi

rc_snippet="$(
  cat <<'EOF'
if [ -z "${USER}" ]; then
  USER=$(whoami)
  export USER
fi
if [[ "${PATH}" != *"$HOME/.local/bin"* ]]; then export PATH="${PATH}:$HOME/.local/bin"; fi
if [ -z "$(git config --get core.editor)" ] && [ -z "${GIT_EDITOR}" ]; then
  if [ "${TERM_PROGRAM}" = "vscode" ]; then
    if [[ -n $(command -v code-insiders) && -z $(command -v code) ]]; then
      export GIT_EDITOR="code-insiders --wait"
    else
      export GIT_EDITOR="code --wait"
    fi
  fi
fi
EOF
)"

codespaces_bash="$(
  cat \
    <<'EOF'
# Codespaces bash prompt theme
__bash_prompt() {
    local userpart='`export XIT=$? \
        && [ ! -z "${GITHUB_USER}" ] && echo -n "\[\033[0;32m\]@${GITHUB_USER} " || echo -n "\[\033[0;32m\]\u " \
        && [ "$XIT" -ne "0" ] && echo -n "\[\033[1;31m\]➜" || echo -n "\[\033[0m\]➜"`'
    local gitbranch='`\
        if [ "$(git config --get codespaces-theme.hide-status 2>/dev/null)" != 1 ]; then \
            export BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null); \
            if [ "${BRANCH}" != "" ]; then \
                echo -n "\[\033[0;36m\](\[\033[1;31m\]${BRANCH}" \
                && if git ls-files --error-unmatch -m --directory --no-empty-directory -o --exclude-standard ":/*" > /dev/null 2>&1; then \
                        echo -n " \[\033[1;33m\]✗"; \
                fi \
                && echo -n "\[\033[0;36m\]) "; \
            fi; \
        fi`'
    local lightblue='\[\033[1;34m\]'
    local removecolor='\[\033[0m\]'
    PS1="${userpart} ${lightblue}\w ${gitbranch}${removecolor}\$ "
    unset -f __bash_prompt
}
__bash_prompt
EOF
)"

if [ "${USERNAME}" = "root" ]; then
  user_rc_path="/root"
else
  user_rc_path="/home/${USERNAME}"
fi

if [ "${RC_SNIPPET_ALREADY_ADDED}" != "true" ]; then
  echo "${rc_snippet}" >>/etc/bash.bashrc
  echo "${codespaces_bash}" >>"${user_rc_path}/.bashrc"
  echo 'export PROMPT_DIRTRIM=4' >>"${user_rc_path}/.bashrc"
  if [ "${USERNAME}" != "root" ]; then
    echo "${codespaces_bash}" >>"/root/.bashrc"
    echo 'export PROMPT_DIRTRIM=4' >>"/root/.bashrc"
  fi
  chown ${USERNAME}:${group_name} "${user_rc_path}/.bashrc"
  RC_SNIPPET_ALREADY_ADDED="true"
fi

if [ ! -d "$MARKER_FILE_DIR" ]; then
  mkdir -p "$MARKER_FILE_DIR"
fi

echo -e "\
    EXISTING_NON_ROOT_USER=${EXISTING_NON_ROOT_USER}\n\
    LOCALE_ALREADY_SET=${LOCALE_ALREADY_SET}\n\
    RC_SNIPPET_ALREADY_ADDED=${RC_SNIPPET_ALREADY_ADDED}" >"${MARKER_FILE}"
