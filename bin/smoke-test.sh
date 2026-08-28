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

# --- neovim config-load check (beyond --version): does AstroNvim LOAD cleanly? ---
# --version only proves the binary runs; a nvim bump that breaks the config at
# startup (removed/renamed Lua API -> E5108, plugin load error) surfaces only
# when the config actually loads. Warmup runs a lazy.nvim sync so plugins are
# installed before the check (fresh containers clone the config but never run
# nvim, so plugins aren't installed yet). Caveat: catches STARTUP errors only;
# a plugin that breaks only when USED (not at load) slips through.
nvim_config_load() {
  [ -d "$HOME/.config/nvim" ] || { printf '  skip  nvim-config (no ~/.config/nvim)\n'; return 0; }
  # warmup: install/sync AstroNvim plugins via lazy.nvim, then sleep so the
  # async clones finish. Best-effort — ignore output + rc (network may be slow).
  nvim --headless "+Lazy sync" "+sleep 20" "+qa!" >/dev/null 2>&1 || true
  # load config, let lazy.nvim settle 5s, capture all output. nvim may exit 0
  # even with startup errors, so we grep the output rather than trust rc.
  local out
  out=$(nvim --headless "+lua vim.defer_fn(function() vim.cmd('qa!') end, 5000)" 2>&1 || true)
  if [ -z "$out" ]; then
    printf '  skip  nvim-config (no output — likely missing runtime, not a config error)\n'
  elif printf '%s\n' "$out" | grep -iqE 'E5[0-9]+:|error detected|traceback'; then
    printf '  FAIL  nvim-config (startup errors in config load)\n' >&2
    printf '%s\n' "$out" | grep -iE 'E5[0-9]+:|error detected|traceback' | head -5 >&2
    fails=$((fails + 1))
  else
    printf '  ok    nvim-config (AstroNvim loads headless, no errors)\n'
  fi
}
nvim_config_load

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

# age: crypto backend for the passage secret store (D017).
smoke age         age --version
# passage refuses to run ANY subcommand (even --version) until ~/.passage/identities
# exists, so CI (no identity) cannot invoke it -- prove it is installed & on PATH instead.
smoke passage     command -v passage

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
