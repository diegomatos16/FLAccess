#!/usr/bin/env python3
"""Summarize structural UI identifiers from FLAccess diagnostic logs.

Read-only: old logs can recover short MSVC widget names from raw qwords;
new logs provide widget_internal_name directly. No role is inferred for speech.
"""

from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import json
from pathlib import Path
import re


EVENT = re.compile(r"(?m)^EVENT (?P<number>\d+) (?P<header>[^\r\n]+)")
QWORD = re.compile(r"\+(0x[0-9a-f]+)=(0x[0-9a-f]+)", re.I)
NAME = re.compile(r"^[A-Za-z0-9_.-]{2,64}$")


def _old_internal_name(block: str) -> str | None:
    raw = re.search(r"raw_qwords=\{([^}]+)\}", block)
    if not raw:
        return None
    words = {int(offset, 16): int(value, 16)
             for offset, value in QWORD.findall(raw.group(1))}
    length, capacity = words.get(0x28), words.get(0x30)
    if length is None or capacity != 15 or not 2 <= length <= 15:
        return None
    if 0x18 not in words or 0x20 not in words:
        return None
    data = words[0x18].to_bytes(8, "little") + words[0x20].to_bytes(8, "little")
    try:
        name = data[:length].decode("ascii")
    except UnicodeDecodeError:
        return None
    return name if NAME.fullmatch(name) else None


def parse_events(log_text: str) -> list[dict[str, str]]:
    matches = list(EVENT.finditer(log_text))
    events: list[dict[str, str]] = []
    for index, match in enumerate(matches):
        block = log_text[match.start():
                         matches[index + 1].start() if index + 1 < len(matches)
                         else len(log_text)]
        role = re.search(r"\brole=([^\s]+)", match.group("header"))
        caption = re.search(r'(?m)^text="(.*?)"\r?$', block)
        vtable = re.search(r"\bvtable_rva=([^\s]+)", block)
        explicit = re.search(r'(?m)^widget_internal_name="(.*?)"', block)
        name = explicit.group(1) if explicit else _old_internal_name(block)
        relation = re.search(r"(?m)^widget_relation_candidate=(0x[0-9a-f]+)",
                             block, re.I)
        if not relation:
            relation = re.search(r"\+0x38=(0x[0-9a-f]+)", block, re.I)
        if not role or not caption or not vtable:
            continue
        events.append({
            "role": role.group(1),
            "text": caption.group(1),
            "vtable": vtable.group(1),
            "internal_name": name or "",
            "relation_candidate": relation.group(1).lower() if relation else "",
        })
    return events


def summarize(events: list[dict[str, str]]) -> dict:
    names: dict[str, Counter[str]] = defaultdict(Counter)
    vtables: dict[str, Counter[str]] = defaultdict(Counter)
    relations: dict[str, Counter[str]] = defaultdict(Counter)
    for event in events:
        vtables[event["vtable"]][event["role"]] += 1
        if event["internal_name"]:
            names[event["internal_name"]][event["role"]] += 1
        if event["relation_candidate"]:
            relations[event["relation_candidate"]][event["internal_name"]
                                                   or event["role"]] += 1
    return {
        "events": len(events),
        "internal_name_coverage": sum(bool(event["internal_name"])
                                      for event in events),
        "names": {key: dict(sorted(value.items()))
                  for key, value in sorted(names.items())},
        "vtables": {key: dict(sorted(value.items()))
                    for key, value in sorted(vtables.items())},
        "relation_candidates": {
            key: {"events": sum(value.values()),
                  "names_or_roles": dict(sorted(value.items()))}
            for key, value in sorted(relations.items())
            if sum(value.values()) >= 2},
        "ambiguous_names": sorted(key for key, roles in names.items()
                                  if len(roles) > 1),
        "mixed_role_vtables": sorted(key for key, roles in vtables.items()
                                     if len(roles) > 1),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("logs", nargs="+", type=Path)
    args = parser.parse_args()
    events = []
    for path in args.logs:
        events.extend(parse_events(path.read_text(encoding="utf-8",
                                                  errors="replace")))
    print(json.dumps(summarize(events), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
