#!/usr/bin/env python3
"""Build compact FLAccess runtime lexicons from the full textAssets catalog."""

from __future__ import annotations

import argparse
import sqlite3
from pathlib import Path


LANGUAGES = {
    "pt": ("Data/dt20_bra_x64.cpk", "%/string/%"),
    "en": ("Data/dt20_eng_x64.cpk", "%/string/%"),
}

ROLE_PRIORITY = {
    "dialog-button": 0,
    "control": 1,
    "instruction": 2,
    "dialog": 3,
    "status": 4,
    "tooltip-or-description": 5,
    "menu-item-or-title": 6,
    "label-or-name": 7,
    "text": 8,
}


def safe_text(value: str) -> str:
    return " ".join(value.replace("\ufeff", "").split())


def load_language(connection: sqlite3.Connection, source: str, member: str):
    rows = connection.execute(
        """
        SELECT a.text, a.role
        FROM assets AS a
        JOIN occurrences AS o ON o.asset_id = a.id
        WHERE o.source_file = ?
          AND o.archive_member LIKE ?
          AND a.role != 'technical'
        GROUP BY a.text, a.role
        """,
        (source, member),
    )
    selected: dict[str, str] = {}
    for raw_text, role in rows:
        text = safe_text(raw_text)
        if not text or "\t" in text:
            continue
        old_role = selected.get(text)
        if old_role is None or ROLE_PRIORITY.get(role, 99) < ROLE_PRIORITY.get(old_role, 99):
            selected[text] = role
    return sorted(selected.items(), key=lambda item: (item[0].casefold(), item[0]))


def write_lexicon(path: Path, language: str, source: str, rows) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as output:
        output.write("# FLAccess runtime text roles v1\n")
        output.write(f"# language={language} source={source}\n")
        output.write("# format: role<TAB>exact game text\n")
        for text, role in rows:
            output.write(f"{role}\t{text}\n")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog", type=Path, default=Path("textAssets/catalog.sqlite"))
    parser.add_argument(
        "--output",
        type=Path,
        action="append",
        default=None,
        help="Output FLAccess-text directory; repeat for deployed and source trees.",
    )
    args = parser.parse_args()
    outputs = args.output or [
        Path("SiderAddons/modules/FLAccess-text"),
        Path("FLAccess/modules/FLAccess-text"),
    ]

    connection = sqlite3.connect(f"file:{args.catalog.resolve()}?mode=ro", uri=True)
    try:
        for language, (source, member) in LANGUAGES.items():
            rows = load_language(connection, source, member)
            for output in outputs:
                write_lexicon(output / f"{language}.tsv", language, source, rows)
            print(f"{language}: {len(rows)} texts")
    finally:
        connection.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
