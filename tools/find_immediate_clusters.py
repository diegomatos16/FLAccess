#!/usr/bin/env python3
"""Find little-endian 32-bit immediates in executable PE sections."""

from __future__ import annotations

import argparse
import mmap
from pathlib import Path

import pefile


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("exe", type=Path)
    parser.add_argument("values", nargs="+", type=lambda value: int(value, 0))
    args = parser.parse_args()

    pe = pefile.PE(str(args.exe), fast_load=True)
    executable = [
        section
        for section in pe.sections
        if section.Characteristics & 0x20000000 and section.SizeOfRawData
    ]
    with args.exe.open("rb") as stream, mmap.mmap(
        stream.fileno(), 0, access=mmap.ACCESS_READ
    ) as data:
        for value in args.values:
            pattern = value.to_bytes(4, "little", signed=False)
            matches: list[int] = []
            for section in executable:
                start = section.PointerToRawData
                finish = start + section.SizeOfRawData
                cursor = start
                while True:
                    raw = data.find(pattern, cursor, finish)
                    if raw < 0:
                        break
                    matches.append(section.VirtualAddress + raw - start)
                    cursor = raw + 1
            print(f"{value}: " + " ".join(f"0x{rva:x}" for rva in matches))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
