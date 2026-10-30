"""Audit current FL2026 camera payload and native profile selector; read-only."""
from pathlib import Path
import struct
import capstone
import pefile
raw=Path('FL_2026.exe').read_bytes();pe=pefile.PE(data=raw,fast_load=True)
base=pe.OPTIONAL_HEADER.ImageBase
cs=capstone.Cs(capstone.CS_ARCH_X86,capstone.CS_MODE_64);cs.detail=True
def code(rva,size=16):
    o=pe.get_offset_from_rva(rva)
    return list(cs.disasm(raw[o:o+size],base+rva))
def check(rva,mnemonic,operand):
    i=code(rva)[0];assert (i.mnemonic,i.op_str)==(mnemonic,operand),(hex(rva),i.mnemonic,i.op_str)
for a,m,o in [
 (0x4277c7,'call','0x141eafdf0'),(0x4277cc,'lea','rcx, [rdi + 8]'),
 (0x4277d5,'call','0x140a91c20'),(0x427bf2,'lea','edx, [r8 + 0x5c]'),
 (0x427c15,'lea','rcx, [rax + 4]'),(0x1eafe9e,'call','0x141eaf100'),
 (0x1eaff13,'call','0x141eaf270'),(0x41b68c,'add','rcx, 4'),
 (0x879a20,'lea','rcx, [rdi + 0x28]'),(0x879a24,'call','0x14041b640'),
 (0x879a29,'mov','r15, rax'),(0x879fe6,'mov','qword ptr [rsp + 0x20], r15'),
 (0x879ff3,'call','0x14087a170'),(0x87a1b6,'mov','rcx, qword ptr [rsp + 0x130]'),
 (0x87a1be,'mov','qword ptr [rsp + 0x20], rcx'),
 (0x87a478,'mov','rcx, qword ptr [rsp + 0x20]'),(0x87a47d,'movzx','ebx, byte ptr [rcx + 0x44]'),
 (0x87a484,'cmp','eax, 5'),(0x87a4b5,'mov','edx, ebx'),(0x87a4ba,'call','0x14087e480'),
 (0x87a4c7,'cmp','eax, 2')]:check(a,m,o)
# Close selected ID -> InplayCamera object -> native parameter consumers.
for a,m,o in [
 (0x87e4be,'mov','dword ptr [rsp + 0x48], edx'),
 (0x87e4d0,'mov','qword ptr [rcx], rax'),
 (0x87e961,'mov','eax, dword ptr [rsp + 0x48]'),
 (0x87e965,'mov','dword ptr [rdi + 8], eax'),
 (0x87f28d,'mov','rbp, rcx'),
 (0x87f371,'mov','eax, dword ptr [rbp + 8]'),
 (0x87f388,'cmp','eax, 6'),(0x87f38b,'je','0x14087f39f'),
 (0x87f38d,'cmp','eax, 3'),(0x87f390,'je','0x14087f39f'),
 (0x87f395,'mov','rcx, rbp'),(0x87f398,'call','0x1408a1a70'),
 (0x87f3a2,'mov','rcx, rbp'),(0x87f3a5,'call','0x1408a57f0'),
 (0x8a1a86,'mov','rdi, rcx'),(0x8a1a89,'cmp','eax, 2'),
 (0x8a1e51,'cmp','dword ptr [rdi + 8], 5'),
 (0x8a582c,'mov','rbx, rcx'),(0x8a5843,'mov','eax, dword ptr [rbx + 8]'),
 (0x8a58ba,'cmp','eax, 6'),(0x8a5b08,'cmp','eax, 3')]:check(a,m,o)
i=code(0x87e4c9)[0]
assert i.address+i.size+i.operands[1].mem.disp==base+0x2609c28
# Verify vtable's parameter callback instead of assuming nearby functions share owner.
assert struct.unpack('<Q',pe.get_data(0x2609c48,8))[0]==base+0x87f280
assert raw[pe.get_offset_from_rva(0x8a1fc2):][:20]==bytes.fromhex('f3410f59faf3450f5ec2f3410f5ef2f3410f5cc0')
lines=['PASS camera view-projection raw+0x0c; MATCH/ENV selected camera ID raw+0x48.',
       'Native family association closed: ID2 FanView, ID3 Broadcast, ID5 DynamicWide, ID6 Stadium; other labels not mapped. ID0 transitional profile only.',
       'Perspective and look-at builders compose matrix; not an orthonormal listener rotation.']
for a,n in [(0x427740,164),(0x427bf2,42),(0x1eafdf0,36),(0x1eafe00,610),
            (0x87e4be,28),(0x87e961,14),(0x87f280,24),(0x87f371,59),(0x8a1a70,72),(0x8a1e51,10),(0x8a5815,55),(0x8a58ba,9),(0x8a5b08,10),
            (0x41b68c,12),(0x879a20,20),(0x879fe6,20),(0x87a1b6,20),(0x87a478,90)]:
    lines.append('\nROUTINE '+hex(a))
    lines.extend(f'{i.address-base:x}: {i.mnemonic} {i.op_str}' for i in code(a,n))
Path('FLAccess/tests/camera-native-audit-2026-10-28.txt').write_text('\n'.join(lines)+'\n',encoding='utf-8')
print(lines[0])
