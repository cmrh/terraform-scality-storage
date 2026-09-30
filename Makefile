.DEFAULT_GOAL := check

# Recipes use bash features (nullglob, pipefail); Ubuntu's /bin/sh is dash.
SHELL       := bash
.SHELLFLAGS := -euo pipefail -c

# Engine for fmt-check / validate: tofu or terraform. Every module and
# example must pass under both — `make validate-all` runs each in turn.
ENGINE ?= tofu

.PHONY: check fmt fmt-check validate validate-all lint actionlint

# Run the same checks CI runs.
check: fmt-check lint actionlint validate-all

# Format every .tf file in place.
fmt:
	$(ENGINE) fmt -recursive

# Verify formatting (fails if any file is not canonically formatted).
fmt-check:
	$(ENGINE) fmt -check -recursive

# Validate every module and example with $(ENGINE). `init` pulls the
# scality provider (cmrh/scality) from the public registry. Each engine
# keeps its init data in its own TF_DATA_DIR (under the gitignored
# .terraform/) so running both engines in one checkout doesn't collide.
#
# Modules that declare configuration_aliases need their provider aliases
# supplied by a caller: Terraform rejects validating them standalone
# ("Provider configuration not present") while OpenTofu accepts it. To keep
# both engines running identical checks, such modules are validated through
# their examples only — under both engines.
validate:
	@shopt -s nullglob; \
	dirs=(modules/*/*/ $$(find examples -mindepth 2 -name main.tf -printf '%h\n' | sort)); \
	for dir in "$${dirs[@]}"; do \
		if [[ $$dir == modules/* ]] && grep -qs configuration_aliases "$$dir"*.tf; then \
			printf '\n=== %s validate: %s (skipped: needs caller-supplied provider aliases; validated through its examples) ===\n' "$(ENGINE)" "$$dir"; \
			continue; \
		fi; \
		printf '\n=== %s validate: %s ===\n' "$(ENGINE)" "$$dir"; \
		(cd "$$dir" && export TF_DATA_DIR=.terraform/$(ENGINE) \
			&& $(ENGINE) init -backend=false -input=false >/dev/null \
			&& $(ENGINE) validate); \
	done

# Validate with both engines.
validate-all:
	$(MAKE) validate ENGINE=tofu
	$(MAKE) validate ENGINE=terraform

# Static analysis with tflint (rules in .tflint.hcl).
lint:
	tflint --init
	tflint --recursive --format compact

# Lint GitHub Actions workflows (config in .github/actionlint.yaml). Also
# shell-checks run: scripts when shellcheck is installed.
actionlint:
	actionlint
