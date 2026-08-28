standup — Configure Your Workspace Once for All
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
  is needed only for apt system packages + `chsh`; all CLI binaries install
  user-local to `~/.local` (no sudo — see D009). `gh` is installed from its
  GitHub `.deb` (not apt) so it works on 22.04, where it isn't in the archives.
- **macOS**: Apple Silicon (arm64). `install.sh` installs Homebrew on first
  run (the only step that needs your password; once per machine).
- Nothing else — `install.sh` bootstraps `uv` (which installs Ansible) itself.

Quick Start
-----------
```bash
# One command (bootstraps brew on macOS + uv on both, then runs the playbook):
curl -LsSf https://raw.githubusercontent.com/iwzbi/standup/main/install.sh | sh
```
Or, from a clone:
```bash
git clone https://github.com/iwzbi/standup.git
cd standup
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
| **neovim** | nvim v0.11.0 to `~/.local` (SHA256-verified, no sudo) | brew neovim |
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
docker build -t standup-test .
docker run --rm -it standup-test
# Inside the container (cwd is /opt/standup, ansible on PATH):
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
  -t standup-test .
```
The Dockerfile sets `Acquire::http::Proxy "DIRECT"` so apt bypasses the
proxy and connects directly to Ubuntu mirrors, while uv/git/curl still
use the proxy env vars.

When running the container, pass proxy env vars and configure git:
```bash
docker run --rm -it \
  -e http_proxy=http://PROXY:PORT \
  -e https_proxy=http://PROXY:PORT \
  standup-test
# Inside: configure git proxy (root + tester)
git config --global http.proxy http://PROXY:PORT
sudo git config --global http.proxy http://PROXY:PORT
echo 'Defaults env_keep += "http_proxy https_proxy HTTP_PROXY HTTPS_PROXY"' | sudo tee /etc/sudoers.d/keep_proxy
```

### Air-gapped / red-zone (uv install fallback)

`install.sh` and the `tools` role both fetch uv from
`https://astral.sh/uv/install.sh`. If your network blocks astral.sh (e.g. a
corporate "red zone"), the install **automatically falls back** instead of
failing (see [memory/decisions.md D011](memory/decisions.md#d011)):

- **macOS** → `brew install uv` (uv is in Homebrew core; brew is ensured by
  `install.sh` on a fresh Mac).
- **Linux** → `pipx install uv` (installs pipx via `sudo apt-get install -y
  pipx` first if missing). Requires **PyPI to be reachable**.

Both land uv in `~/.local/bin`, so the rest of the setup is identical. If
astral.sh **and** PyPI are both unreachable (fully air-gapped), pre-stage the
uv binary yourself:

```bash
mkdir -p ~/.local/bin && cp /path/to/predownloaded-uv ~/.local/bin/uv && chmod +x ~/.local/bin/uv
```

`install.sh`'s `command -v uv` check then skips the whole install.

### Air-gapped / red-zone (mise install fallback)

The `mise` role fetches its installer from `https://mise.run`, which is itself
just a redirect to the GitHub release's `install.sh`. If your network 403s
the `mise.run` → `github.com` redirect tunnel (a corporate "red zone") but
`github.com` is still reachable directly, the role **automatically falls back**
to fetching that same installer from its direct GitHub URL
(`github.com/jdx/mise/releases/latest/download/install.sh`) and runs it — no
version pin or arch detection needed, and it still lands in `~/.local/bin/mise`
(see [memory/decisions.md D016](memory/decisions.md#d016)).

If `github.com` is *also* unreachable (fully air-gapped), the other documented
install methods don't help: the npm package `@jdxcode/mise` is circular
(needs node, which needs mise), and the `mise.jdx.dev` apt repo / PPA are the
same external host family as `mise.run`. Pre-stage the binary yourself:

```bash
mkdir -p ~/.local/bin && cp /path/to/predownloaded-mise ~/.local/bin/mise && chmod +x ~/.local/bin/mise
```

The role's `creates:` check then skips the install.

### Air-gapped / red-zone (opencode via npmjs)

The `opencode` role installs the CLI with `mise exec -- npm install -g
opencode-ai@latest`, which reaches the npm registry at `registry.npmjs.org`.
Unlike uv (D011) and mise (D016), this dependency has **no automatic
fallback**: npm cannot bootstrap itself from a non-npm source, so there is no
`block`/`rescue` to another host. `registry.npmjs.org` is a different host
from `astral.sh` and `mise.run`, so in many red zones it is reachable even when
those are not — if yours is, `opencode` installs normally and no action is
needed.

If `npmjs` is **also** blocked, point npm at a mirror you can reach before
running the playbook (or before `--tags opencode`):

```bash
mise exec -- npm config set registry https://your-npm-mirror.example/
```

or skip the role entirely (`./install.sh --skip-tags opencode`) and install
`opencode-ai` yourself later once you have npm connectivity. There is no
`creates:`/stat gate on this role (it always re-checks `@latest`), so a
pre-staged binary is not auto-detected — configure a mirror or skip the role.

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
- **migrating from nvm with a `~/.npmrc` prefix** (Linux/macOS): a leftover
  `prefix=${HOME}/.npm-global` line (the sudo-free-global pattern from the
  nvm/system-node era) diverts `mise exec -- npm -g` installs — e.g.
  `opencode` — out of mise's shimmed tree into `~/.npm-global/bin`, which is
  neither on `conf/.zshrc`'s PATH nor shimmed by `mise activate`, so the CLI
  vanishes (`command not found`) after re-running `./install.sh`. Remove the
  line (`npm config delete prefix`); mise installs node user-local, so
  `npm -g` is already sudo-free, and CLIs then land in mise's node bin and
  resolve automatically. See [D014](memory/decisions.md#d014). The playbook
  now also auto-warns at start (preflight grep of `~/.npmrc`) and fails fast
  post-install if `opencode` resolves outside mise's node tree — see
  [D015](memory/decisions.md#d015).
