#!/usr/bin/env python3
"""Offline analysis of PES/Football Life string-copy call sites."""

from __future__ import annotations

import argparse
import collections
import mmap
import struct
from pathlib import Path

import pefile
from capstone import CS_ARCH_X86, CS_MODE_64, CS_OP_MEM, Cs


PATTERNS = {
    "ball_name": bytes.fromhex(
        "80 79 04 00 48 8d 51 04 75 12 45 31 c0 48 89 c1"
    ),
    "stadium_name": bytes.fromhex("80 79 08 00 48 8d 51 08 75 12"),
}


def all_offsets(data: mmap.mmap, pattern: bytes) -> list[int]:
    result: list[int] = []
    cursor = 0
    while True:
        found = data.find(pattern, cursor)
        if found < 0:
            return result
        result.append(found)
        cursor = found + 1


def raw_to_rva(pe: pefile.PE, raw_offset: int) -> int:
    for section in pe.sections:
        start = section.PointerToRawData
        finish = start + section.SizeOfRawData
        if start <= raw_offset < finish:
            return section.VirtualAddress + raw_offset - start
    raise ValueError(f"raw offset is not in a section: 0x{raw_offset:x}")


def find_near_call(data: mmap.mmap, pattern_offset: int, pattern_length: int) -> int:
    start = pattern_offset + pattern_length
    finish = min(len(data), start + 32)
    found = data.find(b"\xe8", start, finish)
    if found < 0:
        raise ValueError(f"no nearby CALL after raw offset 0x{pattern_offset:x}")
    return found


def direct_call_target(image_base: int, call_rva: int, data: mmap.mmap, raw: int) -> int:
    relative = struct.unpack_from("<i", data, raw + 1)[0]
    return image_base + call_rva + 5 + relative


def executable_sections(pe: pefile.PE):
    execute = 0x20000000
    for section in pe.sections:
        if section.Characteristics & execute and section.SizeOfRawData:
            yield section


def find_direct_xrefs(
    pe: pefile.PE, data: mmap.mmap, image_base: int, target: int
) -> list[tuple[int, int, str]]:
    result: list[tuple[int, int, str]] = []
    for section in executable_sections(pe):
        raw_start = section.PointerToRawData
        raw_finish = min(len(data), raw_start + section.SizeOfRawData)
        cursor = raw_start
        while True:
            raw = data.find(b"\xe8", cursor, raw_finish)
            if raw < 0 or raw + 5 > raw_finish:
                break
            rva = section.VirtualAddress + raw - raw_start
            if direct_call_target(image_base, rva, data, raw) == target:
                name = section.Name.rstrip(b"\0").decode("ascii", errors="replace")
                result.append((image_base + rva, raw, name))
            cursor = raw + 1
    return result


def disassemble_at(pe: pefile.PE, data: mmap.mmap, va: int, size: int = 192) -> list[str]:
    image_base = pe.OPTIONAL_HEADER.ImageBase
    rva = va - image_base
    raw = pe.get_offset_from_rva(rva)
    code = data[raw : raw + size]
    decoder = Cs(CS_ARCH_X86, CS_MODE_64)
    return [
        f"0x{ins.address:016x}  {ins.bytes.hex(' '):24}  {ins.mnemonic:8} {ins.op_str}"
        for ins in decoder.disasm(code, va)
    ]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("exe", type=Path)
    parser.add_argument("--samples", type=int, default=20)
    parser.add_argument("--at", type=lambda value: int(value, 0))
    parser.add_argument("--pointer-xref", type=lambda value: int(value, 0))
    parser.add_argument("--qwords-at", type=lambda value: int(value, 0))
    parser.add_argument("--disp-xrefs", type=lambda value: int(value, 0))
    parser.add_argument("--direct-xrefs", type=lambda value: int(value, 0))
    parser.add_argument("--size", type=int, default=512)
    args = parser.parse_args()

    pe = pefile.PE(str(args.exe), fast_load=True)
    image_base = pe.OPTIONAL_HEADER.ImageBase
    with args.exe.open("rb") as stream, mmap.mmap(
        stream.fileno(), 0, access=mmap.ACCESS_READ
    ) as data:
        if args.direct_xrefs is not None:
            address = args.direct_xrefs
            if address < image_base:
                address += image_base
            xrefs = find_direct_xrefs(pe, data, image_base, address)
            print(f"target=0x{address:x} direct_xrefs={len(xrefs)}")
            for va, raw, section in xrefs:
                before = bytes(data[max(0, raw - 20) : raw]).hex(" ")
                after = bytes(data[raw + 5 : raw + 17]).hex(" ")
                print(
                    f"xref=0x{va:x} section={section} before={before} after={after}"
                )
            return 0
        if args.disp_xrefs is not None:
            decoder = Cs(CS_ARCH_X86, CS_MODE_64)
            decoder.detail = True
            for section in executable_sections(pe):
                raw = section.PointerToRawData
                code = data[raw : raw + section.SizeOfRawData]
                va = image_base + section.VirtualAddress
                for ins in decoder.disasm(code, va):
                    if any(
                        operand.type == CS_OP_MEM
                        and operand.mem.disp == args.disp_xrefs
                        for operand in ins.operands
                    ):
                        print(
                            f"0x{ins.address:016x}  {ins.mnemonic:8} {ins.op_str}"
                        )
            return 0
        if args.qwords_at is not None:
            address = args.qwords_at
            if address < image_base:
                address += image_base
            raw = pe.get_offset_from_rva(address - image_base)
            for offset in range(0, args.size, 8):
                value = struct.unpack_from("<Q", data, raw + offset)[0]
                print(f"0x{address + offset:016x}  0x{value:016x}")
            return 0
        if args.pointer_xref is not None:
            address = args.pointer_xref
            if address < image_base:
                address += image_base
            needle = struct.pack("<Q", address)
            for raw in all_offsets(data, needle):
                try:
                    rva = raw_to_rva(pe, raw)
                    print(f"pointer=0x{address:x} raw=0x{raw:x} va=0x{image_base + rva:x}")
                except ValueError:
                    print(f"pointer=0x{address:x} raw=0x{raw:x} va=unmapped")
            return 0
        if args.at is not None:
            address = args.at
            if address < image_base:
                address += image_base
            for line in disassemble_at(pe, data, address, args.size):
                print(line)
            return 0

        targets: dict[str, int] = {}
        print(f"image_base=0x{image_base:x}")
        for name, pattern in PATTERNS.items():
            offsets = all_offsets(data, pattern)
            print(f"{name}.matches={len(offsets)}")
            for raw in offsets:
                call_raw = find_near_call(data, raw, len(pattern))
                call_rva = raw_to_rva(pe, call_raw)
                call_va = image_base + call_rva
                target = direct_call_target(image_base, call_rva, data, call_raw)
                targets[name] = target
                print(
                    f"{name}.raw=0x{raw:x} call=0x{call_va:x} target=0x{target:x}"
                )

        unique_targets = sorted(set(targets.values()))
        for target in unique_targets:
            xrefs = find_direct_xrefs(pe, data, image_base, target)
            print(f"target=0x{target:x} direct_xrefs={len(xrefs)}")

            prefixes = collections.Counter(
                bytes(data[max(0, raw - 12) : raw]).hex(" ")
                for _, raw, _ in xrefs
            )
            for prefix, count in prefixes.most_common(12):
                print(f"prefix[{count}]={prefix}")

            for va, raw, section in xrefs[: args.samples]:
                before = bytes(data[max(0, raw - 20) : raw]).hex(" ")
                after = bytes(data[raw + 5 : raw + 17]).hex(" ")
                print(
                    f"xref=0x{va:x} section={section} before={before} after={after}"
                )

            print("target_disassembly:")
            for line in disassemble_at(pe, data, target):
                print(line)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
