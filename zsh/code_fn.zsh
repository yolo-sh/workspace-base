#!/usr/bin/env zsh

code () {
  local vscodeCLI=$(echo ~/.vscode-server/bin/*/bin/remote-cli/code(*oc[1]N))

  if [[ -z ${vscodeCLI} ]]; then
    echo "VSCode needs to be open and connected to your environment first.\n\nPlease, use the 'yolo <cloud_provider> edit' command locally."
    return
  fi

  local vscodeIPCSocket=$(echo /tmp/vscode-ipc-*.sock(=oc[1]N))

  if [[ -z ${vscodeIPCSocket} ]]; then
    echo "VSCode needs to be open and connected to your environment first.\n\nPlease, use the 'yolo <cloud_provider> edit' command locally."
    return
  fi

  export VSCODE_IPC_HOOK_CLI=${vscodeIPCSocket}
  ${vscodeCLI} $@
}
