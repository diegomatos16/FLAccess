import importlib.util
from pathlib import Path
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "tools" / "analyze_widget_structure.py"
SPEC = importlib.util.spec_from_file_location("widget_structure", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC and SPEC.loader
SPEC.loader.exec_module(MODULE)


class StructuralProbeTests(unittest.TestCase):
    def test_old_log_recovers_inline_engine_name(self):
        sample = '''EVENT 1 frame=100 kind=stable-focus role=dialog-button
text="OK"
object class=class-001 vtable_rva=0x27b5260 raw_qwords={+0x18=0x7274735f486e7462,+0x20=0x0,+0x28=0x8,+0x30=0xf}
'''
        events = MODULE.parse_events(sample)
        self.assertEqual(events[0]["internal_name"], "btnH_str")

    def test_relation_candidate_groups_different_widgets(self):
        sample = '''EVENT 1 frame=100 kind=stable-focus role=dialog-button
text="OK"
widget_internal_name="ok_text" source=msvc-string@+0x18
widget_relation_candidate=0x675cf550 source=pointer@+0x38
object class=class-001 vtable_rva=0x27b5260 raw_qwords={}
EVENT 2 frame=110 kind=stable-focus role=seletor
text="Número de usuários"
widget_internal_name="setName" source=msvc-string@+0x18
widget_relation_candidate=0x675cf550 source=pointer@+0x38
object class=class-001 vtable_rva=0x27b5260 raw_qwords={}
'''
        report = MODULE.summarize(MODULE.parse_events(sample))
        self.assertEqual(report["relation_candidates"]["0x675cf550"], {
            "events": 2, "names_or_roles": {"ok_text": 1, "setName": 1}})

    def test_new_log_prefers_explicit_name_and_shows_mixed_class(self):
        sample = '''EVENT 1 frame=100 kind=stable-focus role=dialog-button
text="OK"
widget_internal_name="ok_text" source=msvc-string@+0x18
object class=class-001 vtable_rva=0x27b5260 raw_qwords={}
EVENT 2 frame=110 kind=stable-focus role=seletor
text="Número de usuários"
widget_internal_name="setName" source=msvc-string@+0x18
object class=class-001 vtable_rva=0x27b5260 raw_qwords={}
'''
        report = MODULE.summarize(MODULE.parse_events(sample))
        self.assertEqual(report["events"], 2)
        self.assertEqual(report["names"]["ok_text"], {"dialog-button": 1})
        self.assertEqual(report["mixed_role_vtables"], ["0x27b5260"])


if __name__ == "__main__":
    unittest.main()
