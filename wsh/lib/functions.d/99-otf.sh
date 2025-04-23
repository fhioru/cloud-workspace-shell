#!/usr/bin/env bash

# Specialized init to tidy existing repos
function _otf_init {
    # Trash and rebuild the .terraform folder
    if [[ -d "$(pwd)/.terraform" ]]; then
        _screen_info "Cleanup of local TF Plugins cache folder"
        rm -rf "$(pwd)/.terraform" 2>/dev/null
    fi
    # Rename common var files to aupport auto-loading
    if [[ -f "$(pwd)/00-environment.tfvars" ]]; then
        _screen_info "Moving 00-environment.tfvars to support auto-loading"
        mv "$(pwd)/00-environment.tfvars" "$(pwd)/00-environment.auto.tfvars"
    fi
}


function _otf_doc {
    local _DOC_NAME="AS-BUILT-DOC.md"
    {
        echo ""
        "${HOME}/bin/terraform-state-doc"
        echo ""
        echo "## Stack Changelog"
        echo ""
        echo "| Commit | Changed By | Date Modified | Description of Change|"
        echo "|:--- |:--- | ---:|:--- |"
        git mdlog
    } > "${_DOC_NAME}"
    echo "Updated ${_DOC_NAME} from terraform.tfstate"
}


function _otf_detect_local_vars {
    local var_file_name="00-environment.tfvars"
    _screen_info -n "Check for local vars..."
    if [[ -f "$(pwd)/${var_file_name}" ]]; then
        _screen_info "Found (${var_file_name}). Setting CONF"
        CONF="${var_file_name}"
        TF_VAR_FILE_ARGS="-var-file=${CONF}"
        export CONF TF_VAR_FILE_ARGS
    fi
}


function _otf_export {
    local _TF_EXPORT_OUTPUT="$(basename "$(pwd)").json"
    [ -f terraform.tfstate ] ||  { echo -e "\033[31mNo state file found to export\033[0m"; return 1; }
    _screen_info "Exporting managed resources to ${_TF_EXPORT_OUTPUT}"
    tofu output managed_resources_json | jq '.' > "${_TF_EXPORT_OUTPUT}"
}


# Check our code for syntax/lint issues
function _otf_check_syntax {
    _screen_info "Checking syntax with tflint"
    tflint --config "${HOME}/etc/tflint.hcl"
    [ $? -eq 0 ] ||  { echo -e "\033[31mResolve syntax errors first\033[0m"; return 1; }
}


# Change the default TF version used
function _otf_change_default_version {
    local requested_otf_ver=$1
    local tofu_installed_versons=$(tfenv list | sed 's/*/ /g' | cut -d" " -f3 | tr "\n" " ")
    _screen_info "Available OpenTofu Versions: ${tofu_installed_versons}"
    _screen_info "You can change the default using 'otf default 1.3.9'"
    _screen_info "You can install manually using 'otf use 0.11.15'"

    if [[ "${tofu_installed_versons}" == *"${requested_otf_ver}"* ]]; then
        tfenv use "${requested_otf_ver}"
    else
        _screen_error "Request OpenTofu version (${requested_otf_ver}) not available. Please choose from: ${tofu_installed_versons}"
        _screen_info "You can change the default using 'otf default 1.3.9'"
        _screen_info "You can install it manually using 'otf use ${requested_otf_ver}'"
    fi

    }


function _otf_change_version_autodetect {

    local statefile="$(pwd)/terraform.tfstate"
    if [ -f "${statefile}" ]; then
        _screen_info "Attempting to detect TF version from local state file"
        detected_otf_ver=$(cat "${statefile}" | jq -r '.terraform_version // ""')
        if [ -z "${detected_otf_ver}" ]; then
            _screen_error "Unable to read version from ${statefile}"
        else
            _otf_change_default_version "${detected_otf_ver}"
        fi
        if _aws_is_authenticated ; then
            _screen_info "Attempting to detect AWS region from local state file"
            detected_otf_region="$(cat "${statefile}" | jq -r '.resources[]? | select(.type == "aws_region")? | .instances[].attributes.id // ""')"
            if [ -z "${detected_otf_region}" ]; then
                _screen_error "Unable to read AWS region from ${statefile}"
            else
                _aws_region "${detected_otf_region}"
            fi
        else
            _screen_warn "AWS region detection was skipped due to no active session."
        fi

    else
        _screen_error "No local Terraform statefile found"
    fi

}

function _otf_change_version {

    local requested_otf_ver=$1

    tfenv use "${requested_otf_ver}"

    }

function otf {
##############################################################################
# Main Script
##############################################################################

# Redirect all output through the time-stamper
# exec &> >(_log_pipe)

### Variables
: ${TIMESTAMP_FORMAT:="%Y-%m-%dT%H:%M:%S%z"}    # override via environment
: ${TF_VAR_FILE:="00-environment.tfvars"}       # override via environment
local tf_command="${1}"
local TF_VAR_FILE_ARGS=
# _otf_detect_local_vars

case ${tf_command} in

    doc)
        _otf_doc
    ;;

    init)
        _otf_init
        tofu "${@}" ${TF_VAR_FILE_ARGS}
    ;;

    plan|apply|destroy)
        if grep -rqw "$(pwd)" -e 'aws = {'; then
            if ! _aws_is_authenticated ; then
                _screen_error 'This command requires an active AWS session. Login first please!'
                return
            fi
            tofu "${@}" ${TF_VAR_FILE_ARGS}
        else
            tofu "${@}" ${TF_VAR_FILE_ARGS}
        fi
    ;;

    plandiff|diffplan)
        if grep -rqw "$(pwd)" -e 'aws = {'; then
            if ! _aws_is_authenticated ; then
                _screen_error 'This command requires an active AWS session. Login first please!'
                return
            fi
            tofu "${@}" ${TF_VAR_FILE_ARGS} | landscape
        else
            tofu "${@}" ${TF_VAR_FILE_ARGS} | landscape
        fi
    ;;

    export)
        _otf_export
    ;;

    fmt|format)
        tofu fmt -recursive
    ;;

    lint)
        _otf_check_syntax
        _screen_info "Syntax check passed, Starting run.."
    ;;

    default|switch)
        shift
        _otf_change_default_version "${@}"
    ;;

    autover)
        shift
        _otf_change_version_autodetect "${@}"
    ;;

    use)
        shift
        _otf_change_version "${@}"
    ;;

    validate|check)
        _otf_check_syntax
        _screen_info "Lint check passed, Starting validation.."
        tofu "${@}" ${TF_VAR_FILE_ARGS}
    ;;

    *)
        tofu "${@}"
    ;;

esac

}

export -f otf
