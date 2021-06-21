#!/usr/bin/env bash

set -e

SERVER_URL="https://dl.airplane.gg/latest/Airplane-JDK11/launcher-airplane.jar"
SERVER_FILE="airplane.jar"

if [ -f ../server/$SERVER_FILE ]; then
  echo "airplane.jar found, skipping server setup..."
  exit 0
fi

cd "$(dirname "${BASH_SOURCE[0]}")"
mkdir -p ../server
cd ../server

curl "$SERVER_URL" -o $SERVER_FILE

if [ -z "$MC_EULA" ]; then
  echo "Press Y or set MC_EULA to agree with Mojangs EULA: https://account.mojang.com/documents/minecraft_eula"
  read -p "" -n 1 -r
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
fi

echo "eula=true" >./eula.txt

mkdir -p ./plugins/bStats

{
  echo "motd=some test server"
  echo "online-mode=false"
  echo "spawn-protection=0"
  echo "enable-command-block=true"
} >./server.properties

{
  echo "enabled: false"
  echo "serverUuid: 00000000-0000-0000-0000-000000000000"
  echo "logFailedRequests: false"
} >./plugins/bStats/config.yml

echo "server installation complete"
