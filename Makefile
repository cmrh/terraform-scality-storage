.DEFAULT_GOAL := check

.PHONY: check fmt fmt-check validate lint

# Run the same checks CI runs.
check: fmt-check lint

# Format every .tf file in place.
fmt:
	tofu fmt -recursive

# Verify formatting (fails if any file is not canonically formatted).
fmt-check:
	tofu fmt -check -recursive

# Validate every module. `tofu init` pulls the scality provider
# (cmrh/scality) from the public registry. Also run in CI by
# .github/workflows/validate.yml.
validate:
	@set -e; \
	shopt -s nullglob; \
	for module in modules/*/*/; do \
		printf "\n=== %s ===\n" "$$module"; \
		(cd "$$module" && tofu init -backend=false && tofu validate); \
	done

# Static analysis with tflint (rules in .tflint.hcl).
lint:
	@tflint --init
	@tflint --recursive --format compact
