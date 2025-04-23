#!/usr/bin/env bash
# Intended to perform all tasks that need to be executed on a first run of the
# tools

function _firstrun {

    echo ""
    echo "WSH: Welcome!"
    echo ""
    echo "  Documentation   : https://fhioru.github.io"
    echo "  Found an issue? : https://github.com/fhioru/wsh/issues"

    mkdir -p ~/.wsh/config.d/
    touch ~/.wsh/config.d/.firstrun

}

# Create a tmp dir if none exists
if [[ ! -d "${WSH_ROOT}/tmp" ]]; then
    mkdir -p "${WSH_ROOT}/tmp"
fi

# Create a log dir if none exists
if [[ ! -d "${HOME}/.wsh/log" ]]; then
    mkdir -p "${HOME}/.wsh/log"
fi

# Create an user identities dir if none exists
if [[ ! -d ~/.wsh/identities ]]; then
    mkdir -p ~/.wsh/identities
fi

# First Run helper if no config file is found
if [[ ! -f ~/.wsh/config.d/.firstrun ]]; then
    _firstrun
fi

