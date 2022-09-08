#!/bin/bash
# Yolo base environment docker image builder
set -euo pipefail

BUILDER_NAME="yolo-base-env-image-builder"

log () {
  echo -e "${1}" >&2
}

if [[ "${#}" != 1 ]]; then
  echo "usage: $0 <image-tag-name>"
  exit 1
fi

IMAGE_TAG_NAME="${1}"

# Install emulators to cross-build our base
# dev env image for different architectures
docker run -it --rm --privileged tonistiigi/binfmt --install all

# Create and use buildx builder.
# Drop errors given that the command "buildx create"
# will return an error when the builder already exists.
docker buildx create --name "${BUILDER_NAME}" --use || true

cat /tmp/docker-password | docker login --username jeremylevy --password-stdin

log ""

docker buildx build --platform linux/amd64,linux/arm64 -t yolosh/base-env:"${IMAGE_TAG_NAME}" -t yolosh/base-env:latest --push .
