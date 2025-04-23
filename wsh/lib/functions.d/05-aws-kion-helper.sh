#!/usr/bin/env bash


function _aws_select_kion_account_and_role {

    local sso_buffer=$(mktemp ${WSH_ROOT}/tmp/awsssoXXXX)

    if [[ -z "${CMD_KION_CLI}" ]]; then
      _screen_error "CMD_KION_CLI has not been set. Ensure CMD_KION_CLI is set to the path of your Kion CLI tool"
      return 1
    else
      # Trigger the Kion token generation CLI
      $CMD_KION_CLI -t json -f aws_sso -o "${sso_buffer}"
      _aws_load_credentials_from_sso "${sso_buffer}"
    fi

}