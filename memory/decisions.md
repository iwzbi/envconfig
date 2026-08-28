# Architecture Decision Records

Numbered records of *why* non-obvious choices were made. Referenced from
code comments as `D0xx`. Append new ones at the bottom; never renumber.

## D001 — macOS tools unpinned (follow `brew upgrade`)

**Date:** 2026-08-28
**Context:** The playbook pins Linux binary versions with sha256 in
`vars/versions.yml`. macOS uses Homebrew, which has its own upgrade path.
**Decision:** Brew-managed tools on macOS are NOT pinned — they follow
`brew upgrade`. Linux stays sha256-locked for reproducibility.
**Consequence:** The same tool may briefly differ in version across a user's
Linux server and Mac. Accepted: brew pinning (`brew extract`) isn't worth the
maintenance for a personal dev-env. To force parity, bump the Linux version
to match brew's current.

## D002 — git clones use `force: yes` (authoritative-sourced)

**Date:** 2026-08-28
**Context:** `astrovim`, `fzf`, `tmux-plugins`, `ohmyzsh` themes/plugins all
`git clone` upstream repos into the user's home. On re-run, the `git` module
with `force: no` (default) **fails** if the checkout has local modifications —
breaking the idempotency requirement.
**Decision:** All such clones use `force: yes`: they fast-forward to the
remote tip and discard local changes. `~/.config/nvim` (astrovim) and the
dotfiles are authoritative-sourced from this repo / upstream — local edits
are expected to be overwritten.
**Consequence:** If you keep local nvim tweaks, fork `MyAstroNvim` and point
`roles/astrovim` at your fork. Dotfile edits belong in `conf/`, not in `~`.

## D003 — mise replaces nvm

**Date:** 2026-08-28
**Context:** nvm is bash-only, slow, and macOS/Linux behave differently.
**Decision:** Replace nvm with mise (installed via `mise.run` on both
platforms — single code path). `mise use -g node@<major>` replaces
`nvm install`. The `opencode` role runs npm via `mise exec`.
**Consequence:** The legacy `~/.nvm` directory is intentionally NOT removed
(user data); it just stops being sourced once `.zshrc` switches to
`eval "$(mise activate zsh)"`.

## D004 — macOS needs no sudo in the playbook

**Date:** 2026-08-28
**Context:** Homebrew refuses to run as root, and macOS's default shell is
already zsh (since Catalina).
**Decision:** `install.sh` installs Homebrew on a fresh Mac (the one step
that needs interactive sudo, done before the playbook). No playbook role
uses `become` on macOS: `packages`/`tools`/`neovim`/`lazygit` use brew; the
`shell` role is Linux-only.
**Consequence:** Re-running `./install.sh` on a Mac never prompts for a
password (after the first brew install).

## D005 — ohmyzsh is idempotent (no more wipe-and-reinstall)

**Date:** 2026-08-28
**Context:** The old role did `rm -rf ~/.oh-my-zsh` + reinstall every run
(README called it "deliberate"). This wiped `custom/` and conflicted with
the idempotency requirement.
**Decision:** Replace the install script with a direct `git clone` of
`ohmyzsh/ohmyzsh` with `force: yes` (clone if missing, update if present).
Themes/plugins likewise. The omz installer did nothing we need beyond
cloning (.zshrc comes from the `configs` role, chsh from the `shell` role).

## D006 — uv is owned by `install.sh`, not a role, on macOS

**Date:** 2026-08-28
**Context:** uv is needed *before* the playbook can run (it installs
ansible). `install.sh` installs it via curl on both platforms. The `tools`
role also installs uv on Linux (as a guarantee for users who bypass
`install.sh`).
**Decision:** On macOS the `tools` role does NOT install uv (brew also
packages it — a dual install creates PATH ambiguity). `install.sh` is the
single owner of uv on both platforms.

## D007 — new CLI tools live in the `tools` role, not separate roles

**Date:** 2026-08-28
**Context:** Adding atuin/yazi/glow as separate roles would balloon role
count for little benefit; they share the exact install pattern (github
binary on Linux, brew on macOS).
**Decision:** They are entries in `vars/versions.yml :: github_tools` and
brew lists in `roles/tools/tasks/darwin.yml`. The `tools` tag covers them
all; per-tool selection isn't supported (YAGNI — run the whole `tools` role
or use `--tags tools`).

## D008 — atuin takes over Ctrl-R from fzf

**Date:** 2026-08-28
**Context:** atuin and fzf both bind Ctrl-R. The user chose atuin for shell
history.
**Decision:** `.zshrc` sources fzf first, then `atuin init zsh` later —
atuin wins Ctrl-R. fzf's Ctrl-T (file find) and Alt-C (cd) still work.
