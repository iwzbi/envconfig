FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Enable the 'universe' apt component. The 'packages' role installs
# 'autojump', which lives in universe; the stock ubuntu:24.04 image ships
# only 'main'. Adding a separate DEB822 sources file keeps this codename-agnostic.
RUN . /etc/os-release \
  && printf 'Types: deb\nURIs: http://archive.ubuntu.com/ubuntu/\nSuites: %s %s-updates %s-security\nComponents: universe\nSigned-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg\n' \
     "$VERSION_CODENAME" "$VERSION_CODENAME" "$VERSION_CODENAME" \
     > /etc/apt/sources.list.d/universe.sources \
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
