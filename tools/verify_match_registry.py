"""Audit the read-only native registry route against this game's executable."""
import hashlib
import struct
from pathlib import Path
import capstone
import pefile

exe = Path("FL_2026.exe")
raw = exe.read_bytes()
pe = pefile.PE(data=raw, fast_load=True)
image = pe.OPTIONAL_HEADER.ImageBase
cs = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_64)
cs.detail = True

def code(rva, size):
    offset = pe.get_offset_from_rva(rva)
    return list(cs.disasm(raw[offset:offset + size], image + rva))

def address_of_lea(rva):
    ins = code(rva, 7)[0]
    assert ins.mnemonic in ("lea", "mov")
    return ins.address + ins.size + ins.operands[1].mem.disp - image

assert address_of_lea(0x1b55f40) == 0x37f0ac8
assert address_of_lea(0x1b55ec7) == 0x2ac6670
assert address_of_lea(0x1b6ddd3) == 0x2acaa40
assert address_of_lea(0x1b70d29) == 0x2acb380
assert code(0x217d310, 5)[0].op_str == "rax, [rcx + 0x20]"
for rva, operand in (
    (0x1b6eab6, "rcx, qword ptr [rcx + 0x10]"),
    (0x1b73039, "r9, [rdi + 0x38]"),
    (0x1b73056, "rcx, qword ptr [rax - 0x18]"),
    (0x1b730ab, "rbx, qword ptr [r8 - 8]"),
    (0x1b72f13, "r9, [rbx + 0xa8]"),
    (0x1b72f8c, "rbx, qword ptr [rbx - 8]"),
):
    assert code(rva, 8)[0].op_str == operand, hex(rva)
for getter, text in ((0x4bc170, b"BALL"), (0x427870, b"CAMERA"), (0x86fc50, b"FIELD"), (0x41ef30, b"CURSOR"), (0x419d40, b"MATCH"), (0x458410, b"ANALYZE"), (0x44e0c0, b"INFO")):
    offset = pe.get_offset_from_rva(address_of_lea(getter))
    assert raw[offset:offset + len(text) + 1] == text + b"\0"
for vtable, slot, method in ((0x2ac6670, 0x38, 0x217d310), (0x2acaa40, 0x70, 0x1b6eab0), (0x2acb380, 0x68, 0x1b71c60)):
    offset = pe.get_offset_from_rva(vtable + slot)
    assert struct.unpack_from("<Q", raw, offset)[0] == image + method

assert code(0x41b6fc, 4)[0].op_str == "rcx, 8"
assert code(0xa627e8, 4)[0].op_str == "rax, qword ptr [rcx + 0x18]"
assert code(0xa627ec, 6)[0].op_str == "eax, dword ptr [rax + 0x2601c]"
assert code(0x457259, 7)[0].op_str == "dword ptr [r13 + 0x2601c], edi"
assert address_of_lea(0x4e0c36) == 0x25969b8 # Concrete MatchInfoRef is the small match-settings payload, not possession.
assert code(0x4e0d18, 4)[0].op_str == "rax, 8"
lines = ["PASS executable registry route; keeper getter/writer field requires ANALYZE/INFO (see verify_possession_source.py), not MATCH; read-only static audit", "SHA256 " + hashlib.sha256(raw).hexdigest()]
for rva, size in ((0x1b55f40, 8), (0x217d310, 5), (0x1b6eab0, 0x39), (0x1b72fc0, 0x160), (0x1b72ef0, 0xcb), (0x1b6fe20, 0x80), (0x41b6b0, 0x67), (0xa627e0, 0x17), (0x457204, 0x5c), (0xa179c0, 0x80), (0x4e0d07, 0x19)):
    lines.append("\nROUTINE " + hex(rva))
    for ins in code(rva, size):
        lines.append(f"{ins.address-image:x}: {ins.mnemonic} {ins.op_str}")
Path("FLAccess/tests/match-registry-native-route-2026-10-27.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
print(lines[0])
