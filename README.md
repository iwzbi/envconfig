envconfig — Configure Your Workspace Once for All
================================================

Automated development environment setup via Ansible. One command installs
zsh, Oh My Zsh, Neovim, Node.js, fzf, lazygit, opencode, and all dotfiles —
plus a suite of modern CLI tools (bat, eza, delta, zoxide, btop, dust, etc).

Prerequisites
-------------
- **Ubuntu 24.04** (or compatible Debian). The `autojump` package requires
  the `universe` apt component — enabled by default on stock Ubuntu.
- **uv** (Python package manager) — installs Ansible and manages the project
  environment. Install it with `curl -LsSf https://astral.sh/uv/install.sh | sh`
  (one-time per machine).
- **sudo** access (several roles use `become: yes` for system-level tasks).

Quick Start
-----------
```bash
git clone https://github.com/iwzbi/envconfig.git
cd envconfig
curl -LsSf https://astral.sh/uv/install.sh | sh   # install uv (once per machine)
uv run ansible-playbook configme.yaml
```
Then `source ~/.zshrc` (or restart your terminal).

No inventory file needed — the playbook uses `connection: local`
and runs against `localhost`.

What it installs
----------------
`configme.yaml` runs 12 roles in order:

| Role | Installs |
|------|----------|
| **packages** | apt deps: zsh, git, tmux, ripgrep, fd-find, autojump, cargo, vim, curl, wget, unzip, lsof, **bat, eza, jq, btop, direnv, gh** |
| **tools** | delta (git diff pager), zoxide (smarter cd), lazydocker (Docker TUI), dust (modern du), uv (fast Python). batcat→bat symlink. |
| **nodejs** | nvm + Node 22 (`creates` guard, `changed_when` on already-installed) |
| **neovim** | nvim v0.11.0 to `/opt` (SHA256-verified) |
| **ohmyzsh** | Oh My Zsh + Powerlevel10k + syntax-highlighting + autosuggestions (reinstalled every run by design) |
| **astrovim** | MyAstroNvim config to `~/.config/nvim` |
| **fzf** | fuzzy finder + key-bindings/completion (`--all`) |
| **lazygit** | git TUI, binary-only to `/usr/local/bin` (SHA256-verified) |
| **tmux-plugins** | tpm (plugin manager) + tmux-resurrect (session save/restore) + tmux-continuum (auto-save) |
| **configs** | deploys `.zshrc`, `.tmux.conf`, `.gitconfig` from `conf/`; `.p10k.zsh` copied only if missing (`force: no`) |
| **opencode** | opencode CLI to `~/.opencode/bin` (always-latest; self-skips when current) + syncs configs from `conf/opencode/` to `~/.config/opencode/` |
| **shell** | sets login shell to `/bin/zsh` |

Run a subset with tags (one tag per role): `--tags neovim,fzf`.

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
Ctrl-R                  # fuzzy search shell history
Alt-C                   # fuzzy cd (directories only)
vim **<Tab>             # fzf-completion in any command
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

Sandbox Testing (Docker)
------------------------
The `Dockerfile` builds an Ubuntu 24.04 image with Ansible pre-installed.
The playbook runs at container time so each test starts from a clean machine.

### Build
```bash
docker build -t envconfig-test .
```

### Run a fresh container
```bash
docker run --rm -it envconfig-test
# Inside the container (cwd is /opt/envconfig, ansible on PATH):
ansible-playbook configme.yaml --syntax-check
ansible-lint
ansible-playbook configme.yaml
```

The playbook runs as user `tester` (passwordless sudo). Individual roles
have `become: yes` where needed — **do not** use the `--become` flag on
the command line (it would make all tasks run as root, installing
user-level tools like nvm/fzf/opencode into `/root/` instead of `~`).

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
- **`universe` apt component**: `autojump` lives in Ubuntu's `universe`.
  The stock `ubuntu:24.04` image and desktop installs include it; if
  missing, enable it or the `packages` role fails.
- **Oh My Zsh**: deliberately non-idempotent (reinstalled every run per
  user preference) — expect `changed` on that role every run.
- **opencode always-latest**: the opencode role has no `creates` guard
  and re-downloads the installer every run. It self-skips the actual
  binary install when the version is current (`changed_when: false`).
- **bat on Ubuntu**: the `bat` package installs the binary as `batcat`.
  The `tools` role creates a symlink `/usr/local/bin/bat -> /usr/bin/batcat`.
