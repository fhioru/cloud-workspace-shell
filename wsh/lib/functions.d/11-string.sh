#!/usr/bin/env bash

# Reproduces the behaviour of the Python aray.join() function. Copied from the
# awesome example on https://stackoverflow.com/a/17841619
function _string_join {
    local IFS="$1";
    shift;
    echo "$*";
}


# Reproduces the behaviour of the chomp command/utility
function _string_chomp {
    local s="$(echo "${@}" | sed -e 's/^ *//g;s/ *$//g')"
    echo "${s}"
}


# Reproduces the behaviour of trim() to remove leading and trail spaces
# Reproduced from the awesome: https://github.com/dylanaraps/pure-bash-bible
function _string_trim() {
    # Usage: trim_string "   example   string    "
    : "${1#"${1%%[![:space:]]*}"}"
    : "${_%"${_##*[![:space:]]}"}"
    printf '%s\n' "$_"
}


# Reproduces the behaviour of split()
# Reproduced from the awesome: https://github.com/dylanaraps/pure-bash-bible
function _string_split() {
   # Usage: split "string" "delimiter"
   IFS=$'\n' read -d "" -ra arr <<< "${1//$2/$'\n'}"
   printf '%s\n' "${arr[@]}"
}


# Reproduces the behaviour of lower()
# Reproduced from the awesome: https://github.com/dylanaraps/pure-bash-bible
function _string_lower() {
    # Usage: lower "string"
    printf '%s\n' "${1,,}"
}


# Reproduces the behaviour of upper()
# Reproduced from the awesome: https://github.com/dylanaraps/pure-bash-bible
function _string_upper() {
    # Usage: upper "string"
    printf '%s\n' "${1^^}"
}