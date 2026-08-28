# envconfig — convenience targets. The real entry point is install.sh.
.PHONY: setup update lint test test-docker smoke

# Full setup (installs uv/brew if missing, runs the whole playbook).
# Pass extra args via SETUP_ARGS, e.g. make setup SETUP_ARGS=--tags=neovim,fzf
setup:
	./install.sh $(SETUP_ARGS)

# Update the repo and re-run the playbook (idempotent upgrade path).
update:
	git pull --ff-only
	./install.sh

# Lint + syntax check (no side effects).
lint:
	uv run ansible-lint
	uv run ansible-playbook configme.yaml --syntax-check

# Build the Linux sandbox image and run the playbook twice + a smoke test
# inside it (second run must not fail -> idempotency; smoke proves the
# installed binaries actually execute, not just that they were downloaded).
test: test-docker

test-docker:
	docker build -t envconfig-test . && \
	docker run --rm envconfig-test bash -lc '\
		ansible-playbook configme.yaml && \
		echo "--- second run (idempotency check) ---" && \
		ansible-playbook configme.yaml && \
		echo "--- smoke test ---" && \
		bin/smoke-test.sh'

# Run the smoke test against the current machine (assumes the playbook has
# already been run here). Verifies every installed tool actually executes.
smoke:
	bin/smoke-test.sh
