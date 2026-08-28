#!/bin/sh
# =============================================================================
# envconfig — one-command setup. Works on macOS (Apple Silicon) and Linux.
#
#   ./install.sh [--tags neovim,fzf] [other ansible-playbook args]
#   curl -LsSf https://raw.githubusercontent.com/iwzbi/envconfig/main/install.sh | sh
#
# Idempotent: safe to re-run on an existing machine (upgrades/overwrites per
# the playbook's idempotency design — see memory/decisions.md).
# =============================================================================
set -eu

REPO_URL="https://github.com/iwzbi/envconfig.git"
ENVCONFIG_DIR="${ENVCONFIG_DIR:-$HOME/code/envconfig}"

log() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*"; }

OS="$(uname -s)"

# --- macOS: ensure Homebrew (install.sh owns this; the homebrew role only asserts) ---
if [ "$OS" = "Darwin" ]; then
  if ! command -v brew >/dev/null 2>&1; then
    log "Installing Homebrew (you may be asked for your password once)"
    NONINTERACTIVE=1 /bin/bash -c "$(curl -LsSf https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  # Put brew on PATH for this process (ansible inherits it)
  if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
fi

# --- ensure git is available (fresh macOS may need Xcode Command Line Tools) ---
if ! command -v git >/dev/null 2>&1; then
  if [ "$OS" = "Darwin" ]; then
    warn "git not found. Run: xcode-select --install  (then re-run ./install.sh)"
    exit 1
  fi
  warn "git not found. Install it via your package manager and re-run."
  exit 1
fi

# --- locate or clone the repo ---
if [ -f ./configme.yaml ]; then
  REPO_DIR="$(pwd)"
elif [ -d "$ENVCONFIG_DIR/.git" ]; then
  REPO_DIR="$ENVCONFIG_DIR"
  log "Updating $REPO_DIR"
  git -C "$REPO_DIR" pull --ff-only
else
  log "Cloning $REPO_URL -> $ENVCONFIG_DIR"
  mkdir -p "$(dirname "$ENVCONFIG_DIR")"
  git clone "$REPO_URL" "$ENVCONFIG_DIR"
  REPO_DIR="$ENVCONFIG_DIR"
fi
cd "$REPO_DIR"

# --- ensure uv (Python package manager; installs ansible) ---
if ! command -v uv >/dev/null 2>&1; then
  log "Installing uv"
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"
fi

# --- sync the ansible environment from pyproject.toml + uv.lock ---
log "Syncing ansible environment (uv sync)"
uv sync

# --- run the playbook (args passed through, e.g. --tags neovim) ---
log "Running playbook: configme.yaml $*"
exec uv run ansible-playbook configme.yaml "$@"
