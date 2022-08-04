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
    log "Usage: ${script_name} [-d=<path>] [-p=<port>] [-i=<path>...] [-v] [-h] [--] [version] [build]
Download (and provision) Minecraft servers from the papermc.io api.
Options:
  -d    <path>    Server directory  (default: ./server)
  -p    <port>    Server port       (default: 25565)
  -i    <path>    Plugin jar to install
  -v              Enable verbose output
  -h              Print this help and exit"
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

server_dir=$(realpath "./server")
port=25565
plugins=()
while getopts d:i:vh? opt; do
    case $opt in
    d) server_dir="$OPTARG" ;;
    p) port="$OPTARG" ;;
    i) plugins+=("$OPTARG") ;;
    v) set -o xtrace ;;
    h | \? | *)
        usage
        exit 0
        ;;
    esac
done
shift $((OPTIND - 1))

check_dependency curl
check_dependency jq

set +o nounset
version=$1
build=$2
shift 2 || true
set -o nounset

if [[ -z ${version} ]]; then
    versions_raw=$(curl --silent --location -H "Accept: application/json" "${url_base}" | jq -c '.versions[]')
    mapfile -t versions < <(unquote "${versions_raw}" | grep --perl-regexp "^\d+\.\d+(\.\d)?$" | sort --version-sort --reverse)
    log "latest version: ${versions[0]}"
    version="${versions[0]}"
fi

if [[ -z ${build} ]]; then
    builds_raw=$(curl --silent --location -H "Accept: application/json" "${url_base}/versions/${version}" | jq -c '.builds[]')
    mapfile -t builds < <(echo "${builds_raw}" | sort --numeric-sort --reverse)
    log "latest build:   ${builds[0]}"
    build="${builds[0]}"
fi

download_raw=$(curl --silent --location -H "Accept: application/json" "${url_base}/versions/${version}/builds/${build}" | jq -c '.downloads.application')
download_file="$(unquote "$(echo "${download_raw}" | jq -c '.name')")"
download_hash="$(unquote "$(echo "${download_raw}" | jq -c '.sha256')")"
log "download file:  ${download_file}"
url_download="${url_base}/versions/${version}/builds/${build}/downloads/${download_file}"
log "download url:   ${url_download}"

log "server dir:     ${server_dir}"
mkdir -p "${server_dir}"
(cd "${server_dir}" && curl --location --progress-bar --remote-name --remote-time "${url_download}")
echo "${download_hash}  ${server_dir}/${download_file}" | sha256sum -c -

{ # default config
    echo "motd='${version} test server'"
    echo "server-port=25565"
    echo "spawn-protection=0"
} >"${server_dir}/server.properties"

# create alias
if [[ -L ${server_dir}/server.jar ]]; then rm -f "${server_dir}/server.jar"; fi
ln -s "${server_dir}/${download_file}" "${server_dir}/server.jar"

# disable metrics
bstats_config="${server_dir}/plugins/bStats/config.yml"
mkdir -p "$(dirname "${bstats_config}")"
echo "enabled: false" >"${bstats_config}"

# add plugins
for plugin in "${plugins[@]}"; do
    log "installing plugin: ${plugin}"
    cp "${plugin}" "${server_dir}/plugins/"
done

#    # eula
#    eula_file: Path = args.server_dir.joinpath('eula.txt')
#    eula_accepted = True if os.getenv('MC_EULA') is not None else False
#    if not eula_accepted and eula_file.exists() and eula_file.is_file():
#        with open(eula_file, 'r') as file1:
#            for line in file1:
#                if 'true' in line:
#                    eula_accepted = True
#                    break
#    if not eula_accepted:
#        print('Confirm with Y or set MC_EULA to agree with Mojangs EULA: https://account.mojang.com/documents/minecraft_eula')
#        eula_input = input("[Y/N]: ")
#        if eula_input.lower() == 'y':
#            eula_accepted = True
#        else:
#            print('not agreed with eula')
#    if eula_accepted:
#        with open(eula_file, 'wb') as file1:
#            file1.write(bytes('eula=true', encoding='utf8'))
