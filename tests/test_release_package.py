"""Release regression checks: required DLLs and exact packaged runtime."""
from pathlib import Path
import hashlib
import importlib.util
import json
import shutil
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('build_release', ROOT / 'tools/build_release.py')
release = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(release)


class ReleasePackageTests(unittest.TestCase):
    def test_installer_contains_both_exact_dlls_and_complete_manifest(self):
        with tempfile.TemporaryDirectory() as directory:
            archive, manifest = release.build(ROOT, directory)
            with zipfile.ZipFile(archive) as z:
                self.assertEqual(json.loads(z.read('sider/BUILD.json')), manifest)
                self.assertEqual({p.split('/')[0] for p in z.namelist()}, {'livecpk', 'modules', 'sider'})
                self.assertEqual(set(manifest['components']), {'FlAccessReader', 'FlAccessGameplay'})
                for path, source in [('sider/sider.dll', 'sider-core/sider.dll'),
                                     ('modules/FlAccessReader/bin/prism.dll', 'modules/FlAccessReader/bin/prism.dll'),
                                     ('modules/FlAccessReader/FlAccessReader.lua', 'modules/FlAccessReader/FlAccessReader.lua'),
                                     ('modules/FlAccessGameplay/FlAccessGameplay.lua', 'modules/FlAccessGameplay/FlAccessGameplay.lua'),
                                     ('modules/FlAccessGameplay/bin/flaccess_audio_master.dll', 'modules/FlAccessGameplay/bin/flaccess_audio_master.dll')]:
                    self.assertEqual(z.read(path), (ROOT / source).read_bytes())
                for camera_id in range(10):
                    path = f'modules/FlAccessGameplay/engine/cameraRadars/camera_{camera_id:02d}.ini'
                    self.assertEqual(z.read(path), (ROOT / path).read_bytes())
                self.assertIn('modules/FlAccessGameplay/engine/cameraRadars.lua', z.namelist())
                for asset in (ROOT / 'livecpk').rglob('*'):
                    if asset.is_file(): self.assertEqual(z.read(asset.relative_to(ROOT).as_posix()), asset.read_bytes())
                self.assertFalse(any('FLAccess-Audio' in p or 'FLAccess-text' in p or p.endswith('FLAccess.lua') for p in z.namelist()))
                for name, digest in manifest['sha256'].items():
                    self.assertEqual(hashlib.sha256(z.read(name)).hexdigest(), digest)
                self.assertFalse(any(name.endswith(('.log', '.exe')) or 'probe' in name for name in z.namelist()))
            first = archive.read_bytes()
            release.build(ROOT, directory)
            self.assertEqual(archive.read_bytes(), first)
            self.assertEqual((Path(directory) / 'SHA256SUMS.txt').read_text().split()[0],
                             hashlib.sha256(first).hexdigest())

    def test_packaging_stops_if_either_runtime_dll_is_missing(self):
        with tempfile.TemporaryDirectory() as directory:
            fixture = Path(directory) / 'source'
            for name in ('modules/FlAccessReader/FlAccessReader.lua',
                         'modules/FlAccessReader/licenses/LICENSE',
                         'modules/FlAccessReader/licenses/NOTICE'):
                target = fixture / name
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(ROOT / name, target)
            with self.assertRaisesRegex(ValueError, 'sider.dll'):
                release.build(fixture, Path(directory) / 'out')
            (fixture / 'sider-core').mkdir()
            shutil.copy2(ROOT / 'sider-core/sider.dll', fixture / 'sider-core/sider.dll')
            with self.assertRaisesRegex(ValueError, 'prism.dll'):
                release.build(fixture, Path(directory) / 'out')
            self.assertFalse((Path(directory) / 'out').exists())


if __name__ == '__main__':
    unittest.main()
