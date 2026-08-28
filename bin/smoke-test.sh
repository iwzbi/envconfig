#!/usr/bin/env bash
# =============================================================================
# Smoke-test every tool the playbook installs: invoke each to PROVE it runs.
#
# Why this exists: the playbook only downloads/extracts binaries — it never
# EXECUTES them — so a green playbook run does not prove the tools work. A
# glibc mismatch (e.g. a prebuilt binary needing a newer glibc than 22.04 has),
# a bad extraction, a wrong arch, or a missing runtime dep surfaces only here.
# Run after the playbook: CI does this automatically; locally: bin/smoke-test.sh
# =============================================================================
set -eu

# --- put every install location on PATH (mirrors conf/.zshrc) ---
# macOS: Homebrew on PATH (brew installs nvim/tmux/gh/etc.)
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi
# Linux: neovim extracted to ~/.local/nvim-linux-x86_64/bin
if [ -d "$HOME/.local/nvim-linux-x86_64/bin" ]; then
  PATH="$HOME/.local/nvim-linux-x86_64/bin:$PATH"
fi
PATH="$HOME/.local/bin:$HOME/.fzf/bin:$PATH"
# mise-managed runtimes (node, python, ...) on both platforms
if [ -x "$HOME/.local/bin/mise" ]; then
  eval "$("$HOME/.local/bin/mise" activate bash)"
fi
export PATH

fails=0
# smoke <label> <cmd...> — run cmd; count a failure if it can't even print a version.
smoke() {
  local label="$1"; shift
  if "$@" >/dev/null 2>&1; then
    printf '  ok    %s\n' "$label"
  else
    printf '  FAIL  %s\n' "$label"
    fails=$((fails + 1))
  fi
}

# --- core shell / system tools (package-manager installed, low risk but core) ---
smoke zsh     zsh --version
smoke tmux    tmux -V
smoke git     git --version

# --- mise-managed runtime ---
smoke node    node --version

# --- neovim (THE key sentinel: prebuilt binary that may mismatch the host glibc) ---
smoke nvim    nvim --version

# --- GitHub-release binaries (linux: ~/.local/bin; macOS: brew) ---
smoke delta       delta --version
smoke zoxide      zoxide --version
smoke eza         eza --version
smoke dust        dust --version
smoke lazydocker  lazydocker --version
smoke lazygit     lazygit --version
smoke yazi        yazi --version
smoke glow        glow --version
smoke atuin       atuin --version
smoke gh          gh --version
smoke fzf         fzf --version

# --- installer-managed ---
smoke uv      uv --version
smoke mise    mise --version
smoke opencode opencode --version

# --- package-manager tools (low risk; bat/fd have Ubuntu name variants) ---
smoke rg      rg --version
smoke jq      jq --version
smoke direnv  direnv version
# Ubuntu names these batcat/fdfind; the tools role symlinks bat, but not fd —
# fall back to the alt name so the check passes on both.
bat=bat;  command -v bat  >/dev/null 2>&1 || bat=batcat
smoke bat  "$bat" --version
fd=fd;    command -v fd   >/dev/null 2>&1 || fd=fdfind
smoke fd   "$fd" --version

echo "----"
if [ "$fails" -gt 0 ]; then
  printf 'SMOKE TEST FAILED: %d tool(s) did not run\n' "$fails" >&2
  exit 1
fi
echo "SMOKE TEST PASSED"
