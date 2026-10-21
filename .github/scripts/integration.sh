#!/usr/bin/env bash
# Integration suite: checks that example configurations apply, re-plan with no
# changes, and destroy cleanly against live clusters. It does not test data
# paths (replication, log delivery); those are tested during development.
# Non-blocking: never a release gate.
#
# Environment:
#   ENGINE            terraform (default) or tofu
#   CONFIGS           space-separated subset of: access-logging artesca-edge-to-ring
#                     s3-crr-one-direction delegated-admin (default: all)
#   RUN_PREFIX        prefix for every account/bucket/user name (default: local<epoch>)
#   PROVIDER_VERSION  wait until this cmrh/scality or cmrh/artesca version is on the registry
#   PROVIDER_NAME     scality | artesca (with PROVIDER_VERSION; default scality)
#   SCALITY_ENDPOINT, SCALITY_ACCESS_KEY, SCALITY_SECRET_KEY   primary RING (server access logging
#                     enabled; ARTESCA must reach this endpoint)
#   TF_VAR_dest_endpoint, TF_VAR_dest_access_key, TF_VAR_dest_secret_key   CRR destination RING
#   ARTESCA_MANAGEMENT_ENDPOINT, ARTESCA_OIDC_URL, ARTESCA_USERNAME, ARTESCA_PASSWORD,
#   ARTESCA_S3_ENDPOINT, ARTESCA_INSECURE_SKIP_VERIFY            ARTESCA
set -uo pipefail

ENGINE=${ENGINE:-terraform}
root=$(cd "$(dirname "$0")/../.." && pwd)
ex=$root/examples
all="access-logging artesca-edge-to-ring s3-crr-one-direction delegated-admin"
CONFIGS=${CONFIGS:-$all}
RUN_PREFIX=${RUN_PREFIX:-local$(date +%s)}
export TF_DATA_DIR=.terraform/$ENGINE TF_IN_AUTOMATION=1 TF_INPUT=0 AWS_DEFAULT_REGION=us-east-1
# Use only published providers: ignore any CLI config (e.g. dev_overrides) on the host.
cli_config=$(mktemp)
trap 'rm -f "$cli_config"' EXIT
export TF_CLI_CONFIG_FILE=$cli_config
in_gha=${GITHUB_ACTIONS:-}
declare -A result

log() { printf '%s\n' "$*"; }
group() { if [[ -n $in_gha ]]; then echo "::group::$*"; else log "=== $*"; fi; }
endgroup() { [[ -n $in_gha ]] && echo "::endgroup::"; return 0; }
mask() { [[ -n $in_gha && -n ${1:-} ]] && echo "::add-mask::$1"; return 0; }
tf() { "$ENGINE" "$@"; }
out() { (cd "$1" && tf output -raw "$2" 2>/dev/null); }

wait_for_provider() {
  local name=${PROVIDER_NAME:-scality} v=$PROVIDER_VERSION reg=registry.opentofu.org t=0
  [[ $ENGINE == terraform ]] && reg=registry.terraform.io
  while (( t < 1800 )); do
    curl -sf "https://$reg/v1/providers/cmrh/$name/versions" | grep -q "\"$v\"" && return 0
    log "waiting for cmrh/$name $v on $reg"; sleep 60; t=$((t + 60))
  done
  log "cmrh/$name $v never appeared on $reg"; return 1
}

apply() { (cd "$1" && tf init -upgrade -no-color >/dev/null && tf apply -auto-approve -no-color); }

# replan <dir>: 0 = no changes, 2 = drift, 1 = error
replan() {
  local rc
  (cd "$1" && tf plan -detailed-exitcode -no-color); rc=$?
  [[ $rc == 2 ]] && log "re-plan shows changes after apply: $1"
  return $rc
}

destroy() {
  # Nothing to destroy (e.g. init failed before anything was created).
  [[ -z $(cd "$1" && tf state list 2>/dev/null) ]] && return 0
  (cd "$1" && tf destroy -auto-approve -no-color) || return 1
  [[ $(cd "$1" && tf state list 2>/dev/null | wc -l) == 0 ]]
}

# verdict <name> <apply rc> <replan rc> <destroy rc>
verdict() {
  if [[ $4 != 0 ]]; then result[$1]=LEAKED
  elif [[ $2 != 0 ]]; then result[$1]=FAIL
  elif [[ $3 == 2 ]]; then result[$1]=DRIFT
  elif [[ $3 != 0 ]]; then result[$1]=FAIL
  else result[$1]=pass; fi
}

# run_simple <name> <dir>: apply, re-plan, destroy.
run_simple() {
  local ok=0 rp=1 ds=0
  if apply "$2"; then replan "$2"; rp=$?; else ok=1; fi
  destroy "$2" || ds=1
  verdict "$1" $ok $rp $ds
}

# access-logging: the cluster logs Terraform's own requests on the app bucket,
# so the log bucket can hold objects at destroy time. Empty it and retry.
run_access_logging() {
  local d=$ex/access-logging ok=0 rp=1 ds=0 ak sk logs i page n
  if apply "$d"; then replan "$d"; rp=$?; else ok=1; fi
  ak=$(out "$d" operator_access_key); sk=$(out "$d" operator_secret_key); logs=$(out "$d" log_bucket)
  mask "$ak"; mask "$sk"
  if ! destroy "$d"; then
    ds=1
    for i in 1 2 3; do
      if [[ -n $ak && -n $logs ]]; then
        page=$(AWS_ACCESS_KEY_ID=$ak AWS_SECRET_ACCESS_KEY=$sk aws --endpoint-url "$SCALITY_ENDPOINT" \
          s3api list-objects-v2 --bucket "$logs" --output json 2>/dev/null \
          | jq -c '{Objects: ((.Contents // []) | map({Key})), Quiet: true}')
        n=$(jq '.Objects | length' <<<"$page" 2>/dev/null || echo 0)
        [[ $n != 0 ]] && AWS_ACCESS_KEY_ID=$ak AWS_SECRET_ACCESS_KEY=$sk aws --endpoint-url "$SCALITY_ENDPOINT" \
          s3api delete-objects --bucket "$logs" --delete "$page" >/dev/null 2>&1
      fi
      destroy "$d" && { ds=0; break; }
      sleep 60
    done
  fi
  verdict access-logging $ok $rp $ds
}

run_edge() {
  export TF_VAR_ring_endpoint=$SCALITY_ENDPOINT
  run_simple artesca-edge-to-ring "$ex/artesca-edge-to-ring"
  unset TF_VAR_ring_endpoint
}

run_delegated_admin() {
  local b=$ex/delegated-admin-bootstrap m=$ex/delegated-admin-managed ok=0 rp=0 r ds=0
  if apply "$b"; then
    replan "$b"; r=$?; (( r > rp )) && rp=$r
    TF_VAR_delegator_access_key=$(out "$b" delegator_access_key)
    TF_VAR_delegator_secret_key=$(out "$b" delegator_secret_key)
    TF_VAR_role_arns=$(cd "$b" && tf output -json role_arns)
    mask "$TF_VAR_delegator_access_key"; mask "$TF_VAR_delegator_secret_key"
    export TF_VAR_delegator_access_key TF_VAR_delegator_secret_key TF_VAR_role_arns
    if apply "$m"; then
      # Each app user must be created in its sub-account: same account ID as that sub-account's role.
      jq -n --argjson roles "$TF_VAR_role_arns" --argjson users "$(cd "$m" && tf output -json app_user_arns)" \
        '($roles | keys) == ($users | keys)
         and all($roles | keys[]; ($roles[.] | split(":")[4]) == ($users[.] | split(":")[4]))' | grep -q true \
        || { log "app users were not created in their sub-accounts"; ok=1; }
      replan "$m"; r=$?; (( r > rp )) && rp=$r
    else ok=1; fi
    destroy "$m" || ds=1
    unset TF_VAR_delegator_access_key TF_VAR_delegator_secret_key TF_VAR_role_arns
  else ok=1; fi
  destroy "$b" || ds=1
  verdict delegated-admin $ok $rp $ds
}

command -v "$ENGINE" >/dev/null || { log "$ENGINE not found"; exit 1; }
for t in aws jq curl; do command -v $t >/dev/null || { log "$t not found"; exit 1; }; done
if [[ -n ${PROVIDER_VERSION:-} ]]; then wait_for_provider || exit 1; fi

for c in $CONFIGS; do
  export TF_VAR_account_name="$RUN_PREFIX-$c" TF_VAR_name_prefix="$RUN_PREFIX-${c:0:6}-" TF_VAR_name="$RUN_PREFIX-edge"
  group "$ENGINE: $c (prefix $RUN_PREFIX)"
  case $c in
    access-logging) run_access_logging ;;
    artesca-edge-to-ring) run_edge ;;
    s3-crr-one-direction) run_simple "$c" "$ex/s3-crr-one-direction" ;;
    delegated-admin) run_delegated_admin ;;
    *) log "unknown config: $c"; result[$c]=FAIL ;;
  esac
  endgroup
done

fail=0
summary="| config | $ENGINE |"$'\n'"|---|---|"
for c in $CONFIGS; do
  summary+=$'\n'"| $c | ${result[$c]:-FAIL} |"
  [[ ${result[$c]:-} == pass ]] || fail=1
done
log "$summary"
[[ -n ${GITHUB_STEP_SUMMARY:-} ]] && printf '%s\n\n' "$summary" >>"$GITHUB_STEP_SUMMARY"
exit $fail
