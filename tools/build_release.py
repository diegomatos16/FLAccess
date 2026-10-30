"""Build the local three-folder FlAccess.zip: livecpk, modules and sider."""
from pathlib import Path
import argparse
import hashlib
import json
import re
import subprocess
import zipfile
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_gameplay_module import build as build_gameplay
from build_reader_module import build as build_reader


def build(root, output=None):
    root = Path(root)
    for prerequisite in ('sider-core/sider.dll', 'modules/FlAccessReader/bin/prism.dll'):
        if not (root / prerequisite).is_file():
            raise ValueError('Missing required runtime: ' + prerequisite)
    lua = build_reader(root).read_text(encoding='utf-8')
    version = re.search(r'local VERSION = "([0-9.]+)"', lua).group(1)
    build_number = int(re.search(r'build = (\d+)', lua).group(1))
    files = {
        'modules/FlAccessReader/FlAccessReader.lua': root / 'modules/FlAccessReader/FlAccessReader.lua',
        'modules/FlAccessGameplay/FlAccessGameplay.lua': build_gameplay(root),
        'sider/sider.dll': root / 'sider-core/sider.dll',
        'modules/FlAccessReader/bin/prism.dll': root / 'modules/FlAccessReader/bin/prism.dll',
        'modules/FlAccessGameplay/bin/soft_oal.dll': root / 'modules/FlAccessGameplay/bin/soft_oal.dll',
        'modules/FlAccessGameplay/bin/flaccess_audio_master.dll': root / 'modules/FlAccessGameplay/bin/flaccess_audio_master.dll',
        'modules/FlAccessGameplay/state/live-layout.txt': root / 'modules/FlAccessGameplay/state/live-layout.txt',
        'modules/FlAccessGameplay/COPYING.OpenAL': root / 'modules/FlAccessGameplay/COPYING.OpenAL',
        'livecpk/FlAccessReader/text/pt.tsv': root / 'livecpk/FlAccessReader/text/pt.tsv',
        'livecpk/FlAccessReader/text/en.tsv': root / 'livecpk/FlAccessReader/text/en.tsv',
        'livecpk/FlAccessGameplay/sounds/ball.wav': root / 'livecpk/FlAccessGameplay/sounds/ball.wav',
        'livecpk/FlAccessGameplay/sounds/alertSidelines.wav': root / 'livecpk/FlAccessGameplay/sounds/alertSidelines.wav',
        'livecpk/FlAccessGameplay/sounds/gotBall.wav': root / 'livecpk/FlAccessGameplay/sounds/gotBall.wav',
        'livecpk/FlAccessGameplay/sounds/LostBall.wav': root / 'livecpk/FlAccessGameplay/sounds/LostBall.wav',
        'livecpk/FlAccessGameplay/sounds/alertYourGoalkeeper.wav': root / 'livecpk/FlAccessGameplay/sounds/alertYourGoalkeeper.wav',
        'livecpk/FlAccessGameplay/sounds/alertOpponentGoalkeeper.wav': root / 'livecpk/FlAccessGameplay/sounds/alertOpponentGoalkeeper.wav',
        'livecpk/FlAccessGameplay/sounds/teamStillWithBall.wav': root / 'livecpk/FlAccessGameplay/sounds/teamStillWithBall.wav',
        'modules/FlAccessGameplay/FlAccessGameplay.ini': root / 'modules/FlAccessGameplay/FlAccessGameplay.ini',
        'livecpk/FlAccessGameplay/sounds/alertTacle.wav': root / 'livecpk/FlAccessGameplay/sounds/alertTacle.wav',
        'sider/INSTALL.pt-BR.md': root / 'packaging/INSTALL.pt-BR.md',
        'sider/INSTALL.en.md': root / 'packaging/INSTALL.en.md',
        'sider/sider.ini.snippet': root / 'packaging/sider.ini.snippet',
        'sider/README.md': root / 'sider-core/README.md',
        'sider/CHANGELOG.md': root / 'CHANGELOG.md',
    }
    licenses = root / 'modules/FlAccessReader/licenses'
    for path in licenses.rglob('*'):
        if path.is_file():
            files[path.relative_to(root).as_posix()] = path
    if not (licenses / 'LICENSE').is_file() or not (licenses / 'NOTICE').is_file():
        raise ValueError('Prism LICENSE/NOTICE are required')
    for directory in ('livecpk', 'modules/FlAccessGameplay/engine'):
        for path in (root / directory).rglob('*'):
            if path.is_file(): files[path.relative_to(root).as_posix()] = path
    for path in (root / 'sider-core/licenses').rglob('*'):
        if path.is_file(): files['sider/licenses/' + path.relative_to(root / 'sider-core/licenses').as_posix()] = path
    for mod in ('FlAccessReader', 'FlAccessGameplay'):
        files[f'modules/{mod}/README.pt-BR.md'] = root / 'modules' / mod / 'README.pt-BR.md'
    for name, path in files.items():
        if not path.is_file() or not path.stat().st_size:
            raise ValueError(f'Missing or empty required release file: {name}')
        if name.endswith('.dll') and path.read_bytes()[:2] != b'MZ':
            raise ValueError(f'Invalid DLL: {name}')
    try:
        commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root,
                                         stderr=subprocess.DEVNULL, text=True).strip()
    except (OSError, subprocess.CalledProcessError):
        commit = None
    payload = {name: path.read_bytes() for name, path in files.items()}
    manifest = {'version': version, 'build': build_number, 'source_commit': commit,
                'components': {'FlAccessReader': {'entry': 'modules/FlAccessReader/FlAccessReader.lua', 'assets': 'livecpk/FlAccessReader'},
                               'FlAccessGameplay': {'entry': 'modules/FlAccessGameplay/FlAccessGameplay.lua', 'assets': 'livecpk/FlAccessGameplay'}},
                'sha256': {name: hashlib.sha256(data).hexdigest()
                           for name, data in sorted(payload.items())}}
    payload['sider/BUILD.json'] = (json.dumps(manifest, indent=2) + '\n').encode('utf-8')
    output = Path(output) if output else root / 'release' / version
    output.mkdir(parents=True, exist_ok=True)
    archive = output / 'FlAccess.zip'
    with zipfile.ZipFile(archive, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for name, data in sorted(payload.items()):
            info = zipfile.ZipInfo(name)
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            z.writestr(info, data, compresslevel=9)
    with zipfile.ZipFile(archive) as z:
        if z.testzip() is not None:
            raise ValueError('Corrupt installer archive')
        for name, data in payload.items():
            if z.read(name) != data:
                raise ValueError(f'Installer differs from source: {name}')
    checksum = hashlib.sha256(archive.read_bytes()).hexdigest()
    (output / 'SHA256SUMS.txt').write_text(f'{checksum}  {archive.name}\n', encoding='ascii')
    return archive, manifest


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    archive, manifest = build(args.root, args.output)
    print(f'RELEASE_PACKAGE_OK version={manifest["version"]} build={manifest["build"]} files={len(manifest["sha256"])} archive={archive}')
