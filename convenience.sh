#!/usr/bin/env bash
# https://github.com/nothub/convenience

set -o errexit
set -o nounset
set -o pipefail

url_base="https://papermc.io/api/v2/projects/paper"

log() {
  echo >&2 "$*"
}

usage() {
  set +o xtrace
  script_name="$(basename "${BASH_SOURCE[0]}")"
  log "Download (and provision) Minecraft servers from the papermc.io api.

Usage: ${script_name} [-d=<path>] [-a=<path>] [-p=<port>] [-i=<path>...] [-v] [-h|-?] [--] [version] [build]

By default, the latest possible server release will be used.

Options:
  -d <path>    Server directory       [default: server]
  -a <path>    Server alias           [default: {{server}}/server.jar]
  -p <port>    Server port            [default: 25565]
  -i <path>    Plugin jar to install  (multiple possible)
  -v           Enable verbose output
  -h, -?       Print help and exit

Examples:
  ${script_name} 1.12.2 1337
  ${script_name} -v 1.15
  ${script_name} -d srv
  ${script_name} -d /opt/srv
  ${script_name} -a foo.jar
  ${script_name} -a /home/user/bar.jar
  ${script_name} -p 9001
  ${script_name} -i foo.jar -i rel/bar.jar -i /abs/test.jar
  ${script_name} -i https://example.org/foo/bar.jar"
}

check_dependency() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log "Error: Missing dependency: $1"
    exit 1
  fi
}

unquote() {
  echo "${*//\"/""}"
}

plugins=()
while getopts d:a:p:i:vh? opt; do
  case ${opt} in
  d) server_dir="${OPTARG}" ;;
  a) server_alias="${OPTARG}" ;;
  p) server_port="${OPTARG}" ;;
  i) plugins+=("${OPTARG}") ;;
  v) set -o xtrace ;;
  h | \?)
    usage
    exit 0
    ;;
  *)
    usage
    exit 1
    ;;
  esac
done
shift $((OPTIND - 1))

check_dependency curl
check_dependency jq

# default options
set +o nounset
if [[ -z ${server_dir} ]]; then server_dir="server"; fi
if [[ -z ${server_port} ]]; then server_port=25565; fi
if [[ -z ${server_alias} ]]; then server_alias="${server_dir}/server.jar"; fi
set -o nounset

# resolve absolute pathes
server_dir=$(realpath --no-symlinks --canonicalize-missing "${server_dir}")
server_alias=$(realpath --no-symlinks --canonicalize-missing "${server_alias}")

# read args
set +o nounset
version=$1
build=$2
shift 2 || true
set -o nounset

# fetch latest version
if [[ -z ${version} ]]; then
  versions_raw=$(curl --silent --location -H "Accept: application/json" "${url_base}" | jq -c '.versions[]')
  mapfile -t versions < <(unquote "${versions_raw}" | grep --perl-regexp "^\d+\.\d+(\.\d)?$" | sort --version-sort --reverse)
  log "latest version: ${versions[0]}"
  version="${versions[0]}"
else
  log "selected version: ${version}"
fi

# fetch latest build
if [[ -z ${build} ]]; then
  builds_raw=$(curl --silent --location -H "Accept: application/json" "${url_base}/versions/${version}" | jq -c '.builds[]')
  mapfile -t builds < <(echo "${builds_raw}" | sort --numeric-sort --reverse)
  log "latest build: ${builds[0]}"
  build="${builds[0]}"
else
  log "selected build: ${build}"
fi

download_raw=$(curl --silent --location -H "Accept: application/json" "${url_base}/versions/${version}/builds/${build}" | jq -c '.downloads.application')
download_file="$(unquote "$(echo "${download_raw}" | jq -c '.name')")"
download_hash="$(unquote "$(echo "${download_raw}" | jq -c '.sha256')")"

if [[ ! -f ${server_dir}/${download_file} ]]; then
  download_url="${url_base}/versions/${version}/builds/${build}/downloads/${download_file}"
  log "download url: ${download_url}"
  log "server dir: ${server_dir}"
  mkdir -p "${server_dir}"
  (cd "${server_dir}" && curl --location --progress-bar --remote-name --remote-time "${download_url}")
  echo "${download_hash}  ${server_dir}/${download_file}" | sha256sum -c -
else
  log "skipping install: ${download_file}"
fi

if [[ ! -f "${server_dir}/server.properties" ]]; then
  log "creating default config"
  { # default config
    echo "motd='${version} server'"
    echo "server-port=${server_port}"
    echo "spawn-protection=0"
  } >"${server_dir}/server.properties"
fi

# create alias

if [[ ! -f "${server_alias}" ]]; then
  log "creating server alias: ${server_alias}"
  if [[ -L ${server_alias} ]]; then rm -f "${server_alias}"; fi
  ln -s "${server_dir}/${download_file}" "${server_alias}"
fi

# install plugins
mkdir -p "${server_dir}/plugins"
for plugin in "${plugins[@]}"; do
  plugin_file=$(basename "${plugin}")
  if [[ -f "${server_dir}/plugins/${plugin_file}" ]]; then
    log "skipping install: ${plugin_file}"
    continue
  fi
  if [[ ${plugin} == "https://"* ]]; then
    log "downloading plugin: ${plugin_file}"
    (cd "${server_dir}/plugins/" && curl --location --progress-bar --remote-name --remote-time "${plugin}") || true
  else
    log "installing plugin: ${plugin_file}"
    cp --verbose "${plugin}" "${server_dir}/plugins/" || true
  fi
done

# disable metrics
bstats_config="${server_dir}/plugins/bStats/config.yml"
mkdir -p "$(dirname "${bstats_config}")"
echo "enabled: false" >"${bstats_config}"

# eula
set +o nounset
if [[ ${MC_EULA} == "true" ]]; then
  echo "eula=true" >"${server_dir}/eula.txt"
else
  log "Set MC_EULA=true to agree with Mojangs EULA: https://account.mojang.com/documents/minecraft_eula"
  exit 1
fi
