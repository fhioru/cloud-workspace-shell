#!/usr/bin/env bash

# Specialized init to tidy existing repos
function _tf_init {
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


function _tf_doc {
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


function _tf_detect_local_vars {
    local var_file_name="00-environment.tfvars"
    _screen_info -n "Check for local vars..."
    if [[ -f "$(pwd)/${var_file_name}" ]]; then
        _screen_info "Found (${var_file_name}). Setting CONF"
        CONF="${var_file_name}"
        TF_VAR_FILE_ARGS="-var-file=${CONF}"
        export CONF TF_VAR_FILE_ARGS
    fi
}


function _tf_export {
    local _TF_EXPORT_OUTPUT="$(basename "$(pwd)").json"
    [ -f terraform.tfstate ] ||  { echo -e "\033[31mNo Terraform state file found to export\033[0m"; return 1; }
    _screen_info "Exporting managed resources to ${_TF_EXPORT_OUTPUT}"
    terraform output managed_resources_json | jq '.' > "${_TF_EXPORT_OUTPUT}"
}


# Check our code for syntax/lint issues
function _tf_check_syntax {
    _screen_info "Checking syntax with tflint"
    tflint --config "${HOME}/etc/tflint.hcl"
    [ $? -eq 0 ] ||  { echo -e "\033[31mResolve syntax errors first\033[0m"; return 1; }
}


# Change the default TF version used
function _tf_change_default_version {
    local requested_tf_ver=$1
    local terraform_installed_versons=$(tfenv list | sed 's/*/ /g' | cut -d" " -f3 | tr "\n" " ")
    _screen_info "Available Terraform Versions: ${terraform_installed_versons}"
    _screen_info "You can change the default using 'tf default 1.3.9'"
    _screen_info "You can install manually using 'tf use 0.11.15'"

    if [[ "${terraform_installed_versons}" == *"${requested_tf_ver}"* ]]; then
        tfenv use "${requested_tf_ver}"
    else
        _screen_error "Request TF version (${requested_tf_ver}) not available. Please choose from: ${terraform_installed_versons}"
        _screen_info "You can change the default using 'tf default 1.3.9'"
        _screen_info "You can install it manually using 'tf use ${requested_tf_ver}'"
    fi

    }


function _tf_change_version_autodetect {

    local statefile="$(pwd)/terraform.tfstate"
    if [ -f "${statefile}" ]; then
        _screen_info "Attempting to detect TF version from local state file"
        detected_tf_ver=$(cat "${statefile}" | jq -r '.terraform_version // ""')
        if [ -z "${detected_tf_ver}" ]; then
            _screen_error "Unable to read version from ${statefile}"
        else
            _tf_change_default_version "${detected_tf_ver}"
        fi
        if _aws_is_authenticated ; then
            _screen_info "Attempting to detect AWS region from local state file"
            detected_tf_region="$(cat "${statefile}" | jq -r '.resources[]? | select(.type == "aws_region")? | .instances[].attributes.id // ""')"
            if [ -z "${detected_tf_region}" ]; then
                _screen_error "Unable to read AWS region from ${statefile}"
            else
                _aws_region "${detected_tf_region}"
            fi
        else
            _screen_warn "AWS region detection was skipped due to no active session."
        fi

    else
        _screen_error "No local Terraform statefile found"
    fi

}

function _tf_change_version {
    
    local requested_tf_ver=$1

    tfenv use "${requested_tf_ver}"

    }

function tf {
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
# _tf_detect_local_vars

case ${tf_command} in

    doc)
        _tf_doc
    ;;

    init)
        _tf_init
        terraform "${@}" ${TF_VAR_FILE_ARGS}
    ;;

    plan|apply|destroy)
        if grep -rqw "$(pwd)" -e 'aws = {'; then
            if ! _aws_is_authenticated ; then
                _screen_error 'This command requires an active AWS session. Login first please!'
                return
            fi
            terraform "${@}" ${TF_VAR_FILE_ARGS}
        else
            terraform "${@}" ${TF_VAR_FILE_ARGS}
        fi
    ;;

    plandiff|diffplan)
        if grep -rqw "$(pwd)" -e 'aws = {'; then
            if ! _aws_is_authenticated ; then
                _screen_error 'This command requires an active AWS session. Login first please!'
                return
            fi
            terraform "${@}" ${TF_VAR_FILE_ARGS} | landscape
        else
            terraform "${@}" ${TF_VAR_FILE_ARGS} | landscape
        fi
    ;;

    export)
        _tf_export
    ;;

    fmt|format)
        terraform fmt -recursive
    ;;

    lint)
        _tf_check_syntax
        _screen_info "Syntax check passed, Starting run.."
    ;;

    default|switch)
        shift
        _tf_change_default_version "${@}"
    ;;

    autover)
        shift
        _tf_change_version_autodetect "${@}"
    ;;

    use)
        shift
        _tf_change_version "${@}"
    ;;

    validate|check)
        _tf_check_syntax
        _screen_info "Lint check passed, Starting validation.."
        terraform "${@}" ${TF_VAR_FILE_ARGS}
    ;;

    *)
        terraform "${@}"
    ;;

esac

}

export -f tf
