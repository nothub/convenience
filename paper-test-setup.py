#!/usr/bin/env python3
import argparse
import os
import shutil
from pathlib import Path

import requests

BASE_URL = 'https://papermc.io/api/v2/projects/paper'


def non_empty_string(s) -> str:
    """argparse input validation"""
    s = str(s)
    if not s or not s.isprintable():
        raise argparse.ArgumentTypeError("string is empty")
    return s


def mc_version(s) -> str:
    """argparse input validation via papermc.io/api"""
    s = non_empty_string(s)
    r = requests.get(BASE_URL)
    if r.status_code != 200:
        raise ConnectionError("papermc api lookup failed!")
    if s not in r.json()['versions']:
        raise argparse.ArgumentTypeError('unsupported version')
    return s


def dir_path(s: str) -> Path:
    """argparse input validation"""
    path = Path(non_empty_string(s))
    if path.exists() and not path.is_dir():
        raise argparse.ArgumentTypeError("not a valid directoy path")
    return path


def file_path(s: str) -> Path:
    """argparse input validation"""
    path = Path(non_empty_string(s))
    if path.exists() and not path.is_file():
        raise argparse.ArgumentTypeError("not a valid file path")
    return path


def network_port(n: str) -> int:
    """argparse input validation"""
    n = int(non_empty_string(n))
    if n < 1 or n > 65535:
        raise argparse.ArgumentTypeError("out of range")
    return n


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        '-mc', '--mc-version',
        action='store',
        type=mc_version,
        required=False,
        default='1.16.5',
        metavar='VERSION',
        help='mc version',
    )
    parser.add_argument(
        '-sd', '--server-dir',
        action='store',
        type=dir_path,
        required=False,
        default='server',
        metavar='PATH',
        help='server dir path',
    )
    parser.add_argument(
        '-ln', '--link-name',
        action='store',
        type=file_path,
        required=False,
        default='server.jar',
        metavar='NAME',
        help='server link name',
    )
    parser.add_argument(
        '-p', '--port',
        action='store',
        type=network_port,
        required=False,
        default=25565,
        help='server port',
    )
    parser.add_argument(
        '-cp', '--copy-plugins',
        action='extend',
        type=file_path,
        nargs='+',
        required=False,
        default=list(),
        metavar='PATH',
        help='copy to plugin dir',
    )
    return parser.parse_args()


def main():
    args = parse_args()

    print('args: ' + str(args))

    build_id = str(requests.get(BASE_URL + '/versions/' + args.mc_version).json()['builds'][-1])
    build_file = requests.get(BASE_URL + '/versions/' + args.mc_version + '/builds/' + build_id).json()['downloads']['application']['name']
    build_url = BASE_URL + '/versions/' + args.mc_version + '/builds/' + build_id + '/downloads/' + build_file

    # download
    if not args.server_dir.exists():
        args.server_dir.mkdir()
    server_file = args.server_dir.joinpath(build_file)
    if not server_file.exists():
        print('downloading: ' + build_url)
        dl_request = requests.get(build_url)
        if dl_request.status_code != 200:
            raise ConnectionError("papermc download failed!")
        with open(server_file, 'wb') as file2:
            file2.write(dl_request.content)

    # symlink
    link = args.server_dir.joinpath(args.link_name)
    if link.exists():
        link.unlink()
    print('linking ' + str(server_file) + ' to ' + str(link))
    os.symlink(server_file.absolute(), link)

    # eula
    eula_file: Path = args.server_dir.joinpath('eula.txt')
    eula_accepted = True if os.getenv('MC_EULA') is not None else False
    if not eula_accepted and eula_file.exists() and eula_file.is_file():
        with open(eula_file, 'r') as file1:
            for line in file1:
                if 'true' in line:
                    eula_accepted = True
                    break
    if not eula_accepted:
        print('Confirm with Y or set MC_EULA to agree with Mojangs EULA: https://account.mojang.com/documents/minecraft_eula')
        eula_input = input("[Y/N]: ")
        if eula_input.lower() == 'y':
            eula_accepted = True
        else:
            print('not agreed with eula')
    if eula_accepted:
        with open(eula_file, 'wb') as file1:
            file1.write(bytes('eula=true', encoding='utf8'))

    # server properties
    server_properties: Path = args.server_dir.joinpath('server.properties')
    if not server_properties.exists():
        with open(server_properties, 'wb') as file:
            file.write(bytes('motd=' + args.mc_version + ' test server' + '\n', encoding='utf8'))
            file.write(bytes('server-port=' + str(args.port) + '\n', encoding='utf8'))
            file.write(bytes('spawn-protection=0' + '\n', encoding='utf8'))

    # add plugins
    plugin_dir: Path = args.server_dir.joinpath('plugins')
    if not plugin_dir.exists():
        plugin_dir.mkdir()
    for plugin in args.copy_plugins:
        print('adding plugin: ' + str(plugin))
        shutil.copyfile(plugin, plugin_dir.joinpath(plugin.name))


if __name__ == '__main__':
    main()
