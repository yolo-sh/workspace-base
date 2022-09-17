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

# Auto-start systemd services installed via packages
echo '#!/bin/sh' > /usr/sbin/policy-rc.d
echo '' >> /usr/sbin/policy-rc.d
echo 'exit 0' >> /usr/sbin/policy-rc.d

# -- Install the yolo container agent

log "Installing the yolo container agent"

YOLO_AGENT_VERSION="0.0.2"
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
