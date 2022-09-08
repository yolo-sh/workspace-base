#!/bin/bash
# Yolo environments entrypoint
set -euo pipefail

# Import GitHub GPG keys for user
gpg --import ~/.gnupg/yolo_github_gpg_public.pgp
gpg --import ~/.gnupg/yolo_github_gpg_private.pgp

# Run the Command passed as argument
exec "$@"