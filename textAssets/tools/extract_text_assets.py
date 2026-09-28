#!/usr/bin/env python3
"""Build an offline, searchable text-asset catalog for Football Life.

No game process is started and no source file is modified.  The scanner walks
every physical file, indexes every CPK member, extracts strings from likely
text-bearing data, and always scans PE executables/DLLs in full.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import os
import re
import shutil
import sqlite3
import struct
import sys
import time
import unicodedata
import zlib
from collections import Counter
from pathlib import Path


OUTPUT_NAME = "textAssets"
CHUNK_SIZE = 4 * 1024 * 1024
MAX_MEMBER_SIZE = 64 * 1024 * 1024

TEXT_EXTENSIONS = {
    ".txt", ".csv", ".tsv", ".xml", ".json", ".ini", ".cfg", ".vdf",
    ".lua", ".py", ".ps1", ".bat", ".cmd", ".md", ".html", ".htm",
    ".yml", ".yaml", ".toml", ".cmake", ".c", ".cc", ".cpp", ".h",
    ".hpp", ".def", ".rc", ".manifest", ".log", ".str", ".bin",
}
PE_EXTENSIONS = {".exe", ".dll"}
NON_TEXT_EXTENSIONS = {
    ".png", ".jpg", ".jpeg", ".bmp", ".dds", ".ftex", ".mp3", ".wav",
    ".ogg", ".mp4", ".bk2", ".usm", ".fmdl", ".geom", ".hkx", ".skl",
    ".gani", ".fpkd", ".obj", ".lib", ".pdb", ".zip", ".7z", ".rar",
}
LOCALE_NAMES = {
    "ara": "Arabic", "bra": "Portuguese (Brazil)", "chi": "Chinese (Simplified)",
    "eng": "English", "fra": "French", "ger": "German", "gre": "Greek",
    "ita": "Italian", "jpn": "Japanese", "kor": "Korean", "mex": "Spanish (Mexico)",
    "nld": "Dutch", "por": "Portuguese (Portugal)", "rus": "Russian",
    "spa": "Spanish", "swe": "Swedish", "tur": "Turkish", "zha": "Chinese (Traditional)",
}

BUTTON_WORDS = {
    "sim", "não", "yes", "no", "ok", "cancelar", "cancel", "voltar", "back",
    "confirmar", "confirm", "usar", "use", "fechar", "close", "continuar", "continue",
}
CONTROL_WORDS = {
    "volume", "brilho", "brightness", "câmera", "camera", "velocidade", "speed",
    "dificuldade", "difficulty", "controle", "controller", "cursor", "assistência",
    "assistance", "idioma", "language", "resolução", "resolution", "tela", "screen",
    "áudio", "audio", "música", "music", "comentário", "commentary", "configuração",
    "setting", "formation", "formação", "tática", "tactic",
}
INSTRUCTION_WORDS = {
    "pressione", "aperte", "selecione", "escolha", "mova", "use", "segure", "solte",
    "press", "select", "choose", "move", "hold", "release", "clique", "click",
}
DIALOG_WORDS = {
    "deseja", "tem certeza", "não será possível", "confirma", "would you like",
    "are you sure", "cannot be undone", "do you want", "confirmar", "aviso", "warning",
}
STATUS_WORDS = {
    "carregando", "loading", "salvando", "saving", "conectando", "connecting",
    "concluído", "complete", "erro", "error", "falhou", "failed", "aguarde", "please wait",
}


def json_dump(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True)


def clean_text(value: str) -> str:
    value = value.replace("\ufeff", "").replace("\u200b", "")
    value = re.sub(r"[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]", " ", value)
    return re.sub(r"\s+", " ", value).strip()


def useful_text(value: str, minimum: int = 2) -> bool:
    if len(value) < minimum or len(value) > 4096:
        return False
    if not any(ch.isalpha() for ch in value):
        return False
    printable = sum(ch.isprintable() for ch in value) / len(value)
    if printable < 0.96:
        return False
    letters = sum(ch.isalpha() for ch in value)
    controls = sum(unicodedata.category(ch).startswith("C") for ch in value)
    return letters >= 1 and controls == 0


def useful_binary_text(value: str) -> bool:
    """Reject printable coincidences from packed/encrypted executable data."""
    if len(value) < 8 or len(value) > 1024:
        return False
    letters = sum(ch.isalpha() for ch in value)
    alnum_space = sum(ch.isalnum() or ch.isspace() for ch in value)
    if alnum_space / len(value) < 0.68 or letters / len(value) < 0.42:
        return False
    if not any(ch.isspace() for ch in value):
        if letters / len(value) < 0.62:
            return False
        if not re.search(r"[aeiouAEIOU]", value) and not re.search(
                r"(?:dll|exe|pdb|xml|json|lua|ini|error|menu|text|string)", value,
                re.IGNORECASE):
            return False
    return True


def classify(text: str, source: str) -> tuple[str, float]:
    low = text.casefold()
    words = re.findall(r"[^\W_]+", low, re.UNICODE)
    word_count = len(words)
    if low in BUTTON_WORDS:
        return "dialog-button", 0.98
    if any(item in low for item in DIALOG_WORDS) or (text.endswith("?") and word_count >= 4):
        return "dialog", 0.90
    if any(item in low for item in INSTRUCTION_WORDS) and word_count >= 4:
        return "instruction", 0.88
    if any(item in low for item in STATUS_WORDS):
        return "status", 0.84
    if any(item in low for item in CONTROL_WORDS) and word_count <= 14:
        return "control", 0.82
    if re.search(r"(?:^|[\\/])[^\\/]+\.[a-z0-9]{1,8}$", low) or re.fullmatch(r"[A-Za-z_][\w.:/@\\-]+", text):
        return "technical", 0.88
    if any(token in low for token in ("http://", "https://", "copyright", "exception", "debug", "shader", "register")):
        return "technical", 0.85
    if word_count >= 12 or len(text) >= 90:
        return "tooltip-or-description", 0.68
    if word_count <= 7 and not re.search(r"[.!?;]", text):
        if any(part in source.casefold() for part in ("menu", "string", "all.str")):
            return "menu-item-or-title", 0.64
        return "label-or-name", 0.55
    return "text", 0.50


def locale_from_names(source: str, member: str | None) -> str | None:
    source_low = source.replace("\\", "/").casefold()
    member_low = (member or "").replace("\\", "/").casefold().lstrip("/")
    for code in LOCALE_NAMES:
        if re.search(rf"dt(?:17|20)[^/]*_{code}(?:_|\.)", source_low):
            return code
        if member_low.startswith(f"{code}/"):
            return code
        if re.search(rf"(?:^|/)sys_{code}\.str$", member_low):
            return code
    return None


def iter_utf8_strings(data: bytes, base_offset: int = 0, minimum: int = 2):
    start = 0
    chars: list[str] = []
    i = 0

    def flush(end):
        nonlocal chars, start
        if chars:
            value = clean_text("".join(chars))
            if useful_text(value, minimum):
                yield base_offset + start, value
        chars = []
        start = end

    while i < len(data):
        byte = data[i]
        char = None
        width = 1
        if byte == 9 or 0x20 <= byte <= 0x7E:
            char = chr(byte)
        elif 0xC2 <= byte <= 0xF4:
            width = 2 if byte <= 0xDF else 3 if byte <= 0xEF else 4
            if i + width <= len(data):
                try:
                    char = data[i:i + width].decode("utf-8")
                except UnicodeDecodeError:
                    char = None
        if char is not None and (char.isprintable() or char == "\t"):
            if not chars:
                start = i
            chars.append(char)
            i += width
        else:
            yield from flush(i + 1)
            i += 1
    yield from flush(len(data))


def iter_ascii_strings(data: bytes, base_offset: int = 0, minimum: int = 5):
    pattern = re.compile(rb"[\x20-\x7e]{%d,}" % minimum)
    for match in pattern.finditer(data):
        value = clean_text(match.group().decode("ascii"))
        if useful_text(value, minimum):
            yield base_offset + match.start(), value


def iter_utf16le_strings(data: bytes, base_offset: int = 0, minimum: int = 3):
    # PE wide literals are overwhelmingly ASCII-range UTF-16LE.  Requiring the
    # NUL high byte avoids treating arbitrary machine code as millions of fake
    # Unicode strings.  Full multilingual UI text comes from UTF-8 .str files.
    pattern = re.compile(rb"(?:[\x20-\x7e]\x00){%d,}" % minimum)
    for match in pattern.finditer(data):
        try:
            value = clean_text(match.group().decode("utf-16le"))
        except UnicodeDecodeError:
            continue
        if useful_text(value, minimum):
            yield base_offset + match.start(), value


def wesys_decompress(data: bytes) -> tuple[bytes, str]:
    # PES WESYS header is 00 10 01 + five-byte ASCII magic + two sizes.
    if len(data) >= 16 and data[3:8] == b"WESYS":
        try:
            return zlib.decompress(data[16:]), "wesys-zlib"
        except zlib.error:
            return data, "wesys-invalid"
    return data, "none"


class Catalog:
    def __init__(self, path: Path):
        self.db = sqlite3.connect(path)
        self.db.execute("PRAGMA journal_mode=WAL")
        self.db.execute("PRAGMA synchronous=OFF")
        self.db.execute("PRAGMA temp_store=MEMORY")
        self.db.executescript("""
            CREATE TABLE IF NOT EXISTS assets (
                id INTEGER PRIMARY KEY, sha1 TEXT UNIQUE, text TEXT NOT NULL,
                normalized TEXT NOT NULL, role TEXT NOT NULL, confidence REAL NOT NULL
            );
            CREATE TABLE IF NOT EXISTS occurrences (
                id INTEGER PRIMARY KEY, asset_id INTEGER NOT NULL, source_file TEXT NOT NULL,
                archive_member TEXT, byte_offset INTEGER, encoding TEXT NOT NULL,
                locale TEXT, extraction TEXT NOT NULL,
                FOREIGN KEY(asset_id) REFERENCES assets(id),
                UNIQUE(asset_id,source_file,archive_member,byte_offset,encoding,extraction)
            );
            CREATE TABLE IF NOT EXISTS files (
                path TEXT PRIMARY KEY, size INTEGER NOT NULL, extension TEXT,
                status TEXT NOT NULL, detail TEXT
            );
            CREATE TABLE IF NOT EXISTS archive_members (
                archive TEXT NOT NULL, member TEXT NOT NULL, size INTEGER NOT NULL,
                compressed_size INTEGER NOT NULL, status TEXT NOT NULL,
                PRIMARY KEY(archive, member)
            );
            CREATE INDEX IF NOT EXISTS occurrence_asset ON occurrences(asset_id);
            CREATE INDEX IF NOT EXISTS occurrence_source ON occurrences(source_file);
            CREATE INDEX IF NOT EXISTS occurrence_member ON occurrences(archive_member);
            CREATE INDEX IF NOT EXISTS occurrence_locale ON occurrences(locale);
            CREATE INDEX IF NOT EXISTS asset_role ON assets(role);
            CREATE INDEX IF NOT EXISTS asset_normalized ON assets(normalized);
        """)
        self.asset_cache: dict[str, int] = {}
        self.counts = Counter()

    def add_file(self, path, size, extension, status, detail=None):
        self.db.execute("INSERT OR REPLACE INTO files VALUES (?, ?, ?, ?, ?)",
                        (path, size, extension, status, detail))
        self.counts["files"] += 1

    def add_member(self, archive, member, size, compressed_size, status):
        self.db.execute("INSERT OR REPLACE INTO archive_members VALUES (?, ?, ?, ?, ?)",
                        (archive, member, size, compressed_size, status))
        self.counts["archive_members"] += 1

    def add_text(self, text, source, member, offset, encoding, locale, extraction):
        text = clean_text(text)
        if not useful_text(text):
            return
        normalized = unicodedata.normalize("NFKC", text).casefold()
        digest = hashlib.sha1(normalized.encode("utf-8")).hexdigest()
        asset_id = self.asset_cache.get(digest)
        if asset_id is None:
            row = self.db.execute("SELECT id FROM assets WHERE sha1=?", (digest,)).fetchone()
            if row:
                asset_id = row[0]
            else:
                role, confidence = classify(text, member or source)
                asset_id = self.db.execute(
                    "INSERT INTO assets(sha1,text,normalized,role,confidence) VALUES(?,?,?,?,?)",
                    (digest, text, normalized, role, confidence)).lastrowid
                self.counts[f"role:{role}"] += 1
            self.asset_cache[digest] = asset_id
        self.db.execute("""INSERT OR IGNORE INTO occurrences
            (asset_id,source_file,archive_member,byte_offset,encoding,locale,extraction)
            VALUES(?,?,?,?,?,?,?)""",
            (asset_id, source, member or "", offset, encoding, locale, extraction))

    def close(self):
        self.db.commit()
        self.db.execute("PRAGMA optimize")
        self.db.close()


def scan_buffer(catalog, data, source, member=None, extraction="binary-scan", base=0,
                minimum=4, allow_unicode=False):
    locale = locale_from_names(source, member)
    seen = set()
    byte_iterator = (iter_utf8_strings(data, base, minimum) if allow_unicode
                     else iter_ascii_strings(data, base, max(8, minimum)))
    for encoding, iterator in (
        ("utf-8" if allow_unicode else "ascii", byte_iterator),
        ("utf-16le", iter_utf16le_strings(data, base, max(3, minimum))),
    ):
        for offset, value in iterator:
            if not allow_unicode and not useful_binary_text(value):
                continue
            key = (offset, value)
            if key in seen:
                continue
            seen.add(key)
            catalog.add_text(value, source, member, offset, encoding, locale, extraction)


def scan_stream(catalog, path: Path, relative: str):
    overlap = b""
    position = 0
    with path.open("rb") as stream:
        while True:
            chunk = stream.read(CHUNK_SIZE)
            if not chunk:
                break
            data = overlap + chunk
            base = max(0, position - len(overlap))
            allow_unicode = (path.suffix.casefold() in TEXT_EXTENSIONS
                             and path.suffix.casefold() != ".bin")
            scan_buffer(catalog, data, relative, base=base, minimum=4,
                        allow_unicode=allow_unicode)
            overlap = data[-8192:]
            position += len(chunk)


def pe_sections(path: Path):
    with path.open("rb") as stream:
        header = stream.read(4096)
        if len(header) < 64 or header[:2] != b"MZ":
            raise ValueError("missing MZ header")
        pe_offset = struct.unpack_from("<I", header, 0x3C)[0]
        stream.seek(pe_offset)
        pe_header = stream.read(24)
        if len(pe_header) != 24 or pe_header[:4] != b"PE\0\0":
            raise ValueError("missing PE signature")
        section_count = struct.unpack_from("<H", pe_header, 6)[0]
        optional_size = struct.unpack_from("<H", pe_header, 20)[0]
        stream.seek(pe_offset + 24 + optional_size)
        result = []
        for _ in range(section_count):
            raw = stream.read(40)
            if len(raw) != 40:
                break
            name = raw[:8].split(b"\0", 1)[0].decode("ascii", "replace")
            raw_size, raw_offset = struct.unpack_from("<II", raw, 16)
            characteristics = struct.unpack_from("<I", raw, 36)[0]
            result.append((name, raw_offset, raw_size, characteristics))
        return result


def sample_entropy(stream, offset: int, size: int) -> float:
    stream.seek(offset)
    sample = stream.read(min(size, 1024 * 1024))
    if not sample:
        return 0.0
    counts = Counter(sample)
    total = len(sample)
    return -sum((count / total) * math.log2(count / total) for count in counts.values())


def scan_pe(catalog, path: Path, relative: str) -> str:
    scanned = []
    skipped = []
    try:
        sections = pe_sections(path)
    except Exception as error:
        scan_stream(catalog, path, relative)
        return json_dump({"fallback": "whole-file", "error": str(error)})
    with path.open("rb") as stream:
        for name, offset, size, characteristics in sections:
            is_code = bool(characteristics & 0x20)
            entropy = sample_entropy(stream, offset, size)
            label = {"name": name, "offset": offset, "size": size,
                     "entropy": round(entropy, 3)}
            if not size or is_code or entropy >= 7.55:
                label["reason"] = "code" if is_code else "high-entropy-or-empty"
                skipped.append(label)
                continue
            stream.seek(offset)
            remaining = size
            overlap = b""
            consumed = 0
            while remaining:
                chunk = stream.read(min(CHUNK_SIZE, remaining))
                if not chunk:
                    break
                data = overlap + chunk
                scan_buffer(catalog, data, relative, extraction=f"pe-section:{name}",
                            base=offset + consumed - len(overlap), minimum=8,
                            allow_unicode=False)
                overlap = data[-8192:]
                consumed += len(chunk)
                remaining -= len(chunk)
            scanned.append(label)
    return json_dump({"scanned_sections": scanned, "skipped_sections": skipped})


def load_cpk_support(root: Path):
    lib = root / "FLAccess" / "reference" / "pes-file-tools" / "lib"
    if not lib.exists():
        return None
    sys.path.insert(0, str(lib))
    try:
        from pes_file_tools.cpk import CpkReader
        return CpkReader
    except Exception:
        return None


def scan_cpk(catalog, root: Path, path: Path, relative: str, CpkReader):
    reader = CpkReader()
    try:
        reader.open(str(path))
    except Exception as error:
        catalog.add_file(relative, path.stat().st_size, ".cpk", "cpk-error", str(error))
        return
    extracted = 0
    for entry in reader.files:
        suffix = Path(entry.name).suffix.casefold()
        should_scan = suffix in TEXT_EXTENSIONS and entry.size <= MAX_MEMBER_SIZE
        status = "indexed"
        if should_scan:
            try:
                data = reader.readFile(entry)
                data, container = wesys_decompress(data)
                member_unicode = suffix != ".bin"
                scan_buffer(catalog, data, relative, entry.name, f"cpk/{container}",
                            minimum=2 if suffix == ".str" else 8 if suffix == ".bin" else 4,
                            allow_unicode=member_unicode)
                status = "text-scanned"
                extracted += 1
            except Exception as error:
                status = "scan-error:" + type(error).__name__
        elif entry.size > MAX_MEMBER_SIZE:
            status = "indexed-size-limit"
        elif suffix in NON_TEXT_EXTENSIONS:
            status = "indexed-non-text"
        catalog.add_member(relative, entry.name, entry.size, entry.compressedSize, status)
    reader.close()
    catalog.add_file(relative, path.stat().st_size, ".cpk", "archive-indexed", f"members={len(reader.files)} scanned={extracted}")


def export_catalog(db_path: Path, output: Path):
    db = sqlite3.connect(db_path)
    db.row_factory = sqlite3.Row
    roles = [row[0] for row in db.execute("SELECT DISTINCT role FROM assets ORDER BY role")]
    role_dir = output / "by-role"
    locale_dir = output / "localization"
    role_dir.mkdir(exist_ok=True)
    locale_dir.mkdir(exist_ok=True)
    query = """SELECT a.id,a.text,a.role,a.confidence,COUNT(o.id) occurrence_count,
        MIN(o.source_file) example_source,MIN(COALESCE(o.archive_member,'')) example_member
        FROM assets a JOIN occurrences o ON o.asset_id=a.id WHERE a.role=?
        GROUP BY a.id ORDER BY a.normalized"""
    for role in roles:
        with (role_dir / f"{role}.jsonl").open("w", encoding="utf-8", newline="\n") as out:
            for row in db.execute(query, (role,)):
                out.write(json_dump(dict(row)) + "\n")
    locales = [row[0] for row in db.execute("SELECT DISTINCT locale FROM occurrences WHERE locale IS NOT NULL ORDER BY locale")]
    locale_query = """SELECT a.id,a.text,a.role,a.confidence,o.source_file,o.archive_member,
        o.byte_offset,o.encoding,o.extraction FROM occurrences o
        JOIN assets a ON a.id=o.asset_id WHERE o.locale=?
        ORDER BY o.source_file,o.archive_member,o.byte_offset"""
    for locale in locales:
        with (locale_dir / f"{locale}.jsonl").open("w", encoding="utf-8", newline="\n") as out:
            for row in db.execute(locale_query, (locale,)):
                out.write(json_dump(dict(row)) + "\n")
    with (output / "files.csv").open("w", encoding="utf-8-sig", newline="") as out:
        writer = csv.writer(out)
        writer.writerow(("path", "size", "extension", "status", "detail"))
        writer.writerows(db.execute("SELECT path,size,extension,status,detail FROM files ORDER BY path"))
    with (output / "cpk-members.csv").open("w", encoding="utf-8-sig", newline="") as out:
        writer = csv.writer(out)
        writer.writerow(("archive", "member", "size", "compressed_size", "status"))
        writer.writerows(db.execute("SELECT archive,member,size,compressed_size,status FROM archive_members ORDER BY archive,member"))
    summary = {
        "generated_at": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
        "unique_assets": db.execute("SELECT COUNT(*) FROM assets").fetchone()[0],
        "occurrences": db.execute("SELECT COUNT(*) FROM occurrences").fetchone()[0],
        "physical_files": db.execute("SELECT COUNT(*) FROM files").fetchone()[0],
        "cpk_members": db.execute("SELECT COUNT(*) FROM archive_members").fetchone()[0],
        "roles": dict(db.execute("SELECT role,COUNT(*) FROM assets GROUP BY role ORDER BY role")),
        "locales": {row[0]: {"name": LOCALE_NAMES.get(row[0], row[0]), "occurrences": row[1]}
                    for row in db.execute("SELECT locale,COUNT(*) FROM occurrences WHERE locale IS NOT NULL GROUP BY locale")},
        "file_status": dict(db.execute("SELECT status,COUNT(*) FROM files GROUP BY status ORDER BY status")),
        "member_status": dict(db.execute("SELECT status,COUNT(*) FROM archive_members GROUP BY status ORDER BY status")),
    }
    (output / "manifest.json").write_text(json_dump(summary) + "\n", encoding="utf-8")
    db.close()
    return summary


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--output", type=Path)
    parser.add_argument("--quick", action="store_true", help="Only CPK localization, PE, scripts, configs, and documents")
    parser.add_argument("--resume", action="store_true", help="Keep completed records and continue an interrupted scan")
    args = parser.parse_args()
    root = args.root.resolve()
    output = (args.output or root / OUTPUT_NAME).resolve()
    output.mkdir(parents=True, exist_ok=True)
    db_path = output / "catalog.sqlite"
    if not args.resume:
        for old in (db_path, db_path.with_suffix(".sqlite-wal"), db_path.with_suffix(".sqlite-shm")):
            if old.exists():
                old.unlink()
        for old_dir in (output / "by-role", output / "localization"):
            if old_dir.exists():
                shutil.rmtree(old_dir)
    catalog = Catalog(db_path)
    if args.resume:
        catalog.db.execute("""DELETE FROM occurrences
            WHERE source_file LIKE 'FLAccess/reference/%'
               OR source_file LIKE 'FLAccess/release/%'""")
        catalog.db.execute("""DELETE FROM assets WHERE NOT EXISTS
            (SELECT 1 FROM occurrences o WHERE o.asset_id=assets.id)""")
        catalog.db.execute("""DELETE FROM files
            WHERE path LIKE 'FLAccess/reference/%'
               OR path LIKE 'FLAccess/release/%'""")
        catalog.db.commit()
    CpkReader = load_cpk_support(root)
    files = []
    for path in root.rglob("*"):
        if not path.is_file():
            continue
        try:
            path.relative_to(output)
            continue
        except ValueError:
            pass
        if ".git" in path.parts:
            continue
        files.append(path)
    for index, path in enumerate(files, 1):
        relative = path.relative_to(root).as_posix()
        if args.resume and catalog.db.execute(
                "SELECT 1 FROM files WHERE path=?", (relative,)).fetchone():
            continue
        suffix = path.suffix.casefold()
        size = path.stat().st_size
        try:
            if relative.startswith(("FLAccess/reference/", "FLAccess/release/")):
                catalog.add_file(relative, size, suffix,
                                 "indexed-development-reference")
            elif suffix == ".cpk":
                if CpkReader:
                    scan_cpk(catalog, root, path, relative, CpkReader)
                else:
                    catalog.add_file(relative, size, suffix, "cpk-support-missing")
            elif suffix in PE_EXTENSIONS:
                detail = scan_pe(catalog, path, relative)
                catalog.add_file(relative, size, suffix, "pe-section-scan", detail)
            elif suffix in TEXT_EXTENSIONS:
                if args.quick and size > MAX_MEMBER_SIZE:
                    catalog.add_file(relative, size, suffix, "indexed-quick-size-limit")
                else:
                    scan_stream(catalog, path, relative)
                    catalog.add_file(relative, size, suffix, "text-full-scan")
            elif not args.quick and suffix not in NON_TEXT_EXTENSIONS and size <= MAX_MEMBER_SIZE:
                scan_stream(catalog, path, relative)
                catalog.add_file(relative, size, suffix, "binary-scan")
            else:
                reason = "indexed-non-text" if suffix in NON_TEXT_EXTENSIONS else "indexed-quick"
                catalog.add_file(relative, size, suffix, reason)
        except Exception as error:
            catalog.add_file(relative, size, suffix, "scan-error",
                             f"{type(error).__name__}: {error}")
        if index % 1000 == 0:
            catalog.db.commit()
        if index % 1000 == 0:
            print(f"[{index}/{len(files)}] {relative}", flush=True)
    catalog.close()
    summary = export_catalog(db_path, output)
    print(json_dump(summary))


if __name__ == "__main__":
    main()
