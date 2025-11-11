#!/usr/bin/env bash

# Placeholder function to acquire a bearer token for use the AWS SSO
function _aws_get_secure_bearer_token {

  local token_buffer="${HOME}/workspace/etc/aws-token"

  if [ -f "${token_buffer}" ]; then
    echo "$(cat ${token_buffer})"
    return 0
  fi
  echo ""
  return 1

}



# Using an existing bearer token to acquire AWS session credentials

function _aws_get_sso_account_credentials {

  if [ $# -lt 2 ]; then
      echo "Usage: _aws_get_sso_account_credentials <AWS_ACCOUNT_ID> <ROLE_NAME> [AWS_PORTAL_REGION]"
      return 1
  fi

  local requested_aws_account_id=$1
  local requested_role_name=$2
  local aws_portal_region=$3

  # Get bearer_token from secure source
  local bearer_token="$(_aws_get_secure_bearer_token)"

  : "${AWS_DEFAULT_REGION:=us-east-1}"
  : "${aws_portal_region:-$AWS_DEFAULT_REGION}"

  declare -a headers=(
    "authority: portal.sso.${aws_portal_region}.amazonaws.com"
    'accept: application/json, text/plain, */*'
    "x-amz-sso-bearer-token: ${bearer_token}"
    "x-amz-sso_bearer_token: ${bearer_token}"
  )

  # build the URL in segments to keep it modular and readable
  target_url="https://portal.sso.${aws_portal_region}.amazonaws.com/federation/credentials/?"
  target_url="${target_url}account_id=${requested_aws_account_id}&"
  target_url="${target_url}role_name=${requested_role_name}&"
  target_url="${target_url}debug=false"

  if ! curl -s "${target_url}" -H @<(for hdr in "${headers[@]}"; do echo "${hdr}"; done) ; then
    # echo "Error: Failed to get credentials"
    return 1
  fi

}



function _aws_get_sso_accounts_data {

  if [ -z "${AWS_DEFAULT_REGION:-}" ]; then
      _screen_warn "AWS_DEFAULT_REGION not set. Defaulting to us-east-1"
  fi

  local aws_portal_region=$1

  # Get bearer_token from secure source
  local bearer_token="$(_aws_get_secure_bearer_token)"

  : "${AWS_DEFAULT_REGION:=us-east-1}"
  : "${aws_portal_region:-$AWS_DEFAULT_REGION}"

  declare -a headers=(
    "authority: portal.sso.${aws_portal_region}.amazonaws.com"
    'accept: application/json, text/plain, */*'
    "x-amz-sso-bearer-token: ${bearer_token}"
    "x-amz-sso_bearer_token: ${bearer_token}"
  )

  # build the URL in segments to keep it modular and readable
  target_url="https://portal.sso.${aws_portal_region}.amazonaws.com/instance/appinstances"

  if ! curl -s "${target_url}" -H @<(for hdr in "${headers[@]}"; do echo "${hdr}"; done) ; then
    _screen_error "Error: Failed to AWS account data"
    return 1
  fi

}


function _aws_list_sso_accounts {

  if [ -z "${AWS_DEFAULT_REGION:-}" ]; then
      _screen_warn "AWS_DEFAULT_REGION not set. Defaulting to us-east-1"
  fi

  local aws_portal_region=$1

  : "${AWS_DEFAULT_REGION:=us-east-1}"
  : "${aws_portal_region:-$AWS_DEFAULT_REGION}"

  _aws_get_sso_accounts_data "${aws_portal_region}" \
    | jq -r '.result' \
    | jq '.[] | ( .searchMetadata ) + { id, name, description }' | jq -s '.' | wsh-json2table

}


function _aws_select_sso_account {

    # Trigger an initial login to create the listing of accounts and available roles
    aws-sso list AccountIdPad AccountAlias RoleName Arn Expires > /dev/null

    local selected_aws_arn=$(aws-sso list --sort="AccountAlias" Id AccountAlias AccountIdPad RoleName Arn Expires | tail -n +5 |fzf --delimiter '|' --bind 'enter:become(echo {5})+accept')

    local sso_buffer=$(mktemp ${WSH_ROOT}/tmp/awsssoXXXX)
    /usr/local/bin/aws-sso process --arn="${selected_aws_arn}" 1>"${sso_buffer}"
    echo ""

    _aws_load_credentials_from_sso "${sso_buffer}"

}