# Load the global WSH rc
. /opt/wsh/etc/wshrc

# Load FZF completion support
# eval "$(fzf --bash)"

# Load the optional user rc
[ -f ${HOME}/.bashrc_local ] && . ${HOME}/.bashrc_local