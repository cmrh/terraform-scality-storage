#!/usr/bin/env bash
# Generates module calls and import blocks for the buckets, users and groups
# in an existing ARTESCA account, so they can be adopted without being
# recreated. Read-only against the cluster. Writes no credentials: the
# generated calls take the account name, and the artesca provider signs in
# with its own OIDC settings.
#
# Mapping:
#   bucket with object lock      -> artesca-compliance-bucket
#   bucket with a transition     -> artesca-tiered-bucket
#   other bucket                 -> artesca-application-bucket
#   user                         -> artesca-application-identity, with its
#                                   inline and attached managed policies
#   group                        -> artesca-group-access, with its managed
#                                   policies and members
# Lifecycle rules are adopted one by one into the module rules they match;
# others are listed on stderr and left as they are. Access keys are not
# imported (their secrets can't be recovered); apply creates a new key per
# adopted user. A group owns the account policies attached only to it; other
# policies are attached by ARN and left unmanaged. Settings a module can't
# express are marked "# REVIEW:" in the output and listed on stderr.
# Replication, roles and locations are listed on stderr and left unmanaged.
#
# Environment (the same variables the artesca provider reads):
#   ARTESCA_MANAGEMENT_ENDPOINT, ARTESCA_OIDC_URL, ARTESCA_USERNAME,
#   ARTESCA_PASSWORD, ARTESCA_S3_ENDPOINT
#   ARTESCA_OIDC_REALM (default artesca), ARTESCA_CLIENT_ID (default zenko-ui),
#   ARTESCA_OIDC_SCOPE (default openid)
#   ARTESCA_INSECURE_SKIP_VERIFY  true to skip TLS verification
#
# Usage: artesca-adopt.sh --account NAME [--out FILE]
#                         [--iam-endpoint URL] [--sts-endpoint URL]
#                         [--module-source BASE] [--module-version CONSTRAINT]
#                         [--account-module NAME]
#
# The IAM endpoint is derived from the management endpoint
# (management.<x> -> iam.<x>) and the STS endpoint from the S3 endpoint
# (s3.<x> -> sts.<x>), as the provider does.
# --account-module NAME: the account is adopted in the same configuration as
# module "NAME"; the generated calls take module.NAME.account_name, so destroy
# deletes the buckets, users and groups before the account.
set -euo pipefail

account=
out=adopt.tf
iam_endpoint=
sts_endpoint=
module_source=cmrh/storage/scality//modules
module_version="~> 1.4"
account_module=

usage() { sed -n '/^# Usage:/,/^set /p' "$0" | sed '$d; s/^# \{0,1\}//' >&2; exit "${1:-2}"; }
while (($#)); do
  case $1 in
    --account) account=$2; shift 2 ;;
    --out) out=$2; shift 2 ;;
    --iam-endpoint) iam_endpoint=$2; shift 2 ;;
    --sts-endpoint) sts_endpoint=$2; shift 2 ;;
    --module-source) module_source=$2; shift 2 ;;
    --module-version) module_version=$2; shift 2 ;;
    --account-module) account_module=$2; shift 2 ;;
    -h | --help) usage 0 ;;
    *) echo "unknown argument: $1" >&2; usage ;;
  esac
done

for bin in aws jq curl; do
  command -v "$bin" >/dev/null || { echo "missing dependency: $bin" >&2; exit 1; }
done
# Formats the output.
engine=$(command -v tofu || command -v terraform) ||
  { echo "missing dependency: tofu or terraform" >&2; exit 1; }
[[ -n $account ]] || { echo "pass --account NAME" >&2; usage; }
for v in ARTESCA_MANAGEMENT_ENDPOINT ARTESCA_OIDC_URL ARTESCA_USERNAME ARTESCA_PASSWORD ARTESCA_S3_ENDPOINT; do
  [[ -n ${!v:-} ]] || { echo "set $v" >&2; exit 1; }
done
s3_endpoint=${ARTESCA_S3_ENDPOINT%/}

# Replace the first label of URL's host: derive URL FROM TO.
derive() {
  local scheme=${1%%://*} rest=${1#*://}
  rest=${rest%%/*}
  [[ $rest == "$2".* ]] || return 1
  printf '%s://%s.%s' "$scheme" "$3" "${rest#"$2".}"
}
iam_endpoint=${iam_endpoint:-$(derive "$ARTESCA_MANAGEMENT_ENDPOINT" management iam)} ||
  { echo "can't derive the IAM endpoint from ARTESCA_MANAGEMENT_ENDPOINT; pass --iam-endpoint" >&2; exit 1; }
sts_endpoint=${sts_endpoint:-$(derive "$s3_endpoint" s3 sts)} ||
  { echo "can't derive the STS endpoint from ARTESCA_S3_ENDPOINT; pass --sts-endpoint" >&2; exit 1; }

tls=() ctls=()
[[ ${ARTESCA_INSECURE_SKIP_VERIFY:-} == true ]] && tls=(--no-verify-ssl) ctls=(-k)

# Sign in as the provider does: OIDC password grant, then the account's
# storage manager role over STS. Secrets go through files, never argv.
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
umask 077
uri() { jq -rn --arg v "$1" '$v | @uri'; }
printf 'grant_type=password&client_id=%s&scope=%s&username=%s&password=%s' \
  "$(uri "${ARTESCA_CLIENT_ID:-zenko-ui}")" "$(uri "${ARTESCA_OIDC_SCOPE:-openid}")" \
  "$(uri "$ARTESCA_USERNAME")" "$(uri "$ARTESCA_PASSWORD")" >"$work/login"
curl -sS "${ctls[@]}" --data-binary @"$work/login" \
  "${ARTESCA_OIDC_URL%/}/auth/realms/$(uri "${ARTESCA_OIDC_REALM:-artesca}")/protocol/openid-connect/token" |
  jq -r '.access_token // empty' >"$work/token" || true
[[ -s $work/token ]] || { echo "OIDC sign-in failed: check ARTESCA_OIDC_URL, ARTESCA_USERNAME and ARTESCA_PASSWORD" >&2; exit 1; }

account_id= marker=
while :; do
  printf 'Action=GetRolesForWebIdentity&WebIdentityToken=%s%s' "$(<"$work/token")" \
    "${marker:+&Marker=$(uri "$marker")}" >"$work/roles"
  page=$(curl -sS "${ctls[@]}" -H 'Accept: application/json' --data-binary @"$work/roles" "$iam_endpoint/") ||
    { echo "GetRolesForWebIdentity failed: check the IAM endpoint" >&2; exit 1; }
  account_id=$(jq -r --arg a "$account" '[.Accounts[]? | select(.Name == $a) | .Roles[]?.Arn
    | split(":")[4]] | first // empty' <<<"$page")
  [[ -z $account_id && $(jq -r '.IsTruncated // false' <<<"$page") == true ]] || break
  marker=$(jq -r '.Marker' <<<"$page")
done
[[ -n $account_id ]] || { echo "account $account not found, or this login can't manage it" >&2; exit 1; }

jq -n --arg r "arn:aws:iam::$account_id:role/scality-internal/storage-manager-role" --rawfile t "$work/token" \
  '{RoleArn: $r, RoleSessionName: "artesca-adopt", WebIdentityToken: ($t | rtrimstr("\n"))}' >"$work/sts.json"
unset AWS_PROFILE AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION:-us-east-1} AWS_PAGER=""
creds=$(aws sts assume-role-with-web-identity --endpoint-url "$sts_endpoint" "${tls[@]}" \
  --cli-input-json "file://$work/sts.json" --output json 2>/dev/null) ||
  { echo "STS assume-role-with-web-identity failed: check the STS endpoint" >&2; exit 1; }
AWS_ACCESS_KEY_ID=$(jq -r .Credentials.AccessKeyId <<<"$creds")
AWS_SECRET_ACCESS_KEY=$(jq -r .Credentials.SecretAccessKey <<<"$creds")
AWS_SESSION_TOKEN=$(jq -r .Credentials.SessionToken <<<"$creds")
export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
unset creds

s3() { aws --endpoint-url "$s3_endpoint" "${tls[@]}" s3api "$@" --output json 2>/dev/null; }
iam() { aws --endpoint-url "$iam_endpoint" "${tls[@]}" iam "$@" --output json 2>/dev/null; }
# Run an s3api read; print its JSON, or {} when the configuration doesn't exist.
s3_or_empty() {
  local r
  r=$(s3 "$@") || r=
  printf '%s' "${r:-{\}}"
}

note() { printf '%s\n' "$*" >&2; }
label() { printf '%s_%s' "$1" "$(tr -c 'a-zA-Z0-9_\n' '_' <<<"$2" | tr 'A-Z' 'a-z')"; }
src() {
  printf '  source  = "%s/%s"\n' "$module_source" "$1"
  [[ -n $module_version ]] && printf '  version = "%s"\n' "$module_version"
  return 0
}
hcl_str() { jq -Rn --arg v "$1" '$v'; }
hcl_tags() { jq -r '(.TagSet // []) | if length == 0 then "{}" else
  "{\n" + (map("    \(.Key | tojson) = \(.Value | tojson)") | join("\n")) + "\n  }" end'; }
hcl_num() { jq -r --arg k "$1" '.[$k] // "null"'; }
imp() { printf 'import {\n  to = module.%s.%s\n  id = %s\n}\n\n' "$1" "$2" "$(hcl_str "$3")"; }
# The account argument every call takes.
hcl_account() {
  if [[ -n $account_module ]]; then
    echo "  account_name = module.$account_module.account_name"
  else
    echo "  account_name = $(hcl_str "$account")"
  fi
}
# The bucket's policy as a bucket_policy argument, when it has one.
hcl_policy() {
  [[ -n $policy ]] || return 0
  echo
  echo '  bucket_policy = jsonencode('"$(sed '2,$s/^/  /' <<<"$policy")"')'
}

buckets=$(s3 list-buckets) || { echo "list-buckets failed: check the S3 endpoint" >&2; exit 1; }
users=$(iam list-users) || { echo "iam list-users failed: check the IAM endpoint" >&2; exit 1; }

tmp=$work/adopt.tf
{
  echo "# Generated by artesca-adopt.sh on $(date -u +%Y-%m-%dT%H:%M:%SZ) for account $account."
  echo "# Review every \"# REVIEW:\" line, then plan. Expect imports and no replacements."
  echo
} >"$tmp"

# --- Buckets ---------------------------------------------------------------
# Lifecycle rules that match a module rule: cleanup (noncurrent expiration,
# multipart abort, delete markers; whole bucket), expiration (current
# versions, optional prefix), transition (current versions, optional prefix)
# and noncurrent transition (whole bucket). The first match of each kind is
# adopted; the rest stay as they are.
classify='
  def prefix: (.Filter.Prefix // .Filter.And.Prefix // .Prefix // "");
  def tagged: ((.Filter // {}) | has("Tag") or has("And"));
  def acts: [keys[] | select(IN("ID", "Status", "Filter", "Prefix") | not)];
  def plain: .Status == "Enabled" and (tagged | not);
  def cleanup: plain and prefix == ""
    and (acts - ["NoncurrentVersionExpiration", "AbortIncompleteMultipartUpload", "Expiration"]) == []
    and (.Expiration == null or (.Expiration | keys) == ["ExpiredObjectDeleteMarker"])
    and ((.NoncurrentVersionExpiration.NoncurrentDays // .AbortIncompleteMultipartUpload.DaysAfterInitiation) != null
         or .Expiration.ExpiredObjectDeleteMarker == true);
  def expiration: plain and acts == ["Expiration"] and (.Expiration | keys) == ["Days"];
  def transition: plain and acts == ["Transitions"] and (.Transitions | length) == 1
    and (.Transitions[0] | keys) == ["Days", "StorageClass"];
  def ntransition: plain and prefix == "" and acts == ["NoncurrentVersionTransitions"]
    and (.NoncurrentVersionTransitions | length) == 1
    and (.NoncurrentVersionTransitions[0] | keys) == ["NoncurrentDays", "StorageClass"];
  ([.[] | select(cleanup)] | first) as $c
  | ([.[] | select(expiration)] | first) as $e
  | ([.[] | select(transition)] | first) as $t
  | ([.[] | select(ntransition)] | first) as $n
  | {cleanup: ($c | if . then {id: .ID, noncurrent: .NoncurrentVersionExpiration.NoncurrentDays,
                              abort: .AbortIncompleteMultipartUpload.DaysAfterInitiation,
                              markers: (.Expiration.ExpiredObjectDeleteMarker // false)} else null end),
     expiration: ($e | if . then {id: .ID, days: .Expiration.Days, prefix: (prefix | if . == "" then null else . end)} else null end),
     transition: ($t | if . then {id: .ID, days: .Transitions[0].Days, location: .Transitions[0].StorageClass,
                                  prefix: (prefix | if . == "" then null else . end)} else null end),
     ntransition: ($n | if . then {id: .ID, days: .NoncurrentVersionTransitions[0].NoncurrentDays,
                                   location: .NoncurrentVersionTransitions[0].StorageClass} else null end),
     ids: map(.ID)}'

for bucket in $(jq -r '.Buckets[].Name' <<<"$buckets"); do
  name=$(label bucket "$bucket")
  versioning=$(s3_or_empty get-bucket-versioning --bucket "$bucket" | jq -r '.Status // "Unversioned"')
  lock=$(s3_or_empty get-object-lock-configuration --bucket "$bucket")
  sse=$(s3_or_empty get-bucket-encryption --bucket "$bucket" |
    jq -r '.ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm // empty')
  tags=$(s3_or_empty get-bucket-tagging --bucket "$bucket" | hcl_tags)
  ntags=$(s3_or_empty get-bucket-tagging --bucket "$bucket" | jq '.TagSet // [] | length')
  location=$(s3_or_empty get-bucket-location --bucket "$bucket" | jq -r '.LocationConstraint // empty')
  policy=$(s3_or_empty get-bucket-policy --bucket "$bucket" |
    jq 'if .Policy then .Policy | fromjson else empty end')
  lc=$(s3_or_empty get-bucket-lifecycle-configuration --bucket "$bucket" | jq -c '.Rules // []' | jq -c "$classify")

  [[ $(s3_or_empty get-bucket-replication --bucket "$bucket") != '{}' ]] &&
    note "bucket $bucket: replication configured; left unmanaged"
  [[ $location == us-east-1 ]] && location=

  cleanup=$(jq -c .cleanup <<<"$lc")
  kind=application
  if [[ $(jq -r '.ObjectLockConfiguration.ObjectLockEnabled // empty' <<<"$lock") == Enabled ]]; then
    kind=compliance
  elif [[ $(jq -r '.transition != null' <<<"$lc") == true ]]; then
    kind=tiered
  fi
  if [[ -n $location && $kind != application ]]; then
    note "bucket $bucket: stored in location $location, which artesca-$kind-bucket can't set; not adopted (REVIEW)"
    continue
  fi

  # Rules this bucket's module call adopts; the rest are listed as unmanaged.
  adopted=()
  inner=$([[ $kind == application ]] && echo "" || echo "module.bucket.")
  {
    echo "module \"$name\" {"
    src "artesca-$kind-bucket"
    echo
    hcl_account
    echo "  bucket_name  = $(hcl_str "$bucket")"
    echo "  tags         = $tags"
    if [[ -n $sse ]]; then
      echo "  sse_algorithm = \"$sse\""
    else
      echo '  sse_algorithm = null # no default encryption today'
    fi

    case $kind in
      compliance)
        mode=$(jq -r '.ObjectLockConfiguration.Rule.DefaultRetention.Mode // empty' <<<"$lock")
        rdays=$(jq -r '.ObjectLockConfiguration.Rule.DefaultRetention.Days // empty' <<<"$lock")
        ryears=$(jq -r '.ObjectLockConfiguration.Rule.DefaultRetention.Years // empty' <<<"$lock")
        echo
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
        # The module's cleanup rule can only abort multipart uploads.
        if [[ $(jq -r 'if . == null then "none" elif .noncurrent == null and .markers == false then "ok" else "other" end' <<<"$cleanup") == ok ]]; then
          echo "  abort_incomplete_multipart_upload_days = $(hcl_num abort <<<"$cleanup")"
          adopted+=("$(jq -r .id <<<"$cleanup")")
        else
          echo '  abort_incomplete_multipart_upload_days = null'
        fi
        ;;
      tiered)
        transition=$(jq -c .transition <<<"$lc") ntransition=$(jq -c .ntransition <<<"$lc")
        tloc=$(jq -r .location <<<"$transition")
        echo
        echo "  transition_location = $(hcl_str "$tloc")"
        echo "  transition_days     = $(hcl_num days <<<"$transition")"
        [[ $(jq -r '.prefix // empty' <<<"$transition") ]] &&
          echo "  transition_prefix   = $(hcl_str "$(jq -r .prefix <<<"$transition")")"
        adopted+=("$(jq -r .id <<<"$transition")")
        if [[ $ntransition != null && $(jq -r .location <<<"$ntransition") == "$tloc" ]]; then
          echo "  noncurrent_transition_days = $(hcl_num days <<<"$ntransition")"
          adopted+=("$(jq -r .id <<<"$ntransition")")
        fi
        [[ $versioning == Enabled ]] || {
          echo '  # REVIEW: versioning is off on this bucket; the module turns it on.'
          note "bucket $bucket: unversioned; artesca-tiered-bucket enables versioning (REVIEW)"
        }
        ;;
      application)
        [[ -n $location ]] && echo "  location_constraint = $(hcl_str "$location")"
        if [[ $versioning == Enabled ]]; then
          echo '  versioning   = true'
        else
          echo '  versioning   = false # leaves versioning as it is'
        fi
        expiration=$(jq -c .expiration <<<"$lc")
        if [[ $expiration != null ]]; then
          echo
          echo "  expiration_days   = $(hcl_num days <<<"$expiration")"
          [[ $(jq -r '.prefix // empty' <<<"$expiration") ]] &&
            echo "  expiration_prefix = $(hcl_str "$(jq -r .prefix <<<"$expiration")")"
          adopted+=("$(jq -r .id <<<"$expiration")")
        fi
        ;;
    esac

    if [[ $kind != compliance ]]; then
      echo
      echo '  # Mirrors the bucket today. Module defaults: 90 / 7 / false.'
      if [[ $cleanup != null ]]; then
        echo "  noncurrent_version_expiration_days     = $(hcl_num noncurrent <<<"$cleanup")"
        echo "  abort_incomplete_multipart_upload_days = $(hcl_num abort <<<"$cleanup")"
        echo "  expire_delete_markers                  = $(jq -r .markers <<<"$cleanup")"
        adopted+=("$(jq -r .id <<<"$cleanup")")
      else
        echo '  noncurrent_version_expiration_days     = null'
        echo '  abort_incomplete_multipart_upload_days = null'
        echo '  expire_delete_markers                  = false'
      fi
    fi
    hcl_policy
    echo '}'
    echo

    imp "$name" "${inner}artesca_bucket.this" "$account/$bucket"
    [[ -n $sse ]] && imp "$name" "${inner}artesca_bucket_encryption.this[0]" "$account/$bucket"
    ((ntags > 0)) && imp "$name" "${inner}artesca_bucket_tagging.this[0]" "$account/$bucket"
    [[ -n $policy ]] && imp "$name" "${inner}artesca_bucket_policy.this[0]" "$account/$bucket"
    for id in "${adopted[@]}"; do
      case $id in
        "$(jq -r '.cleanup.id // empty' <<<"$lc")") to="${inner}artesca_bucket_workflow_expiration.cleanup[0]" ;;
        "$(jq -r '.expiration.id // empty' <<<"$lc")") to="artesca_bucket_workflow_expiration.this[0]" ;;
        "$(jq -r '.transition.id // empty' <<<"$lc")") to="artesca_bucket_workflow_transition.this" ;;
        *) to="artesca_bucket_workflow_transition.noncurrent[0]" ;;
      esac
      imp "$name" "$to" "$account/$bucket/$id"
    done
    [[ $kind == compliance && -n $mode ]] && imp "$name" artesca_bucket_object_lock.this "$account/$bucket"
  } >>"$tmp"

  left=$(jq -r --args '.ids - $ARGS.positional | map(. // "(no id)") | join(", ")' "${adopted[@]}" <<<"$lc")
  [[ -n $left ]] && note "bucket $bucket: lifecycle rules left as they are (no matching module rule): $left"
done

# --- Users -----------------------------------------------------------------
# One inline policy goes in policy_name / policy_document, several in policies;
# attached managed policies go in policy_arns.
user_doc() {
  iam get-user-policy --user-name "$1" --policy-name "$2" |
    jq '.PolicyDocument | if type == "string" then fromjson else . end'
}
for user in $(jq -r '.Users[] | select(.Path != "/scality-internal/") | .UserName' <<<"$users"); do
  policies=$(iam list-user-policies --user-name "$user" | jq -r '.PolicyNames[]')
  attached=$(iam list-attached-user-policies --user-name "$user" | jq -r '.AttachedPolicies[] | [.PolicyName, .PolicyArn] | @tsv')
  keys=$(iam list-access-keys --user-name "$user" | jq -r '.AccessKeyMetadata | length')
  count=$(grep -c . <<<"$policies" || true)
  ((keys >= 2)) && note "user $user: has $keys access keys; delete an unused one if apply can't create a key (REVIEW)"

  name=$(label user "$user")
  {
    echo "module \"$name\" {"
    src artesca-application-identity
    echo
    hcl_account
    if ((count == 1)); then
      echo "  username        = $(hcl_str "$user")"
      echo "  policy_name     = $(hcl_str "$policies")"
      echo '  policy_document = jsonencode('"$(user_doc "$user" "$policies" | sed '2,$s/^/  /')"')'
    else
      echo "  username     = $(hcl_str "$user")"
    fi
    if ((count > 1)); then
      echo
      echo '  policies = {'
      for p in $policies; do
        echo "    $(hcl_str "$p") = jsonencode($(user_doc "$user" "$p" | sed '2,$s/^/    /'))"
      done
      echo '  }'
    fi
    if [[ -n $attached ]]; then
      echo
      echo '  policy_arns = {'
      while IFS=$'\t' read -r pname parn; do
        echo "    $(hcl_str "$pname") = $(hcl_str "$parn")"
      done <<<"$attached"
      echo '  }'
    fi
    echo '}'
    echo
    echo "# Access keys are not imported; apply creates a new key for $user."
    echo "# Move the application to it, then delete the old key."
    printf 'output "%s_access_key" {\n  value     = module.%s.access_key\n  sensitive = true\n}\n\n' "$name" "$name"
    printf 'output "%s_secret_key" {\n  value     = module.%s.secret_key\n  sensitive = true\n}\n\n' "$name" "$name"
    imp "$name" artesca_user.this "$account/$user"
    if ((count == 1)); then
      imp "$name" 'artesca_user_policy.this[0]' "$account/$user/$policies"
    else
      for p in $policies; do
        imp "$name" "artesca_user_policy.policies[$(hcl_str "$p")]" "$account/$user/$p"
      done
    fi
    if [[ -n $attached ]]; then
      while IFS=$'\t' read -r pname parn; do
        imp "$name" "artesca_user_policy_attachment.this[$(hcl_str "$pname")]" "$account/$user/$parn"
      done <<<"$attached"
    fi
  } >>"$tmp"
done

# --- Groups ----------------------------------------------------------------
groups=$(iam list-groups) || { echo "iam list-groups failed" >&2; exit 1; }
local_arns=$(iam list-policies --scope Local | jq -c '[.Policies[].Arn]') ||
  { echo "iam list-policies failed" >&2; exit 1; }
declare -A noted=()
for group in $(jq -r '.Groups[] | select(.Path != "/scality-internal/") | .GroupName' <<<"$groups"); do
  name=$(label group "$group")
  members=$(iam get-group --group-name "$group" | jq -r '[.Users[].UserName] | sort')
  attached=$(iam list-attached-group-policies --group-name "$group" | jq -c '.AttachedPolicies')
  inline=$(iam list-group-policies --group-name "$group" | jq -r '.PolicyNames | length')
  ((inline > 0)) &&
    note "group $group: $inline inline policies; left unmanaged, and destroy fails until they're deleted (REVIEW)"

  owned=() shared=()
  while IFS=$'\t' read -r pname parn; do
    [[ -n $pname ]] || continue
    if [[ $(jq --arg a "$parn" 'index($a) != null' <<<"$local_arns") == true ]]; then
      n=$(iam get-policy --policy-arn "$parn" | jq -r '.Policy.AttachmentCount')
      if ((n == 1)); then
        owned+=("$pname"$'\t'"$parn")
        continue
      fi
      [[ -n ${noted[$parn]:-} ]] ||
        note "policy $pname: attached to $n users, groups or roles; attached by ARN, left unmanaged"
      noted[$parn]=1
    fi
    shared+=("$pname"$'\t'"$parn")
  done < <(jq -r '.[] | [.PolicyName, .PolicyArn] | @tsv' <<<"$attached")

  {
    echo "module \"$name\" {"
    src artesca-group-access
    echo
    hcl_account
    echo "  group_name   = $(hcl_str "$group")"
    echo "  members      = $(jq -c . <<<"$members")"
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
    imp "$name" artesca_group.this "$account/$group"
    for p in "${owned[@]}"; do
      pname=${p%%$'\t'*} parn=${p#*$'\t'}
      imp "$name" "artesca_policy.this[$(hcl_str "$pname")]" "$account/$parn"
      imp "$name" "artesca_group_policy_attachment.created[$(hcl_str "$pname")]" "$account/$group/$parn"
    done
    for p in "${shared[@]}"; do
      imp "$name" "artesca_group_policy_attachment.existing[$(hcl_str "${p%%$'\t'*}")]" "$account/$group/${p#*$'\t'}"
    done
    for m in $(jq -r '.[]' <<<"$members"); do
      imp "$name" "artesca_group_membership.this[$(hcl_str "$m")]" "$account/$group/$m"
    done
  } >>"$tmp"
done

# Skip the roles ARTESCA creates itself (path /scality-internal/).
n=$(iam list-roles | jq -r '(.Roles // []) | map(select(.Path != "/scality-internal/")) | length')
((n > 0)) && note "account: $n roles found; not adopted (left unmanaged)"

formatted=$("$engine" fmt - <"$tmp") || { echo "fmt failed on the generated configuration" >&2; exit 1; }
printf '%s\n' "$formatted" >"$out"
note "wrote $out"
