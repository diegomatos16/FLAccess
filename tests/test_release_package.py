"""Release regression checks: required DLLs and exact packaged runtime."""
from pathlib import Path
import hashlib
import importlib.util
import shutil
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('build_release', ROOT / 'tools/build_release.py')
release = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(release)


class ReleasePackageTests(unittest.TestCase):
    def test_installer_contains_only_runtime_files_at_destination_paths(self):
        with tempfile.TemporaryDirectory() as directory:
            archive, manifest = release.build(ROOT, directory)
            with zipfile.ZipFile(archive) as z:
                self.assertEqual(set(z.namelist()), set(manifest['sha256']))
                self.assertEqual({p.split('/')[0] for p in z.namelist()}, {'content', 'modules', 'sider.dll'})
                self.assertEqual(manifest['version'], '0.2.3')
                self.assertEqual(len(manifest['components']['modules']), 32)
                self.assertEqual(len(z.namelist()), 66)
                self.assertIn('modules/FlAccessOpeningTrace.lua', z.namelist())
                self.assertNotIn('ad_replays', z.read('modules/FlAccess/FlAccess.ini').decode())
                for entry in manifest['components']['modules']:
                    name = 'modules/' + entry
                    self.assertEqual(z.read(name), (ROOT/name).read_bytes())
                self.assertEqual(z.read('sider.dll'), (ROOT/'sider-core/sider.dll').read_bytes())
                for name, digest in manifest['sha256'].items():
                    self.assertEqual(hashlib.sha256(z.read(name)).hexdigest(), digest)
                self.assertFalse(any(name.endswith(('.log', '.exe', '.md', '.json', '.h', '.snippet'))
                                     or 'license' in name.lower() for name in z.namelist()))
                self.assertFalse(any('FlAccessReader/' in p or 'FlAccessGameplay/' in p for p in z.namelist()))
                self.assertNotIn('sider.ini', z.namelist())
                sounds = {Path(name).name for name in z.namelist() if name.endswith('.wav')}
                self.assertEqual(sounds, {'ball.wav', 'alertSidelines.wav', 'alertGoal line.wav',
                    'alertYourGoalkeeper.wav', 'alertOpponentGoalkeeper.wav', 'gotBall.wav',
                    'LostBall.wav', 'teamStillWithBall.wav', 'alertTacle.wav', 'playerControlled.wav',
                    'FreePlayer.wav', 'MarckedPlayer.wav', 'PlayerOpponent.wav', 'PlayerNextOpponent.wav'})
                for camera in range(10):
                    self.assertIn(f'content/FlAccess/cameras/camera_{camera:02d}.ini', z.namelist())
                for dll in ('prism.dll','soft_oal.dll','flaccess_audio_master.dll'):
                    name='modules/FlAccess/bin/'+dll
                    self.assertEqual(z.read(name),(ROOT/name).read_bytes())
            first=archive.read_bytes()
            release.build(ROOT,directory)
            self.assertEqual(archive.read_bytes(),first)
            self.assertEqual(list(Path(directory).iterdir()), [archive])

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
