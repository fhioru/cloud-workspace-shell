#!/usr/bin/env bash

__WSH_COMPLETIONS="
console-login
creds
kion-login
kion-select
login
logout
region
region
session-load
session-purge
session-save
sso-list
sso-login
sso-login-with-arn
sso-logout
sso-select
sudo
"


function show_help {
    cat <<EOF
usage: wsh [--help] <command> [<args>]

available commands:

EOF
    _wsh_list_subcommands
}


function _wsh_show_completions {

    # Variable setup
    local DEFAULT_OUT="${HOME}/.wsh/log/wsh-cli.log"
    local SUBCOMMAND_ROOT="${WSH_ROOT}/bin/subcommands"
    local SUBCOMMANDS="$(find ${SUBCOMMAND_ROOT} -type f -name 'wsh-*' -exec basename {} \; 2> /dev/null | sed -e 's/wsh-//g')"

    readarray -t <<<$__WSH_COMPLETIONS VS_SUBCOMMANDS
    # Add all of our discovered sub-commands
    VS_SUBCOMMANDS+=( $SUBCOMMANDS )

    saveIFS=$IFS
    IFS=$'\n'
    echo "${VS_SUBCOMMANDS[*]} ${INTERNALCOMMANDS}" | sort
    IFS=$saveIFS

}


function _wsh_show_usage {
    cat <<EOF
usage: wsh [version] [--help] <command> [<args>]

The most commonly used commands are:
  whoami            Lists information about the current API user
  list              Lists many AWS resource types using JQ based filters
  vpc-viz           Creates diagrams and graphs of your VPC resources
  scp               Wrapper for SCP configured to use loaded AWS identity
  ssh               Wrapper for SSH configured to use loaded AWS identity

'wsh -h' lists available subcommands
EOF
}


function _wsh_version {
    # Default for WSH_VERSION if unset
    : "${WSH_ROOT:='unknown'}"
    echo "wsh version $WSH_VERSION"
}


function cleanup {
    echo "Exiting."
    exit 1
}


function _wsh_list_subcommands {

    _wsh_show_completions | sort | column -c 80

}


function wsh {

    # Variable setup
    local DEFAULT_OUT="${HOME}/.wsh/log/wsh-cli.log"
    local SUBCOMMAND_ROOT="${WSH_ROOT}/bin/subcommands"
    local SUBCOMMANDS="$(find $SUBCOMMAND_ROOT -type f -name 'wsh-*' -exec basename {} \; 2> /dev/null | sed -e 's/wsh-//g')"

    # Show most common commands if no args are given
    if { [ -z "$1" ] && [ -t 0 ] ; }; then
        _wsh_show_usage
        return 0
    fi

    # show help for no arguments if stdin is a terminal
    if [ "$1" == '-h' ] || [ "$1" == '--help' ] || [ "$1" == 'help' ]; then
        show_help
        return 0
    fi

    # show lst of commands
    if [ "$1" == '-c' ] || [ "$1" == '--commands' ] || [ "$1" == 'commands' ]; then
        _wsh_show_completions
        return 0
    fi


    # Pop the first arg as a potential command and attempt to process
    _sub_command=$1
    shift

    case ${_sub_command} in

        oldprompt)
            _cli_restore_prompt
        ;;

        prompt)
            _cli_wsh_prompt
        ;;

        login)
            if [[ -n "$AWS_CONTAINER_CREDENTIALS_FULL_URI" ]] && [[ -n "$AWS_CONTAINER_AUTHORIZATION_TOKEN" ]]; then
                _screen_info "CloudShell detected. Attempting to load existing credentials"
                _aws_load_credentials_from_cloudshell
            elif [[ "$1" == "instance" ]]; then
                _screen_info "Attempting to aquire credentials from Instance"
                _aws_load_credentials_from_instance
            else
                _aws_login "${@}"
            fi
        ;;

        assume|sudo)
            _aws_assume_role_and_load_credentials "${@}"
        ;;

        console-login)
            _aws_get_console_presigned_url
        ;;

        sso-list)
            /usr/local/bin/aws-sso list --sort="AccountAlias" Id AccountAlias AccountIdPad RoleName Arn Expires
        ;;

        sso-logout)
            /usr/local/bin/aws-sso logout "${@}"
        ;;

        sso-login-with-arn)
            sso_buffer=$(mktemp ${WSH_ROOT}/tmp/awsssoXXXX)
            /usr/local/bin/aws-sso process --arn "${@}" 1>"${sso_buffer}"
            echo ""
            _aws_load_credentials_from_sso "${sso_buffer}"
        ;;

        sso-select|sso-login)
            _aws_select_sso_account "${@}"
        ;;

        kion-select|kion-login)
            _aws_select_kion_account_and_role "${@}"
        ;;

        sso-token-login)
            if [[ -e ~/workspace/etc/aws-token ]]; then
              _screen_info "AWS bearer token detected. Attempting to acquire credentials"
              _aws_load_credentials_from_json <( _aws_get_sso_account_credentials "${@}" )
            else
              _screen_error "No AWS bearer token detected in ~/workspace/etc/aws-token"
            fi
        ;;

        logout|session-purge)
            _aws_logout
        ;;

        credentials|creds)
            if [[ "$1" == "load" ]]; then
                _aws_load_sso_credentials
            else
                _aws_show_credentials
            fi

        ;;

        session-save)
            _aws_session_save
        ;;

        session-load)
            _aws_session_load
        ;;

        region)
            _aws_region "${@}"
        ;;

        version)
            _wsh_version
        ;;

        reload)
            . "${WSH_ROOT}/etc/wshrc"
        ;;

        *)
            # Ensure that the command we will try to execute actually exists in the
            # subcommand dir
            if [ ! -x "${SUBCOMMAND_ROOT}/wsh-${_sub_command}" ]; then
                _screen_error "'${_sub_command}' is not a valid wsh command. See 'wsh --help' for more info."
                return 1
            fi

            # Now attempt to execute the subcommand
            "${SUBCOMMAND_ROOT}/wsh-${_sub_command}" "${@}"
        ;;

    esac

}

export -f wsh
