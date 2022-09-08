#!/bin/bash
# Yolo base workspace docker image builder
set -euo pipefail

BUILDER_NAME="yolo-base-workspace-image-builder"

log () {
  echo -e "${1}" >&2
}

if [[ "${#}" != 1 ]]; then
  echo "usage: $0 <image-tag-name>"
  exit 1
fi

IMAGE_TAG_NAME="${1}"

# Install emulators to cross-build our base
# workspace image for different architectures
docker run -it --rm --privileged tonistiigi/binfmt --install all

# Create and use buildx builder.
# We drop errors given that the command "buildx create"
# will return an error when the builder already exists.
docker buildx create --name "${BUILDER_NAME}" --use || true

cat /tmp/docker-password | docker login ghcr.io --username jeremylevy --password-stdin

log ""

docker buildx build --platform linux/amd64,linux/arm64 -t ghcr.io/yolo-sh/workspace-base:"${IMAGE_TAG_NAME}" -t ghcr.io/yolo-sh/workspace-base:latest --push .
