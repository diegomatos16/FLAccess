#!/usr/bin/env python3
"""Disassemble the menu probe template before it is used in-game."""

from capstone import CS_ARCH_X86, CS_MODE_64, Cs


code = (
    bytes.fromhex("48 85 d2 74 26")
    + bytes.fromhex("81 3a 43 6f 6d 65 75 1e")
    + bytes.fromhex("66 81 7a 04 6e 74 75 16")
    + bytes.fromhex("53 51 48 bb")
    + bytes(8)
    + bytes.fromhex("66 b9 01 00 ff d3 48 83 c4 10")
    + bytes.fromhex("48 89 5c 24 08 48 89 74 24 10 57 48 83 ec 20")
    + bytes.fromhex("ff 25 00 00 00 00")
    + bytes(8)
)

decoder = Cs(CS_ARCH_X86, CS_MODE_64)
for instruction in decoder.disasm(code, 0x1000):
    print(
        f"0x{instruction.address:04x} "
        f"{instruction.bytes.hex(' '):<32} "
        f"{instruction.mnemonic} {instruction.op_str}"
    )

assert len(code) == 72
