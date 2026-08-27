Configure Your Workspace Once for All~
==============================================


Getting Started
---------------
```
git clone https://github.com/iwzbi/envconfig.git
cd envconfig
pip install -r requirements.txt
ansible-playbook -i inventory.ini configme.yaml
```
Then `source ~/.zshrc` or `docker exec -it $CONTAINER /bin/zsh` if you are working in docker

What it installs
---------------
`configme.yaml` imports 10 roles (in this order):

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
| **opencode** | opencode CLI to `~/.opencode/bin` (always-latest; self-skips when current) + syncs pre-saved `opencode.json`/`tui.json`/`dcp.jsonc`/`vibeguard.config.json` from `conf/opencode/` to `~/.config/opencode/`. Plugins: pty, oh-my-openagent, superpowers, dcp (compress limits 400k/100k), notifier, vibeguard (secret redaction), scheduler (cron jobs), goal-plugin (`/goal` auto-continue). idealab API key reads `{file:~/.secrets/idealab.key}` — kept out of the repo |
| **shell** | sets login shell to `/bin/zsh` |

Run a subset with tags (one tag per role): `--tags neovim,fzf`.

Sandbox testing
---------------
The playbook was syntax-checked but **never run end-to-end in isolation** — the authoring environment had no container runtime. Use the `Dockerfile` to verify real execution and idempotency.

### Already verified (no sandbox needed)
- `ansible-playbook --syntax-check` passes
- `zsh -n conf/.zshrc` OK
- neovim + lazygit SHA256 checksums match the upstream tarballs
- opencode `--no-modify-path` is a real installer flag; the role's `changed_when` logic matches the install script's `"already installed"` exit path

### Build & enter the test image
```bash
docker build -t envconfig-test .
docker run --rm -it envconfig-test
# inside the container (cwd is /opt/envconfig, ansible on PATH):
ansible-playbook -i inventory.ini configme.yaml --syntax-check
ansible-lint
ansible-playbook -i inventory.ini configme.yaml
```

### Sandbox TODO checklist

Run inside the container and confirm each:

- [ ] `ansible-lint` → no blocking findings
- [ ] Full run completes with `failed=0`
- [ ] **Idempotency**: immediate re-run reports `changed=0`, except the deliberately non-idempotent `ohmyzsh` role (reinstalls every run by design)
- [ ] **opencode self-skip**: re-run → opencode task `changed: false` (the role injects `~/.opencode/bin` into PATH so the installer's version-check sees opencode and skips the download)
- [ ] **neovim `creates`**: re-run → unarchive skipped (`/opt/nvim-linux-x86_64` exists)
- [ ] **nvm `changed_when`**: re-run → node install `changed: false` (nvm prints `is already installed`)
- [ ] **fzf**: `~/.fzf/bin/fzf` exists; re-run skips via `creates`
- [ ] **lazygit**: `ls /usr/local/bin/lazygit` is the only file added there (no `README`/`LICENSE` dumped); re-run skips
- [ ] **.p10k.zsh `force: no`**: edit `~/.p10k.zsh`, re-run → kept; delete it, re-run → copied
- [ ] **autojump loads**: `zsh -ic 'type j'` → `j is a shell function`
- [ ] **chsh**: `getent passwd tester | cut -d: -f7` → `/bin/zsh`
- [ ] **opencode on PATH**: `zsh -ic 'command -v opencode'` → `/home/tester/.opencode/bin/opencode`

### Known items to watch
- **`universe` apt component**: `autojump` lives in Ubuntu's `universe`. The Dockerfile enables it; on a real host ensure `universe` is enabled or the `packages` role fails.
- **nvm stdout coupling**: the `nodejs` role's `changed_when` keys off nvm's exact `"is already installed"` wording. Works today; fragile to upstream nvm changes.
- **Oh My Zsh**: deliberately non-idempotent (reinstalled every run per user preference) — expect `changed` on that role every run.
- **opencode API key**: `conf/opencode/opencode.json` reads the key from `{file:~/.secrets/idealab.key}` (kept out of this public repo). One-time per machine: `mkdir -p ~/.secrets && printf '%s' 'YOUR_KEY' > ~/.secrets/idealab.key && chmod 600 ~/.secrets/idealab.key`. Without it, opencode runs but the idealab provider has no key.

Test image design
-----------------
The `Dockerfile` is a **harness**, not a baked result — you run the playbook at container time so each test starts from a clean machine:
- `ubuntu:24.04` base (matches the Debian package names the playbook uses: `fd-find`, `autojump`, `ripgrep`)
- non-root `tester` user with passwordless sudo → exercises the real `become: yes` paths
- venv install of `ansible` + `ansible-lint` (mirrors `requirements.txt`)
- enables the `universe` apt component (required by `autojump`)
- `.dockerignore` skips `.venv/`, `.git/`, `.omo/` to keep the build context small
