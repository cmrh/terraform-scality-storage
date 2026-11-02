#!/usr/bin/env bash
# Generates module calls and import blocks for the buckets and users in an
# existing Scality account, so they can be adopted without being recreated.
# Read-only against the cluster. Writes no credentials: module calls take
# var.account_access_key / var.account_secret_key (set them via TF_VAR_*).
#
# Mapping:
#   bucket receiving access logs -> scality-access-log-bucket, with the logging
#                                   configuration of the buckets logging to it
#   bucket with object lock      -> scality-compliance-bucket (with its policy)
#   other bucket                 -> scality-application-bucket (with its policy)
#   user with one inline policy  -> scality-application-identity
#   group                        -> scality-group-access, with its managed
#                                   policies and members
# Access keys are not imported (their secrets can't be recovered); apply
# creates a new key per adopted user. A group owns the account policies
# attached only to it; other policies are attached by ARN and left unmanaged.
# Settings a module can't express are marked "# REVIEW:" in the output and
# listed on stderr; the plan shows the resulting change. Replication and
# roles are listed on stderr and left unmanaged.
#
# Environment:
#   SCALITY_ACCOUNT_ACCESS_KEY, SCALITY_ACCOUNT_SECRET_KEY   account credentials
#                     (the same variables the provider's import reads)
#   SCALITY_ENDPOINT  S3 and IAM endpoint (or --endpoint)
#   SCALITY_INSECURE_SKIP_VERIFY  true to skip TLS verification
#
# Usage: scality-adopt.sh [--endpoint URL] [--iam-endpoint URL] [--out FILE]
#                         [--module-source BASE] [--module-version CONSTRAINT]
set -euo pipefail

endpoint=${SCALITY_ENDPOINT:-}
iam_endpoint=
out=adopt.tf
module_source=cmrh/storage/scality//modules
module_version="~> 1.4"

usage() { sed -n '/^# Usage:/,/^set /p' "$0" | sed '$d; s/^# \{0,1\}//' >&2; exit "${1:-2}"; }
while (($#)); do
  case $1 in
    --endpoint) endpoint=$2; shift 2 ;;
    --iam-endpoint) iam_endpoint=$2; shift 2 ;;
    --out) out=$2; shift 2 ;;
    --module-source) module_source=$2; shift 2 ;;
    --module-version) module_version=$2; shift 2 ;;
    -h | --help) usage 0 ;;
    *) echo "unknown argument: $1" >&2; usage ;;
  esac
done
iam_endpoint=${iam_endpoint:-$endpoint}

for bin in aws jq; do
  command -v "$bin" >/dev/null || { echo "missing dependency: $bin" >&2; exit 1; }
done
[[ -n $endpoint ]] || { echo "set SCALITY_ENDPOINT or pass --endpoint" >&2; exit 1; }
[[ -n ${SCALITY_ACCOUNT_ACCESS_KEY:-} && -n ${SCALITY_ACCOUNT_SECRET_KEY:-} ]] ||
  { echo "set SCALITY_ACCOUNT_ACCESS_KEY and SCALITY_ACCOUNT_SECRET_KEY" >&2; exit 1; }

# Credentials reach awscli through its environment only, never argv.
unset AWS_PROFILE AWS_SESSION_TOKEN
export AWS_ACCESS_KEY_ID=$SCALITY_ACCOUNT_ACCESS_KEY
export AWS_SECRET_ACCESS_KEY=$SCALITY_ACCOUNT_SECRET_KEY
export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION:-us-east-1} AWS_PAGER=""
tls=()
[[ ${SCALITY_INSECURE_SKIP_VERIFY:-} == true ]] && tls=(--no-verify-ssl)

s3() { aws --endpoint-url "$endpoint" "${tls[@]}" s3api "$@" --output json 2>/dev/null; }
iam() { aws --endpoint-url "$iam_endpoint" "${tls[@]}" iam "$@" --output json 2>/dev/null; }
# Run an s3api read; print its JSON, or {} when the configuration doesn't exist.
s3_or_empty() {
  local r
  r=$(s3 "$@") || r=
  printf '%s\n' "${r:-{\}}"
}

note() { printf '%s\n' "$*" >&2; }
label() { printf '%s_%s' "$1" "$(tr -c 'a-zA-Z0-9_\n' '_' <<<"$2" | tr 'A-Z' 'a-z')"; }
src() {
  printf '  source  = "%s/%s"\n' "$module_source" "$1"
  [[ -n $module_version ]] && printf '  version = "%s"\n' "$module_version"
  return 0
}
hcl_tags() { jq -r '(.TagSet // []) | if length == 0 then "{}" else
  "{\n" + (map("    \(.Key | tojson) = \(.Value | tojson)") | join("\n")) + "\n  }" end'; }
hcl_days() { jq -r --arg k "$1" '.[$k] // "null"' <<<"$lc"; }
# The bucket's policy as a bucket_policy argument, when it has one.
hcl_policy() {
  [[ -n $policy ]] || return 0
  echo
  echo '  bucket_policy = jsonencode('"$(sed '2,$s/^/  /' <<<"$policy")"')'
}
# A log target as a scality-access-log-bucket call. Reads the bucket loop's
# variables: bucket, name, tags, versioning, rules, lc, unmapped, sse, kms, policy.
emit_log_bucket() {
  local retention principal sources source_bucket
  retention=$(jq -r 'if .expiration != null and .abort == null and .noncurrent == null
    then .expiration else empty end' <<<"$lc")
  [[ -n $unmapped ]] && retention=
  # The delivery principal: the Allow s3:PutObject statement's AWS principal.
  principal=$(jq -r '[.Statement[]? | select(.Effect == "Allow")
    | select([.Action] | flatten | index("s3:PutObject"))
    | .Principal.AWS? | select(. != null) | if type == "array" then .[] else . end
    | select(test("access-logging"))] | first // empty' <<<"${policy:-{\}}")
  sources=()
  for source_bucket in "${!log_target[@]}"; do
    [[ ${log_target[$source_bucket]} == "$bucket" ]] && sources+=("$source_bucket")
  done
  mapfile -t sources < <(printf '%s\n' "${sources[@]}" | sort)

  echo "module \"$name\" {"
  src scality-access-log-bucket
  echo
  echo '  account_access_key = var.account_access_key'
  echo '  account_secret_key = var.account_secret_key'
  echo
  echo "  bucket_name = $(hcl_str "$bucket")"
  echo "  tags        = $tags"
  if [[ -n $retention ]]; then
    echo "  retention_days = $retention"
  else
    echo '  # REVIEW: the module deletes log objects after 90 days and replaces any other lifecycle rules.'
    echo '  retention_days = 90'
    note "bucket $bucket: log target; module sets a 90-day expiry in place of its lifecycle (REVIEW)"
  fi
  if [[ $versioning == Enabled ]]; then
    echo '  # REVIEW: versioning is on; the module suspends it.'
    note "bucket $bucket: log target is versioned; module suspends versioning (REVIEW)"
  fi
  if [[ -z $policy ]]; then
    echo '  # REVIEW: no bucket policy; the module adds the log delivery grant.'
    note "bucket $bucket: log target has no policy; module adds the log delivery grant (REVIEW)"
  elif [[ -z $principal ]]; then
    echo '  # REVIEW: the module replaces the bucket policy with the log delivery grant alone.'
    note "bucket $bucket: log target policy has no log delivery grant; module replaces the policy (REVIEW)"
  elif [[ $(jq '.Statement | length' <<<"$policy") != 1 ]]; then
    echo '  # REVIEW: the module replaces the bucket policy with the log delivery grant alone.'
    note "bucket $bucket: log target policy has other statements; module replaces the policy (REVIEW)"
  fi
  [[ -n $principal && $principal != "$default_log_principal" ]] &&
    echo "  log_delivery_principal = $(hcl_str "$principal")"
  if [[ -n $sse ]]; then
    echo "  sse_algorithm = \"$sse\""
    [[ -n $kms ]] && echo "  kms_master_key_id = $(hcl_str "$kms")"
  else
    echo '  sse_algorithm = null'
  fi
  echo
  echo '  logged_buckets = {'
  for source_bucket in "${sources[@]}"; do
    echo "    $(hcl_str "$source_bucket") = $(hcl_str "${log_prefix[$source_bucket]}")"
  done
  echo '  }'
  echo '}'
  echo
  imp "$name" scality_bucket.this "$bucket"
  [[ -n $policy ]] && imp "$name" scality_bucket_policy.this "$bucket"
  [[ -n $sse ]] && imp "$name" 'scality_bucket_encryption.this[0]' "$bucket"
  [[ $rules != '[]' ]] && imp "$name" scality_bucket_lifecycle.this "$bucket"
  for source_bucket in "${sources[@]}"; do
    imp "$name" "scality_bucket_logging.this[$(hcl_str "$source_bucket")]" "$source_bucket"
  done
}
hcl_str() { jq -Rn --arg v "$1" '$v'; }
imp() { printf 'import {\n  to = module.%s.%s\n  id = %s\n}\n\n' "$1" "$2" "$(jq -Rn --arg v "$3" '$v')"; }

buckets=$(s3 list-buckets) || { echo "list-buckets failed: check endpoint and credentials" >&2; exit 1; }
users=$(iam list-users) || { echo "iam list-users failed: check --iam-endpoint and credentials" >&2; exit 1; }

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
{
  echo "# Generated by scality-adopt.sh on $(date -u +%Y-%m-%dT%H:%M:%SZ)."
  echo "# Review every \"# REVIEW:\" line, then plan. Expect imports and no replacements."
  echo
  echo 'variable "account_access_key" {'
  echo '  type      = string'
  echo '  sensitive = true'
  echo '}'
  echo
  echo 'variable "account_secret_key" {'
  echo '  type      = string'
  echo '  sensitive = true'
  echo '}'
  echo
} >"$tmp"

# --- Log targets -----------------------------------------------------------
# A bucket that receives server access logs becomes a scality-access-log-bucket
# call, which also owns the logging configuration of its source buckets.
default_log_principal=arn:aws:iam::000000000000:user/scality-internal/service-access-logging-user
bucket_names=$(jq -r '.Buckets[].Name' <<<"$buckets")
declare -A log_target=() log_prefix=() targets=()
for b in $bucket_names; do
  l=$(s3_or_empty get-bucket-logging --bucket "$b" |
    jq -r '.LoggingEnabled // empty | [.TargetBucket, (.TargetPrefix // "")] | @tsv')
  [[ -n $l ]] || continue
  IFS=$'\t' read -r t p <<<"$l"
  if [[ $t == "$b" ]]; then
    note "bucket $b: logs into itself; logging left unmanaged"
  elif ! grep -qxF -- "$t" <<<"$bucket_names"; then
    note "bucket $b: logs to $t, which isn't in this account; logging left unmanaged"
  elif [[ $(s3_or_empty get-object-lock-configuration --bucket "$t" |
    jq -r '.ObjectLockConfiguration.ObjectLockEnabled // empty') == Enabled ]]; then
    note "bucket $b: logs to $t, which has object lock; logging left unmanaged"
  else
    log_target[$b]=$t log_prefix[$b]=$p targets[$t]=1
  fi
done

# --- Buckets ---------------------------------------------------------------
for bucket in $bucket_names; do
  name=$(label bucket "$bucket")
  versioning=$(s3_or_empty get-bucket-versioning --bucket "$bucket" | jq -r '.Status // "Unversioned"')
  lock=$(s3_or_empty get-object-lock-configuration --bucket "$bucket")
  enc=$(s3_or_empty get-bucket-encryption --bucket "$bucket" |
    jq -c '.ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault // empty')
  tags=$(s3_or_empty get-bucket-tagging --bucket "$bucket" | hcl_tags)
  rules=$(s3_or_empty get-bucket-lifecycle-configuration --bucket "$bucket" | jq -c '.Rules // []')

  policy=$(s3_or_empty get-bucket-policy --bucket "$bucket" |
    jq 'if .Policy then .Policy | fromjson else empty end')

  if [[ $(s3_or_empty get-bucket-replication --bucket "$bucket") != '{}' ]]; then
    note "bucket $bucket: replication configured; not adopted (left unmanaged)"
  fi

  # Map lifecycle rules onto the module's three baseline rules: whole-bucket
  # (empty prefix, no tag filter), enabled, one action each.
  lc=$(jq -c '
    def whole: ((.Filter // {}) | (.Prefix // "") == "" and (has("Tag") | not) and (has("And") | not))
               and ((.Prefix // "") == "") and .Status == "Enabled";
    def kind: if (.AbortIncompleteMultipartUpload.DaysAfterInitiation) then "abort"
              elif (.NoncurrentVersionExpiration.NoncurrentDays) then "noncurrent"
              elif (.Expiration.Days) then "expiration" else "other" end;
    def days: .AbortIncompleteMultipartUpload.DaysAfterInitiation
              // .NoncurrentVersionExpiration.NoncurrentDays // .Expiration.Days;
    def actions: [.AbortIncompleteMultipartUpload, .NoncurrentVersionExpiration, .Expiration,
                  .Transitions, .NoncurrentVersionTransitions] | map(select(. != null)) | length;
    (map(select(whole and actions == 1 and kind != "other"))) as $ok
    | {abort:      ([$ok[] | select(kind == "abort")      | days] | first),
       noncurrent: ([$ok[] | select(kind == "noncurrent") | days] | first),
       expiration: ([$ok[] | select(kind == "expiration") | days] | first),
       unmapped:   ([.[] | select((whole and actions == 1 and kind != "other") | not) | .ID // "(no id)"]
                    + ([$ok[] | kind] | group_by(.) | map(select(length > 1) | .[0] + " (duplicate)")))}' <<<"$rules")
  unmapped=$(jq -r '.unmapped | join(", ")' <<<"$lc")
  has_lc=$([[ $rules != '[]' ]] && echo yes || echo no)

  sse=$(jq -r '.SSEAlgorithm // empty' <<<"$enc")
  kms=$(jq -r '.KMSMasterKeyID // empty' <<<"$enc")

  if [[ -n ${targets[$bucket]:-} ]]; then
    emit_log_bucket >>"$tmp"
    continue
  fi

  if [[ $(jq -r '.ObjectLockConfiguration.ObjectLockEnabled // empty' <<<"$lock") == Enabled ]]; then
    mode=$(jq -r '.ObjectLockConfiguration.Rule.DefaultRetention.Mode // empty' <<<"$lock")
    rdays=$(jq -r '.ObjectLockConfiguration.Rule.DefaultRetention.Days // empty' <<<"$lock")
    ryears=$(jq -r '.ObjectLockConfiguration.Rule.DefaultRetention.Years // empty' <<<"$lock")
    abort=$(hcl_days abort)
    {
      echo "module \"$name\" {"
      src scality-compliance-bucket
      echo
      echo '  account_access_key = var.account_access_key'
      echo '  account_secret_key = var.account_secret_key'
      echo
      echo "  bucket_name = $(jq -Rn --arg v "$bucket" '$v')"
      echo "  tags        = $tags"
      if [[ -n $mode ]]; then
        echo "  retention_mode = \"$mode\""
        [[ -n $rdays ]] && echo "  retention_days = $rdays"
        [[ -n $ryears ]] && echo "  retention_years = $ryears"
      else
        echo '  # REVIEW: no default retention on this bucket; the module requires one.'
        echo '  retention_mode = "GOVERNANCE"'
        echo '  retention_days = 1'
        note "bucket $bucket: object lock without default retention; module will add one (REVIEW)"
      fi
      if [[ -n $sse ]]; then
        echo "  sse_algorithm = \"$sse\""
        [[ -n $kms ]] && echo "  kms_master_key_id = $(jq -Rn --arg v "$kms" '$v')"
      else
        echo '  # REVIEW: no default encryption on this bucket; the module adds SSE-S3.'
        note "bucket $bucket: no default encryption; module will add SSE-S3 (REVIEW)"
      fi
      echo "  abort_incomplete_multipart_upload_days = $abort"
      if [[ $(jq '.noncurrent != null or .expiration != null' <<<"$lc") == true || -n $unmapped ]]; then
        echo '  # REVIEW: lifecycle rules other than MPU abort are replaced by the module.'
        note "bucket $bucket: lifecycle rules beyond MPU abort would be replaced (REVIEW)"
      fi
      hcl_policy
      echo '}'
      echo
      imp "$name" scality_bucket.this "$bucket"
      [[ -n $policy ]] && imp "$name" 'scality_bucket_policy.this[0]' "$bucket"
      [[ -n $sse ]] && imp "$name" scality_bucket_encryption.this "$bucket"
      [[ -n $mode ]] && imp "$name" scality_bucket_object_lock.this "$bucket"
      [[ $has_lc == yes && $abort != null ]] && imp "$name" 'scality_bucket_lifecycle.this[0]' "$bucket"
    } >>"$tmp"
    [[ $has_lc == yes && $abort == null ]] &&
      note "bucket $bucket: existing lifecycle rules left unmanaged (no MPU-abort rule to map)"
    continue
  fi

  abort=$(hcl_days abort) noncurrent=$(hcl_days noncurrent) expiration=$(hcl_days expiration)
  {
    echo "module \"$name\" {"
    src scality-application-bucket
    echo
    echo '  account_access_key = var.account_access_key'
    echo '  account_secret_key = var.account_secret_key'
    echo
    echo "  bucket_name = $(jq -Rn --arg v "$bucket" '$v')"
    echo "  tags        = $tags"
    case $versioning in
      Enabled) echo '  versioning  = true' ;;
      Suspended) echo '  versioning  = false' ;;
      *) echo '  versioning  = false' ;;
    esac
    if [[ -n $sse ]]; then
      echo "  sse_algorithm = \"$sse\""
      [[ -n $kms ]] && echo "  kms_master_key_id = $(jq -Rn --arg v "$kms" '$v')"
    else
      echo '  # REVIEW: no default encryption on this bucket; the module adds SSE-S3.'
      note "bucket $bucket: no default encryption; module will add SSE-S3 (REVIEW)"
    fi
    echo
    echo '  # Mirrors the bucket today. Module defaults: 7 / 90 / null.'
    echo "  abort_incomplete_multipart_upload_days = $abort"
    echo "  noncurrent_version_expiration_days     = $noncurrent"
    echo "  expiration_days                        = $expiration"
    if [[ -n $unmapped ]]; then
      echo "  # REVIEW: lifecycle rules the module can't express are replaced: $unmapped"
      note "bucket $bucket: lifecycle rules not expressible by the module: $unmapped (REVIEW)"
    fi
    hcl_policy
    echo '}'
    echo
    imp "$name" scality_bucket.this "$bucket"
    [[ -n $policy ]] && imp "$name" 'scality_bucket_policy.this[0]' "$bucket"
    [[ -n $sse ]] && imp "$name" scality_bucket_encryption.this "$bucket"
    if [[ $has_lc == yes && "$abort$noncurrent$expiration" != nullnullnull ]]; then
      imp "$name" 'scality_bucket_lifecycle.this[0]' "$bucket"
    fi
  } >>"$tmp"
  [[ $has_lc == yes && "$abort$noncurrent$expiration" == nullnullnull ]] &&
    note "bucket $bucket: existing lifecycle rules left unmanaged (none map to the module)"
done

# --- Users -----------------------------------------------------------------
for user in $(jq -r '.Users[].UserName' <<<"$users"); do
  policies=$(iam list-user-policies --user-name "$user" | jq -r '.PolicyNames[]')
  attached=$(iam list-attached-user-policies --user-name "$user" | jq -r '.AttachedPolicies | length')
  keys=$(iam list-access-keys --user-name "$user" | jq -r '.AccessKeyMetadata | length')
  count=$(grep -c . <<<"$policies" || true)

  if ((count != 1)); then
    note "user $user: $count inline policies; module takes exactly one (skipped)"
    continue
  fi
  ((attached > 0)) && note "user $user: $attached managed policies attached; left unmanaged"
  ((keys >= 4)) && note "user $user: at the 4-key limit; delete an unused key before apply (REVIEW)"

  doc=$(iam get-user-policy --user-name "$user" --policy-name "$policies" |
    jq '.PolicyDocument | if type == "string" then fromjson else . end')
  name=$(label user "$user")
  {
    echo "module \"$name\" {"
    src scality-application-identity
    echo
    echo '  account_access_key = var.account_access_key'
    echo '  account_secret_key = var.account_secret_key'
    echo
    echo "  username        = $(jq -Rn --arg v "$user" '$v')"
    echo "  policy_name     = $(jq -Rn --arg v "$policies" '$v')"
    echo '  policy_document = jsonencode('"$(jq '.' <<<"$doc" | sed '2,$s/^/  /')"')'
    echo '}'
    echo
    echo "# Access keys are not imported; apply creates a new key for $user."
    echo "# Move the application to it, then delete the old key."
    printf 'output "%s_access_key" {\n  value     = module.%s.access_key\n  sensitive = true\n}\n\n' "$name" "$name"
    printf 'output "%s_secret_key" {\n  value     = module.%s.secret_key\n  sensitive = true\n}\n\n' "$name" "$name"
    imp "$name" scality_user.this "$user"
    imp "$name" scality_user_policy.this "$user:$policies"
  } >>"$tmp"
done

# --- Groups ----------------------------------------------------------------
# Skip groups and roles the platform creates itself (path /scality-internal/).
groups=$(iam list-groups) || { echo "iam list-groups failed" >&2; exit 1; }
local_arns=$(iam list-policies --scope Local | jq -c '[.Policies[].Arn]') ||
  { echo "iam list-policies failed" >&2; exit 1; }
declare -A noted=()
for group in $(jq -r '.Groups[] | select(.Path != "/scality-internal/") | .GroupName' <<<"$groups"); do
  name=$(label group "$group")
  members=$(iam get-group --group-name "$group" | jq -r '[.Users[].UserName] | sort | map(tojson) | join(", ")')
  attached=$(iam list-attached-group-policies --group-name "$group" | jq -c '.AttachedPolicies')
  inline=$(iam list-group-policies --group-name "$group" | jq -r '.PolicyNames | length')
  ((inline > 0)) &&
    note "group $group: $inline inline policies; left unmanaged, and destroy fails until they're deleted (REVIEW)"

  owned=() shared=()
  while IFS=$'\t' read -r pname parn; do
    [[ -n $pname ]] || continue
    if [[ $(jq --arg a "$parn" 'index($a) != null' <<<"$local_arns") == true ]]; then
      count=$(iam get-policy --policy-arn "$parn" | jq -r '.Policy.AttachmentCount')
      if ((count == 1)); then
        owned+=("$pname"$'\t'"$parn")
        continue
      fi
      [[ -n ${noted[$parn]:-} ]] ||
        note "policy $pname: attached to $count groups, users or roles; attached by ARN, left unmanaged"
      noted[$parn]=1
    fi
    shared+=("$pname"$'\t'"$parn")
  done < <(jq -r '.[] | [.PolicyName, .PolicyArn] | @tsv' <<<"$attached")

  {
    echo "module \"$name\" {"
    src scality-group-access
    echo
    echo '  account_access_key = var.account_access_key'
    echo '  account_secret_key = var.account_secret_key'
    echo
    echo "  group_name = $(hcl_str "$group")"
    echo "  members    = [$members]"
    if ((${#owned[@]})); then
      echo
      echo '  policies = {'
      for p in "${owned[@]}"; do
        pname=${p%%$'\t'*} parn=${p#*$'\t'}
        ver=$(iam get-policy --policy-arn "$parn" | jq -r '.Policy.DefaultVersionId')
        doc=$(iam get-policy-version --policy-arn "$parn" --version-id "$ver" |
          jq '.PolicyVersion.Document | if type == "string" then fromjson else . end')
        echo "    $(hcl_str "$pname") = jsonencode($(sed '2,$s/^/    /' <<<"$doc"))"
      done
      echo '  }'
    fi
    if ((${#shared[@]})); then
      echo
      echo '  policy_arns = {'
      for p in "${shared[@]}"; do
        echo "    $(hcl_str "${p%%$'\t'*}") = $(hcl_str "${p#*$'\t'}")"
      done
      echo '  }'
    fi
    echo '}'
    echo
    imp "$name" scality_group.this "$group"
    for p in "${owned[@]}"; do
      pname=${p%%$'\t'*} parn=${p#*$'\t'}
      imp "$name" "scality_iam_policy.this[$(hcl_str "$pname")]" "$parn"
      imp "$name" "scality_iam_group_policy_attachment.created[$(hcl_str "$pname")]" "$group:$parn"
    done
    for p in "${shared[@]}"; do
      imp "$name" "scality_iam_group_policy_attachment.existing[$(hcl_str "${p%%$'\t'*}")]" "$group:${p#*$'\t'}"
    done
    imp "$name" 'scality_group_membership.this[0]' "$group"
  } >>"$tmp"
done

n=$(iam list-roles | jq -r '(.Roles // []) | map(select(.Path != "/scality-internal/")) | length')
((n > 0)) && note "account: $n roles found; not adopted (left unmanaged)"

mv "$tmp" "$out"
trap - EXIT
note "wrote $out"
