# Workspace Shell (WSH) for TACOS 🌮

## What is WSH?

WSH is a collection of libraries, tools and utility scripts aimed at improving the experience for
users that need to work with TACOS (TF Automation and Collaboration Software) to develop, build and operate
workloads on AWS (for now).

WSH can be used as;
- As a CLI to normal AWS work
- As a container based image from which to run CI/CD or TACOS tasks
- As a base layer on which to build AWS applications and services
- As a Lambda layer from which to build and run serverless functions


## Getting Started

### Have a look around

If you just want to try it out and have a look around it's as simple as running the Docker container.

```bash
docker run -it --rm ghcr.io/fhioru/wsh:latest
```

### Add your own preferences, credentials and identity

Start the container with access to useful data that holds your preferences, credentials and identity

```bash
# Init to handle first run and mitigate issues with Docker creating files as directories or
# creating either with root ownership
[ -d "${HOME}/.wsh" ] || mkdir -p "${HOME}/.wsh"
[ -d "${HOME}/workspace" ] || mkdir -p "${HOME}/workspace"
[ -d "${HOME}/.ssh" ] || mkdir -p "${HOME}/.ssh"
# Files
[ -f "${HOME}/.gitconfig" ] || touch "${HOME}/.gitconfig"
[ -f "${HOME}/.netrc" ] || touch "${HOME}/.netrc"
[ -f "${HOME}/.terraformrc" ] || touch "${HOME}/.terraformrc"
[ -f "${HOME}/.tofurc" ] || touch "${HOME}/.tofurc"

docker run \
    -it \
    --rm \
    --network=host \
    --user "$(id -u):$(id -g)" \
    -v "${HOME}/.wsh:/home/wsh/.wsh" \
    -v "${HOME}/.ssh:/home/wsh/.ssh" \
    -v "${HOME}/workspace:/home/wsh/workspace" \
    -v "${HOME}/.gitconfig:/home/wsh/.gitconfig" \
    -v "${HOME}/.terraformrc:/home/wsh/.terraformrc" \
    -v "${HOME}/.netrc:/home/wsh/.netrc" \
    -v "${HOME}/.bashrc_wsh:/home/wsh/.bashrc_local" \
    -e "PUID=$(id -u)" \
    -e "PGID=$(id -g)" \
    -e "http_proxy=${http_proxy}" \
    -e "https_proxy=${https_proxy}" \
    -e "no_proxy=${no_proxy}" \
    -e "KRB5CCNAME=${KRB5CCNAME}" \
    ghcr.io/fhioru/wsh:latest
```

### Regular use

For everyday or regular use we recommend creating a wrapper script that will ensure that all of the important preferences, credentials and identity is passed through to WSH.

This makes it easy to combine WSH with your exsting IDE (ie. VSCode) to create an improved experience with working with AWS.

Create the `wsh` wrapper that defaults to using the latest image, ensuring that it is both executable (`chmod 755 wsh`) and available from your `PATH`

```bash
#!/bin/bash

PUID=$(id -u)
PGID=$(id -g)

_DEFAULT_IMAGE='ghcr.io/fhioru/wsh:latest'
WSH_INSTANCE_IMAGE="${1:-$_DEFAULT_IMAGE}"
WSH_INSTANCE_TMP="$(mktemp -d)"

function _init() {
  # Init to handle first run and mitigate issues with Docker creating files as directories or
  # creating either with root ownership
  [ -d "${HOME}/.wsh" ] || mkdir -p "${HOME}/.wsh"
  [ -d "${HOME}/workspace" ] || mkdir -p "${HOME}/workspace"
  [ -d "${HOME}/.ssh" ] || mkdir -p "${HOME}/.ssh"

  # Files
  [ -f "${HOME}/.gitconfig" ] || touch "${HOME}/.gitconfig"
  [ -f "${HOME}/.netrc" ] || touch "${HOME}/.netrc"
  [ -f "${HOME}/.terraformrc" ] || touch "${HOME}/.terraformrc"
  [ -f "${HOME}/.tofurc" ] || touch "${HOME}/.tofurc"

  # Build a dynamic snippet that will `cd` into the relative path once inside the WSH container
  REL_WORKING_DIR=$(pwd | sed -e "s|${HOME}|/home/wsh|g")
  [ -f "${HOME}/.bashrc_wsh" ] && rm -f "${HOME}/.bashrc_wsh"
  cat > "${HOME}/.bashrc_wsh" <<EOF
  [ -d '${REL_WORKING_DIR}' ] && cd '${REL_WORKING_DIR}'
EOF

  [ -d ${WSH_INSTANCE_TMP} ] || mkdir -p "${WSH_INSTANCE_TMP}"

}

_init

docker run \
    -it \
    --rm \
    --network=host \
    --user "${PUID}:${PGID}" \
    -v "${HOME}/.wsh:/home/wsh/.wsh" \
    -v "${HOME}/.ssh:/home/wsh/.ssh" \
    -v "${HOME}/workspace:/home/wsh/workspace" \
    -v "${HOME}/.gitconfig:/home/wsh/.gitconfig" \
    -v "${HOME}/.terraformrc:/home/wsh/.terraformrc" \
    -v "${HOME}/.netrc:/home/wsh/.netrc" \
    -v "${HOME}/.bashrc_wsh:/home/wsh/.bashrc_local" \
    -v "${WSH_INSTANCE_TMP}:/tmp" \
    -e "HOME=/home/wsh" \
    -e "PUID=${PUID}" \
    -e "PGID=${PGID}" \
    -e "http_proxy=${http_proxy}" \
    -e "https_proxy=${https_proxy}" \
    -e "no_proxy=${no_proxy}" \
    -e "KRB5CCNAME=${KRB5CCNAME}" \
    "${WSH_INSTANCE_IMAGE}"
```

Now you can start the shell with a simple

```bash
wsh
```

If you want to run a specific version or tag, just pass it when starting WSH

```bash
wsh ghcr.io/fhioru/wsh:v1.4.0
```


## Documentation

*In the works*



## FAQ


### Why is the WSH image so large?

Within the container image are recent versions of many common utilities used in combination with AWS
from the TACOS ecosystem. All we've done is bundle the hard work of many other great contributors to
improve the user experience. These include;

- AWS-CLI [https://github.com/aws/aws-cli](https://github.com/aws/aws-cli)
- AWS-SSO [https://github.com/synfinatic/aws-sso-cli](https://github.com/synfinatic/aws-sso-cli)
- Delta [https://github.com/dandavison/delta](https://github.com/dandavison/delta)
- Driftctl [https://github.com/snyk/driftctl](https://github.com/snyk/driftctl)
- Fixuid [https://github.com/boxboat/fixuid](https://github.com/boxboat/fixuid)
- Fzf [https://github.com/junegunn/fzf](https://github.com/junegunn/fzf)
- Glow [https://github.com/charmbracelet/glow](https://github.com/charmbracelet/glow)
- Infracost [https://github.com/infracost/infracost](https://github.com/infracost/infracost)
- OpenTofu [https://github.com/opentofu/opentofu](https://github.com/opentofu/opentofu)
- Packer [https://releases.hashicorp.com/packer](https://releases.hashicorp.com/packer) (locked at last OpenSource version)
- Starship [https://github.com/starship/starship](https://github.com/starship/starship)
- Terraform [https://releases.hashicorp.com/terraform](https://releases.hashicorp.com/terraform) (locked at last OpenSource version)
- Terraform-docs [https://github.com/terraform-docs](https://github.com/terraform-docs)
- Terragrunt [https://github.com/gruntwork-io](https://github.com/gruntwork-io)
- Terrascan [https://github.com/tenable/terrascan](https://github.com/tenable/terrascan)
- Tflint [https://github.com/terraform-linters](https://github.com/terraform-linters)
- Tfsec [https://github.com/aquasecurity/tfsec](https://github.com/aquasecurity/tfsec)
- Tenv [https://github.com/tofuutils/tenv](https://github.com/tofuutils/tenv)
- Kubectl [https://kubernetes.io/docs/reference/kubectl/](https://kubernetes.io/docs/reference/kubectl/)
- Krew [https://github.com/kubernetes-sigs/krew](https://github.com/kubernetes-sigs/krew)

Due to the many of these tools being written in Go and it's nature of creating "batteries included" artifacts that bundle all of the dependencies into standalone binaries this adds a whopping 1.5GB to the image size!


### Why is the version of the AWS-CLI bundled v2.x?

- The team that provide the AWS CLI decided that most people would encounter problems when trying to get started via what is the norm for a v1 install (`python -m pip install awscli`). The variety of different versions of both Python and libraries made supporting and troubleshooting the v1 CLI difficult.
- For the v2 CLI they decided instead to follow what is now the community norm of providing a single binary that contains all of it's dependencies and gives them a known stack to develop and support.
- This "batteries included" artifact includes SSL and Python3 which in turn creates issues for any other tools that require similar dependencies (Python3, Botocode, Boto3). While this is great from a support perspective (for AWS) it does mean that the versions of important (Python) dependencies can be different to those used by the rest of the software in the container.
- Due to the number of [breaking changes](https://docs.aws.amazon.com/cli/latest/userguide/cliv2-migration-changes.html) in the v2 CLI and its embedded Python 3.11, our container will continue to build a v2 CLI that works within the installed Python 3.x environment in WSH
- If you are interested in understanding more about this topic, the AWS CLI GitHub is [littered](https://github.com/aws/aws-cli/issues?q=is%3Aissue+v2++build) with issues highlighting the impact of downstream projects that build and depend on the AWS CLI


### What is WSH's connection to AWSH and BLOX?

WSH is a derivative fork of [hestio/awsh](https://github.com/hest-io/awsh) and [hestio/blox](https://github.com/hest-io/blox), rebased
(@commit: https://github.com/hest-io/blox/commit/e82664a611b7a8570b3070283e936290ac941161) to Ubuntu Linux and available for
amd64 and (soon) arm64 based environments as a containerized image.


### How I get started  with contributing?

- Get a copy of `uv` for your operating system from [https://docs.astral.sh/uv/](https://docs.astral.sh/uv/)
- Clone this repo

```
git clone https://github.com/fhioru/cloud-workspace-shell.git
cd cloud-workspace-shell
```

- Install the Python dependencies

```
uv venv --no-project .venv
uv pip install --requirements build/pyproject.toml
```

- Open your favourite IDE and set it's Python path to the Virtualenv you just created
