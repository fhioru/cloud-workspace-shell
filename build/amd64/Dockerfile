# syntax=docker/dockerfile:1
###############################################################################
# Global ARGs for all stages of the build
###############################################################################
ARG GBL_ARCH="amd64"
ARG GBL_ARCH_FAMILY="x86_64"
ARG GBL_TZ="Etc/UTC"
ARG GBL_DEBIAN_FRONTEND="noninteractive"
ARG GBL_STAGING_ROOT="/tmp"
ARG GBL_WSH_ROOT="/opt/wsh"
ARG GBL_WSH_USER_HOME="/home/wsh"
ARG GBL_WSH_USER=wsh
ARG GBL_WSH_GROUP=wsh
ARG GBL_PUID=1000
ARG GBL_PGID=1000
ARG GBL_WSH_BUILD_VERSION=unknown
ARG GBL_LOCALE="en_US.UTF-8"

ARG GBL_CMD_PIP="uv pip"
ARG GBL_CMD_PIP_DEFAULT_ARGS="--system"

ARG GBL_HTTP_PROXY="${HTTP_PROXY}"
ARG GBL_HTTPS_PROXY="${HTTPS_PROXY}"
ARG GBL_NO_PROXY="${NO_PROXY}"

###############################################################################
# Build Container - AWS SSM
###############################################################################
FROM public.ecr.aws/docker/library/golang:1.23 AS gobuild_awsssm

# Renew ARGS from the global context
ARG GBL_ARCH
ARG GBL_ARCH_FAMILY
ARG GBL_TZ
ARG GBL_DEBIAN_FRONTEND
ARG GBL_STAGING_ROOT
ARG GBL_WSH_ROOT
ARG GBL_WSH_USER_HOME
ARG GBL_WSH_USER
ARG GBL_WSH_GROUP
ARG GBL_WSH_BUILD_VERSION
ARG GBL_LOCALE
ARG GBL_PUID
ARG GBL_PGID
ARG GBL_CMD_PIP
ARG GBL_CMD_PIP_DEFAULT_ARGS
ARG GBL_HTTP_PROXY
ARG GBL_HTTPS_PROXY
ARG GBL_NO_PROXY

ENV GOARCH=$GBL_ARCH
ENV GOOS=linux

SHELL ["/bin/bash", "-c"]

# Install of OS packages for runtime
RUN <<EOF
set -eux

# OS packages
apt-get update && \
  apt-get install -y --no-install-recommends tar gzip wget zip git make gawk grep bash && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/*

EOF

WORKDIR /src

RUN <<EOF
set -eux

# Return the latest tagged commit for the given Git repo URL
function get_latest_tag_for_repo() {
    pattern_repo_url="$1"

    # Retrieve list of tags, extract tag names, sort them, and get the latest one
    latest_tag=$(git ls-remote --tags "${pattern_repo_url}" \
        | awk '{print $2}' \
        | awk -F '/' '{print $3}' \
        | grep -v '{}' \
        | grep -v '^v' \
        | sort -V \
        | tail -1)

    echo "$latest_tag"
}


# Build our tool binary from the latest tag
pattern_repo_url="https://github.com/aws/session-manager-plugin.git"
latest_tag="$(get_latest_tag_for_repo "${pattern_repo_url}")"
git clone --quiet --depth=1 --branch="${latest_tag}" "${pattern_repo_url}" .

# Workaround for deprecation of '-i' when using 'go build'
sed -i -e "s|GO_BUILD \:\= go build \-i|GO_BUILD \:\= go build|g" makefile

echo "Building for build-${GOOS}-${GOARCH}"
make "build-${GOOS}-${GOARCH}"

EOF

# Compiled binaries can be found via:
# find bin -name session-manager-plugin -type f -exec sha1sum "{}" \; | sort


###############################################################################
# Base Container - Vanilla Toolset
###############################################################################
FROM ubuntu:24.04 AS base

# Renew ARGS from the global context
ARG GBL_ARCH
ARG GBL_ARCH_FAMILY
ARG GBL_TZ
ARG GBL_DEBIAN_FRONTEND
ARG GBL_STAGING_ROOT
ARG GBL_WSH_ROOT
ARG GBL_WSH_USER_HOME
ARG GBL_WSH_USER
ARG GBL_WSH_GROUP
ARG GBL_WSH_BUILD_VERSION
ARG GBL_LOCALE
ARG GBL_PUID
ARG GBL_PGID
ARG GBL_CMD_PIP
ARG GBL_CMD_PIP_DEFAULT_ARGS
ARG GBL_HTTP_PROXY
ARG GBL_HTTPS_PROXY
ARG GBL_NO_PROXY

ARG WSH_OS_RUNTIME_DEPS="requirements_os_runtime.txt"

ENV ARCH=$GBL_ARCH
ENV ARCH_FAMILY=$GBL_ARCH_FAMILY
ENV TZ=$GBL_TZ
ENV DEBIAN_FRONTEND=$GBL_DEBIAN_FRONTEND
ENV WSH_ROOT=$GBL_WSH_ROOT
ENV WSH_USER_HOME=$GBL_WSH_USER_HOME
ENV WSH_USER=$GBL_WSH_USER
ENV WSH_GROUP=$GBL_WSH_GROUP
ENV PUID=$GBL_PUID
ENV PGID=$GBL_PGID
ENV HTTP_PROXY=${HTTP_PROXY}
ENV http_proxy=${HTTP_PROXY}
ENV HTTPS_PROXY=${HTTPS_PROXY}
ENV https_proxy=${HTTPS_PROXY}
ENV no_proxy=${NO_PROXY}
ENV NO_PROXY=${NO_PROXY}

# Copy in requirement files
COPY "build/${WSH_OS_RUNTIME_DEPS}" "${GBL_STAGING_ROOT}/${WSH_OS_RUNTIME_DEPS}"

# Install of OS packages for runtime
RUN <<EOF
set -eux

# OS packages
apt-get update && \
  apt-get install -y --no-install-recommends $(cat "${GBL_STAGING_ROOT}/${WSH_OS_RUNTIME_DEPS}" | egrep -v "^\s*(#|$)") && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/*

# Ensure the default locale is generated
locale-gen "${GBL_LOCALE}"

# PEP-668 (https://peps.python.org/pep-0668/) is not required in this case as the entire OS is
# our application and we intentionally want to modify the default system packages if needed by
# an installed software artifact
[ -e "/usr/lib/python3.12/EXTERNALLY-MANAGED" ] && rm -fv "/usr/lib/python3.12/EXTERNALLY-MANAGED"

# Install our Python package manager
wget -q https://github.com/astral-sh/uv/releases/latest/download/uv-${GBL_ARCH_FAMILY}-unknown-linux-gnu.tar.gz -O "${GBL_STAGING_ROOT}/uv-${GBL_ARCH_FAMILY}-unknown-linux-gnu.tar.gz" && \
  tar -zxvf "${GBL_STAGING_ROOT}/uv-${GBL_ARCH_FAMILY}-unknown-linux-gnu.tar.gz" -C /usr/local/bin --strip-components 1 && \
  uv generate-shell-completion bash > /etc/bash_completion.d/uv

# Update the default Ubuntu user and group
groupmod --new-name ${WSH_GROUP} ubuntu
usermod --move-home --home ${WSH_USER_HOME} --login ${WSH_USER} -a -G sudo ubuntu

# Add support for running Docker as a sidecar
groupadd docker
usermod -a -G docker ${WSH_USER}

# Add sudo permissions to allow the WSH user to make changes if needed inside the container
echo "${WSH_USER} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
EOF


###############################################################################
# Runtime layers with 3rd party software
###############################################################################
FROM base AS runtime

# Renew ARGS from the global context
ARG GBL_ARCH
ARG GBL_ARCH_FAMILY
ARG GBL_TZ
ARG GBL_DEBIAN_FRONTEND
ARG GBL_STAGING_ROOT
ARG GBL_WSH_ROOT
ARG GBL_WSH_USER_HOME
ARG GBL_WSH_USER
ARG GBL_WSH_GROUP
ARG GBL_WSH_BUILD_VERSION
ARG GBL_LOCALE
ARG GBL_PUID
ARG GBL_PGID
ARG GBL_CMD_PIP`
ARG GBL_CMD_PIP_DEFAULT_ARGS
ARG GBL_HTTP_PROXY
ARG GBL_HTTPS_PROXY
ARG GBL_NO_PROXY

ARG WSH_PYTHON_RUNTIME_DEPS="pyproject.toml"

ARG SW_VER_FIXUID="0.6.0"
ARG SW_VER_STARSHIP="1.21.1"
ARG SW_VER_SSOTOOL="1.17.0"
ARG SW_VER_DELTA="0.18.0"
ARG SW_VER_GLOW="1.5.1"
ARG SW_VER_TENV="4.4.0"
ARG SW_VER_TERRAFORM="1.5.7"
ARG SW_VER_OPENTOFU="1.9.0"
ARG SW_VER_TFLINT="0.56.0"
ARG SW_VER_PACKER="1.9.5"
ARG SW_VER_TERRAGRUNT="v0.69.1"
ARG SW_VER_INFRACOST="v0.10.37"
ARG SW_VER_DRIFTCTL="v0.40.0"
ARG SW_VER_TERRAFORMDOCS="0.19.0"
ARG SW_VER_TFSEC="1.28.11"
ARG SW_VER_TERRASCAN="1.19.9"
ARG SW_VER_FZF="0.56.3"
# curl -L -s https://dl.k8s.io/release/stable.txt
ARG SW_VER_KUBECTL="v1.31.1"
ARG SW_VER_CURLIE="1.8.2"
ARG SW_VER_OPENCODE="0.0.55"

ENV ARCH=$GBL_ARCH
ENV ARCH_FAMILY=$GBL_ARCH_FAMILY
ENV TZ=$GBL_TZ
ENV DEBIAN_FRONTEND=$GBL_DEBIAN_FRONTEND
ENV LANG=$GBL_LOCALE
ENV WSH_ROOT=$GBL_WSH_ROOT
ENV WSH_USER_HOME=$GBL_WSH_USER_HOME
ENV WSH_USER=$GBL_WSH_USER
ENV WSH_GROUP=$GBL_WSH_GROUP
ENV PUID=$GBL_PUID
ENV PGID=$GBL_PGID
ENV HTTP_PROXY=${HTTP_PROXY}
ENV http_proxy=${HTTP_PROXY}
ENV HTTPS_PROXY=${HTTPS_PROXY}
ENV https_proxy=${HTTPS_PROXY}
ENV no_proxy=${NO_PROXY}
ENV NO_PROXY=${NO_PROXY}
ENV TENV_ROOT=${GBL_WSH_USER_HOME}/.tenv

# Copy in requirement and helper files
COPY build/${WSH_PYTHON_RUNTIME_DEPS} build/${ARCH}/build-helper-3rdparty-installer.sh ${GBL_STAGING_ROOT}/

# Copy in binary tools compiled at other stages
COPY --chown=${WSH_USER}:${WSH_GROUP} --from=gobuild_awsssm "/src/bin/linux_${ARCH}_plugin/session-manager-plugin" /usr/local/bin/

# Add the Terraform CLI config and ensure the cache dir exists
COPY --chown=${WSH_USER}:${WSH_GROUP} wsh/lib/docker/terraformrc "${GBL_WSH_USER_HOME}/.terraformrc"

# A layer just for Python additions
RUN <<EOF
set -eux

# PEP-668 (https://peps.python.org/pep-0668/) is not required in this case as the entire OS is
# our application and we intentionally want to modify the default packages if needed by
# an installed software artifact
[ -e "/usr/lib/python3.12/EXTERNALLY-MANAGED" ] && rm -fv "/usr/lib/python3.12/EXTERNALLY-MANAGED"

# Python dependencies
uv --no-cache pip install --system --requirements "${GBL_STAGING_ROOT}/${WSH_PYTHON_RUNTIME_DEPS}"
uv cache clean

# BASH completion for the awscli
mkdir -p /etc/bash_completion.d
cp /usr/local/bin/aws_bash_completer /etc/bash_completion.d/

# Workaround for https://github.com/aws/aws-cli/issues/8547 to trigger compile cache for the AWS CLI
aws --version
EOF

# A layer just for 3rd party tools
RUN <<EOF
set -eux

# Call the GitHub install helper to install our 3rd party tools
bash "${GBL_STAGING_ROOT}/build-helper-3rdparty-installer.sh" "${GBL_STAGING_ROOT}"

# Configuration for fixuid
mkdir -p /etc/fixuid
# Build the config for fixuid
echo "user: ${GBL_WSH_USER}" | tee -a /etc/fixuid/config.yml
echo "group: ${GBL_WSH_GROUP}" | tee -a /etc/fixuid/config.yml

chown root:root /usr/local/bin/fixuid
chmod 4755 /usr/local/bin/fixuid

# Configuration of batcat
ln -s /usr/bin/batcat /usr/bin/bat

# Configuration for terraform
mkdir -p "${GBL_WSH_USER_HOME}/.terraform.d/plugin-cache"

# Configuration for TENV our TACOS tool manager
tenv terraform install ${SW_VER_TERRAFORM}
tenv tofu install ${SW_VER_OPENTOFU}
tenv tg install ${SW_VER_TERRAGRUNT}
tenv completion bash > /etc/bash_completion.d/tenv.completion.bash

EOF


###############################################################################
# Main Docker image assembly for WSH
###############################################################################

FROM runtime AS cloudshell

# Renew ARGS from the global context
ARG GBL_ARCH
ARG GBL_TZ
ARG GBL_DEBIAN_FRONTEND
ARG GBL_STAGING_ROOT
ARG GBL_WSH_ROOT
ARG GBL_WSH_USER_HOME
ARG GBL_WSH_USER
ARG GBL_WSH_GROUP
ARG GBL_WSH_BUILD_VERSION
ARG GBL_PUID
ARG GBL_PGID
ARG GBL_CMD_PIP
ARG GBL_CMD_PIP_DEFAULT_ARGS
ARG GBL_HTTP_PROXY
ARG GBL_HTTPS_PROXY
ARG GBL_NO_PROXY

ENV ARCH=$GBL_ARCH
ENV ARCH_FAMILY=$GBL_ARCH_FAMILY
ENV TZ=$GBL_TZ
ENV DEBIAN_FRONTEND=$GBL_DEBIAN_FRONTEND
ENV WSH_ROOT=$GBL_WSH_ROOT
ENV WSH_USER_HOME=$GBL_WSH_USER_HOME
ENV WSH_USER=$GBL_WSH_USER
ENV WSH_GROUP=$GBL_WSH_GROUP
ENV PUID=$GBL_PUID
ENV PGID=$GBL_PGID
ENV HTTP_PROXY=${HTTP_PROXY}
ENV http_proxy=${HTTP_PROXY}
ENV HTTPS_PROXY=${HTTPS_PROXY}
ENV https_proxy=${HTTPS_PROXY}
ENV no_proxy=${NO_PROXY}
ENV NO_PROXY=${NO_PROXY}


ENV PYTHONPATH=${WSH_ROOT}/lib/python
ENV PATH="${WSH_ROOT}/bin:${WSH_ROOT}/bin/tools:${PATH}:${WSH_USER_HOME}/bin:${WSH_USER_HOME}/.tfenv/bin"
ENV PATCHED_FONT_IN_USE=no
ENV WSH_VERSION="${GBL_WSH_BUILD_VERSION}"

ENV DEFAULT_TERRAFORM_VERSION=${SW_VER_TERRAFORM}
ENV DEFAULT_OPENTOFU_VERSION=${SW_VER_OPENTOFU}

# Infracost token injection
ENV INFRACOST_API_KEY=${INFRACOST_API_KEY}

# SSO Tool: default to looking inside the .wsh path
ENV AWS_SSO_CONFIG="${WSH_USER_HOME}/.wsh/aws-sso-config.yml"

# FZF: Preview file content using bat (https://github.com/sharkdp/bat)
ENV FZF_CTRL_T_OPTS="\
  --height 40%\
  --walker-skip .git,node_modules,target\
  --preview 'bat --color=always\
  --style=numbers\
  --line-range=:500 {}'\
"
ENV FZF_DEFAULT_OPTS="\
  --height 40% --tmux bottom,40% --layout reverse --border top\
  --color=fg:#d0d0d0,fg+:#d0d0d0,bg:#121212,bg+:#262626\
  --color=hl:#5f87af,hl+:#5fd7ff,info:#afaf87,marker:#87ff00\
  --color=prompt:#d7005f,spinner:#af5fff,pointer:#af5fff,header:#87afaf\
  --color=border:#262626,label:#aeaeae,query:#d9d9d9\
  --border="rounded" --border-label='' --preview-window='border-rounded' --prompt='> '\
  --marker='>' --pointer='◆' --separator='─' --scrollbar='│'\
"

# Add all of our own utilities
COPY --chown=${GBL_PUID}:${GBL_PGID} wsh/ ${GBL_WSH_ROOT}

RUN <<EOF
set -eux

# Silence any default banner noise
touch "${GBL_WSH_USER_HOME}/.hushlogin"

# WSH and AWS CLI paths
mkdir -p \
  ${GBL_WSH_USER_HOME}/.wsh/log \
  ${GBL_WSH_USER_HOME}/.aws

# Link the JQ module library
ln -s ${GBL_WSH_ROOT}/lib/jq ${GBL_WSH_USER_HOME}/.jq

# Create a dummy AWS CLI config so that it doesnt have a brain fart when
# run due to not setting its own sensible defaults
cat ${GBL_WSH_ROOT}/lib/awscli/config >> ${GBL_WSH_USER_HOME}/.aws/config
cat ${GBL_WSH_ROOT}/lib/awscli/config >> ${GBL_WSH_USER_HOME}/.aws/credentials

# Ensure the WSH lib is being loaded into the shell
cat ${GBL_WSH_ROOT}/lib/wsh/.bashrc >> ${GBL_WSH_USER_HOME}/.bashrc

# Ensure ownership of WSH paths
chown -c -R ${GBL_PUID}:${GBL_PGID} ${GBL_WSH_ROOT}
chown -c -R ${GBL_PUID}:${GBL_PGID} ${GBL_WSH_USER_HOME}
EOF

WORKDIR ${GBL_WSH_USER_HOME}
USER wsh

RUN <<EOF
set -eux

# Config and setup of terrascan
terrascan init -l debug

EOF

ENTRYPOINT ["/opt/wsh/lib/docker/entrypoint.sh"]

CMD ["/bin/bash", "-i"]

