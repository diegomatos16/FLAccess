"""Read-only disassembly/xrefs of the current owned executable. No live calls.

RIP-relative LEA and direct CALL references are candidates, not semantic proof.
"""
import argparse
import bisect
import json
import re
import struct
from pathlib import Path

import capstone
import pefile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--exe', type=Path, default=Path('FL_2026.exe'))
    parser.add_argument('--strings', nargs='*', default=[])
    parser.add_argument('--refs', nargs='*', default=[])
    parser.add_argument('--functions', nargs='*', default=[])
    parser.add_argument('--types', nargs='*', default=[])
    parser.add_argument('--size', type=lambda x: int(x, 0), default=0)
    args = parser.parse_args()
    pe = pefile.PE(str(args.exe), fast_load=True)
    base = pe.OPTIONAL_HEADER.ImageBase
    pdata = next(s for s in pe.sections if s.Name.rstrip(b'\0') == b'.pdata')
    pdata_bytes = pdata.get_data()
    ranges = sorted(struct.unpack_from('<III', pdata_bytes, at)[:2]
                    for at in range(0, pdata.SizeOfRawData - 11, 12)
                    if struct.unpack_from('<I', pdata_bytes, at)[0])
    starts = [a for a, _ in ranges]
    def function(rva):
        at = bisect.bisect_right(starts, rva) - 1
        return ranges[at] if at >= 0 and rva < ranges[at][1] else (rva, rva + 256)
    targets = {int(value, 0): value for value in args.refs}
    if args.types:
        rdata = next(s for s in pe.sections if s.Name.rstrip(b'\0') == b'.rdata')
        rd = rdata.get_data()
        for section in pe.sections:
            for match in re.finditer(rb'\.\?A[UV][^\0]{1,180}\0', section.get_data()):
                name = match.group()[:-1].decode('ascii', errors='replace')
                if not any(value in name for value in args.types):
                    continue
                td = section.VirtualAddress + match.start() - 16
                for ref in re.finditer(re.escape(struct.pack('<I', td)), rd):
                    at = ref.start() - 12
                    if at < 0 or at + 24 > len(rd):
                        continue
                    col = struct.unpack_from('<6I', rd, at)
                    if col[0] != 1 or col[5] != rdata.VirtualAddress + at:
                        continue
                    for loc in re.finditer(re.escape(struct.pack('<Q', base + col[5])), rd):
                        vt = rdata.VirtualAddress + loc.start() + 8
                        methods = struct.unpack('<' + 'Q' * 100, pe.get_data(vt, 800))
                        valid = []
                        for method in methods:
                            if not any(s.Characteristics & 0x20000000 and
                                       s.VirtualAddress <= method-base < s.VirtualAddress+s.Misc_VirtualSize
                                       for s in pe.sections):
                                break
                            valid.append(hex(method-base))
                        if valid:
                            print('TYPE', name, 'VTABLE', hex(vt), 'OFFSET', col[1], 'METHODS', ','.join(valid))
    for word in args.strings:
        for section in pe.sections:
            data = section.get_data()
            for encoding in ('ascii', 'utf-16le'):
                raw = word.encode(encoding) + (b'\0' if encoding == 'ascii' else b'\0\0')
                for match in re.finditer(re.escape(raw), data):
                    rva = section.VirtualAddress + match.start()
                    targets[rva] = word
                    print('STRING', word, encoding, hex(rva))
    for section in pe.sections:
        if not section.Characteristics & 0x20000000:
            continue
        data = section.get_data()
        for match in re.finditer(rb'[\x48\x4c]\x8d[\x05\x0d\x15\x1d\x25\x2d\x35\x3d]....', data, re.S):
            rva = section.VirtualAddress + match.start()
            target = rva + 7 + struct.unpack_from('<i', match.group(), 3)[0]
            if target in targets:
                print('LEA', hex(rva), targets[target], 'FUNCTION', hex(function(rva)[0]))
        if args.refs:
            for match in re.finditer(rb'\xe8....', data, re.S):
                rva = section.VirtualAddress + match.start()
                target = rva + 5 + struct.unpack_from('<i', match.group(), 1)[0]
                if target in targets:
                    print('CALL', hex(rva), hex(target), 'FUNCTION', hex(function(rva)[0]))
    decoder = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_64)
    for value in args.functions:
        at = int(value, 0)
        first, end = (at, at + args.size) if args.size else function(at)
        print('FUNCTION', hex(first), hex(end))
        for ins in decoder.disasm(pe.get_data(first, end - first), first + base):
            print(f'{ins.address-base:#x} {ins.mnemonic} {ins.op_str}')
    pe.close()


if __name__ == '__main__':
    main()
