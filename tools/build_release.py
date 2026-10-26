"""Build the installer from versioned runtime files; both DLLs are mandatory."""
from pathlib import Path
import argparse
import hashlib
import json
import re
import subprocess
import zipfile


def build(root, output=None):
    root = Path(root)
    lua = (root / 'modules/FLAccess.lua').read_text(encoding='utf-8')
    version = re.search(r'local VERSION = "([0-9.]+)"', lua).group(1)
    build_number = int(re.search(r'build = (\d+)', lua).group(1))
    files = {
        'modules/FLAccess.lua': root / 'modules/FLAccess.lua',
        'sider.dll': root / 'sider-core/sider.dll',
        'modules/FLAccess-Prism/prism.dll': root / 'modules/FLAccess-Prism/prism.dll',
        'modules/FLAccess-text/pt.tsv': root / 'modules/FLAccess-text/pt.tsv',
        'modules/FLAccess-text/en.tsv': root / 'modules/FLAccess-text/en.tsv',
        'INSTALL.pt-BR.md': root / 'packaging/INSTALL.pt-BR.md',
        'INSTALL.en.md': root / 'packaging/INSTALL.en.md',
        'sider.ini.snippet': root / 'packaging/sider.ini.snippet',
        'README.md': root / 'README.md',
        'CHANGELOG.md': root / 'CHANGELOG.md',
        'sider-core/README.md': root / 'sider-core/README.md',
    }
    for name in ('README.pt-BR.md', 'README.en.md', f'RELEASE-{version}.pt-BR.md',
                 'PUBLICACAO.pt-BR.md', 'TESTES-LEITURA-PENDENCIAS.pt-BR.md'):
        files['docs/' + name] = root / 'docs' / name
    licenses = root / 'modules/FLAccess-Prism/licenses'
    for path in licenses.rglob('*'):
        if path.is_file():
            files[path.relative_to(root).as_posix()] = path
    if not (licenses / 'LICENSE').is_file() or not (licenses / 'NOTICE').is_file():
        raise ValueError('Prism LICENSE/NOTICE are required')
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
                'sha256': {name: hashlib.sha256(data).hexdigest()
                           for name, data in sorted(payload.items())}}
    payload['BUILD.json'] = (json.dumps(manifest, indent=2) + '\n').encode('utf-8')
    output = Path(output) if output else root / 'release' / version
    output.mkdir(parents=True, exist_ok=True)
    archive = output / f'FLAccess-{version}-sider.zip'
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
