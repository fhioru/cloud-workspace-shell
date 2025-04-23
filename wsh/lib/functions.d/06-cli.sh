#!/usr/bin/env bash

# We will attempt to create a PS1 that displays AWS identity when active

_WSH_OLDPROMPT=
_WSH_OLDPS1=

_SEPARATOR_LEFT_BOLD=
_SEPARATOR_LEFT_THIN=
_SEPARATOR_RIGHT_BOLD=
_SEPARATOR_RIGHT_THIN=

function _patched_font_in_use {
    if [ -z "$PATCHED_FONT_IN_USE" ]; then
      return 1
    fi
    return 0
}


if _patched_font_in_use; then
	_SEPARATOR_LEFT_BOLD=""
	_SEPARATOR_LEFT_THIN=""
	_SEPARATOR_RIGHT_BOLD=""
	_SEPARATOR_RIGHT_THIN=""
else
	_SEPARATOR_LEFT_BOLD="◀"
	_SEPARATOR_LEFT_THIN="❮"
	_SEPARATOR_RIGHT_BOLD="▶"
	_SEPARATOR_RIGHT_THIN="❯"
fi

# Segment colors
__wsh_segment="$(_screen_encode_color ${__wsh_brand_bg} ${__wsh_brand_fg})"
__wsh_next_sep="$(_screen_encode_color ${__wsh_datetime_bg} ${__wsh_brand_bg})"

__date_segment="$(_screen_encode_color ${__wsh_datetime_bg} ${__wsh_datetime_fg})"
__date_next_sep="$(_screen_encode_color ${__wsh_account_bg} ${__wsh_datetime_bg})"

__awsid_segment="$(_screen_encode_color ${__wsh_account_bg} ${__wsh_account_fg})"
__awsid_next_sep="$(_screen_encode_color ${__wsh_region_bg} ${__wsh_account_bg})"

__awsregion_segment="$(_screen_encode_color ${__wsh_region_bg} ${__wsh_region_fg})"
__awsregion_next_sep="$(_screen_encode_color ${__wsh_brand_bg} ${__wsh_region_bg})"

__awstoken_valid_segment="$(_screen_encode_color ${__dark_green} ${__wsh_brand_fg})"
__awstoken_valid_next_sep="$(_screen_encode_color ${__dark_green} ${__wsh_region_bg})"

__awstoken_expired_segment="$(_screen_encode_color ${__red} ${__wsh_brand_fg})"
__awstoken_expired_next_sep="$(_screen_encode_color ${__red} ${__wsh_region_bg})"

__awstoken_lowtime_segment="$(_screen_encode_color ${__dark_orange} ${__wsh_brand_fg})"
__awstoken_lowtime_next_sep="$(_screen_encode_color ${__dark_orange} ${__wsh_region_bg})"



# Attempts to retrieve the current AWS identity name
function _cli_get_segment_aws_id_name {
    local segment_value="$(echo ${AWS_ID_NAME})"
    if [[ ! -z $segment_value ]]; then
        echo "${__date_next_sep}${_SEPARATOR_RIGHT_BOLD}${__awsid_segment} ${segment_value} "
    fi
}


# Attempts to retrieve the current AWS region
function _cli_get_segment_aws_region {
    local segment_value="$(echo ${AWS_DEFAULT_REGION})"
    if [ ! -z $segment_value ]; then
        echo "${__awsid_next_sep}${_SEPARATOR_RIGHT_BOLD}${__awsregion_segment} ${segment_value} "
    fi
}


# Attempts to retrieve the current AWS identity name
function _cli_get_segment_aws_token_expiry {
    if [[ ! -z ${AWS_TOKEN_EXPIRY} ]]; then
        local dt_now="$(date)"
        local dt_expiry="$(date --date "@${AWS_TOKEN_EXPIRY}")"
        local delta=$(( $(date -d "$dt_expiry" +%s) - $(date -d "$dt_now" +%s) ))
        if [[ ${delta} -gt 300 ]]; then
            local segment_value="$(date -d @$(( $(date -d "$dt_expiry" +%s) - $(date -d "$dt_now" +%s) )) -u +'%H:%M:%S')"
            local segment_style="${__awstoken_valid_next_sep}${_SEPARATOR_RIGHT_BOLD}${__awstoken_valid_segment}"
        elif [[ ${delta} -gt 0 ]]; then
            local segment_value="$(date -d @$(( $(date -d "$dt_expiry" +%s) - $(date -d "$dt_now" +%s) )) -u +'%H:%M:%S')"
            local segment_style="${__awstoken_lowtime_next_sep}${_SEPARATOR_RIGHT_BOLD}${__awstoken_lowtime_segment}"
        else
            local segment_value="EXPIRED"
            local segment_style="${__awstoken_expired_next_sep}${_SEPARATOR_RIGHT_BOLD}${__awstoken_expired_segment}"
        fi
        if [[ ! -z $segment_value ]]; then
            echo "${segment_style} ${segment_value} "
        fi
    fi
}


function _cli_get_segment_wsh {
    echo "${__wsh_segment} WSH "
}


function _cli_get_segment_datetime {
    echo "${__wsh_next_sep}${_SEPARATOR_RIGHT_BOLD}${__date_segment}"' \t '
}


function _cli_update_wsh_ps1 {
    PS1="\n$(_cli_get_segment_wsh)"
    PS1="${PS1}$(_cli_get_segment_datetime)"
    PS1="${PS1}$(_cli_get_segment_aws_id_name)"
    PS1="${PS1}$(_cli_get_segment_aws_region)"
    PS1="${PS1}$(_cli_get_segment_aws_token_expiry)"
    PS1="${PS1}${__reset}"' \w\n\\$ '
    export PS1
}


function _cli_save_prompt {
    if [[ ! -z ${PROMPT} ]]; then
        export _WSH_OLDPROMPT="${PROMPT}"
    else
        export _WSH_OLDPROMPT="${PROMPT_COMMAND}"
    fi
    export _WSH_OLDPS1="${PS1}"
}

function _cli_restore_prompt {
    unset PROMPT_COMMAND PROMPT PS1
    export PROMPT_COMMAND="${_WSH_OLDPROMPT}"
    export PROMPT="${_WSH_OLDPROMPT}"
    export PS1="${_WSH_OLDPS1}"
}


function _cli_wsh_prompt {
    unset PROMPT_COMMAND PROMPT
    export PROMPT_COMMAND="_cli_update_wsh_ps1; $PROMPT_COMMAND"
    export PROMPT="_cli_update_wsh_ps1; $PROMPT"
}


function _cli_startup {
    if [[ ! -z "$BASH_VERSION" ]]; then
        echo ""
        echo "Getting Started:"
        echo ""
        echo "  'wsh identity-create'    Create a simple AWS Credentials identity"
        echo "  'wsh login'              Login to AWS using a configured identity"
        echo "  'wsh region'             Change the default AWS region"
        echo "  'wsh logout'             Logout of an active session"
        echo "  'wsh session-save'       Save an active AWS session"
        echo "  'wsh session-load'       Resume a previous saved AWS session"
        echo "  'wsh help'               Show help and usage"
        echo ""
        echo "If you do not wish to see these tips then 'touch ~/.wsh/config.d/.notips'"
        echo ""
    fi
}


# Activate promt only if we're a terminal and it was the starting shell
if [[ -t 1 ]] && [[ "bash" == "${0##*/}" ]]; then
    if [[ ! -z "$BASH_VERSION" ]]; then
        _cli_save_prompt
        # Info helper for first run if no marker file are found
        if [[ ! -f ~/.wsh/config.d/.notips ]]; then
            _cli_startup
        fi
        _cli_wsh_prompt
    fi
fi
