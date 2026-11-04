"""Migration contracts: native module order, preference preservation and Prism ABI."""
from pathlib import Path
import ctypes
import hashlib
import importlib.util
import json
import shutil
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[1]
SPEC=importlib.util.spec_from_file_location('install_flaccess',ROOT/'tools/install_flaccess.py')
installer=importlib.util.module_from_spec(SPEC);SPEC.loader.exec_module(installer)

class MigrationTests(unittest.TestCase):
    def test_ini_changes_only_flaccess_and_keeps_order_and_other_mods(self):
        before='[sider]\r\ncpk.root = ".\\livecpk\\other"\r\ncpk.root = ".\\livecpk\\FlAccessReader"\r\nlua.module = "FlAccessReader\\FlAccessReader.lua"\r\nlua.module = "FlAccessGameplay\\FlAccessGameplay.lua"\r\nlua.module = "camera.lua"\r\n'
        entries=['FlAccess/core.lua','FlAccess/reader_lifecycle.lua']
        result=installer.migrate_ini(before,entries)
        self.assertIn('cpk.root = ".\\livecpk\\other"\r\n',result)
        self.assertIn('lua.module = "camera.lua"\r\n',result)
        self.assertNotIn('FlAccessReader',result)
        self.assertEqual(installer.migrate_ini(result,entries),result)
        self.assertLess(result.index('core.lua'),result.index('reader_lifecycle.lua'))

    def test_unknown_install_position_is_rejected(self):
        with self.assertRaises(ValueError): installer.migrate_ini('[sider]\nlua.module = "camera.lua"\n',['FlAccess/core.lua'])

    def test_settings_keep_custom_values_and_unrelated_keys(self):
        result=installer.merge_settings('read_tooltips=true\ntackle_volume=0.30\nother=7\n','read_tooltips=false\ntackle_volume=0.12\ncustom=9\n')
        self.assertIn('read_tooltips=false',result);self.assertIn('tackle_volume=0.12',result)
        self.assertIn('other=7',result);self.assertIn('custom=9',result)

    def test_clean_install_migrates_user_wav_camera_settings_and_preserves_core(self):
        with tempfile.TemporaryDirectory() as directory:
            sider=Path(directory)/'SiderAddons';sider.mkdir()
            (sider/'sider.dll').write_bytes(b'MZ-original-core')
            (sider/'sider.ini').write_text('[sider]\nlua.module = "FlAccessReader\\FlAccessReader.lua"\nlua.module = "FlAccessGameplay\\FlAccessGameplay.lua"\nlua.module = "camera.lua"\n')
            originals={'modules/FlAccessReader/FlAccessReader.ini':b'read_tooltips=false\n',
                       'modules/FlAccessGameplay/FlAccessGameplay.ini':b'tackle_volume=0.12\n',
                       'livecpk/FlAccessGameplay/sounds/ball.wav':b'custom-WAV',
                       'modules/FlAccessGameplay/engine/cameraRadars/camera_02.ini':b'native_id=2\npan_sign=-1\n'}
            for name,data in originals.items():
                p=sider/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(data)
            # Backups are inside fixture, never a user directory.
            fixture=Path(directory)/'source';shutil.copytree(ROOT/'modules/FlAccess',fixture/'modules/FlAccess')
            shutil.copytree(ROOT/'content/FlAccess',fixture/'content/FlAccess')
            report=installer.install(fixture,sider)
            self.assertEqual(len(report['modules']),31)
            self.assertEqual((sider/'sider.dll').read_bytes(),b'MZ-original-core')
            self.assertEqual((sider/'content/FlAccess/sounds/ball.wav').read_bytes(),b'custom-WAV')
            self.assertIn('pan_sign=-1',(sider/'content/FlAccess/cameras/camera_02.ini').read_text())
            config=(sider/'modules/FlAccess/FlAccess.ini').read_text()
            self.assertIn('read_tooltips=false',config);self.assertIn('tackle_volume=0.12',config)
            for name,data in originals.items():self.assertEqual((sider/name).read_bytes(),data)
            ini=(sider/'sider.ini').read_bytes()
            installer.install(fixture,sider)
            self.assertEqual((sider/'sider.ini').read_bytes(),ini)
            self.assertEqual((sider/'modules/FlAccess/FlAccess.ini').read_text(),config)

    def test_source_built_prism_matches_provenance_and_native_registry_abi(self):
        path=ROOT/'modules/FlAccess/bin/prism.dll'
        info=json.loads((ROOT/'modules/FlAccess/PRISM-SOURCE.json').read_text())
        self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(),info['sha256'])
        dll=ctypes.CDLL(str(path.resolve()))
        dll.prism_version_string.restype=ctypes.c_char_p
        self.assertEqual(dll.prism_version_string().decode(),info['version'])
        dll.prism_init.argtypes=[ctypes.c_void_p];dll.prism_init.restype=ctypes.c_void_p
        dll.prism_registry_count.argtypes=[ctypes.c_void_p];dll.prism_registry_count.restype=ctypes.c_size_t
        dll.prism_registry_id_at.argtypes=[ctypes.c_void_p,ctypes.c_size_t];dll.prism_registry_id_at.restype=ctypes.c_uint64
        dll.prism_registry_name.argtypes=[ctypes.c_void_p,ctypes.c_uint64];dll.prism_registry_name.restype=ctypes.c_char_p
        dll.prism_shutdown.argtypes=[ctypes.c_void_p]
        context=dll.prism_init(None);self.assertTrue(context)
        try:
            count=dll.prism_registry_count(context);self.assertGreater(count,0)
            names={dll.prism_registry_name(context,dll.prism_registry_id_at(context,i)).decode() for i in range(count)}
            self.assertTrue({'NVDA','JAWS','SAPI'}.issubset(names))
            for export in ('prism_backend_get_features','prism_backend_initialize','prism_backend_speak','prism_backend_stop','prism_registry_create'):
                self.assertTrue(getattr(dll,export))
        finally:dll.prism_shutdown(context)

if __name__=='__main__':unittest.main()
