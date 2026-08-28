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

## D009 — sudo minimization (binaries install user-local)

**Date:** 2026-08-28
**Context:** Several tools were installed to system paths (/usr/local/bin,
/opt) which forced `become: true` (sudo). On machines where the user lacks
passwordless sudo, the playbook hung or failed mid-run.
**Decision:** All GitHub binaries (delta, zoxide, eza, dust, lazydocker,
yazi, glow, atuin, gh, lazygit) and neovim install **user-local** under
`~/.local/bin` / `~/.local/...` — no sudo. `.deb` assets (delta, gh) are
extracted with `dpkg-deb -x` (NOT `apt install`) so we get the binary without
root or system-package metadata. The batcat→bat symlink lives in
`~/.local/bin`, not `/usr/local/bin`.
**Consequence:** The only `become: true` tasks left are: the `packages` role
(apt system packages + the `/etc/apt/apt.conf.d/99no-proxy` config — apt
config fundamentally needs root) and the `shell` role (`chsh` needs root to
change the login shell without an interactive password prompt). apt system
packages and chsh are irreducibly root on Debian/Ubuntu; everything else is
user-local. On a machine WITHOUT sudo, the user must still run apt + chsh by
hand (or have sudo for just those).

## D010 — weekly auto-bump CI bumps only low-risk tools

**Date:** 2026-08-28
**Context:** Versions are pinned for reproducibility, but bumping them by hand
is tedious and easy to forget. The user wants the latest versions kept
automatically, but a blanket auto-bump is unsafe for tools whose config/API
breaks across versions.
**Decision:** A weekly GitHub Actions workflow (`.github/workflows/bump.yml`,
Monday 06:00 UTC) runs `bump-version.py --latest-all`, which bumps every
github_tools entry marked `auto: true` to its latest GitHub release (downloads
the asset, recomputes sha256, rewrites `vars/versions.yml`), then opens a PR.
Only the 6 LOW compat-risk tools are `auto: true`: zoxide, dust, eza, glow,
lazydocker, gh. High-risk tools (neovim — must match AstroNvim API; atuin —
init/config schema breaks across majors; yazi — pre-1.0 plugin API evolves;
delta — .gitconfig keys change across majors; lazygit — config format changed
before) are NOT auto and are bumped manually with `bump-version.py --latest
<tool>` after a human review.
**Why not auto-bump everything:** the smoke test catches "binary runs" +
"config loads headless" (the nvim functional check in `bin/smoke-test.sh`),
but does NOT catch a plugin that breaks only when USED (headless load-only
catches ~50% of real nvim-bump breakage). Auto-bumping neovim could ship a
break that smoke misses. The low-risk 6 have stable interfaces and are
empirically safe to float (the user's Mac already floats all of them via brew
with no issues — D001).
**Consequence:** The PR's own CI (`test.yml` on: pull_request) re-runs the full
22.04/24.04/macos playbook×2 + smoke matrix on the bumped versions. Merge only
if green. The weekly job itself does NOT run tests (no duplication — the PR
triggers them). If a bumped version breaks CI, the PR stays red: investigate,
don't merge.

## D011 — uv install falls back when astral.sh is unreachable (red zone)

**Date:** 2026-08-28
**Context:** `install.sh` bootstraps uv *before* the playbook (uv installs
ansible), and the `tools` role installs uv on Linux as a guarantee for users
who bypass `install.sh`. Both reached for `https://astral.sh/uv/install.sh`.
In a restricted network ("red zone") that 403s or times out on astral.sh, the
bootstrap dies before the playbook can start — the whole setup is blocked with
no recourse. `apt install uv` is not a fallback: uv is absent from the official
Ubuntu/Debian archives (`Unable to locate package`), and the only apt source
(deb.griffo.io) is itself an external host that is also typically unreachable
in a red zone.
**Decision:** Keep the Astral installer as the *primary* path but fall back
automatically when it is unreachable:
- `install.sh`: `curl --max-time 20` the installer to a temp file; on failure,
  by OS — macOS: `brew install uv` (uv is in Homebrew core; brew is already
  ensured by `install.sh` on a fresh Mac); Linux: `pipx install uv`, running
  `sudo apt-get install -y pipx` first if pipx is missing (sudo for apt is
  already an expected prerequisite — D009; pipx needs PyPI reachable).
- `roles/tools/tasks/linux.yml`: the uv install is a `block`/`rescue`; the
  `rescue` runs `pipx install uv` when the Astral `get_url`/command fails.
- `pipx` is added to the `packages` role's apt list so the `tools`-role
  fallback can rely on pipx already being present (pipx is a system package).
Both fallbacks land uv in `~/.local/bin` — the same path the Astral installer
uses — so PATH and the `tools` role's stat-gate stay consistent regardless of
which method installed it. macOS's `tools` role still does NOT install uv
(D006 unchanged: `install.sh` owns uv on both platforms; brew on mac is the
fallback inside `install.sh`, not the `tools` role).
**Consequence:** Red-zone users with PyPI reachable get a working setup with no
extra flags (zero-config). Red-zone users WITHOUT PyPI (fully air-gapped) must
still pre-stage the uv binary to `~/.local/bin/uv` by hand — `install.sh`'s
`command -v uv` gate then skips the whole install. The fallback adds one sudo
hit (`apt install pipx`) on Linux during the `install.sh` bootstrap, within the
existing "sudo for apt system packages" contract. uv is NOT version-pinned via
the fallbacks (follows brew/pipx), consistent with D006 not pinning uv.

## D012 — github_binary find excludes share/completions (same-named completion trap)

**Date:** 2026-08-28
**Context:** The `github_binary` role locates the binary inside an extracted
`.deb`/tarball with `find <extract> -type f -name <bin> | head -1`. GitHub
`.deb` releases ship a **same-named** bash-completion file alongside the real
binary — e.g. `gh`'s `.deb` contains both `usr/bin/gh` (41 MB ELF) and
`usr/share/bash-completion/completions/gh` (16 KB shell script). `find`'s result
order is the filesystem's readdir order, which is **non-deterministic across
filesystems**: on a real host's ext4 the completion file sorted *before* the
binary, so `head -1` picked the script and `install` copied it to
`~/.local/bin/gh`. `gh` then resolved to a completion script that `/bin/sh`
cannot parse (`Syntax error: "(" unexpected`). It was deterministic *per
filesystem* but varied *across* filesystems — CI ran on Docker overlayfs, where
`find` returned the binary first, so the smoke test stayed green while real
installs (the documented `curl ... | sh`) shipped a broken `gh`. Any `type: deb`
tool (gh, delta) and any tarball shipping a same-name completion file was exposed.
**Decision:** Exclude `*/share/*`, `*/bash-completion/*`, and
`*/completions/*` from the `find`. Real binaries live under `usr/bin/` (deb) or
the archive root / a `bin/` dir (tarball) — never under these paths — so the
exclusions are safe and make selection **deterministic** regardless of readdir
order.
**Consequence:** The `gh`-as-completion-script failure mode is closed for every
tool, and CI green no longer masks the bug because correctness no longer depends
on `find` order.
