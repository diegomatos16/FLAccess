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
                self.assertEqual(json.loads(z.read('BUILD.json')), manifest)
                for path, source in [('sider.dll', 'sider-core/sider.dll'),
                                     ('modules/FLAccess-Prism/prism.dll', 'modules/FLAccess-Prism/prism.dll'),
                                     ('modules/FLAccess.lua', 'modules/FLAccess.lua')]:
                    self.assertEqual(z.read(path), (ROOT / source).read_bytes())
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
            for name in ('modules/FLAccess.lua',
                         'modules/FLAccess-Prism/licenses/LICENSE',
                         'modules/FLAccess-Prism/licenses/NOTICE'):
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
