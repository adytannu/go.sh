#!/usr/bin/env bash
set -Eeuo pipefail

# Public bootstrap for new machines. Keep this file free of secrets.

INSTALL_PACKAGES="${INSTALL_PACKAGES:-1}"
INSTALL_OH_MY_BASH="${INSTALL_OH_MY_BASH:-1}"
CONFIGURE_GIT="${CONFIGURE_GIT:-1}"
CREATE_SSH_KEY="${CREATE_SSH_KEY:-1}"

SSH_KEY_NAME="${SSH_KEY_NAME:-id_rsa}"
SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/$SSH_KEY_NAME}"
OMB_THEME="${OMB_THEME:-font}"
OMB_PLUGINS="${OMB_PLUGINS:-git}"
SETUP_EDITOR="${SETUP_EDITOR:-vim}"
SETUP_GIT_NAME="${SETUP_GIT_NAME:-}"
SETUP_GIT_EMAIL="${SETUP_GIT_EMAIL:-}"

usage() {
  cat <<'USAGE'
Usage:
  curl -fsSL https://tannu.me/go.sh | bash

Environment overrides:
  INSTALL_PACKAGES=0      Skip installing prerequisite packages
  INSTALL_OH_MY_BASH=0    Skip Oh My Bash
  CONFIGURE_GIT=0         Skip global git config
  CREATE_SSH_KEY=0        Skip Bitbucket SSH key setup
  NO_PROMPT=1             Kept for compatibility; no prompts by default

  SETUP_GIT_NAME="Your Name"
  SETUP_GIT_EMAIL="you@example.com"
  SSH_KEY_NAME="id_rsa"
  OMB_THEME="font"
  OMB_PLUGINS="git"
USAGE
}

log() {
  printf '\n==> %s\n' "$*"
}

warn() {
  printf 'warning: %s\n' "$*" >&2
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

have() {
  command -v "$1" >/dev/null 2>&1
}

run_as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif have sudo; then
    sudo "$@"
  else
    warn "sudo is not installed; cannot run: $*"
    return 1
  fi
}

install_packages() {
  [ "$INSTALL_PACKAGES" = "1" ] || return 0

  local missing=0
  for cmd in git wget ssh ssh-keygen; do
    have "$cmd" || missing=1
  done

  [ "$missing" = "1" ] || {
    log "Prerequisite commands already installed"
    return 0
  }

  log "Installing prerequisite packages"
  if have apt-get; then
    run_as_root apt-get update
    run_as_root apt-get install -y git wget ca-certificates openssh-client
  elif have dnf; then
    run_as_root dnf install -y git wget ca-certificates openssh-clients
  elif have yum; then
    run_as_root yum install -y git wget ca-certificates openssh-clients
  elif have pacman; then
    run_as_root pacman -Sy --needed git wget ca-certificates openssh
  elif have zypper; then
    run_as_root zypper --non-interactive install git wget ca-certificates openssh
  elif have brew; then
    brew install git wget openssh
  else
    warn "No supported package manager found. Install git, wget, and OpenSSH manually if needed."
  fi
}

replace_assignment() {
  local file="$1"
  local name="$2"
  local line="$3"
  local tmp

  [ -f "$file" ] || return 0
  tmp="$(mktemp)"
  awk -v name="$name" -v line="$line" '
    skipping {
      if ($0 ~ /^[[:space:]]*\)[[:space:]]*($|#)/) skipping = 0
      next
    }
    $0 ~ "^" name "=" {
      if (!done) print line
      done = 1
      if ($0 ~ /\(/ && $0 !~ /\)/) skipping = 1
      next
    }
    { print }
    END {
      if (!done) print line
    }
  ' "$file" >"$tmp"
  mv "$tmp" "$file"
}

replace_block() {
  local file="$1"
  local name="$2"
  local body="$3"
  local start="# >>> $name"
  local end="# <<< $name"
  local tmp

  mkdir -p "$(dirname "$file")"
  touch "$file"
  tmp="$(mktemp)"
  awk -v start="$start" -v end="$end" '
    $0 == start { skipping = 1; next }
    $0 == end { skipping = 0; next }
    !skipping { print }
  ' "$file" >"$tmp"
  {
    cat "$tmp"
    printf '\n%s\n%s\n%s\n' "$start" "$body" "$end"
  } >"$file"
  rm -f "$tmp"
}

install_oh_my_bash() {
  [ "$INSTALL_OH_MY_BASH" = "1" ] || return 0
  have wget || die "wget is required to install Oh My Bash"
  have git || die "git is required to install Oh My Bash"
  local bashrc_block

  if [ -d "$HOME/.oh-my-bash" ]; then
    log "Oh My Bash already installed"
  else
    log "Installing Oh My Bash"
    bash -c "$(wget https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh -O -)" bash --unattended
  fi

  if [ -f "$HOME/.bashrc" ]; then
    replace_assignment "$HOME/.bashrc" "OSH_THEME" "OSH_THEME=\"$OMB_THEME\""
    replace_assignment "$HOME/.bashrc" "plugins" "plugins=($OMB_PLUGINS)"
  fi

  bashrc_block="$(cat <<EOF
export PATH="\$HOME/.local/bin:\$PATH"
export EDITOR="$SETUP_EDITOR"
alias ll="ls -alF"
alias gs="git status --short --branch"
EOF
)"
  replace_block "$HOME/.bashrc" "dot bootstrap" "$bashrc_block"
}

configure_git() {
  [ "$CONFIGURE_GIT" = "1" ] || return 0
  have git || {
    warn "git is not installed; skipping git config"
    return 0
  }

  log "Configuring git"
  git config --global init.defaultBranch main
  git config --global core.editor "$SETUP_EDITOR"

  if [ -n "$SETUP_GIT_NAME" ]; then
    git config --global user.name "$SETUP_GIT_NAME"
  fi

  if [ -n "$SETUP_GIT_EMAIL" ]; then
    git config --global user.email "$SETUP_GIT_EMAIL"
  fi
}

default_key_comment() {
  printf 'aditya@%s' "$(hostname 2>/dev/null || printf machine)"
}

copy_to_clipboard() {
  local file="$1"
  if have pbcopy; then
    pbcopy <"$file"
  elif have wl-copy; then
    wl-copy <"$file"
  elif have xclip; then
    xclip -selection clipboard <"$file"
  else
    return 1
  fi
}

setup_ssh_key() {
  [ "$CREATE_SSH_KEY" = "1" ] || return 0
  have ssh-keygen || {
    warn "ssh-keygen is not installed; skipping SSH key setup"
    return 0
  }

  log "Configuring Bitbucket SSH key"
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"

  local comment
  comment="$(default_key_comment)"

  if [ -f "$SSH_KEY_PATH" ]; then
    log "SSH key already exists at $SSH_KEY_PATH"
  else
    ssh-keygen -t rsa -C "$comment" -f "$SSH_KEY_PATH" -N ""
  fi

  chmod 600 "$SSH_KEY_PATH"
  chmod 644 "$SSH_KEY_PATH.pub"

  replace_block "$HOME/.ssh/config" "dot bootstrap bitbucket" "Host bitbucket.org
  HostName bitbucket.org
  User git
  IdentityFile $SSH_KEY_PATH
  IdentitiesOnly yes
  AddKeysToAgent yes"
  chmod 600 "$HOME/.ssh/config"

  if copy_to_clipboard "$SSH_KEY_PATH.pub"; then
    log "Copied public key to clipboard"
  fi

  log "Public key"
  cat "$SSH_KEY_PATH.pub"

  printf '\nPaste that public key into Bitbucket: Personal Bitbucket settings -> SSH keys -> Add key.\n'
  printf 'After adding it, test with: ssh -T git@bitbucket.org\n'
}

main() {
  case "${1:-}" in
    -h|--help)
      usage
      exit 0
      ;;
  esac

  install_packages
  install_oh_my_bash
  configure_git
  setup_ssh_key

  log "Done"
}

main "$@"
