envconfig — Configure Your Workspace Once for All
================================================

Automated development environment setup via Ansible. One command installs
zsh, Oh My Zsh, Neovim, Node.js, fzf, lazygit, opencode, and all dotfiles.

Prerequisites
-------------
- **Ubuntu 24.04** (or compatible Debian). The `autojump` package requires
  the `universe` apt component — enabled by default on stock Ubuntu.
- **Python 3** + `pip` (for installing Ansible).
- **sudo** access (several roles use `become: yes` for system-level tasks:
  apt install, neovim unarchive, lazygit binary copy, chsh).

Quick Start
-----------
```bash
git clone https://github.com/iwzbi/envconfig.git
cd envconfig
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
.venv/bin/ansible-playbook configme.yaml
```
Then `source ~/.zshrc` (or restart your terminal).

No inventory file needed — the playbook uses `connection: local`
and runs against `localhost`.

What it installs
----------------
`configme.yaml` runs 10 roles in order:

| Role | Installs |
|------|----------|
| **packages** | apt deps: zsh, git, tmux, ripgrep, fd-find, autojump, cargo, vim, curl, wget, unzip, lsof |
| **nodejs** | nvm + Node 22 (`creates` guard, `changed_when` on already-installed) |
| **neovim** | nvim v0.11.0 to `/opt` (SHA256-verified) |
| **ohmyzsh** | Oh My Zsh + Powerlevel10k + syntax-highlighting + autosuggestions (reinstalled every run by design) |
| **astrovim** | MyAstroNvim config to `~/.config/nvim` |
| **fzf** | fuzzy finder + key-bindings/completion (`--all`) |
| **lazygit** | git TUI, binary-only to `/usr/local/bin` (SHA256-verified) |
| **configs** | deploys dotfiles from `conf/`; sets `EDITOR`/`VISUAL=nvim`; `.p10k.zsh` copied only if missing (`force: no`) |
| **opencode** | opencode CLI to `~/.opencode/bin` (always-latest; self-skips when current) + syncs pre-saved `opencode.json`/`tui.json`/`dcp.jsonc`/`vibeguard.config.json` from `conf/opencode/` to `~/.config/opencode/`. `opencode.json` reads idealab API key from `{file:~/.secrets/idealab.key}` — see [opencode API key](#opencode-api-key) below. |
| **shell** | sets login shell to `/bin/zsh` |

Run a subset with tags (one tag per role): `--tags neovim,fzf`.

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
If your network requires a proxy for GitHub/pip but the proxy 403s on
Ubuntu apt archives (common in corporate environments), build with:
```bash
docker build \
  --build-arg http_proxy=http://PROXY:PORT \
  --build-arg https_proxy=http://PROXY:PORT \
  -t envconfig-test .
```
The Dockerfile sets `Acquire::http::Proxy "DIRECT"` so apt bypasses the
proxy and connects directly to Ubuntu mirrors, while pip/git/curl still
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

### Verified results
All tests pass in a fresh container:

| Check | Result |
|-------|--------|
| `ansible-lint` | No blocking findings (style warnings only) |
| Full run | `ok=27  changed=23  failed=0` |
| Idempotency re-run | `ok=25  changed=4  failed=0  skipped=2` |
| opencode self-skip | `changed: false` on re-run |
| neovim `creates` | Unarchive skipped on re-run |
| nvm `changed_when` | `changed: false` on re-run (checks stdout + stderr) |
| fzf | `~/.fzf/bin/fzf` exists; re-run skips via `creates` |
| lazygit | `/usr/local/bin/lazygit` only (no README/LICENSE); re-run skips |
| `.p10k.zsh` `force: no` | Custom edit survives re-run |
| autojump | `zsh -ic 'type j'` → `j is a shell function` |
| chsh | `getent passwd $USER \| cut -d: -f7` → `/bin/zsh` |
| opencode on PATH | `zsh -ic 'command -v opencode'` → `~/.opencode/bin/opencode` |

The 4 `changed` tasks on re-run are all expected:
- 3 × ohmyzsh (remove + reinstall + reclone — by design)
- 1 × configs `.zshrc` (ohmyzsh modifies `.zshrc` during reinstall; configs overwrites with the authoritative version)

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
