#!/usr/bin/env bash

# UID/GID (may) map to unknown user/group, $HOME=/ (the default when no home directory is defined)
eval $( fixuid -q )
# UID/GID now match user/group, $HOME has been set to user's home directory

# Starship setup
[ -d "${HOME}/.config" ] || mkdir -p "${HOME}/.config"
[ -f "${HOME}/.config/starship.toml" ] || ln -s /opt/wsh/lib/starship/starship.toml "${HOME}/.config/starship.toml"

# Ensure the designated default versions of terraform and tofu are active as a workaround for
# GitLab CICD issues where entrypoint is run for each stage when using container based builds
tenv -q tofu use "${DEFAULT_OPENTOFU_VERSION}"
tenv -q tf use "${DEFAULT_TERRAFORM_VERSION}"

# On with the show
exec "$@"