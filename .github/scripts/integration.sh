#!/usr/bin/env bash
# Integration suite: for each config, apply -> re-plan (must show no changes)
# -> destroy (always). Runs against live clusters.
#
# Environment:
#   ENGINE            tofu | terraform                       (required)
#   CONFIGS           space-separated subset of the names below (default: all)
#   RUN_PREFIX        prefix for every account/bucket/user name (default: local<epoch>)
#   PROVIDER_VERSION  wait until this cmrh/scality version is on the engine's registry
#   SCALITY_ENDPOINT, SCALITY_ACCESS_KEY, SCALITY_SECRET_KEY      primary cluster
#   SCALITY_CONSOLE_ENDPOINT, _USERNAME, _PASSWORD                primary Console
#   TF_VAR_dest_endpoint, TF_VAR_dest_access_key, TF_VAR_dest_secret_key   CRR destination
set -uo pipefail

: "${ENGINE:?set ENGINE to tofu or terraform}"
root=$(cd "$(dirname "$0")/../.." && pwd)
ex=$root/examples/scality
all="operator-test access-logging compliance-bucket terraform-state-bootstrap delegated-admin s3-crr-one-direction s3-crr-bidirectional"
CONFIGS=${CONFIGS:-$all}
RUN_PREFIX=${RUN_PREFIX:-local$(date +%s)}
export TF_DATA_DIR=.terraform/$ENGINE TF_IN_AUTOMATION=1 TF_INPUT=0
in_gha=${GITHUB_ACTIONS:-}
declare -A result

log() { printf '%s\n' "$*"; }
group() { [[ -n $in_gha ]] && echo "::group::$*" || log "=== $*"; }
endgroup() { [[ -n $in_gha ]] && echo "::endgroup::"; return 0; }
mask() { [[ -n $in_gha && -n $1 ]] && echo "::add-mask::$1"; return 0; }
tf() { "$ENGINE" "$@"; }

wait_for_provider() {
  local v=$PROVIDER_VERSION reg=registry.opentofu.org i
  [[ $ENGINE == terraform ]] && reg=registry.terraform.io
  for i in $(seq 1 30); do
    curl -sf "https://$reg/v1/providers/cmrh/scality/versions" | grep -q "\"$v\"" && { log "cmrh/scality $v is on $reg"; return 0; }
    log "waiting for cmrh/scality $v on $reg ($i/30)"; sleep 60
  done
  log "cmrh/scality $v never appeared on $reg"; return 1
}

# apply_replan <dir>: init, apply, then a plan that must show no changes.
apply_replan() {
  local d=$1 rc
  (cd "$d" && tf init -upgrade -no-color >/dev/null) || { log "init failed: $d"; return 1; }
  (cd "$d" && tf apply -auto-approve -no-color) || { log "apply failed: $d"; return 1; }
  (cd "$d" && tf plan -detailed-exitcode -no-color); rc=$?
  case $rc in
    0) return 0 ;;
    2) log "re-plan shows changes after apply: $d"; return 2 ;;
    *) log "re-plan failed: $d"; return 1 ;;
  esac
}

# destroy <dir>: destroy, then report anything left in state.
destroy() {
  local d=$1 left
  (cd "$d" && tf destroy -auto-approve -no-color) || return 1
  left=$(cd "$d" && tf state list 2>/dev/null | wc -l)
  [[ $left == 0 ]] || { log "state not empty after destroy: $d"; return 1; }
}

# Delete every object version and delete marker in a bucket.
purge_bucket() {
  local b=$1 page n
  while :; do
    page=$(aws --endpoint-url "$SCALITY_ENDPOINT" s3api list-object-versions --bucket "$b" --max-items 1000 --output json) || return 1
    page=$(jq -c '{Objects: ([(.Versions // [])[], (.DeleteMarkers // [])[]] | map({Key, VersionId})), Quiet: true}' <<<"$page")
    n=$(jq '.Objects | length' <<<"$page")
    [[ $n == 0 ]] && return 0
    log "deleting $n object versions from $b"
    aws --endpoint-url "$SCALITY_ENDPOINT" s3api delete-objects --bucket "$b" --delete "$page" >/dev/null || return 1
  done
}

# access-logging: the log bucket receives log objects, so empty both buckets
# and retry, since logs can still arrive after logging is disabled.
destroy_access_logging() {
  local d=$1 ak sk logs app i
  ak=$(cd "$d" && tf output -raw operator_access_key 2>/dev/null) || ak=
  sk=$(cd "$d" && tf output -raw operator_secret_key 2>/dev/null) || sk=
  logs=$(cd "$d" && tf output -raw log_bucket 2>/dev/null) || logs=
  app=$(cd "$d" && tf output -raw app_bucket 2>/dev/null) || app=
  mask "$ak"; mask "$sk"
  destroy "$d" && return 0
  [[ -n $ak && -n $sk ]] || { log "no operator keys to empty the buckets"; return 1; }
  for i in 1 2 3; do
    (export AWS_ACCESS_KEY_ID=$ak AWS_SECRET_ACCESS_KEY=$sk AWS_DEFAULT_REGION=us-east-1
      purge_bucket "$logs" && purge_bucket "$app") || true
    destroy "$d" && return 0
    log "destroy retry $i failed; waiting for late log deliveries"; sleep 60
  done
  return 1
}

run_simple() {
  local name=$1 d=$2 destroy_fn=${3:-destroy} rc
  apply_replan "$d"; rc=$?
  "$destroy_fn" "$d" || { result[$name]=LEAKED; return; }
  case $rc in 0) result[$name]=pass ;; 2) result[$name]=DRIFT ;; *) result[$name]=FAIL ;; esac
}

run_delegated_admin() {
  local b=$ex/delegated-admin/bootstrap m=$ex/delegated-admin/managed rc=0 mrc=0 leaked=
  apply_replan "$b"; rc=$?
  if [[ $rc != 1 ]]; then
    TF_VAR_delegator_access_key=$(cd "$b" && tf output -raw delegator_access_key)
    TF_VAR_delegator_secret_key=$(cd "$b" && tf output -raw delegator_secret_key)
    TF_VAR_role_arns=$(cd "$b" && tf output -json role_arns)
    mask "$TF_VAR_delegator_access_key"; mask "$TF_VAR_delegator_secret_key"
    export TF_VAR_delegator_access_key TF_VAR_delegator_secret_key TF_VAR_role_arns
    apply_replan "$m"; mrc=$?
    destroy "$m" || leaked=1
    unset TF_VAR_delegator_access_key TF_VAR_delegator_secret_key TF_VAR_role_arns
  fi
  destroy "$b" || leaked=1
  if [[ -n $leaked ]]; then result[delegated-admin]=LEAKED
  elif [[ $rc == 1 || $mrc == 1 ]]; then result[delegated-admin]=FAIL
  elif [[ $rc == 2 || $mrc == 2 ]]; then result[delegated-admin]=DRIFT
  else result[delegated-admin]=pass; fi
}

command -v "$ENGINE" >/dev/null || { log "$ENGINE not found"; exit 1; }
for t in aws jq curl; do command -v $t >/dev/null || { log "$t not found"; exit 1; }; done
[[ -n ${PROVIDER_VERSION:-} ]] && { wait_for_provider || exit 1; }

eng=${ENGINE:0:2}
for c in $CONFIGS; do
  export TF_VAR_account_name="$RUN_PREFIX-$eng-$c" TF_VAR_name_prefix="$RUN_PREFIX-$eng-${c:0:8}-"
  group "$ENGINE: $c (prefix $RUN_PREFIX-$eng)"
  case $c in
    operator-test | compliance-bucket | terraform-state-bootstrap) run_simple "$c" "$ex/$c" ;;
    access-logging) run_simple "$c" "$ex/$c" destroy_access_logging ;;
    delegated-admin) run_delegated_admin ;;
    s3-crr-one-direction) run_simple "$c" "$ex/s3-crr/one-direction" ;;
    s3-crr-bidirectional) run_simple "$c" "$ex/s3-crr/bidirectional" ;;
    *) log "unknown config: $c"; result[$c]=FAIL ;;
  esac
  endgroup
done

fail=0
summary="| config | $ENGINE |"$'\n'"|---|---|"
for c in $CONFIGS; do
  summary+=$'\n'"| $c | ${result[$c]} |"
  [[ ${result[$c]} == pass ]] || fail=1
done
log "$summary"
[[ -n ${GITHUB_STEP_SUMMARY:-} ]] && printf '%s\n\n' "$summary" >>"$GITHUB_STEP_SUMMARY"
exit $fail
