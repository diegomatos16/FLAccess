"""Extract only native playing-style IDs from the owned game's locale archives."""
from pathlib import Path
import argparse
import hashlib
import json
import struct
import sys

ROOT = Path(__file__).resolve().parents[1]


def parse_string_bundle(data):
    if len(data) < 8:
        raise ValueError("Truncated string bundle")
    count, start = struct.unpack_from("<II", data)
    if count > 4096 or start < 8 or start + count * 12 > len(data):
        raise ValueError("Invalid group table")
    result = {}
    for index in range(count):
        offset, size, name = struct.unpack_from("<III", data, start + index * 12)
        if name >= len(data) or data.find(b"\0", name) < 0 or size < 8 or offset + size > len(data):
            raise ValueError("Invalid group range")
        group = data[offset:offset + size]
        entries, group_id = struct.unpack_from("<II", group)
        if group_id > 65535 or entries > 65536 or 8 + entries * 12 > len(group):
            raise ValueError("Invalid group header")
        for item in range(entries):
            key, byte_count, char_count, pointer = struct.unpack_from("<IHHI", group, 8 + item * 12)
            if key > 65535 or pointer < 8 + entries * 12 or pointer + byte_count > len(group):
                raise ValueError("Invalid string range")
            raw = group[pointer:pointer + byte_count]
            if not raw.endswith(b"\0"):
                raise ValueError("Unterminated string")
            text = raw[:-1].decode("utf-8")
            string_id = group_id << 16 | key
            if string_id in result and result[string_id] != text:
                raise ValueError("Ambiguous localization ID")
            result[string_id] = text
    return result


def build(game_root, output):
    sys.path.insert(0, str(ROOT / ".python"))
    sys.path.insert(0, str(ROOT / "reference/pes-file-tools/lib"))
    import pefile
    from pes_file_tools import cpk, zlib as wesys
    game_root, output = Path(game_root), Path(output)
    exe = pefile.PE(str(game_root / "FL_2026.exe"), fast_load=True)
    ids = [struct.unpack("<I", exe.get_data(0x27d3500 + index * 8, 4))[0] for index in range(22)]
    if len(set(ids)) != 22 or not all(ids):
        raise ValueError("Unsupported native style ID table")
    output.mkdir(parents=True, exist_ok=True)
    evidence = {"native_table_rva": "0x27d3500", "ids": ids, "languages": {}}
    for language, locale in (("pt", "bra"), ("en", "eng")):
        archive = game_root / "Data" / f"dt20_{locale}_x64.cpk"
        reader = cpk.CpkReader()
        reader.open(archive)
        member = f"{locale}/string/all.str"
        matches = [entry for entry in reader.files if entry.name.replace("\\", "/") == member]
        if len(matches) != 1:
            raise ValueError("Missing or ambiguous string member")
        data = wesys.tryDecompress(reader.readFile(matches[0]))
        reader.close()
        catalog = parse_string_bundle(data)
        rows = []
        for string_id in ids:
            text = catalog[string_id]
            if not text or any(character in text for character in "\t\r\n"):
                raise ValueError("Invalid style label")
            rows.append(f"{string_id}\t{text}\n")
        path = output / f"styles-{language}.tsv"
        path.write_text("# Native FL2026 playing styles; localization-ID<TAB>exact game text\n" + "".join(rows), encoding="utf-8")
        evidence["languages"][language] = {"archive": archive.name, "archive_sha256": hashlib.sha256(archive.read_bytes()).hexdigest(),
            "member": member, "bundle_sha256": hashlib.sha256(data).hexdigest(), "asset_sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "count": len(rows)}
    return evidence


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--game-root", type=Path, default=ROOT.parent)
    parser.add_argument("--output", type=Path, default=ROOT / "livecpk/FlAccessReader/text")
    args = parser.parse_args()
    print(json.dumps(build(args.game_root, args.output), indent=2))
