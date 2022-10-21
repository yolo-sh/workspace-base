export TZ=America/Los_Angeles
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8

cd ~/workspace

if [[ "$(find . -maxdepth 1 -mindepth 1 -type d | wc -l)" -eq 1 ]]; then
  cd "$(find . -maxdepth 1 -mindepth 1 -type d)"
fi
