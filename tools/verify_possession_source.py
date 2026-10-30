"""Prove which registry payload owns current keep-player; no game process access."""
from pathlib import Path
import struct
import capstone
import pefile
raw=Path('FL_2026.exe').read_bytes()
pe=pefile.PE(data=raw,fast_load=True)
base=pe.OPTIONAL_HEADER.ImageBase
cs=capstone.Cs(capstone.CS_ARCH_X86,capstone.CS_MODE_64);cs.detail=True

def code(rva,size):
    offset=pe.get_offset_from_rva(rva)
    return list(cs.disasm(raw[offset:offset+size],base+rva))

def operand(rva,text):
    assert code(rva,16)[0].op_str==text,hex(rva)

def lea(rva):
    ins=code(rva,8)[0]
    return ins.address+ins.size+ins.operands[1].mem.disp-base

# MatchInfoRef is bound to MATCH/INFO and only 0x2378 payload bytes per copy.
assert lea(0x4e0c36)==0x25969b8
assert lea(0x4e0cd7)==0x4e0810
operand(0x4e08bb,'edx, 0x2378')
operand(0x4e08c0,'r8d, 2')
assert 0x2601c+4>0x2378
# Producer's +508 is the +20 cache of AnalyzeInfoRef at +4e8.
operand(0x4563e5,'rsi, [r14 + 0x4e8]')
assert lea(0x4563fc)==0x259d590
assert struct.unpack_from('<Q',raw,pe.get_offset_from_rva(0x259d590+8))[0]==base+0x458410
key=lea(0x458410)
assert raw[pe.get_offset_from_rva(key):][:8]==b'ANALYZE\0'
operand(0x4582e1,'rcx, 0x4e8')
operand(0x4582e8,'0x1404589a0')
operand(0x4589ec,'rcx, 8')
operand(0x4589f0,'qword ptr [rdi + 0x20], rcx')
operand(0x4571fd,'r13, qword ptr [rbp + 0x508]')
operand(0x457259,'dword ptr [r13 + 0x2601c], edi')
operand(0xa627ec,'eax, dword ptr [rax + 0x2601c]')
# Analyze allocation can hold this offset, unlike MATCH.
operand(0x4636e2,'edx, 0xeae28')
operand(0x463706,'rcx, [rax + 8]')
operand(0x46370a,'0x140a6f240')
assert 8+0x2601c+4<=0xeae28
lines=['PASS current keeper belongs to ANALYZE/INFO raw+8+2601c; MATCH/INFO is only 2378 bytes',
       'Do not ban actor zero: 0..21 are valid native actor indices. Wrong payload caused arbitrary zero.',
       'Native producer +508 = AnalyzeInfoRef(+4e8).read_cache(+20), header8 verified.']
for rva,size in [(0x4e0c36,17),(0x4e0cd7,7),(0x4e0882,73),(0x4563e5,33),
                 (0x458410,8),(0x4582de,23),(0x4589dd,32),(0x4571fd,99),
                 (0xa627e0,23),(0x4636df,53)]:
    lines.append('\nROUTINE '+hex(rva))
    lines.extend(f'{i.address-base:x}: {i.mnemonic} {i.op_str}' for i in code(rva,size))
Path('FLAccess/tests/possession-source-native-2026-10-28.txt').write_text('\n'.join(lines)+'\n',encoding='utf-8')
print(lines[0])
