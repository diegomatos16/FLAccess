"""Export observed field packets, not inferred visibility or native ownership.

The Lua fixture exercises composition with real captions/values. It does not
reconstruct truncated trees or certify the native discovery/selection path.
"""
import argparse
import hashlib
import json
from pathlib import Path

from analyze_component_capture import fields


def export(capture: Path, output: Path) -> int:
    raw = capture.read_bytes()
    packet, rows, seen, per_label = {}, [], set(), {}
    for line in raw.decode('utf-8-sig').splitlines():
        if line.startswith('SNAP '):
            packet = fields(line)
        elif line.startswith('NODE '):
            node = fields(line)
            label, value = node.get('label'), node.get('value')
            if (node.get('relation') == 'native-field' and node.get('selected') == 'true'
                    and node.get('rendered_read') == 'true' and node.get('member') == 'input-owner'
                    and label and value and node.get('text') == label
                    and (label, value) not in seen and per_label.get(label, 0) < 2):
                seen.add((label, value))
                per_label[label] = per_label.get(label, 0) + 1
                rows.append({'sequence': int(packet['sequence']), 'frame': int(packet['frame']),
                             'key': node['key'], 'name': node['name'], 'label': label, 'value': value})
                if len(rows) == 12:
                    break
    if not rows:
        raise ValueError('No observed selected native-field packet available')
    quote = lambda text: json.dumps(text, ensure_ascii=False)
    result = ['-- Generated from a real capture; composition replay only.',
              'return {source=' + quote(capture.name) + ', sha256=' + quote(hashlib.sha256(raw).hexdigest()) + ', rows={']
    for row in rows:
        result.append('  {' + ','.join(key + '=' + (str(value) if isinstance(value, int) else quote(value))
                                      for key, value in row.items()) + '},')
    result.append('}}')
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text('\n'.join(result) + '\n', encoding='utf-8')
    return len(rows)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('capture', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    print('OBSERVED_FIELD_PACKETS', export(args.capture, args.output))
