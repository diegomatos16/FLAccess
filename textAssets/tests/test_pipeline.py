"""Focused regression tests for text extraction and runtime lexicon building."""

from __future__ import annotations

import importlib.util
import sqlite3
import tempfile
import unittest
import zlib
from pathlib import Path


TOOLS = Path(__file__).resolve().parents[1] / "tools"


def load_script(name: str):
    path = TOOLS / name
    spec = importlib.util.spec_from_file_location(path.stem, path)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


extract = load_script("extract_text_assets.py")
runtime = load_script("build_flaccess_runtime_assets.py")


class ExtractionTests(unittest.TestCase):
    def test_utf8_offsets_and_accents(self):
        data = b"\0\0" + "Configurações de volume".encode() + b"\0"
        self.assertIn((2, "Configurações de volume"),
                      list(extract.iter_utf8_strings(data)))

    def test_wesys_header_decompresses(self):
        data = b"\0\x10\x01WESYS" + b"\0" * 8 + zlib.compress(b"Dialog OK")
        self.assertEqual(extract.wesys_decompress(data),
                         (b"Dialog OK", "wesys-zlib"))

    def test_malformed_wesys_remains_available_for_analysis(self):
        data = b"\0\x10\x01WESYS" + b"\0" * 8 + b"invalid"
        self.assertEqual(extract.wesys_decompress(data),
                         (data, "wesys-invalid"))

    def test_locale_and_role(self):
        self.assertEqual(extract.locale_from_names(
            "Data/dt20_bra_x64.cpk", "bra/string/all.str"), "bra")
        self.assertEqual(extract.classify("Cancelar", "bra/string/all.str")[0],
                         "dialog-button")


class RuntimeLexiconTests(unittest.TestCase):
    def test_primary_source_and_priority(self):
        with sqlite3.connect(":memory:") as db:
            db.executescript("""
                CREATE TABLE assets(id INTEGER PRIMARY KEY, text TEXT, role TEXT);
                CREATE TABLE occurrences(asset_id INTEGER, source_file TEXT,
                                         archive_member TEXT);
                INSERT INTO assets VALUES
                  (1, 'Cancelar', 'menu-item-or-title'),
                  (2, 'Cancelar', 'dialog-button'),
                  (3, 'Debug\nDump', 'technical'),
                  (4, 'Início', 'menu-item-or-title'),
                  (5, 'Only DLC', 'dialog');
                INSERT INTO occurrences VALUES
                  (1, 'Data/dt20_bra_x64.cpk', 'bra/string/all.str'),
                  (2, 'Data/dt20_bra_x64.cpk', 'bra/string/all.str'),
                  (3, 'Data/dt20_bra_x64.cpk', 'bra/string/all.str'),
                  (4, 'Data/dt20_bra_x64.cpk', 'bra/string/all.str'),
                  (5, 'Data/dt80_100E_x64.cpk', 'bra/string/all.str');
            """)
            rows = runtime.load_language(
                db, "Data/dt20_bra_x64.cpk", "%/string/%")
        self.assertEqual(rows, [
            ("Cancelar", "dialog-button"),
            ("Início", "menu-item-or-title"),
        ])

    def test_tsv_is_deterministic_utf8(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "pt.tsv"
            rows = [("Configurações", "control"), ("OK", "dialog-button")]
            runtime.write_lexicon(path, "pt", "Data/dt20_bra_x64.cpk", rows)
            first = path.read_bytes()
            runtime.write_lexicon(path, "pt", "Data/dt20_bra_x64.cpk", rows)
            self.assertEqual(path.read_bytes(), first)
            self.assertIn("control\tConfigurações".encode(), first)


if __name__ == "__main__":
    unittest.main()
