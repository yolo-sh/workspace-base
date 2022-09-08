# All environments will be Ubuntu-based (Ubuntu 22.04)
FROM buildpack-deps:jammy

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
    git \
    gnupg \
    locales \
    lsb-release \
    man-db \
    manpages-posix \
    nano \
    socat \
    software-properties-common \
    sudo \
    tzdata \
    unzip \
    vim \
    wget \
  && apt-get clean && rm --recursive --force /var/lib/apt/lists/* /tmp/*

# Set default timezone
ENV TZ=America/Los_Angeles

# Set default locale.
# /!\ locale-gen must be run as root.
RUN set -euo pipefail \
  && locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Install entrypoint script
COPY ./entrypoint.sh /
RUN set -euo pipefail \
  && chmod +x /entrypoint.sh

# Only for documentation purpose.
# Entrypoint and CMD are always set by the 
# agent when running the container.
ENTRYPOINT ["/entrypoint.sh"]
CMD ["sleep", "infinity"]

# Configure the user "yolo" in container.
# 
# We want the user "yolo" inside the container to get 
# the same permissions than the user "yolo" in the instance 
# (to access the Docker daemon, SSH keys and so on).
# 
# To do this, the two users need to share the same UID/GID.
ENV USER=yolo
ENV HOME=/home/$USER
ENV EDITOR=/usr/bin/nano
ENV WORKSPACE=$HOME/workspace
ENV WORKSPACE_CONFIG=$HOME/.workspace-config
RUN set -euo pipefail \
  && groupadd --gid 10000 --non-unique "${USER}" \
  && useradd --gid 10000 --uid 10000 --non-unique --home "${HOME}" --create-home --shell /bin/bash "${USER}" \
  && cp /etc/sudoers /etc/sudoers.orig \
  && echo "${USER} ALL=(ALL) NOPASSWD:ALL" | tee "/etc/sudoers.d/${USER}" > /dev/null \
  && mkdir --parents "${WORKSPACE_CONFIG}" \
  && mkdir --parents "${WORKSPACE}" \
  && mkdir --parents "${HOME}/.ssh" \
  && mkdir --parents "${HOME}/.gnupg" \
  && mkdir --parents "${HOME}/.vscode-server" \
  && chown --recursive "${USER}:${USER}" "${HOME}" \
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

WORKDIR $WORKSPACE
