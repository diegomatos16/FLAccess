"""Summarize read-only component evidence without inferring visibility or roles.

The runtime log uses Lua %q strings. This parser does not execute Lua, and
distinguishes unknown membership, empty rendered text and unsupported getters.
"""
from __future__ import annotations

import argparse
from collections import Counter
import json
from pathlib import Path
import re


FIELDS = re.compile(r'(\w+)=("(?:\\.|[^"\\])*"|\S+)')


def fields(line: str) -> dict[str, str]:
    result = {}
    for key, raw in FIELDS.findall(line):
        if raw.startswith('"'):
            def unescape(match):
                value = match[1]
                if value.isdigit():
                    return chr(int(value))
                return {'n': '\n', 'r': '\r', 't': '\t'}.get(value, value)
            raw = re.sub(r'\\(\d{1,3}|.)', unescape, raw[1:-1])
        result[key] = raw
    return result


def analyze(text: str) -> dict:
    nodes: dict[str, dict] = {}
    scope = None
    pending = None
    findings = []
    kinds: Counter = Counter()
    resources: set[str] = set()
    frontiers: set[str] = set()
    snapshots = 0
    maximum_total = 0
    truncated_samples = 0
    links = []
    link_kinds: Counter = Counter()

    def finish():
        if pending is None:
            return
        for node in nodes.values():
            kinds[node.get('name', '')] += 1
            reasons = []
            if node.get('selected') == 'true' and node.get('rendered_read') == 'false':
                reasons.append('selected-without-supported-text-getter')
            if node.get('member') == 'unknown' and node.get('rendered_read') == 'true':
                reasons.append('rendered-copy-without-proven-window-membership')
            if (node.get('relation') == 'native-field' and node.get('provisional')
                    and node['provisional'] != node.get('label')):
                reasons.append('native-value-also-registered-as-provisional-label')
            if node.get('name') == 'padIcon' and node.get('font') == 'nil':
                reasons.append('icon-without-font-id')
            if reasons and len(findings) < 240:
                findings.append({'sequence': pending.get('sequence'), 'key': node.get('key'),
                                 'name': node.get('name'), 'text': node.get('text'),
                                 'reasons': reasons})

    for line in text.splitlines():
        kind = line.split(' ', 1)[0]
        item = fields(line)
        if kind == 'SNAP':
            finish()
            new_scope = (item.get('owner'), item.get('generation'))
            if new_scope != scope:
                nodes.clear()
                scope = new_scope
            pending = item
            snapshots += 1
        elif kind == 'NODE':
            if 'key' not in item:
                raise ValueError('NODE without key')
            nodes[item['key']] = item
        elif kind == 'DROP':
            nodes.pop(item.get('key', ''), None)
        elif kind == 'RESOURCE':
            resources.add(item.get('name', ''))
        elif kind == 'FRONTIER':
            frontiers.add(item.get('rva', ''))
        elif kind in {'PAGE', 'COMMAND', 'ROSTER', 'SLOT', 'RESULT', 'ASSIGNMENT'}:
            link_kinds[kind] += 1
            if len(links) < 2048:
                links.append({'kind': kind, 'sequence': (pending or {}).get('sequence'), **item})
        elif kind == 'END':
            total, sampled = int(item.get('total', 0)), int(item.get('sampled', 0))
            maximum_total = max(maximum_total, total)
            truncated_samples += total > sampled
    finish()
    return {'snapshots': snapshots, 'maximum_observed_nodes': maximum_total,
            'samples_with_more_nodes_than_budget': truncated_samples,
            'node_names_by_snapshot': dict(kinds), 'resource_paths': sorted(resources),
            'unsupported_branch_rvas': sorted(frontiers), 'findings': findings,
            'component_link_counts': dict(link_kinds), 'component_links': links,
            'component_links_truncated': sum(link_kinds.values()) > len(links),
            'limit': 'Observations and native getters do not establish visibility, button identity or roster status.'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('capture', type=Path)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    report = json.dumps(analyze(args.capture.read_text(encoding='utf-8-sig')), ensure_ascii=False, indent=2)
    if args.output:
        args.output.write_text(report + '\n', encoding='utf-8')
    else:
        print(report)
