"""Audit player yaw and the native fixed goal getter; no live memory access."""
import struct
from pathlib import Path
import capstone
import pefile
raw = Path('FL_2026.exe').read_bytes()
pe = pefile.PE(data=raw, fast_load=True)
base = pe.OPTIONAL_HEADER.ImageBase
cs = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_64)
cs.detail = True

def code(rva, size):
    offset = pe.get_offset_from_rva(rva)
    return list(cs.disasm(raw[offset:offset+size], base+rva))

def operand(rva, text):
    assert code(rva, 16)[0].op_str == text, hex(rva)

operand(0x8c4d1e, 'xmm6, dword ptr [rcx + 0x61c]')
operand(0x9234b8, 'rbx, [rdi + 0x61c]')
operand(0x92357c, 'rdx, rbx')
operand(0x92357f, '0x141eb56d0')
operand(0x1eb56df, 'dword ptr [r10], eax')
operand(0x439e8a, 'xmm1, xmm3') # delta Z
operand(0x439e8e, 'xmm0, xmm2') # delta X
operand(0x439e92, '0x140a92d40') # atan2(X,Z), then degrees
operand(0xa48a38, 'rax, 0xa1')
operand(0xa48a3e, 'rax, [rax + rax*4]')
operand(0xa48a42, 'rax, qword ptr [rcx + rax*8]')
operand(0xa42570, 'byte ptr [rcx + 0x254], dl')
operand(0x4feb9c, '0x1404f4ae0')
operand(0x4febab, '0x140a42570')
operand(0xa627a3, '0x140a48a30')
operand(0xa627ae, 'eax, byte ptr [rax + 0x254]')
operand(0xa627aa, 'qword ptr [rbx + 4], rcx') # Goal Y=Z=0
operand(0xa627bf, 'xmm0, xmm6')
operand(0x9792af, 'esi, 1') # ActionShoot flips own team to opponent
operand(0x9792bf, 'r8d, esi')
operand(0x9792c2, '0x140a62780')
ins = code(0xa627c8, 7)[0]
mask_rva = ins.address+ins.size+ins.operands[1].mem.disp-base
assert struct.unpack_from('<I', raw, pe.get_offset_from_rva(mask_rva))[0] == 0x80000000
# Fixed center X = negative current TeamAI sign * field half-length, never keeper XYZ.
lines = ['PASS native body heading/model consumer and own-goal getter; ActionShoot uses opposite team',
         'TeamAI payloads: world+0x1928+side*0x28; TeamAIInfoRef vtable 0x2596cd8.',
         'Own goal=(-sign*halfLength,0,0); opponent uses the other team.']
for rva, size in [(0x8c4d10,94),(0x9234b8,82),(0x923572,18),(0x1eb56d0,22),
                  (0x439e50,155),(0xa92d40,121),(0xa48a30,31),
                  (0x4feb69,71),(0x4f4ae0,140),(0xa62780,89),(0x9792a6,33)]:
    lines.append('\nROUTINE '+hex(rva))
    lines.extend(f'{i.address-base:x}: {i.mnemonic} {i.op_str}' for i in code(rva,size))
Path('FLAccess/tests/body-goals-native-route-2026-10-27.txt').write_text('\n'.join(lines)+'\n', encoding='utf-8')
print(lines[0])
