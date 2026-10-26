import importlib.util
import hashlib
import re
from pathlib import Path
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'tools' / 'analyze_component_capture.py'
SPEC = importlib.util.spec_from_file_location('component_capture', SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class ComponentCaptureTests(unittest.TestCase):
    def test_observed_field_replay_is_tied_to_the_preserved_capture(self):
        root=Path(__file__).resolve().parent
        capture=root/'capture-dev18-components.log'
        if not capture.exists():
            self.skipTest('preserved local capture unavailable')
        fixture=(root/'fixtures'/'observed-fields-dev18.lua').read_text(encoding='utf-8')
        self.assertIn(hashlib.sha256(capture.read_bytes()).hexdigest(),fixture)
        packets=re.findall(r'key="([^"]+)",name="([^"]+)",label="([^"]+)",value="([^"]+)"',fixture)
        self.assertEqual(len(packets),10)
        observed=set()
        for line in capture.read_text(encoding='utf-8-sig').splitlines():
            if line.startswith('NODE '):
                node=MODULE.fields(line)
                if node.get('selected')=='true' and node.get('relation')=='native-field':
                    observed.add(tuple(node.get(k) for k in ('key','name','label','value')))
        self.assertTrue(set(packets).issubset(observed),'replay must not invent captions or values')

    def test_lua_escapes_are_data_not_executable(self):
        self.assertEqual(MODULE.fields(r'NODE key="12" text="A\"B\\C\017"')['text'], 'A"B\\C\x11')

    def test_unknown_membership_is_reported_without_claiming_visibility(self):
        report = MODULE.analyze('''FLACCESS_COMPONENTS format=1 build=16
SNAP sequence=1 owner="one" generation=1
NODE key="10" name="text_item" text="Título real" member="unknown" rendered_read=true
END sampled=1 total=2
RESOURCE name="common/menu/font/ext_fnt.bin"
''')
        self.assertEqual(report['snapshots'], 1)
        self.assertEqual(report['samples_with_more_nodes_than_budget'], 1)
        self.assertEqual(report['findings'][0]['reasons'], ['rendered-copy-without-proven-window-membership'])
        self.assertEqual(report['resource_paths'], ['common/menu/font/ext_fnt.bin'])

    def test_deltas_reentry_and_drops_do_not_retain_old_nodes(self):
        report = MODULE.analyze('''SNAP sequence=1 owner="one" generation=1
NODE key="10" name="text" text="Valor" selected=true rendered_read=false
END sampled=1 total=1
SNAP sequence=2 owner="one" generation=1
DROP key="10" reason=outside-sampled-model
END sampled=0 total=0
SNAP sequence=3 owner="one" generation=2
NODE key="20" name="text" text="Novo" selected=true rendered_read=true member="input-owner"
END sampled=1 total=1
''')
        self.assertEqual(report['snapshots'], 3)
        self.assertEqual(len(report['findings']), 1)
        self.assertEqual(report['node_names_by_snapshot'], {'text': 2})

    def test_component_links_retain_sequence_and_missing_boundary_without_guessing_status(self):
        report = MODULE.analyze('''SNAP sequence=4 owner="window" generation=2
PAGE window=100 index=1 caption=200 text="Guia"
COMMAND bar=300 index=0 icon=400 caption=500 raw="\\017jb" text="Pular"
ROSTER window=100 side=0 scroll=7 boundary=nil
SLOT window=100 index=0 card=600
PLAYER_PANEL widget=700 window=100 slot=18 side=0 player_id=1234 section="" identity="real-id"
CAPTION_SELECTION widget=700 identity="window:cursor:panel"
END sampled=0 total=0
''')
        self.assertEqual(report['component_link_counts'], {'PAGE': 1, 'COMMAND': 1, 'ROSTER': 1, 'SLOT': 1, 'PLAYER_PANEL': 1, 'CAPTION_SELECTION': 1})
        self.assertEqual(report['component_links'][1]['raw'], '\x11jb')
        self.assertEqual(report['component_links'][2]['boundary'], 'nil')
        self.assertEqual(report['component_links'][4]['section'], '')
        self.assertEqual(report['component_links'][4]['player_id'], '1234')
        self.assertEqual(report['component_links'][5]['identity'], 'window:cursor:panel')
        self.assertTrue(all(item['sequence'] == '4' for item in report['component_links']))
        self.assertFalse(report['component_links_truncated'])


if __name__ == '__main__':
    unittest.main()
