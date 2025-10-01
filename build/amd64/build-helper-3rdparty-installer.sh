#!/usr/bin/env bash
#
# Simple utility script to download and extract artifacts from GitHub
#

##############################################################################
# Shell Behaviour
##############################################################################

# Check for unbound variables being used
set -o nounset

# Exit is a bad command is attempted. If you're going to handle errors then
# leave this disabled
set -o errexit

# Exit if any of the commands in a pipeline exit with a non-zero exit code
# set -o pipefail

STAGING_ROOT="$1"

[ -d "${STAGING_ROOT}/stage" ] || mkdir -p "${STAGING_ROOT}/stage"
[ -d "${STAGING_ROOT}/install" ] || mkdir -p "${STAGING_ROOT}/install"
[ -d "${STAGING_ROOT}/installers" ] || mkdir -p "${STAGING_ROOT}/installers"

# Return the latest tagged commit for the given Git repo URL
function __get_latest_tag_for_repo() {
    local pattern_repo_url="$1"
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

# Download the artifact at the specificed URL to an optional path
function __util_download {
  local url="$1"
  local download_path="${2:-$STAGING_ROOT/install}"
  [ -d "${download_path}" ] || mkdir -p "${download_path}"
  echo "Downloading to ${download_path}/$(basename "${url}")"
  curl -SsL "${url}" -o "${download_path}/$(basename "${url}")"
}

# Archive based downloads
__util_download "https://github.com/aquasecurity/tfsec/releases/download/v${SW_VER_TFSEC}/tfsec_${SW_VER_TFSEC}_linux_${ARCH}.tar.gz"
__util_download "https://github.com/boxboat/fixuid/releases/download/v${SW_VER_FIXUID}/fixuid-${SW_VER_FIXUID}-linux-${ARCH}.tar.gz"
__util_download "https://github.com/charmbracelet/glow/releases/download/v${SW_VER_GLOW}/glow_Linux_${ARCH_FAMILY}.tar.gz"
__util_download "https://github.com/dandavison/delta/releases/download/${SW_VER_DELTA}/delta-${SW_VER_DELTA}-${ARCH_FAMILY}-unknown-linux-gnu.tar.gz"
__util_download "https://github.com/infracost/infracost/releases/download/${SW_VER_INFRACOST}/infracost-linux-${ARCH}.tar.gz"
__util_download "https://github.com/junegunn/fzf/releases/download/v${SW_VER_FZF}/fzf-${SW_VER_FZF}-linux_${ARCH}.tar.gz"
__util_download "https://github.com/starship/starship/releases/download/v${SW_VER_STARSHIP}/starship-${ARCH_FAMILY}-unknown-linux-gnu.tar.gz"
__util_download "https://github.com/tenable/terrascan/releases/download/v${SW_VER_TERRASCAN}/terrascan_${SW_VER_TERRASCAN}_Linux_${ARCH_FAMILY}.tar.gz"
__util_download "https://github.com/terraform-docs/terraform-docs/releases/download/v${SW_VER_TERRAFORMDOCS}/terraform-docs-v${SW_VER_TERRAFORMDOCS}-linux-${ARCH}.tar.gz"
__util_download "https://github.com/terraform-linters/tflint/releases/download/v${SW_VER_TFLINT}/tflint_linux_${ARCH}.zip"
__util_download "https://github.com/tofuutils/tenv/releases/download/v${SW_VER_TENV}/tenv_v${SW_VER_TENV}_linux_${ARCH_FAMILY}.tar.gz"
__util_download "https://releases.hashicorp.com/packer/${SW_VER_PACKER}/packer_${SW_VER_PACKER}_linux_${ARCH}.zip"
__util_download "https://github.com/rs/curlie/releases/download/v${SW_VER_CURLIE}/curlie_${SW_VER_CURLIE}_linux_${ARCH}.tar.gz"
__util_download "https://github.com/opencode-ai/opencode/releases/download/v${SW_VER_OPENCODE}/opencode-linux-${ARCH_FAMILY}.tar.gz"

# Binary only downloads
__util_download "https://github.com/snyk/driftctl/releases/download/${SW_VER_DRIFTCTL}/driftctl_linux_${ARCH}" "${STAGING_ROOT}/stage"
__util_download "https://github.com/synfinatic/aws-sso-cli/releases/download/v${SW_VER_SSOTOOL}/aws-sso-${SW_VER_SSOTOOL}-linux-${ARCH}" "${STAGING_ROOT}/stage"
# Add Kubernetes CLI tooling
__util_download "https://dl.k8s.io/release/${SW_VER_KUBECTL}/bin/linux/${ARCH}/kubectl" "${STAGING_ROOT}/stage"
__util_download "https://github.com/derailed/k9s/releases/download/v${SW_VER_K9S}/k9s_Linux_${ARCH}.tar.gz"
__util_download "https://github.com/kubernetes-sigs/krew/releases/download/v${SW_VER_K8S_PLUGIN_KREW}/krew-linux_${ARCH}.tar.gz" "${STAGING_ROOT}/installers"
__util_download "https://get.helm.sh/helm-v${SW_VER_HELM}-linux-${ARCH}.tar.gz"

# Ensure that filename globbing patterns that don't match any filenames are simply expanded to nothing rather than remaining unexpanded.
shopt -s nullglob

# Extract installers
for archive in "${STAGING_ROOT}"/installers/*.tar.gz; do
  tar -xvf "$archive" -C "${STAGING_ROOT}/installers/"
done

# Extract zip installers, handling case where no files match the pattern
for archive in "${STAGING_ROOT}"/installers/*.zip; do
  unzip -o "$archive" -d "${STAGING_ROOT}/installers/"
done

# Extract archives
for archive in "${STAGING_ROOT}"/install/*.tar.gz; do
  tar -xvf "$archive" -C "${STAGING_ROOT}/stage/"
done

for archive in "${STAGING_ROOT}"/install/*.zip; do
  unzip -o "$archive" -d "${STAGING_ROOT}/stage/"
done

shopt -u nullglob

# Find and relocate executables
find "${STAGING_ROOT}/stage/" -type f | while read entry; do
  echo "Checking ${entry}"
  if [[ $(file -b "$entry" | grep executable) != "" ]]; then
    full_bin_name="$(basename "$entry")"
    short_bin_name=${full_bin_name%%-[0-9]*}    # remove the first hyphen followed by a digit and everything after
    short_bin_name=${short_bin_name%%_[0-9]*}   # remove the first underscore followed by a digit and everything after
    short_bin_name=${short_bin_name%%_linux_amd64*}  # remove trailing artifact naming from GitHub build system
    short_bin_name=${short_bin_name%%-linux-amd64*}  # remove trailing artifact naming from GitHub build system
    echo "Relocating executable ${full_bin_name} to /usr/local/bin/${short_bin_name}"
    mv -v "$entry" "/usr/local/bin/${short_bin_name}"
    chmod 755 "/usr/local/bin/${short_bin_name}"
  fi
done

# Cleanup
echo "Cleaning up ${STAGING_ROOT}/stage, ${STAGING_ROOT}/install"
rm -Rf "${STAGING_ROOT}/stage" "${STAGING_ROOT}/install"
