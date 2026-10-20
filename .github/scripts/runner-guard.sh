#!/usr/bin/env bash
# Keeps the self-hosted runner (tf-module-runner) for heavy acceptance work:
#   - integration.yml is the only workflow allowed off GitHub-hosted runners;
#   - integration.yml may only be triggered manually, on schedule, by a
#     release, or by repository_dispatch (never by a push or a pull request).
# The runner host enforces the same rules in its pre-job hook; this check
# catches mistakes in our own branches before review.
set -euo pipefail
shopt -s nullglob

dir=.github/workflows
self_hosted=integration.yml
allowed_triggers="workflow_dispatch schedule release repository_dispatch"
fail=0

for f in "$dir"/*.yml "$dir"/*.yaml; do
  [[ $(basename "$f") == "$self_hosted" ]] && continue
  while IFS= read -r line; do
    echo "::error file=$f::only $self_hosted may leave GitHub-hosted runners: $line"
    fail=1
  done < <(grep -nE '^\s*runs-on:' "$f" | grep -vE 'runs-on:\s*(ubuntu|macos|windows)-[a-z0-9.-]+\s*$' || true)
done

f="$dir/$self_hosted"
if [[ -f $f ]]; then
  # Trigger names: the keys of the top-level `on:` block (block form only).
  if grep -qE '^on:\s*\S' "$f"; then
    echo "::error file=$f::write 'on:' as a block so its triggers can be checked"
    fail=1
  fi
  while IFS= read -r t; do
    if [[ " $allowed_triggers " != *" $t "* ]]; then
      echo "::error file=$f::trigger '$t' not allowed (allowed: $allowed_triggers)"
      fail=1
    fi
  done < <(awk '/^on:/{in_on=1; next} in_on && /^[^ #]/{exit} in_on && /^  [a-z_]+:/{sub(/^  /,""); sub(/:.*/,""); print}' "$f")
fi

exit "$fail"
