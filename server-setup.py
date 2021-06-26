#!/usr/bin/env python3
import argparse
import enum
import glob
import os
import shutil
from pathlib import Path

import requests

PAPER_API_BASE = 'https://papermc.io/api/v2/projects/paper'


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        '-f', '--fork',
        action='store',
        type=server_fork,
        required=False,
        default=Fork.PAPER,
        metavar='NAME',
        help='server fork (paper, tuinity, airplane)',
    )
    parser.add_argument(
        '-mc', '--mc-version',
        action='store',
        type=mc_version,
        required=False,
        default='1.16.5',
        metavar='VERSION',
        help='mc version (paper only)',
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
        '-d', '--server-dir',
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
        '-cp', '--copy-plugins',
        action='extend',
        type=file_glob_path,
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

    # download
    if not args.server_dir.exists():
        args.server_dir.mkdir()
    server_file = args.fork(args)

    # symlink
    link = args.server_dir.joinpath(args.link_name)
    if link.exists():
        link.unlink()
    print('linking ' + str(server_file) + ' to ' + str(link))
    os.symlink(server_file.absolute(), link)

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

    # disable metrics
    bstats_dir: Path = args.server_dir.joinpath('plugins').joinpath('bStats')
    if not bstats_dir.exists():
        bstats_dir.mkdir()
    bstats_config: Path = bstats_dir.joinpath('config.yml')
    if not bstats_config.exists():
        with open(bstats_config, 'wb') as file:
            file.write(bytes('enabled: false', encoding='utf8'))

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


def download(build_url, server_file, replace: bool = False):
    if replace or not server_file.exists():
        print('downloading: ' + build_url)
        r = requests.get(build_url)
        if r.status_code != 200:
            raise ConnectionError("download download failed!")
        with open(server_file, 'wb') as f:
            f.write(r.content)


def download_paper(args):
    build_id = str(requests.get(PAPER_API_BASE + '/versions/' + args.mc_version).json()['builds'][-1])
    server_file = requests.get(PAPER_API_BASE + '/versions/' + args.mc_version + '/builds/' + build_id).json()['downloads']['application']['name']
    url = PAPER_API_BASE + '/versions/' + args.mc_version + '/builds/' + build_id + '/downloads/' + server_file
    path = args.server_dir.joinpath(server_file)
    download(url, path)
    return path


def download_tuinity(args):
    url = 'https://ci.codemc.io/job/Spottedleaf/job/Tuinity/lastSuccessfulBuild/artifact/tuinity-paperclip.jar'
    path = args.server_dir.joinpath('tuinity-paperclip.jar')
    download(url, path)
    return path


def download_airplane(args):
    url = 'https://ci.tivy.ca/job/Airplane-1.16/lastSuccessfulBuild/artifact/launcher-airplane.jar'
    path = args.server_dir.joinpath('launcher-airplane.jar')
    download(url, path)
    return path


class Fork(enum.Enum):
    PAPER = download_paper
    TUINITY = download_tuinity
    AIRPLANE = download_airplane


def non_empty_string(s) -> str:
    """argparse input validation"""
    s = str(s)
    if not s or not s.isprintable():
        raise argparse.ArgumentTypeError("string is empty")
    return s


def mc_version(s) -> str:
    """argparse input validation via papermc.io/api"""
    s = non_empty_string(s)
    r = requests.get(PAPER_API_BASE)
    if r.status_code != 200:
        raise ConnectionError("papermc api lookup failed!")
    if s not in r.json()['versions']:
        raise argparse.ArgumentTypeError('unsupported version')
    return s


def server_fork(s) -> Fork:
    """argparse input validation"""
    s = non_empty_string(s)
    if s.lower() == 'paper':
        return Fork.PAPER
    if s.lower() == 'tuinity':
        return Fork.TUINITY
    if s.lower() == 'airplane':
        return Fork.AIRPLANE
    else:
        raise argparse.ArgumentTypeError('unsupported fork')


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


def file_glob_path(s: str) -> Path:
    """argparse input validation"""
    results = glob.glob(non_empty_string(s))
    if not len(results) or len(results) > 1:
        raise argparse.ArgumentTypeError("not a valid file glob path")
    return file_path(results[0])


def network_port(n: str) -> int:
    """argparse input validation"""
    n = int(non_empty_string(n))
    if n < 1 or n > 65535:
        raise argparse.ArgumentTypeError("out of range")
    return n


if __name__ == '__main__':
    main()
