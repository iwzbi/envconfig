# BASE_IMAGE lets CI build against both 22.04 and 24.04 from the same
# Dockerfile (see .github/workflows/test.yml). Defaults to 24.04 for local use.
ARG BASE_IMAGE=ubuntu:24.04
FROM ${BASE_IMAGE}

ENV DEBIAN_FRONTEND=noninteractive

# The stock ubuntu images (22.04 and 24.04) include the 'universe' component
# (Components: main universe restricted multiverse in ubuntu.sources),
# so 'autojump' from the 'packages' role is available without extra config.
# Bypass any proxy env vars for apt (the proxy may 403 on Ubuntu archives).
RUN echo 'Acquire::http::Proxy "DIRECT";' > /etc/apt/apt.conf.d/99no-proxy \
  && echo 'Acquire::https::Proxy "DIRECT";' >> /etc/apt/apt.conf.d/99no-proxy \
  && apt-get update \
  && apt-get install -y --no-install-recommends \
        python3 \
        sudo git curl wget ca-certificates openssh-client \
  && rm -rf /var/lib/apt/lists/*

# Non-root ansible user with passwordless sudo. This mirrors a real host where
# become: yes is needed, so the playbook's become paths actually get exercised.
RUN useradd -m -s /bin/bash tester \
  && echo 'tester ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/tester \
  && chmod 0440 /etc/sudoers.d/tester

WORKDIR /opt/standup
COPY . .

# uv is installed as root (to /root/.local); copy the self-contained binary
# to a shared path so the runtime user 'tester' can execute it (a symlink into
# /root would be unreadable once USER switches away from root). Then run uv
# sync AS tester — so the venv and any uv-managed Python land under tester's
# home (readable at runtime) instead of /root (mode 700, unreadable by tester).
# This avoids the "bad interpreter: Permission denied" trap on 22.04, where
# the system python (3.10) is too old (project needs >=3.12) so uv downloads a
# managed CPython — if that download lands under /root, tester can't run it.
RUN curl -LsSf https://astral.sh/uv/install.sh | sh \
  && cp /root/.local/bin/uv /usr/local/bin/uv \
  && chown -R tester:tester /opt/standup \
  && runuser -u tester -- sh -c 'export HOME=/home/tester && cd /opt/standup && uv sync'

USER tester
ENV PATH="/opt/standup/.venv/bin:$PATH"

# Harness, not a baked result: drop into a shell and run the playbook at
# container time so every test starts from a clean machine.
CMD ["bash"]
