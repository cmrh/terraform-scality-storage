#!/usr/bin/env bash
# Integration suite. Covers what the providers' acceptance tests can't: the
# data paths our examples document, their teardown steps, and modules wired
# together. For each config: apply -> data check -> re-plan (no changes) ->
# destroy (always, following the example's README).
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
in_gha=${GITHUB_ACTIONS:-}
artesca_tls=()
[[ ${ARTESCA_INSECURE_SKIP_VERIFY:-} == true ]] && artesca_tls=(--no-verify-ssl)
declare -A result

log() { printf '%s\n' "$*"; }
group() { if [[ -n $in_gha ]]; then echo "::group::$*"; else log "=== $*"; fi; }
endgroup() { [[ -n $in_gha ]] && echo "::endgroup::"; return 0; }
mask() { [[ -n $in_gha && -n ${1:-} ]] && echo "::add-mask::$1"; return 0; }
tf() { "$ENGINE" "$@"; }
out() { (cd "$1" && tf output -raw "$2" 2>/dev/null); }

# s3 <endpoint> <access key> <secret key> <aws args...>
s3() {
  local ep=$1 ak=$2 sk=$3; shift 3
  local tls=()
  [[ $ep == "${ARTESCA_S3_ENDPOINT:-}" ]] && tls=("${artesca_tls[@]}")
  AWS_ACCESS_KEY_ID=$ak AWS_SECRET_ACCESS_KEY=$sk aws "${tls[@]}" --endpoint-url "$ep" "$@" 2>/dev/null
}

# wait_for <seconds> <description> <command...>: poll every 15s until the command succeeds.
wait_for() {
  local limit=$1 what=$2 t=0; shift 2
  while (( t < limit )); do
    "$@" && { log "$what after ${t}s"; return 0; }
    sleep 15; t=$((t + 15))
  done
  log "timed out after ${limit}s waiting for: $what"; return 1
}

# Delete every object version and delete marker in a bucket.
purge() {
  local ep=$1 ak=$2 sk=$3 b=$4 page n
  [[ -n $b && -n $ak ]] || return 0
  while :; do
    page=$(s3 "$ep" "$ak" "$sk" s3api list-object-versions --bucket "$b" --max-items 1000 --output json) || return 0
    page=$(jq -c '{Objects: ([(.Versions // [])[], (.DeleteMarkers // [])[]] | map({Key, VersionId})), Quiet: true}' <<<"$page")
    n=$(jq '.Objects | length' <<<"$page")
    [[ $n == 0 ]] && return 0
    log "deleting $n object versions from $b"
    s3 "$ep" "$ak" "$sk" s3api delete-objects --bucket "$b" --delete "$page" >/dev/null || return 1
  done
}

wait_for_provider() {
  local name=${PROVIDER_NAME:-scality} v=$PROVIDER_VERSION reg=registry.opentofu.org
  [[ $ENGINE == terraform ]] && reg=registry.terraform.io
  wait_for 1800 "cmrh/$name $v on $reg" \
    bash -c "curl -sf https://$reg/v1/providers/cmrh/$name/versions | grep -q '\"$v\"'"
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
  (cd "$1" && tf destroy -auto-approve -no-color) || return 1
  [[ $(cd "$1" && tf state list 2>/dev/null | wc -l) == 0 ]]
}

# verdict <name> <apply/check rc> <replan rc> <destroy rc>
verdict() {
  if [[ $4 != 0 ]]; then result[$1]=LEAKED
  elif [[ $2 != 0 ]]; then result[$1]=FAIL
  elif [[ $3 == 2 ]]; then result[$1]=DRIFT
  elif [[ $3 != 0 ]]; then result[$1]=FAIL
  else result[$1]=pass; fi
}

run_access_logging() {
  local d=$ex/scality/access-logging ok=0 rp=1 ds=0 ak sk app logs i
  if apply "$d"; then
    ak=$(out "$d" operator_access_key); sk=$(out "$d" operator_secret_key); mask "$ak"; mask "$sk"
    app=$(out "$d" app_bucket); logs=$(out "$d" log_bucket)
    echo probe | s3 "$SCALITY_ENDPOINT" "$ak" "$sk" s3 cp - "s3://$app/probe.txt" >/dev/null || ok=1
    [[ $ok == 0 ]] && { wait_for 900 "access log delivered" \
      bash -c "[[ \$(AWS_ACCESS_KEY_ID='$ak' AWS_SECRET_ACCESS_KEY='$sk' aws --endpoint-url '$SCALITY_ENDPOINT' s3api list-objects-v2 --bucket '$logs' --prefix '$app/' --query 'length(Contents || \`[]\`)' 2>/dev/null) -gt 0 ]]" || ok=1; }
    replan "$d"; rp=$?
  else ok=1; fi
  # README: destroy (fails on non-empty buckets), empty both, destroy again; retry for late log deliveries.
  if ! destroy "$d"; then
    ds=1
    for i in 1 2 3; do
      purge "$SCALITY_ENDPOINT" "${ak:-}" "${sk:-}" "${logs:-}"; purge "$SCALITY_ENDPOINT" "${ak:-}" "${sk:-}" "${app:-}"
      destroy "$d" && { ds=0; break; }
      sleep 60
    done
  fi
  verdict access-logging $ok $rp $ds
}

run_edge() {
  local d=$ex/hybrid/artesca-edge-to-ring ok=0 rp=1 ds=0 rak rsk ring edge aak ask
  export TF_VAR_ring_endpoint=$SCALITY_ENDPOINT
  if apply "$d"; then
    rak=$(out "$d" ring_operator_access_key); rsk=$(out "$d" ring_operator_secret_key); mask "$rak"; mask "$rsk"
    ring=$(out "$d" ring_bucket); edge=$(out "$d" edge_bucket)
    aak=$(cd "$d" && tf output -json app_keys | jq -r 'to_entries[0].value.access_key')
    ask=$(cd "$d" && tf output -json app_keys | jq -r 'to_entries[0].value.secret_key'); mask "$aak"; mask "$ask"
    echo probe | s3 "$ARTESCA_S3_ENDPOINT" "$aak" "$ask" s3 cp - "s3://$edge/probe.txt" >/dev/null || ok=1
    [[ $ok == 0 ]] && { wait_for 600 "object replicated to RING" \
      bash -c "AWS_ACCESS_KEY_ID='$rak' AWS_SECRET_ACCESS_KEY='$rsk' aws --endpoint-url '$SCALITY_ENDPOINT' s3api head-object --bucket '$ring' --key probe.txt >/dev/null 2>&1" || ok=1; }
    replan "$d"; rp=$?
  else ok=1; fi
  # README: force_destroy apply, destroy (fails on the RING bucket), empty it, destroy again.
  export TF_VAR_force_destroy=true
  (cd "$d" && tf apply -auto-approve -no-color >/dev/null)
  if ! destroy "$d"; then
    purge "$SCALITY_ENDPOINT" "${rak:-}" "${rsk:-}" "${ring:-}"
    destroy "$d" || ds=1
  fi
  unset TF_VAR_force_destroy TF_VAR_ring_endpoint
  verdict artesca-edge-to-ring $ok $rp $ds
}

run_crr() {
  local d=$ex/scality/s3-crr/one-direction ok=0 rp=1 ds=0 wak wsk sak ssk dak dsk src dst
  if apply "$d"; then
    wak=$(out "$d" source_writer_access_key); wsk=$(out "$d" source_writer_secret_key)
    sak=$(out "$d" source_operator_access_key); ssk=$(out "$d" source_operator_secret_key)
    dak=$(out "$d" dest_operator_access_key); dsk=$(out "$d" dest_operator_secret_key)
    for k in "$wak" "$wsk" "$sak" "$ssk" "$dak" "$dsk"; do mask "$k"; done
    src=$(out "$d" source_bucket_name); dst=$(out "$d" dest_bucket_name)
    echo probe | s3 "$SCALITY_ENDPOINT" "$wak" "$wsk" s3 cp - "s3://$src/probe.txt" >/dev/null || ok=1
    [[ $ok == 0 ]] && { wait_for 600 "object replicated to destination" \
      bash -c "AWS_ACCESS_KEY_ID='$dak' AWS_SECRET_ACCESS_KEY='$dsk' aws --endpoint-url '$TF_VAR_dest_endpoint' s3api head-object --bucket '$dst' --key probe.txt >/dev/null 2>&1" || ok=1; }
    replan "$d"; rp=$?
  else ok=1; fi
  purge "$SCALITY_ENDPOINT" "${sak:-}" "${ssk:-}" "${src:-}"
  purge "$TF_VAR_dest_endpoint" "${dak:-}" "${dsk:-}" "${dst:-}"
  destroy "$d" || ds=1
  verdict s3-crr-one-direction $ok $rp $ds
}

run_delegated_admin() {
  local b=$ex/scality/delegated-admin/bootstrap m=$ex/scality/delegated-admin/managed ok=0 rp=0 r ds=0
  if apply "$b"; then
    replan "$b"; r=$?; (( r > rp )) && rp=$r
    TF_VAR_delegator_access_key=$(out "$b" delegator_access_key)
    TF_VAR_delegator_secret_key=$(out "$b" delegator_secret_key)
    TF_VAR_role_arns=$(cd "$b" && tf output -json role_arns)
    mask "$TF_VAR_delegator_access_key"; mask "$TF_VAR_delegator_secret_key"
    export TF_VAR_delegator_access_key TF_VAR_delegator_secret_key TF_VAR_role_arns
    if apply "$m"; then
      # Each app user must live in its sub-account: same account ID as that sub-account's role.
      jq -n --argjson roles "$TF_VAR_role_arns" --argjson users "$(cd "$m" && tf output -json app_user_arns)" \
        '($roles | keys) == ($users | keys)
         and all($roles | keys[]; ($roles[.] | split(":")[4]) == ($users[.] | split(":")[4]))' | grep -q true \
        || { log "app users did not land in their sub-accounts"; ok=1; }
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
    s3-crr-one-direction) run_crr ;;
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
