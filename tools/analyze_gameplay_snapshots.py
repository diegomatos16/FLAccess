"""Summarize changing finite floats from probe captures; candidates, not facts."""
import argparse
import collections
import json
import math
import struct
from pathlib import Path

def analyze(path):
    groups = collections.defaultdict(list)
    for line in path.read_text(encoding='ascii').splitlines():
        parts = line.split('\t')
        if len(parts) != 4: continue  # Ignore an incomplete line during a live write.
        try:
            timestamp, name, address, raw = parts
            groups[name, address].append((float(timestamp), bytes.fromhex(raw)))
        except ValueError: continue
    output = []
    for (name, address), samples in groups.items():
        if len(samples) < 2: continue
        varying = []
        for offset in range(0, min(len(data) for _, data in samples)-3, 4):
            values = [struct.unpack_from('<f', data, offset)[0] for _, data in samples]
            if not all(math.isfinite(v) and abs(v) <= 30000 for v in values): continue
            spread = max(values)-min(values)
            if spread < 0.05 or max(abs(v) for v in values) < 0.05: continue
            varying.append(dict(offset=hex(offset), first=round(values[0],4),
                                last=round(values[-1],4), min=round(min(values),4),
                                max=round(max(values),4), spread=round(spread,4),
                                values=[round(v,4) for v in values]))
        output.append(dict(type=name,address=address,samples=len(samples),
                           duration=round((samples[-1][0]-samples[0][0])/1000,1),varying=varying))
    return sorted(output,key=lambda item:(item['type'],item['address']))

if __name__=='__main__':
    parser=argparse.ArgumentParser(); parser.add_argument('capture',type=Path)
    parser.add_argument('output',type=Path); args=parser.parse_args()
    result=analyze(args.capture)
    args.output.write_text(json.dumps(result,indent=2),encoding='utf-8')
    for item in result:
        if item['type'] in ('Player','BallControl'): continue
        print(item['type'],item['address'],'samples',item['samples'],'seconds',item['duration'])
        print([(v['offset'],v['first'],v['last'],v['spread']) for v in item['varying'][:24]])
