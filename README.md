envconfig — Configure Your Workspace Once for All
================================================

Automated development environment setup via Ansible. **One command** installs
zsh, Oh My Zsh, Neovim, Node.js (via mise), fzf, lazygit, opencode, and all
dotfiles — plus a suite of modern CLI tools (bat, eza, delta, zoxide, btop,
dust, yazi, glow, atuin, etc).

Works on **Ubuntu/Debian servers** and **macOS (Apple Silicon)**. Idempotent:
safe to re-run on an existing machine — it upgrades/overwrites without
conflicts (see [memory/decisions.md](memory/decisions.md) for the design).

Prerequisites
-------------
- **Linux**: Ubuntu 22.04 or 24.04 (or compatible Debian). `autojump` needs
  the `universe` apt component (enabled by default on stock Ubuntu). `sudo`
  access (for system packages; the binary tools install user-local where
  possible). `gh` is installed from its GitHub `.deb` (not apt) so it works
  on 22.04, where it isn't in the default archives.
- **macOS**: Apple Silicon (arm64). `install.sh` installs Homebrew on first
  run (the only step that needs your password; once per machine).
- Nothing else — `install.sh` bootstraps `uv` (which installs Ansible) itself.

Quick Start
-----------
```bash
# One command (bootstraps brew on macOS + uv on both, then runs the playbook):
curl -LsSf https://raw.githubusercontent.com/iwzbi/envconfig/main/install.sh | sh
```
Or, from a clone:
```bash
git clone https://github.com/iwzbi/envconfig.git
cd envconfig
./install.sh                      # add e.g. --tags neovim,fzf to run a subset
```
Then `source ~/.zshrc` (or restart your terminal).

No inventory file needed — the playbook uses `connection: local` and runs
against `localhost`. To update an existing machine later: `./install.sh`
again (it pulls the repo and re-runs; everything is idempotent).

What it installs
----------------
`configme.yaml` runs these roles in order (versions pinned in
[`vars/versions.yml`](vars/versions.yml)):

| Role | Linux | macOS |
|------|-------|-------|
| **homebrew** | — | asserts brew is present (install.sh installs it) |
| **packages** | apt: zsh, git, tmux, ripgrep, fd-find, autojump, cargo, vim, curl, wget, unzip, lsof, bat, jq, btop, direnv | brew: git, curl, wget, tmux, autojump, ripgrep, fd, bat, jq, btop, direnv, gh |
| **tools** | sha256-verified GitHub binaries: delta, zoxide, eza, dust, lazydocker, **yazi, glow, atuin, gh**; uv via install script; batcat→bat symlink | brew: git-delta, zoxide, eza, dust, lazydocker, yazi, glow, atuin, gh |
| **mise** | `mise.run` + `mise use -g node@22` (replaces nvm) | same (single code path) |
| **neovim** | nvim v0.11.0 to `/opt` (SHA256-verified) | brew neovim |
| **ohmyzsh** | Oh My Zsh + Powerlevel10k + syntax-highlighting + autosuggestions (idempotent git update) | same |
| **astrovim** | MyAstroNvim config to `~/.config/nvim` (force: yes — repo is authoritative) | same |
| **fzf** | git clone + `install --all` | same |
| **lazygit** | binary to `/usr/local/bin` (SHA256-verified) | brew lazygit |
| **tmux-plugins** | tpm + tmux-resurrect + tmux-continuum | same |
| **configs** | deploys `.zshrc`, `.tmux.conf`, `.gitconfig` from `conf/` (with `backup: yes`); `.p10k.zsh` only if missing | same |
| **opencode** | npm `-g opencode-ai@latest` via `mise exec`; syncs `conf/opencode/` → `~/.config/opencode/` | same |
| **shell** | `chsh -s /bin/zsh` | no-op (zsh is default on macOS) |

Run a subset with tags (one tag per role): `./install.sh --tags neovim,fzf`.

One-command & updates
---------------------
- `./install.sh` — full setup (bootstraps brew/uv if missing, runs playbook). Args pass through to `ansible-playbook`.
- `make update` — `git pull` then `./install.sh` (idempotent upgrade path).
- `make lint` — `ansible-lint` + `--syntax-check` (no side effects).
- `make test` — Docker build + run the playbook **twice** (second run must not fail → idempotency gate).

Version management
------------------
All pinned versions live in [`vars/versions.yml`](vars/versions.yml) — the
single source of truth. Linux binaries are SHA256-verified at download.
macOS tools follow `brew upgrade` (unpinned by design — see
[memory/decisions.md D001](memory/decisions.md#d001)).

Bump a tool (downloads the asset, computes sha256, updates the file):
```bash
uv run python bin/bump-version.py zoxide 0.11.0
```
Version history is recorded in [memory/versions.md](memory/versions.md).

Tool Usage Guide
---------------

### bat — syntax-highlighted `cat`
```bash
bat file.py              # syntax-highlighted view
bat -p file.py           # plain mode (no decorations)
bat -r 10:20 file.py     # show lines 10-20
bat file1 file2          # concatenate multiple files
```
Aliased as `cat` in `.zshrc`. Theme: Dracula.

### eza — modern `ls` with icons, git status, tree view
```bash
ls                       # icons + git status (aliased)
ll                       # long format (aliased)
la                       # long + hidden (aliased)
lt                       # tree view, depth 2 (aliased)
eza --tree --level=3     # deeper tree
```

### delta — git diff with syntax highlighting
Configured in `.gitconfig` as the default pager. Works automatically with:
```bash
git diff               # side-by-side colored diff
git show HEAD          # colored commit view
git log -p             # colored log with diffs
```
Inside lazygit: diffs are automatically colored by delta.

### zoxide — smarter `cd` (replaces autojump)
```bash
z proj                  # jump to most-used dir matching "proj"
z env config            # multi-keyword match
zi proj                 # interactive selection (fzf popup)
z foo bar               # jump to "bar" inside best "foo" match
```
Learns from your `cd` habits. `j` (autojump) still works alongside.

### fzf — fuzzy finder
```bash
Ctrl-T                  # fuzzy find files (uses fd)
Alt-C                   # fuzzy cd (directories only)
vim **<Tab>             # fzf-completion in any command
```
Note: Ctrl-R is handled by **atuin** (below), not fzf.

### atuin — shell history with full-text search
```bash
Ctrl-R                  # fuzzy full-text search across shell history
atuin search "git push" # search from the command line
atuin stats             # history stats
```
Takes over Ctrl-R from fzf (see [D008](memory/decisions.md#d008)). Works
offline; sync across machines is optional (`atuin sync`).

### mise — runtime version manager (node, python, go, …)
```bash
mise use -g node@22      # set global node version
mise use -g python@3.12  # set global python
mise ls node             # list installed node versions
mise exec -- node -v    # run a command in the mise environment
```
Replaces nvm; identical behaviour on Linux and macOS.

### yazi — terminal file manager
```bash
yazi                    # launch (TUI file manager with image preview)
# inside: hjkl navigate, Enter open, d delete, y yank, q quit
```
`ya` (the companion CLI) is also installed (used for yazi plugins).

### glow — render markdown in the terminal
```bash
glow README.md          # pretty-print a markdown file
glow -p README.md       # pager mode
cat README.md | glow -  # render from stdin
```

### gh — GitHub CLI
```bash
gh pr create            # create a PR interactively
gh pr list              # list open PRs
gh pr checkout 123      # checkout PR #123 locally
gh issue list           # list issues
gh repo clone owner/repo  # clone a repo
gh release create v1.0  # create a release
```
First-time: `gh auth login` to authenticate.

### lazydocker — Docker TUI (same author as lazygit)
```bash
lazydocker              # full Docker dashboard (containers, images, volumes)
```
Inside: `hjkl` to navigate, `Enter` to inspect, `x` to remove, `b` for bulk.

### btop — modern system monitor (replaces htop/top)
```bash
btop                    # full system dashboard (CPU, RAM, disk, network)
```
Inside: `1-9` switch views, `q` quit. Aliased as `top`.

### dust — modern `du` with tree view
```bash
du /path                # tree view of disk usage (aliased)
dust -d 2 /path         # limit depth to 2
dust -n 20              # show top 20 entries
dust -r                 # reverse sort (largest first, aliased)
```

### direnv — directory-specific environment
```bash
# In a project directory:
echo 'export DATABASE_URL=postgresql://...' > .envrc
direnv allow             # load env vars when entering this dir
direnv deny              # unload
# .envrc auto-loads on cd, auto-unloads on leave
```

### jq — JSON processor
```bash
echo '{"name":"alice","age":30}' | jq '.name'      # -> "alice"
curl -s api.example.com | jq '.data[].id'           # extract all IDs
jq '.users | map(.name)' file.json                  # transform
jq '.items | length' file.json                     # count
```

### uv — ultra-fast Python package manager
```bash
uv venv                  # create venv (instant)
uv pip install package   # install (10-100x faster than pip)
uv pip list              # list installed packages
uv run script.py         # run in an ephemeral env
uv tool install ruff      # install a CLI tool globally
```

### tmux-resurrect — session persistence
```bash
# In tmux, press Prefix (C-a) then:
C-a s                   # save session (windows, panes, programs)
C-a r                   # restore session (after tmux restart/reboot)
```
tmux-continuum auto-saves every 15 minutes. On tmux start, sessions auto-restore.

### .gitconfig — sensible git defaults
Deployed to `~/.gitconfig` with: `pull.rebase=true`,
`init.defaultBranch=main`, delta as pager (side-by-side).
Set your name/email in `~/.gitconfig.local`:
```bash
git config --file ~/.gitconfig.local user.name "Your Name"
git config --file ~/.gitconfig.local user.email "you@example.com"
```

opencode API key
----------------
`conf/opencode/opencode.json` reads the API key from
`{file:~/.secrets/idealab.key}` (kept out of this public repo).
One-time per machine:
```bash
mkdir -p ~/.secrets && printf '%s' 'YOUR_KEY' > ~/.secrets/idealab.key && chmod 600 ~/.secrets/idealab.key
```
Without it, opencode runs but the idealab provider has no key.

Project memory
--------------
[memory/](memory/) records conflicts, bugs, version decisions, and the
reasoning behind non-obvious choices (referenced from code as `D0xx`). When
you hit a setup issue on any machine, add a row to
[memory/known-issues.md](memory/known-issues.md).

Sandbox Testing (Docker, Linux)
-------------------------------
The `Dockerfile` builds an Ubuntu 24.04 image with Ansible pre-installed.
The playbook runs at container time so each test starts from a clean machine.

```bash
docker build -t envconfig-test .
docker run --rm -it envconfig-test
# Inside the container (cwd is /opt/envconfig, ansible on PATH):
ansible-playbook configme.yaml --syntax-check
ansible-lint
ansible-playbook configme.yaml
```

The playbook runs as user `tester` (passwordless sudo). Individual roles
have `become: yes` where needed — **do not** use the `--become` flag on
the command line (it would make all tasks run as root, installing
user-level tools like mise/fzf/opencode into `/root/` instead of `~`).

CI runs `ansible-lint` + `--syntax-check`, plus the playbook **twice** on
both `ubuntu-latest` (Docker) and `macos-latest` (`./install.sh`) — the
second run must not fail, which proves idempotency on both platforms.

### Behind a proxy
If your network requires a proxy for GitHub/uv but the proxy 403s on
Ubuntu apt archives (common in corporate environments), build with:
```bash
docker build \
  --build-arg http_proxy=http://PROXY:PORT \
  --build-arg https_proxy=http://PROXY:PORT \
  -t envconfig-test .
```
The Dockerfile sets `Acquire::http::Proxy "DIRECT"` so apt bypasses the
proxy and connects directly to Ubuntu mirrors, while uv/git/curl still
use the proxy env vars.

When running the container, pass proxy env vars and configure git:
```bash
docker run --rm -it \
  -e http_proxy=http://PROXY:PORT \
  -e https_proxy=http://PROXY:PORT \
  envconfig-test
# Inside: configure git proxy (root + tester)
git config --global http.proxy http://PROXY:PORT
sudo git config --global http.proxy http://PROXY:PORT
echo 'Defaults env_keep += "http_proxy https_proxy HTTP_PROXY HTTPS_PROXY"' | sudo tee /etc/sudoers.d/keep_proxy
```

Known items to watch
--------------------
Moved to [memory/known-issues.md](memory/known-issues.md). Highlights:
- **`universe` apt component** (Linux): `autojump` lives in Ubuntu's
  `universe`; enable it if the `packages` role fails.
- **astrovim `force: yes`**: re-running overwrites local `~/.config/nvim`
  edits — the repo is authoritative. Fork MyAstroNvim if you keep local
  nvim tweaks (see [D002](memory/decisions.md#d002)).
- **atuin takes Ctrl-R**: fzf's Ctrl-R is replaced by atuin (fzf's Ctrl-T
  and Alt-C still work) — see [D008](memory/decisions.md#d008).
- **bat on Ubuntu**: the `bat` apt package installs the binary as
  `batcat`; the `tools` role symlinks `/usr/local/bin/bat -> /usr/bin/batcat`.
