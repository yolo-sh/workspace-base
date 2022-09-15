# Workspace / Base

This repository contains the source code of the Docker image named `ghcr.io/yolo-sh/workspace-base`. 

This image is the base image that powers all the environments created via the [CLI](https://github.com/yolo-sh/cli).

## Table of contents
- [Requirements](#requirements)
- [Build](#build)
- [Image](#image)
  - [Init service](#init-service)
- [License](#license)

## Requirements

- `Docker`

## Build

In this repository root directory, run:

```bash
docker build -t yolo-base-workspace-image .
```

## Image

The Dockerfile has been extensively commented to be self-explanatory. You can see it below.

In summary, Yolo is built on `ubuntu 22.04` with `systemd` installed and an user named `yolo` configured as the default user. Root privileges are managed via `sudo` and `zsh` (with `oh-my-zsh`) is used as default shell.

Your repositories will be cloned in `/home/yolo/workspace`.

```Dockerfile
# All environments will be Ubuntu-based (Ubuntu 22.04)
FROM buildpack-deps:jammy

LABEL org.opencontainers.image.source=https://github.com/yolo-sh/workspace-base
LABEL org.opencontainers.image.description="The Docker image that powers all the environments created via the Yolo CLI"

ARG DEBIAN_FRONTEND=noninteractive

# RUN will use bash
SHELL ["/bin/bash", "-c"]

# We want a "standard Ubuntu"
# (i.e. not one that has been minimized
# by removing packages and content
# not required in a production system)
RUN yes | unminimize

# Install system dependencies
RUN set -euo pipefail \
  && apt-get --assume-yes --quiet --quiet update \
  && apt-get --assume-yes --quiet --quiet install \
    apt-transport-https \
    build-essential \
    ca-certificates \
    curl \
    dbus \
    git \
    gnupg \
    iproute2 \
    iptables \
    kmod \
    less \
    libsystemd0 \
    locales \
    lsb-release \
    man-db \
    manpages-posix \
    nano \
    socat \
    software-properties-common \
    sudo \
    systemd \
    systemd-sysv \
    tzdata \
    udev \
    unzip \
    vim \
    wget \
  && apt-get clean && rm --recursive --force /var/lib/apt/lists/* /tmp/* \
  && echo "ReadKMsg=no" >> /etc/systemd/journald.conf

# Mask unused services
RUN systemctl mask systemd-udevd.service \
  systemd-udevd-kernel.socket \
  systemd-udevd-control.socket \
  systemd-modules-load.service \
  sys-kernel-debug.mount \
  sys-kernel-tracing.mount

# Make use of stopsignal (instead of sigterm) 
# to stop systemd containers
STOPSIGNAL SIGRTMIN+3

# Install init service in systemd
COPY ./init/init.sh /usr/bin/yolo-init.sh
COPY ./init/init.service /lib/systemd/system/yolo-init-script.service
RUN chmod +x /usr/bin/yolo-init.sh \
  && ln -sf /lib/systemd/system/yolo-init-script.service /etc/systemd/system/multi-user.target.wants/yolo-init-script.service

# Set default timezone
ENV TZ=America/Los_Angeles

# Set default locale.
# /!\ locale-gen must be run as root.
RUN set -euo pipefail \
  && locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Configure the user "yolo" in container.
# 
# We want the user "yolo" inside the container to get 
# the same group than the user "yolo" in the instance 
# (to share files through the /yolo-config mount).
# 
# To do this, the two users need to share the same GID.
ENV USER=yolo
ENV GROUP=yolo
ENV HOME=/home/$USER
ENV EDITOR=/usr/bin/nano
ENV YOLO_WORKSPACE=$HOME/workspace
RUN set -euo pipefail \
  && YOLO_CONFIG_DIR="/yolo-config" \
  && YOLO_WORKSPACE_CONFIG_DIR="${YOLO_CONFIG_DIR}/workspace" \
  && groupadd --gid 10000 --non-unique --force "${GROUP}" \
  && useradd --gid "${GROUP}" --home "${HOME}" --create-home --shell /bin/bash "${USER}" \
  && cp /etc/sudoers /etc/sudoers.orig \
  && echo "${USER} ALL=(ALL) NOPASSWD:ALL" | tee "/etc/sudoers.d/${USER}" > /dev/null \
  && mkdir --parents "${YOLO_CONFIG_DIR}" \
  && mkdir --parents "${YOLO_WORKSPACE_CONFIG_DIR}" \
  && mkdir --parents "${YOLO_WORKSPACE}" \
  && mkdir --parents "${HOME}/.ssh" \
  && mkdir --parents "${HOME}/.gnupg" \
  && mkdir --parents "${HOME}/.vscode-server" \
  && chown --recursive "${USER}:${GROUP}" "${HOME}" \
  && chown --recursive "${USER}:${GROUP}" "${YOLO_CONFIG_DIR}" \
  && chmod 700 "${HOME}/.gnupg"

USER $USER
WORKDIR $HOME

# Install ZSH
RUN set -euo pipefail \
  && sudo apt-get --assume-yes --quiet --quiet update \
  && sudo apt-get --assume-yes --quiet --quiet install zsh \
  && sudo apt-get clean && sudo rm --recursive --force /var/lib/apt/lists/* /tmp/* \
  && mkdir .zfunc

# Install OhMyZSH and some plugins
RUN set -euo pipefail \
  && sh -c "$(curl --fail --silent --show-error --location https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
  && git clone --quiet https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions \
  && git clone --quiet https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

# Change default shell for current user
RUN set -euo pipefail \
  && sudo usermod --shell $(which zsh) "${USER}"

# Add a command "code" to ZSH.
# This command lets you open a file in VSCode 
# while being connected to an environment via SSH.
COPY --chown=$USER:$USER ./zsh/code_fn.zsh .zfunc/code

# Add .zshrc to home folder
COPY --chown=$USER:$USER ./zsh/.zshrc .

WORKDIR $YOLO_WORKSPACE
```

### Init service

The init service is a `bash` script named `init.sh` that will be run once during container initialization:

```bash
#!/bin/bash
# 
# Yolo environment container init script.
set -euo pipefail

log () {
  echo -e "${1}" >&2
}

# -- System configuration

# Lookup instance architecture for the yolo container agent
INSTANCE_ARCH=""
case $(uname -m) in
  i386)       INSTANCE_ARCH="386" ;;
  i686)       INSTANCE_ARCH="386" ;;
  x86_64)     INSTANCE_ARCH="amd64" ;;
  arm)        dpkg --print-architecture | grep -q "arm64" && INSTANCE_ARCH="arm64" || INSTANCE_ARCH="armv6" ;;
  aarch64_be) INSTANCE_ARCH="arm64" ;;
  aarch64)    INSTANCE_ARCH="arm64" ;;
  armv8b)     INSTANCE_ARCH="arm64" ;;
  armv8l)     INSTANCE_ARCH="arm64" ;;
esac

# -- Install the yolo container agent

log "Installing the yolo container agent"

YOLO_AGENT_VERSION="0.0.1"
YOLO_AGENT_TMP_ARCHIVE_PATH="/tmp/yolo-agent-container.tar.gz"
YOLO_AGENT_NAME="yolo-agent-container"
YOLO_AGENT_DIR="/usr/local/bin"
YOLO_AGENT_PATH="${YOLO_AGENT_DIR}/${YOLO_AGENT_NAME}"
YOLO_AGENT_SYSTEMD_SERVICE_NAME="yolo-agent-container.service"

if [[ ! -f "${YOLO_AGENT_PATH}" ]]; then
  #curl --fail --silent --show-error --location --header "Accept: application/octet-stream" https://api.github.com/repos/yolo-sh/agent-container/releases/assets/77754300 --output "${YOLO_AGENT_PATH}"
  rm --recursive --force "${YOLO_AGENT_TMP_ARCHIVE_PATH}"
  curl --fail --silent --show-error --location --header "Accept: application/octet-stream" "https://github.com/yolo-sh/agent-container/releases/download/v${YOLO_AGENT_VERSION}/agent-container_${YOLO_AGENT_VERSION}_linux_${INSTANCE_ARCH}.tar.gz" --output "${YOLO_AGENT_TMP_ARCHIVE_PATH}"
  tar --directory "${YOLO_AGENT_DIR}" --extract --file "${YOLO_AGENT_TMP_ARCHIVE_PATH}"
  rm --recursive --force "${YOLO_AGENT_TMP_ARCHIVE_PATH}"
fi

chmod +x "${YOLO_AGENT_PATH}"

if [[ ! -f "/etc/systemd/system/${YOLO_AGENT_SYSTEMD_SERVICE_NAME}" ]]; then
  tee /etc/systemd/system/"${YOLO_AGENT_SYSTEMD_SERVICE_NAME}" > /dev/null << EOF
  [Unit]
  Description=The agent that runs in your environment container.

  [Service]
  Type=simple
  ExecStart=${YOLO_AGENT_PATH}
  WorkingDirectory=${YOLO_AGENT_DIR}
  Restart=always
  User=yolo
  Group=yolo

  [Install]
  WantedBy=multi-user.target
EOF
fi

systemctl enable "${YOLO_AGENT_SYSTEMD_SERVICE_NAME}"
systemctl start "${YOLO_AGENT_SYSTEMD_SERVICE_NAME}"
```
In summary, this script installs and starts the [container agent](https://github.com/yolo-sh/agent-container) via `systemd`.

## License

Yolo is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
