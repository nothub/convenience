#!/usr/bin/env bash

set -e

if [ -z "$1" ]; then
  echo "please provide artifact id as script argument!"
  exit 1
fi

cd "$(dirname "${BASH_SOURCE[0]}")"

bash ./install-server.sh

rm -f ../server/plugins/"$1"-*.jar
cp ../target/"$1"-*.jar ../server/plugins

echo "plugin installation complete"
