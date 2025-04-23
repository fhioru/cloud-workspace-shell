#!/usr/bin/env bash

# Simple function to download a release from a GitHub project, extract the contents
# and relocate any executables to /usr/local/bin
function _github_install_project_release {

  local gh_url="${1}"
  local gh_release="${2:-latest}"
  local target_path="${3:-/usr/local/bin}"
  local gh_url_with_version="$(echo "${gh_url}" | sed -e "s/GHVERSION/${gh_release}/g")"

  _screen_info "Source will be ${gh_url_with_version}"
  _screen_info "Attempting to install version ${gh_release} to ${target_path}"

  filename=$(echo ${gh_url_with_version##*/})

  _screen_info "Extracting ${filename}"
  _system_extract "${filename}"

}


# Attempts to correctly extract the specified archive
function _system_extract {
  if [ -f $1 ]; then
    case $1 in
    *.tar.bz2) tar xjf $1 ;;
    *.tar.gz) tar xzf $1 ;;
    *.bz2) bunzip2 $1 ;;
    *.rar) rar x $1 ;;
    *.gz) gunzip $1 ;;
    *.tar) tar xf $1 ;;
    *.tbz2) tar xjf $1 ;;
    *.tgz) tar xzf $1 ;;
    *.zip) unzip $1 ;;
    *.Z) uncompress $1 ;;
    *) _log_exit_with_error "${1} cannot be extracted via extract()" ;;
    esac
  else
    _log_exit_with_error "${1} is not a valid file"
  fi
}
