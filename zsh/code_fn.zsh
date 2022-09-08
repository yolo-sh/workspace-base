#!/usr/bin/env zsh

code () {
  local vscodeCLI=$(echo ~/.vscode-server/bin/*/bin/remote-cli/code(*oc[1]N))

  if [[ -z ${vscodeCLI} ]]; then
    echo "VSCode needs to be open and connected to your environment first.\n\nPlease, use the 'yolo <cloud_provider> edit' command locally."
    return
  fi

  if [[ -z "${VSCODE_IPC_HOOK_CLI}" ]]; then
    for socketPath in /tmp/vscode-ipc-*.sock; do
      if socat -u OPEN:/dev/null "UNIX-CONNECT:${socketPath}" 2> /dev/null; then
        export VSCODE_IPC_HOOK_CLI=${socketPath}
        break
      fi
    done

    if [[ -z "${VSCODE_IPC_HOOK_CLI}" ]]; then
      echo "VSCode needs to be open and connected to your environment first.\n\nPlease, use the 'yolo <cloud_provider> edit' command locally."
      return
    fi
  fi

  ${vscodeCLI} $@
}
