"""Verify reproducible single-chunk Reader builds and failure atomicity."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('build_reader_module', ROOT / 'tools/build_reader_module.py')
BUILDER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BUILDER)


class ReaderBundleTests(unittest.TestCase):
    def test_maintained_sources_match_runtime(self):
        BUILDER.build(ROOT, check=True)
        self.assertEqual(len(BUILDER.FRAGMENTS), len(set(BUILDER.FRAGMENTS)))

    def test_missing_fragment_preserves_previous_runtime(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            target = root / 'modules/FlAccessReader/FlAccessReader.lua'
            target.parent.mkdir(parents=True)
            target.write_bytes(b'previous runtime')
            with self.assertRaises(FileNotFoundError):
                BUILDER.build(root)
            self.assertEqual(target.read_bytes(), b'previous runtime')

    def test_order_and_stale_bundle_detection(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            engine = root / 'modules/FlAccessReader/engine'
            engine.mkdir(parents=True)
            for index, name in enumerate(BUILDER.FRAGMENTS):
                (engine / (name + '.lua')).write_text(str(index) + '\n', encoding='utf-8')
            target = BUILDER.build(root)
            self.assertEqual(target.read_text(encoding='utf-8'), BUILDER.HEADER +
                             ''.join(str(i) + '\n' for i in range(len(BUILDER.FRAGMENTS))))
            target.write_text('stale', encoding='utf-8')
            with self.assertRaisesRegex(ValueError, 'stale'):
                BUILDER.build(root, check=True)
