"""Read-only MSVC x64 RTTI inventory for the local PES executable.

Requires pefile. Addresses are preferred-image RVAs, not live pointers.
COL candidates must have signature 1 and a matching self RVA. Vtables
must refer to such a COL and start with an executable-section address.
This identifies types; it does not establish active instances or semantics.
"""
import argparse
import json
import mmap
import re
import struct
from pathlib import Path
import pefile


def inventory(path):
    pe = pefile.PE(str(path), fast_load=True)
    base = pe.OPTIONAL_HEADER.ImageBase
    sections = list(pe.sections)
    def rva(raw):
        for s in sections:
            if s.PointerToRawData <= raw < s.PointerToRawData + s.SizeOfRawData:
                return raw - s.PointerToRawData + s.VirtualAddress
    def executable(va):
        value = va - base
        return any(s.Characteristics & 0x20000000 and
                   s.VirtualAddress <= value < s.VirtualAddress + s.Misc_VirtualSize
                   for s in sections)
    with path.open('rb') as stream, mmap.mmap(stream.fileno(), 0, access=mmap.ACCESS_READ) as data:
        descriptors = {}
        for match in re.finditer(rb'\.\?A[UV][^\x00]{1,180}@menusystem@@\x00', data):
            value = rva(match.start() - 16)
            if value is not None:
                descriptors[value] = match.group()[:-1].decode('ascii')
        result = []
        for s in sections:
            if s.Name.rstrip(b'\x00') != b'.rdata':
                continue
            start, end = s.PointerToRawData, s.PointerToRawData + s.SizeOfRawData
            for raw in range(start, end - 24, 4):
                signature, offset, cd_offset, td, hierarchy, self_rva = struct.unpack_from('<6I', data, raw)
                if signature != 1 or td not in descriptors or self_rva != rva(raw):
                    continue
                needle = struct.pack('<Q', base + self_rva)
                cursor = start
                while True:
                    ref = data.find(needle, cursor, end - 8)
                    if ref < 0:
                        break
                    cursor = ref + 1
                    if ref % 8 or not executable(struct.unpack_from('<Q', data, ref + 8)[0]):
                        continue
                    methods = []
                    for index in range(80):
                        method = struct.unpack_from('<Q', data, ref + 8 + index * 8)[0]
                        if not executable(method):
                            break
                        methods.append(hex(method - base))
                    result.append({'type': descriptors[td], 'type_descriptor_rva': hex(td),
                                   'col_rva': hex(self_rva), 'object_offset': offset,
                                   'vtable_rva': hex(rva(ref + 8)), 'method_rvas': methods})
        return {'executable': str(path), 'image_base': hex(base),
                'descriptor_count': len(descriptors), 'vtables': result}


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('exe', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    result = inventory(args.exe)
    args.output.write_text(json.dumps(result, indent=2), encoding='utf-8')
    print('Descriptors:', result['descriptor_count'], 'vtables:', len(result['vtables']))
    for entry in result['vtables']:
        if any(name + '@menusystem@@' in entry['type'] for name in
               ('WindowManager', 'Window', 'NodeCursor', 'NodeRectText', 'NodeRectSelector',
                'NodeRoot', 'NodeChoice', 'SoundTitle', 'System')):
            print(entry['type'], entry['vtable_rva'], 'object offset', entry['object_offset'],
                  'methods', len(entry['method_rvas']))
