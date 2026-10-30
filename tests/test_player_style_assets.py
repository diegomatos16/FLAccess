import importlib.util
from pathlib import Path
import struct
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("style_assets", ROOT / "tools/build_player_style_assets.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


def bundle(text="Ala produtivo", duplicate=None):
    encoded = text.encode("utf-8") + b"\0"
    rows = [(7, encoded)]
    if duplicate is not None:
        rows.append((7, duplicate.encode("utf-8") + b"\0"))
    offset = 8 + len(rows) * 12
    group = bytearray(struct.pack("<II", len(rows), 37))
    strings = b""
    for key, raw in rows:
        group += struct.pack("<IHHI", key, len(raw), len(raw[:-1].decode("utf-8")), offset + len(strings))
        strings += raw
    group += strings
    return struct.pack("<IIIII", 1, 8, 22, len(group), 20) + b"x\0" + group


class PlayerStyleAssets(unittest.TestCase):
    def test_group_id_is_not_outer_index_and_utf8_is_preserved(self):
        self.assertEqual(module.parse_string_bundle(bundle("Criação")), {(37 << 16) | 7: "Criação"})

    def test_truncation_bad_offsets_and_missing_terminators_are_rejected(self):
        data = bundle()
        variants = [data[:5], data[:-1], data[:8] + struct.pack("<I", 0xFFFFFFFF) + data[12:], data[:-1] + b"x"]
        for invalid in variants:
            with self.subTest(size=len(invalid)), self.assertRaises(ValueError):
                module.parse_string_bundle(invalid)

    def test_conflicting_localization_id_is_not_chosen_by_order(self):
        with self.assertRaises(ValueError):
            module.parse_string_bundle(bundle(duplicate="Outro estilo"))

    def test_invalid_utf8_is_rejected(self):
        with self.assertRaises(UnicodeDecodeError):
            module.parse_string_bundle(bundle().replace(b"Ala", b"\xffla"))

    def test_shipped_languages_cover_exact_same_22_native_ids(self):
        catalogs = {}
        for language in ("pt", "en"):
            rows = [line.split("\t") for line in (ROOT / f"livecpk/FlAccessReader/text/styles-{language}.tsv").read_text(encoding="utf-8").splitlines() if not line.startswith("#")]
            catalogs[language] = {int(key): value for key, value in rows}
            self.assertEqual(len(rows), 22)
            self.assertEqual(len(catalogs[language]), 22)
        self.assertEqual(catalogs["pt"].keys(), catalogs["en"].keys())
        self.assertEqual(catalogs["pt"][2424927], "Ala produtivo")
        self.assertEqual(catalogs["en"][2424927], "Prolific Winger")


if __name__ == "__main__":
    unittest.main()
