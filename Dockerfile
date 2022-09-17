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
  && apt-get clean && rm --recursive --force /tmp/*

# Configure systemd
RUN echo "ReadKMsg=no" >> /etc/systemd/journald.conf \
  && systemctl mask systemd-udevd.service \
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
  && sudo apt-get clean && sudo rm --recursive --force /tmp/* \
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
