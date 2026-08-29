#!/usr/bin/env python3
"""Find direct x64 RIP-relative code references to strings in a PE file."""

from __future__ import annotations

import argparse
import mmap
import struct
from pathlib import Path

import pefile


def occurrences(data: mmap.mmap, needle: bytes):
    cursor = 0
    while True:
        found = data.find(needle, cursor)
        if found < 0:
            return
        yield found
        cursor = found + 1


def section_for_raw(pe: pefile.PE, raw: int):
    for section in pe.sections:
        start = section.PointerToRawData
        if start <= raw < start + section.SizeOfRawData:
            return section
    return None


def executable_sections(pe: pefile.PE):
    for section in pe.sections:
        if section.Characteristics & 0x20000000 and section.SizeOfRawData:
            yield section


def rip_xrefs_many(pe: pefile.PE, data: mmap.mmap, target_vas: set[int]):
    image_base = pe.OPTIONAL_HEADER.ImageBase
    for section in executable_sections(pe):
        raw_start = section.PointerToRawData
        raw_finish = min(len(data), raw_start + section.SizeOfRawData)
        for rex in range(0x40, 0x50):
            for opcode in (0x8B, 0x8D):
                prefix = bytes((rex, opcode))
                cursor = raw_start
                while True:
                    raw = data.find(prefix, cursor, raw_finish)
                    if raw < 0 or raw + 7 > raw_finish:
                        break
                    modrm = data[raw + 2]
                    if modrm & 0xC7 == 0x05:
                        displacement = struct.unpack_from("<i", data, raw + 3)[0]
                        instruction_va = (
                            image_base + section.VirtualAddress + raw - raw_start
                        )
                        target_va = instruction_va + 7 + displacement
                        if target_va in target_vas:
                            name = section.Name.rstrip(b"\0").decode(
                                "ascii", errors="replace"
                            )
                            yield target_va, instruction_va, raw, name
                    cursor = raw + 1


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("exe", type=Path)
    parser.add_argument("terms", nargs="+")
    args = parser.parse_args()

    pe = pefile.PE(str(args.exe), fast_load=True)
    image_base = pe.OPTIONAL_HEADER.ImageBase
    with args.exe.open("rb") as stream, mmap.mmap(
        stream.fileno(), 0, access=mmap.ACCESS_READ
    ) as data:
        found_strings = []
        for term in args.terms:
            for encoding in ("utf-8", "utf-16le"):
                needle = term.encode(encoding)
                for raw in occurrences(data, needle):
                    section = section_for_raw(pe, raw)
                    if section is None:
                        print(f"{term} {encoding} raw=0x{raw:x} section=none")
                        continue
                    rva = section.VirtualAddress + raw - section.PointerToRawData
                    va = image_base + rva
                    section_name = section.Name.rstrip(b"\0").decode(
                        "ascii", errors="replace"
                    )
                    found_strings.append((term, encoding, raw, va, section_name))

        refs_by_target: dict[int, list[tuple[int, int, str]]] = {}
        targets = {entry[3] for entry in found_strings}
        for target, ref_va, ref_raw, ref_section in rip_xrefs_many(pe, data, targets):
            refs_by_target.setdefault(target, []).append((ref_va, ref_raw, ref_section))

        for term, encoding, raw, va, section_name in found_strings:
                    refs = refs_by_target.get(va, [])
                    print(
                        f"{term} {encoding} raw=0x{raw:x} va=0x{va:x} "
                        f"section={section_name} xrefs={len(refs)}"
                    )
                    for ref_va, ref_raw, ref_section in refs[:40]:
                        context = bytes(
                            data[max(0, ref_raw - 16) : ref_raw + 24]
                        ).hex(" ")
                        print(
                            f"  xref=0x{ref_va:x} section={ref_section} bytes={context}"
                        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
