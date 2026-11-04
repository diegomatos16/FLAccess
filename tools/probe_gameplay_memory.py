"""Read-only RTTI discovery and live snapshots; never writes to game memory."""
import argparse
import ctypes as C
import json
import re
import struct
from pathlib import Path
import pefile

TYPES = (b'BallInfoRef@registry@match', b'PlayerInfoRef@registry@match',
         b'PlayerMoveRef@registry@match', b'CameraInfoRef@registry@match',
         b'CameraTargetInfoRef@registry@match', b'FieldInfoRef@registry@match',
         b'Player@match', b'BallControl@match', b'InplayCamera@plugin@camera@match')

def inventory(exe):
    pe = pefile.PE(str(exe), fast_load=True)
    data = exe.read_bytes()
    base = pe.OPTIONAL_HEADER.ImageBase
    def rva(raw):
        for s in pe.sections:
            if s.PointerToRawData <= raw < s.PointerToRawData+s.SizeOfRawData:
                return raw-s.PointerToRawData+s.VirtualAddress
    def executable(va):
        return any(s.Characteristics & 0x20000000 and
                   s.VirtualAddress <= va-base < s.VirtualAddress+s.Misc_VirtualSize
                   for s in pe.sections)
    types = {}
    for match in re.finditer(rb'\.\?A[UV][^\x00]{1,180}\x00', data):
        if any(match.group()[4:].startswith(name+b'@@') for name in TYPES):
            types[rva(match.start()-16)] = match.group()[:-1].decode('ascii')
    result = []
    for s in pe.sections:
        if s.Name.rstrip(b'\0') != b'.rdata': continue
        start, end = s.PointerToRawData, s.PointerToRawData+s.SizeOfRawData
        for raw in range(start, end-24, 4):
            sig, offset, _, td, _, self_rva = struct.unpack_from('<6I', data, raw)
            if sig != 1 or td not in types or self_rva != rva(raw): continue
            needle = struct.pack('<Q', base+self_rva)
            pos = start
            while True:
                ref = data.find(needle, pos, end-8)
                if ref < 0: break
                pos = ref+1
                if ref % 8 or not executable(struct.unpack_from('<Q',data,ref+8)[0]): continue
                methods = []
                for i in range(32):
                    va = struct.unpack_from('<Q',data,ref+8+i*8)[0]
                    if not executable(va): break
                    methods.append(hex(va-base))
                result.append(dict(type=types[td], vtable_rva=hex(rva(ref+8)),
                                   object_offset=offset, methods=methods))
    return dict(image_base=hex(base), size=pe.OPTIONAL_HEADER.SizeOfImage, types=result)

class MBI(C.Structure):
    _fields_ = [('BaseAddress',C.c_void_p), ('AllocationBase',C.c_void_p),
                ('AllocationProtect',C.c_uint32),('PartitionId',C.c_uint16),
                ('RegionSize',C.c_size_t),('State',C.c_uint32),
                ('Protect',C.c_uint32),('Type',C.c_uint32)]

def snapshot(pid, table, limit_mb):
    k = C.WinDLL('kernel32', use_last_error=True)
    k.OpenProcess.argtypes=[C.c_uint32,C.c_int,C.c_uint32]; k.OpenProcess.restype=C.c_void_p
    k.ReadProcessMemory.argtypes=[C.c_void_p,C.c_void_p,C.c_void_p,C.c_size_t,C.POINTER(C.c_size_t)]
    k.VirtualQueryEx.argtypes=[C.c_void_p,C.c_void_p,C.POINTER(MBI),C.c_size_t]
    k.VirtualQueryEx.restype=C.c_size_t
    k.CloseHandle.argtypes=[C.c_void_p]
    handle=k.OpenProcess(0x410,False,pid)
    if not handle: raise C.WinError(C.get_last_error())
    def read(address,size):
        output=C.create_string_buffer(size); got=C.c_size_t()
        k.ReadProcessMemory(handle,address,output,size,C.byref(got))
        return output.raw[:got.value]
    try:
        # PES has no ASLR in this build; verify PE signature at preferred base.
        base=int(table['image_base'],16)
        if read(base,2)!=b'MZ': raise RuntimeError('preferred image base unavailable; do not assume ASLR address')
        needles={struct.pack('<Q',base+int(t['vtable_rva'],16)):t for t in table['types']}
        found=[]; address=0; scanned=0; budget=limit_mb*1024*1024
        while address < 0x7fffffffffff and scanned < budget:
            region=MBI()
            if not k.VirtualQueryEx(handle,address,C.byref(region),C.sizeof(region)): break
            start=region.BaseAddress or 0; size=region.RegionSize
            address=start+size
            if address<=start: break
            if region.State!=0x1000 or region.Type!=0x20000 or region.Protect & 0x101: continue
            for offset in range(0,size,4*1024*1024):
                length=min(4*1024*1024,size-offset,budget-scanned)
                if length<=0: break
                data=read(start+offset,length); scanned+=length
                for needle,entry in needles.items():
                    cursor=0
                    while True:
                        pos=data.find(needle,cursor)
                        if pos<0: break
                        cursor=pos+8
                        pointer=start+offset+pos
                        if pointer%8: continue
                        block=read(pointer-entry['object_offset'],512)
                        if len(block)<32: continue
                        floats=[]; pointers=[]
                        for i in range(8,len(block)-3,4):
                            value=struct.unpack_from('<f',block,i)[0]
                            if 0.01<=abs(value)<=10000: floats.append([hex(i),round(value,5)])
                        for i in range(8,len(block)-7,8):
                            value=struct.unpack_from('<Q',block,i)[0]
                            if 0x10000<=value<0x7fffffffffff and value%8==0:
                                pointers.append([hex(i),hex(value)])
                        found.append(dict(type=entry['type'],address=hex(pointer-entry['object_offset']),
                                          floats=floats,pointers=pointers,raw=block.hex()))
                        if len(found)>=2000: raise RuntimeError('too many RTTI candidates')
        return dict(pid=pid,scanned_mb=round(scanned/1024/1024,1),instances=found)
    finally: k.CloseHandle(handle)

if __name__=='__main__':
    p=argparse.ArgumentParser(); p.add_argument('exe',type=Path); p.add_argument('output',type=Path)
    p.add_argument('--pid',type=int); p.add_argument('--limit-mb',type=int,default=2048)
    args=p.parse_args(); table=inventory(args.exe)
    result=dict(inventory=table)
    if args.pid: result['snapshot']=snapshot(args.pid,table,args.limit_mb)
    args.output.write_text(json.dumps(result,indent=2),encoding='utf-8')
    print('Types:',len(table['types']))
    for entry in table['types']: print(entry['type'],entry['vtable_rva'],entry['methods'][:6])
    if args.pid:
        print('Scanned MB:',result['snapshot']['scanned_mb'],'instances:',len(result['snapshot']['instances']))
        for item in result['snapshot']['instances'][:40]: print(item['type'],item['address'],item['floats'][:16])
