FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# The stock ubuntu:24.04 image already includes the 'universe' component
# (Components: main universe restricted multiverse in ubuntu.sources),
# so 'autojump' from the 'packages' role is available without extra config.
# Bypass any proxy env vars for apt (the proxy may 403 on Ubuntu archives).
RUN echo 'Acquire::http::Proxy "DIRECT";' > /etc/apt/apt.conf.d/99no-proxy \
  && echo 'Acquire::https::Proxy "DIRECT";' >> /etc/apt/apt.conf.d/99no-proxy \
  && apt-get update \
  && apt-get install -y --no-install-recommends \
       python3 python3-venv python3-pip \
       sudo git curl wget ca-certificates openssh-client \
  && rm -rf /var/lib/apt/lists/*

# Non-root ansible user with passwordless sudo. This mirrors a real host where
# become: yes is needed, so the playbook's become paths actually get exercised.
RUN useradd -m -s /bin/bash tester \
  && echo 'tester ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/tester \
  && chmod 0440 /etc/sudoers.d/tester

WORKDIR /opt/envconfig
COPY . .

# Install ansible (+ ansible-lint for the lint TODO) into a venv, matching
# requirements.txt. chown last so tester owns the venv too.
RUN python3 -m venv .venv \
  && .venv/bin/pip install --upgrade pip \
  && .venv/bin/pip install -r requirements.txt ansible-lint \
  && chown -R tester:tester /opt/envconfig

USER tester
ENV PATH="/opt/envconfig/.venv/bin:$PATH"

# Harness, not a baked result: drop into a shell and run the playbook at
# container time so every test starts from a clean machine.
CMD ["bash"]
