"""Read-only contracts against this installed executable, not simulated UI proof."""
from pathlib import Path
import os
import re
import struct
import unittest

EXE = Path(os.environ.get("FLACCESS_TEST_EXE", str(Path(__file__).resolve().parents[2] / "FL_2026.exe")))


@unittest.skipUnless(EXE.exists(), "local executable unavailable")
class NativeContracts(unittest.TestCase):
    def test_key_configuration_uses_native_modes_rows_and_assignment_slots(self):
        vt = 0x2673ff8
        self.assertEqual(self.read_rva(vt + 0x18, 8), struct.pack("<Q", 0x140ac1940))
        self.assertEqual(self.read_rva(vt + 0x1a8, 8), struct.pack("<Q", 0x140ac2860))
        self.assertEqual(self.read_rva(0xac21ca, 6), bytes.fromhex("8887a2000000"))
        self.assertEqual(self.read_rva(0xac2627, 5), bytes.fromhex("e834faffff"))
        slots = []
        for index in range(8):
            slot, key = struct.unpack("<II", self.read_rva(0x2673b80 + index * 8, 8))
            slots.append(slot)
            self.assertGreaterEqual(key, 0x670003)
            self.assertLessEqual(key, 0x67000c)
        self.assertEqual(sorted(slots), list(range(8)))
        for index in range(8):
            pointer, slot = struct.unpack("<QI", self.read_rva(0x2674270 + index * 16, 12))
            self.assertEqual(self.read_rva(pointer - 0x140000000, 13), ("buttonName_" + str(index)).encode() + b"\0")
            self.assertIn(slot, slots)

    def test_audio_description_signatures_match_the_executable(self):
        source = (Path(__file__).resolve().parents[1] /
                  "modules/FlAccessOpeningTrace.lua").read_bytes()
        checks = re.findall(rb'\{(0x[0-9a-f]+), "((?:\\x[0-9a-f]{2})+)"\}', source)
        self.assertTrue(checks, "audio description has no executable guards")
        for address, literal in checks:
            with self.subTest(rva=address.decode()):
                expected = bytes.fromhex(literal.replace(b"\\x", b"").decode())
                self.assertEqual(self.read_rva(int(address, 16), len(expected)), expected)

    @classmethod
    def setUpClass(cls):
        cls.file = EXE.open("rb")
        cls.file.seek(0x3C)
        pe = struct.unpack("<I", cls.file.read(4))[0]
        cls.file.seek(pe)
        assert cls.file.read(4) == b"PE\0\0"
        coff = cls.file.read(20)
        sections = struct.unpack_from("<H", coff, 2)[0]
        optional = struct.unpack_from("<H", coff, 16)[0]
        cls.file.seek(pe + 24 + optional)
        cls.sections = []
        for _ in range(sections):
            data = cls.file.read(40)
            virtual_size, rva, size, offset = struct.unpack_from("<4I", data, 8)
            cls.sections.append((rva, max(size, virtual_size), offset))

    @classmethod
    def tearDownClass(cls):
        cls.file.close()

    def test_swf_loader_delegates_only_with_a_live_owned_child(self):
        self.assertEqual(self.read_rva(0x27b9038+0x88,8),struct.pack('<Q',0x140e53800))
        self.assertEqual(self.read_rva(0x27b9038+0x28,8),struct.pack('<Q',0x140e537e0))
        for rva in (0xe53800,0xe537e0):
            code=self.read_rva(rva,26)
            self.assertEqual(code[:7],bytes.fromhex('488b8198000000'))
            self.assertIn(bytes.fromhex('4883783800'),code)
            self.assertEqual(code[-3:],bytes.fromhex('33c0c3'))

    def test_save_selector_and_agreement_dialog_are_the_typed_native_windows(self):
        for vt,name,a,b in ((0x2948538,b'SaveDataSelect@savesystem',0x14217c0,0xca1a50),
                            (0x27bd238,b'DialogAgreement@menusystem',0xe607d0,0xe472b0)):
            col=struct.unpack('<Q',self.read_rva(vt-8,8))[0]-0x140000000
            td=struct.unpack('<I',self.read_rva(col+12,4))[0]
            self.assertIn(name,self.read_rva(td+16,100))
            self.assertEqual(self.read_rva(vt+0x18,8),struct.pack('<Q',0x140000000+a))
            self.assertEqual(self.read_rva(vt+0x100,8),struct.pack('<Q',0x140000000+b))

    def test_automatic_carousel_filter_uses_the_real_team_select_common_type(self):
        vt=0x271c8c8
        col=struct.unpack('<Q',self.read_rva(vt-8,8))[0]-0x140000000
        td=struct.unpack('<I',self.read_rva(col+12,4))[0]
        self.assertIn(b'TeamSelectCommon@',self.read_rva(td+16,100))
        self.assertEqual(self.read_rva(vt+0x18,8),struct.pack('<Q',0x140000000+0xc93200))

    def test_standings_row_renderer_indexes_the_native_team_vector(self):
        vt=0x2684408
        self.assertEqual(self.read_rva(vt+0x18,8),struct.pack('<Q',0x140000000+0xaed5d0))
        self.assertEqual(self.read_rva(vt+0x130,8),struct.pack('<Q',0x140000000+0xaedf80))
        self.assertEqual(self.read_rva(0xaedfb6,7),bytes.fromhex('488b8398000000'))
        self.assertEqual(self.read_rva(0xaedfbd,7),bytes.fromhex('482b8390000000'))
        self.assertEqual(self.read_rva(0xe3d1c1,6),bytes.fromhex('8b80bc000000'))
        self.assertEqual(self.read_rva(0xe3d1a9,3),bytes.fromhex('4533c0'))

    def test_standings_visible_selection_comes_from_window_controller(self):
        self.assertEqual(self.read_rva(0xe3d120,14),bytes.fromhex('488b81880000008b80d8000000c3'))
        self.assertEqual(self.read_rva(0xe41512,16),bytes.fromhex('448b87bc000000418bc02b87c0000000'))
        self.assertEqual(self.read_rva(0xe41532,6),bytes.fromhex('8981d8000000'))

    def test_current_career_date_copies_the_native_year_month_day_value(self):
        self.assertEqual(self.read_rva(0x14b6a60,8),bytes.fromhex('488b05a9f32402c3'))
        self.assertEqual(0x14b6a67+0x224f3a9,0x3705e10)
        self.assertEqual(self.read_rva(0x15765ee,4),bytes.fromhex('488b5048'))
        self.assertEqual(self.read_rva(0x15765f2,6),bytes.fromhex('8b82242a6401'))
        self.assertEqual(self.read_rva(0x15765f8,2),bytes.fromhex('8903'))
        self.assertEqual(self.read_rva(0x14c92cc,8),bytes.fromhex('6641890245885a02'))

    def test_calendar_cursor_uses_its_typed_controller_and_visible_row_not_outer_cursor(self):
        self.assertEqual(self.read_rva(0x268bda8+0x18,8),struct.pack('<Q',0x140000000+0xb05640))
        self.assertEqual(self.read_rva(0xb0120c,6),bytes.fromhex('8b8bfc000000'))
        self.assertEqual(self.read_rva(0xb01323,6),bytes.fromhex('89b3fc000000'))
        self.assertEqual(self.read_rva(0xb01296,4),bytes.fromhex('448d460e'))

    def test_record_display_state_does_not_require_input_participation(self):
        self.assertEqual(self.read_rva(0xe4bb90,12),bytes.fromhex('0fb6410c24073c070f94c0c3'))

    def read_rva(self, rva, size):
        for first, length, offset in self.sections:
            if first <= rva and rva + size <= first + length:
                self.file.seek(offset + rva - first)
                return self.file.read(size)
        raise AssertionError("RVA outside executable sections")

    def test_holder_secondary_dispatch_visits_both_secondary_maps(self):
        data = self.read_rva(0xE4DBD0, 0x163)
        self.assertIn(bytes.fromhex("488b8188000000"), data)  # holder +88
        self.assertIn(bytes.fromhex("488b4778"), data)  # holder +78
        self.assertEqual(data.count(bytes.fromhex("488b4b40")), 2)  # child +40
        self.assertEqual(data[-1], 0xC3)

    def test_structured_record_inner_selector_uses_the_native_selected_index_getter(self):
        self.assertEqual(self.read_rva(0xE3D91E, 6).hex(), '8b80bc000000')
        self.assertEqual(self.read_rva(0xE3D910, 4).hex(), '418d5010')
        for vt,kind in ((0x27B84D0,b'NodeRectSelector@'),(0x27BE998,b'NodeRectSelectorJump@')):
            col=struct.unpack('<Q',self.read_rva(vt-8,8))[0]-0x140000000
            td=struct.unpack('<I',self.read_rva(col+12,4))[0]
            self.assertIn(kind,self.read_rva(td+16,96))

    def test_standings_column_names_come_from_the_actual_native_renderer(self):
        # af7327..af7389 initializes the ordered numeric column descriptors;
        # af76b1 resolves the team caption. Read the executable's pointers.
        expected={0x34ACD00:'match',0x34ACD48:'ptsText',0x34ACD40:'winText',
            0x34ACD38:'drawText',0x34ACD30:'loseText',0x34ACD28:'goalsText',
            0x34ACD20:'goalsAgainstText',0x34ACD18:'goalDifferenceText',0x34ACD50:'teamNameText'}
        for at,name in expected.items():
            ptr=struct.unpack('<Q',self.read_rva(at,8))[0]-0x140000000
            self.assertEqual(self.read_rva(ptr,len(name)+1),name.encode()+b'\0')

    def test_loading_singleton_is_created_typed_and_cleared_by_its_cleanup(self):
        create = self.read_rva(0xE4A698, 7)
        self.assertEqual(create[:3], bytes.fromhex('488905'))
        self.assertEqual(0xE4A69F + struct.unpack_from('<i', create, 3)[0], 0x36F9A68)
        clear = self.read_rva(0xE4A63B, 11)
        self.assertEqual(clear[:3], bytes.fromhex('48c705'))
        self.assertEqual(0xE4A646 + struct.unpack_from('<i', clear, 3)[0], 0x36F9A68)
        constructor = self.read_rva(0xE4A2BA, 7)
        self.assertEqual(0xE4A2C1 + struct.unpack_from('<i', constructor, 3)[0], 0x27B55B8)
        self.assertEqual(struct.unpack('<Q', self.read_rva(0x27B55B8 + 8, 8))[0], 0x140E4A630)

    def test_mailbox_selected_record_layout_matches_the_native_render_producer(self):
        self.assertEqual(struct.unpack('<Q', self.read_rva(0x26A1120 + 0x148, 8))[0], 0x140B43AD0)
        data = self.read_rva(0xB44520, 0x400)
        for pattern in ('488b8998000000', '482b8f90000000', '488d5308', '48635348', '4c8d4350'):
            self.assertIn(bytes.fromhex(pattern), data)
        self.assertEqual(self.read_rva(0xB4458E, 15).hex(), '4b8d1cc048c1e30448039f90000000')
        self.assertEqual(self.read_rva(0xE3D91E, 6).hex(), '8b80bc000000')

    def test_country_guard_uses_the_real_native_method_slot(self):
        source = (Path(__file__).resolve().parents[1] / 'modules/FlAccess/reader_lists.lua').read_text(encoding='utf-8')
        import re
        guard = re.search(r'menu_read\(vt\+(0x[0-9a-f]+),"u64"\)==base\+0xc97190', source)
        self.assertIsNotNone(guard)
        slot = int(guard[1], 16)
        self.assertEqual(struct.unpack('<Q', self.read_rva(0x271f4d0 + slot, 8))[0], 0x140C97190)
        self.assertEqual(struct.unpack('<Q', self.read_rva(0x271f4d0 + 0x260, 8))[0], 0x140C9DAF0)

    def test_nationality_override_uses_filtered_ids_instead_of_generic_caption_records(self):
        vt = 0x271f4d0
        self.assertEqual(struct.unpack('<Q', self.read_rva(vt + 0x278, 8))[0], 0x140C9E980)
        render = self.read_rva(0xC9E980, 0x290)
        self.assertIn(bytes.fromhex('80bd8001000000'), render)  # specialized mode at +180
        self.assertIn(bytes.fromhex('458b7f64'), render)  # center scroll index
        for at, target in ((0xC9EB30, 0xC9D900), (0xC9EB3D, 0xCBBA20)):
            call = self.read_rva(at, 5)
            self.assertEqual(call[0], 0xe8)
            self.assertEqual(at + 5 + struct.unpack_from('<i', call, 1)[0], target)
        selected = self.read_rva(0xC952F3, 6)
        self.assertEqual(selected.hex(), '8b4168034164')  # selected+scroll, not cursor flags
        getter = self.read_rva(0xC9D900, 0x7a)
        self.assertIn(bytes.fromhex('488d8b70010000'), getter)  # per-continent filtered map
        self.assertIn(bytes.fromhex('488b4128'), getter)
        self.assertIn(bytes.fromhex('0fb70450'), getter)  # uint16 ID vector

    def test_country_name_database_layout_matches_the_native_lookup(self):
        getter = self.read_rva(0x14B6A60, 8)
        self.assertEqual(getter[:3], bytes.fromhex('488b05'))
        self.assertEqual(0x14B6A67 + struct.unpack_from('<i', getter, 3)[0], 0x3705E10)
        self.assertEqual(self.read_rva(0xCBBA3F, 4).hex(), '488b4848')
        lookup = self.read_rva(0x14BB0B0, 0x3c)
        self.assertIn(bytes.fromhex('8b81e0b58401'), lookup)  # count
        self.assertIn(bytes.fromhex('488d99203f8401'), lookup)  # records
        self.assertIn(bytes.fromhex('4c6bc04c'), lookup)  # 0x4c stride
        search = self.read_rva(0x14B8060, 0x85)
        self.assertIn(bytes.fromhex('81e1ff010000'), search)  # 9-bit country ID
        # Compare maintained Lua offsets with values encoded by the native
        # consumer; a fixture repeating a wrong constant must not certify it.
        source = (Path(__file__).resolve().parents[1] / 'modules/FlAccess/reader_lists.lua').read_text(encoding='utf-8')
        import re
        body = source.split('function shared.a11y.country_name(id)', 1)[1].split('function shared.a11y.native_country_selection()', 1)[0]
        global_offset = int(re.search(r'base\+(0x[0-9a-f]+)', body)[1], 16)
        count_offset = int(re.search(r'database\+(0x[0-9a-f]+),"u32"', body)[1], 16)
        records_offset = int(re.search(r'local first=database\+(0x[0-9a-f]+)', body)[1], 16)
        stride = int(re.search(r'first\+mid\*(0x[0-9a-f]+)', body)[1], 16)
        self.assertEqual(global_offset, 0x14B6A67 + struct.unpack_from('<i', getter, 3)[0])
        self.assertEqual(count_offset, struct.unpack('<I', self.read_rva(0x14BB0B8, 4))[0])
        self.assertEqual(records_offset, struct.unpack('<I', self.read_rva(0x14BB0BF, 4))[0])
        self.assertEqual(stride, self.read_rva(0x14BB0D0, 1)[0])

    def test_nested_list_caption_hook_preserves_complete_nonrelative_instructions(self):
        self.assertEqual(self.read_rva(0xC978B5,15).hex(),'904533c94533c0488d542430488bcf')
        self.assertEqual(self.read_rva(0xC97874,4).hex(),'488d5628')
        call=self.read_rva(0xC978C4,5)
        self.assertEqual(call[0],0xe8)
        self.assertEqual(0xC978C9+struct.unpack_from('<i',call,1)[0],0xE48BF0)


    def test_final_setter_prologue_contains_complete_instructions(self):
        self.assertEqual(self.read_rva(0xE49070, 22).hex(),
                         "488bc45556574881ec0001000048c7442420feffffff")

    def test_final_setter_has_a_direct_caller_bypassing_outer_preparation(self):
        for caller in (0x915F86, 0xE48F69):
            data = self.read_rva(caller, 5)
            self.assertEqual(data[0], 0xE8)
            self.assertEqual(caller + 5 + struct.unpack_from("<i", data, 1)[0], 0xE49070)

    def test_native_renderer_setter_owns_a_persistent_text_copy(self):
        self.assertEqual(self.read_rva(0xE29EB8, 4), bytes.fromhex("48894638"))
        for vtable in (0x27AE960, 0x27B0860):
            self.assertEqual(struct.unpack("<Q", self.read_rva(vtable + 16, 8))[0],
                             0x140000000 + 0xE29E40)

    def test_headline_and_slider_thunk_has_the_same_owned_node_contract(self):
        code = self.read_rva(0xE546A0, 5)
        self.assertEqual(code[0], 0xE9)
        self.assertEqual(0xE546A5 + struct.unpack('<i', code[1:])[0], 0xE8ECD0)
        for vtable in (0x27B9770, 0x27B9848, 0x27BAC10):
            self.assertEqual(struct.unpack('<Q', self.read_rva(vtable + 0x88, 8))[0], 0x140E546A0)
            self.assertEqual(struct.unpack('<Q', self.read_rva(vtable + 0x28, 8))[0], 0x140E8ECB0)

    def test_language_commit_slot_distinguishes_sound_and_text_before_confirmation(self):
        for vtable, setter in ((0x2696610, 0xB229F0), (0x2696390, 0xB22A50)):
            self.assertEqual(struct.unpack('<Q', self.read_rva(vtable + 0x258, 8))[0], 0x140000000 + setter)

    def test_playing_style_uses_property_3b_and_separate_native_translation_tables(self):
        self.assertEqual(self.read_rva(0x14C0309, 5), bytes.fromhex('ba3b000000'))
        target = struct.unpack('<I', self.read_rva(0x14C6CDC + 0x3B * 4, 4))[0]
        self.assertEqual(self.read_rva(target, 10), bytes.fromhex('8b411cc1e80b83e01f41'))
        self.assertEqual(struct.unpack('<22I', self.read_rva(0x2979080, 88)),
                         (0,1,2,3,6,9,10,11,14,12,19,15,17,4,5,18,20,21,7,8,13,16))
        self.assertEqual(self.read_rva(0xEA67B0, 3), bytes.fromhex('83f916'))
        self.assertEqual(self.read_rva(0xEA67C1, 3), bytes.fromhex('8b04c1'))

    def test_information_and_pause_roles_have_distinct_lifecycle_and_update_methods(self):
        for vtable, destructor, update in ((0x2628BD0,0x90CA30,0x9113C0),
                                          (0x25B3CF8,0x4D7540,0x4D7610)):
            self.assertEqual(struct.unpack('<Q',self.read_rva(vtable+0x18,8))[0],0x140000000+destructor)
            self.assertEqual(struct.unpack('<Q',self.read_rva(vtable+0x100,8))[0],0x140000000+update)

    def test_parts_forward_to_owned_node_pointer_not_inline_holder(self):
        # Two independent forwarders read +98 then invoke the child, proving
        # the layout used by traversal. No game calls are executed by the mod.
        self.assertEqual(self.read_rva(0xE8ECD0, 7), bytes.fromhex("488b8998000000"))
        self.assertEqual(self.read_rva(0xE8ECB0, 7), bytes.fromhex("488b8998000000"))
        for vtable in (0x27B84D0, 0x27BB538, 0x27C0338, 0x27C3A38):
            self.assertEqual(struct.unpack("<Q", self.read_rva(vtable + 0x88, 8))[0],
                             0x140E8ECD0)
            self.assertEqual(struct.unpack("<Q", self.read_rva(vtable + 0x28, 8))[0],
                             0x140E8ECB0)

    def test_default_text_renderer_proxy_calls_the_same_owned_copy_setter(self):
        self.assertEqual(struct.unpack("<Q", self.read_rva(0x27B0420 + 16, 8))[0],
                         0x140E2FA60)
        # Proxy does not adjust rcx before calling the known base setter.
        data = self.read_rva(0xE2FA60, 27)
        self.assertEqual(data[22], 0xE8)
        self.assertEqual(0xE2FA76 + 5 + struct.unpack_from("<i", data, 23)[0], 0xE29E40)

    def test_carousel_label_registers_are_the_actual_text_assignment_targets(self):
        self.assertEqual(self.read_rva(0xC973ED, 3), bytes.fromhex("498bcc"))  # rcx=r12
        for caller in (0xC97C3D, 0xC97CB3):
            self.assertEqual(self.read_rva(caller, 3), bytes.fromhex("488bcf"))  # rcx=rdi

    def test_popup_edit_state_and_utf8_cursor_are_read_from_native_consumers(self):
        self.assertEqual(self.read_rva(0xD42B9B, 4), bytes.fromhex("488d5108"))
        self.assertEqual(self.read_rva(0xE7B51A, 7), bytes.fromhex("498d8d10010000"))
        self.assertEqual(self.read_rva(0xE7B6DB, 7), bytes.fromhex("418b9d10010000"))
        self.assertIn(bytes.fromhex("24c03c80"), self.read_rva(0x14ABC20, 33))

    def test_window_close_owns_all_resource_roots_and_clears_their_shown_state(self):
        data = self.read_rva(0xE4346C, 0x49)
        self.assertIn(bytes.fromhex("488b4178"), data)  # vector end
        self.assertIn(bytes.fromhex("488b5970"), data)  # vector begin
        self.assertIn(bytes.fromhex("488b4b40"), data)  # each owned Node
        self.assertIn(bytes.fromhex("4883c350"), data)  # record stride
        self.assertEqual(self.read_rva(0xE4C24F, 8), bytes.fromhex("418bc0f7d021410c"))

    def test_help_box_and_editable_input_use_the_verified_node_delegates(self):
        for vtable in (0x27C17A0, 0x27C3A38):
            self.assertEqual(struct.unpack('<Q', self.read_rva(vtable + 0x88, 8))[0], 0x140E8ECD0)
            self.assertEqual(struct.unpack('<Q', self.read_rva(vtable + 0x28, 8))[0], 0x140E8ECB0)

    def test_inspected_controller_font_fixture_has_the_actual_profile_signature(self):
        import zlib
        path = Path(__file__).resolve().parent / "voice-evidence" / "controller-font.bin"
        raw = path.read_bytes()
        self.assertEqual((len(raw), zlib.adler32(raw)), (55036, 38782804))
        decoded = zlib.decompress(raw[16:])
        self.assertEqual((len(decoded), zlib.adler32(decoded)), (760560, 3728391537))
        self.assertEqual(decoded[32:36], b"WFNT")
        # Glyph e008 is the actual Options bitmap inspected in the gallery.
        self.assertEqual(decoded[64+8*16:68+8*16], bytes.fromhex("8880ee00"))

    def test_page_records_own_the_caption_and_native_index_drives_active_animation(self):
        self.assertEqual(self.read_rva(0xEB1C87,6).hex(), '89aed0010000')
        self.assertEqual(self.read_rva(0xEB1928,6).hex(), '89b3d0010000')
        self.assertEqual(self.read_rva(0xEB1353,4).hex(), '49895e20')
        self.assertIn(bytes.fromhex('488b4b20'),self.read_rva(0xEB0E90,62))
        self.assertIn(bytes.fromhex('488b4b20'),self.read_rva(0xEB1090,62))
        self.assertEqual(struct.unpack('<Q',self.read_rva(0x27D65C8+0x2E8,8))[0],0x140EB1B60)

    def test_command_bar_singleton_and_explicit_icon_caption_pairs(self):
        data=self.read_rva(0xE34B6F,7)
        self.assertEqual(0xE34B76+struct.unpack_from('<i',data,3)[0],0x36F98F0)
        data=self.read_rva(0xE353F0,0x59)
        self.assertIn(bytes.fromhex('488907'),data)  # icon at current pair
        self.assertIn(bytes.fromhex('48894708'),data)  # caption at pair+8
        self.assertIn(bytes.fromhex('4883c718'),data)  # stride 18
        self.assertIn(bytes.fromhex('488dbb90000000'),self.read_rva(0xE353CD,0x1A))
        self.assertIn(bytes.fromhex('48894370'),self.read_rva(0xE35354,0x1A))

    def test_command_presentation_uses_ordered_kind_indices_not_constructor_templates(self):
        self.assertEqual(self.read_rva(0xE4D1C0,4).hex(),'488b4978')
        self.assertIn(bytes.fromhex('488b5040'),self.read_rva(0xE4D1C0,0x22))
        self.assertIn(bytes.fromhex('44399288000000'),self.read_rva(0xE4D1C0,0x22))
        data=self.read_rva(0xE3593A,0x34)
        self.assertIn(bytes.fromhex('ba13000000'),data)
        self.assertIn(bytes.fromhex('448d4307'),data)
        for caller in (0xE3594D,0xE35969,0xE35A77,0xE35A94):
            data=self.read_rva(caller,5)
            self.assertEqual(data[0],0xE8)
            self.assertEqual(caller+5+struct.unpack_from('<i',data,1)[0],0xE4D1C0)

    def test_window_exposes_distinct_resource_and_navigation_graphs(self):
        self.assertEqual(self.read_rva(0xE3D790,15).hex(),'488b8188000000488b8090000000c3')
        self.assertEqual(self.read_rva(0xE3DC90,15).hex(),'488b8188000000488b8098000000c3')

    def test_roster_boundary_hook_copies_complete_position_independent_instructions(self):
        # Executed after the actual rules helper returns, EBX contains its result.
        self.assertEqual(self.read_rva(0x8F8392,14).hex(),'488d4c2430ba0d0000000f1f4000')
        data=self.read_rva(0x8F837F,13)
        self.assertEqual(data[0],0xE8)
        self.assertEqual(0x8F8384+struct.unpack_from('<i',data,1)[0],0x8E9210)
        self.assertEqual(data[5:8],bytes.fromhex('0fb6d8'))  # EBX=AL
        self.assertEqual(self.read_rva(0x8F7F90,12).hex(),'8b81e804000083c00b03c2c3')
        self.assertEqual(self.read_rva(0x914810,8).hex(),'488b8cf3b8000000')

    def test_roster_model_getters_bind_slots_records_and_player_ids(self):
        getter = self.read_rva(0x8E1AF0, 8)
        self.assertEqual(getter[:3], bytes.fromhex('488b05'))
        self.assertEqual(0x8E1AF7 + struct.unpack_from('<i', getter, 3)[0], 0x36F38A0)
        for table in (0x261EAA0, 0x261F788):
            self.assertEqual(struct.unpack('<Q', self.read_rva(table+0x328,8))[0], 0x140914280)
            self.assertEqual(struct.unpack('<Q', self.read_rva(table+0x338,8))[0], 0x140A42FA0)
        body=self.read_rva(0x914280,0x65)
        self.assertIn(bytes.fromhex('8bbc81a0020000'),body)  # card index -> record index
        self.assertIn(bytes.fromhex('4869d340030000'),body)  # side * 340
        self.assertIn(bytes.fromhex('488d88a8040000'),body)  # model base +4a8
        self.assertEqual(self.read_rva(0x8E1E14,9).hex(),'420f1084c1b8000000')
        self.assertEqual(self.read_rva(0x8E1E47,4).hex(),'488b402c')
        # Rendering reads the high dword of this exact +2c pair as player id.
        self.assertEqual(self.read_rva(0x915E43,3).hex(),'8b5004')
        self.assertEqual(self.read_rva(0x8E1C38,8).hex(),'0fb68408e4010000')

    def test_shared_caption_consumer_and_related_player_controller_contracts(self):
        lea=self.read_rva(0x8F0385,7)
        self.assertEqual(lea[:3],bytes.fromhex('488d15'))
        target=0x8F038C+struct.unpack_from('<i',lea,3)[0]
        self.assertEqual(self.read_rva(target,5),b'text\0')
        self.assertEqual(self.read_rva(0x8F03EF,3).hex(),'488bce')
        # Both selection components use the same inherited controller methods.
        for table in (0x2622C98,0x2623198,0x2623678):
            self.assertEqual(struct.unpack('<Q',self.read_rva(table+0x100,8))[0],0x140917A40)
            self.assertEqual(struct.unpack('<Q',self.read_rva(table+0x1A0,8))[0],0x140917EE0)
        self.assertEqual(struct.unpack('<Q',self.read_rva(0x261E0C8+0x110,8))[0],0x1408F59F0)
        self.assertEqual(self.read_rva(0x8F59AB,7).hex(),'448b8398000000')
        self.assertEqual(self.read_rva(0x917F07,8).hex(),'c74424301b300801')

    def test_player_panel_descriptor_selects_variant_slot_and_side(self):
        for index, name in enumerate((b'playerInfo_0\0', b'playerInfo_1\0')):
            pointer=struct.unpack('<Q',self.read_rva(0x34A2048+index*8,8))[0]-0x140000000
            self.assertEqual(self.read_rva(pointer,len(name)),name)
        self.assertEqual(self.read_rva(0x8E1E90,31).hex(),
                         '418bc04c8d0480428b84818c000000420f1044817c0f1102894210488bc2c3')
        self.assertIn(bytes.fromhex('4869c9a8000000'),self.read_rva(0x910410,0x80))
        self.assertEqual(self.read_rva(0x21F8690,5).hex(),'488b4108c3')

    def test_player_position_properties_are_packed_independently_from_formation(self):
        targets=struct.unpack('<14I',self.read_rva(0x14C6CDC,56))
        self.assertEqual(self.read_rva(targets[0],12).hex(),'8b4104c1e81c418900b001c3')
        for position, target in enumerate(targets[1:]):
            if position<3:
                prefix=bytes.fromhex('8b411cc1e8')+bytes([25+position*2])+bytes.fromhex('83e003')
            elif position==3:
                prefix=bytes.fromhex('8b412083e003')
            elif position==11:
                prefix=bytes.fromhex('0fb7412283e003')  # low bits of +22 = +20 >>16
            else:
                prefix=bytes.fromhex('8b4120c1e8')+bytes([(position-3)*2])+bytes.fromhex('83e003')
            self.assertEqual(self.read_rva(target,len(prefix)),prefix)

    def test_formation_role_getter_uses_slot_and_current_phase(self):
        data=self.read_rva(0x14C61D0,68)
        for instruction in ('0fb6440842','0fb6440821','0fb60408','b80d000000c3'):
            self.assertIn(bytes.fromhex(instruction),data)
        data=self.read_rva(0x8E1550,74)
        for instruction in ('4869c8a8000000','468b8c11340b0000','4869c848020000'):
            self.assertIn(bytes.fromhex(instruction),data)
        self.assertEqual(self.read_rva(0x14C0D50,5).hex(),'0fb64133c3')

    def test_window_task_layout_is_identified_by_two_lifecycle_methods(self):
        for table in (0x2673558,0x2715608,0x261F788,0x27D65C8,0x2675FD0,0x27C0B30):
            self.assertEqual(struct.unpack('<Q',self.read_rva(table+0x50,8))[0],0x140E43510)
            self.assertEqual(struct.unpack('<Q',self.read_rva(table+0x58,8))[0],0x140E43450)
        data=self.read_rva(0x149FC70,0x70)
        self.assertIn(bytes.fromhex('48897b38'),data)  # child's parent link
        self.assertIn(bytes.fromhex('48895f40'),data)  # parent's child anchor

    def test_renderer_markers_use_the_actual_symbol_table_and_remapped_confirm(self):
        # j/k dispatch selects physical/current-action callbacks, not alphabetic glyph order.
        for letter,target in (('j',0xE2AE1B),('k',0xE2AE26)):
            self.assertEqual(struct.unpack('<I',self.read_rva(0xE2AEA8+(ord(letter)-0x63)*4,4))[0],target)
        self.assertEqual(struct.unpack('<15I',self.read_rva(0x27AE3B8,60)),tuple(range(12))+(29,30,31))
        self.assertEqual(struct.unpack('<9I',self.read_rva(0x27AE3F8,36)),(32,33,6,7,8,9,5,2,0))
        # Physical marker jb references the actual Options glyph in the default table.
        pointer=struct.unpack('<Q',self.read_rva(0x34C0660+16+8,8))[0]-0x140000000
        self.assertEqual(self.read_rva(pointer,4),bytes.fromhex('ee808800'))
        self.assertEqual(struct.unpack('<Q',self.read_rva(0x267E750+0x2E8,8))[0],0x140EB1B60)

    def test_assignment_component_indexes_the_actual_selected_group_and_column(self):
        self.assertEqual(struct.unpack('<Q',self.read_rva(0x2715608+0x140,8))[0],0x140C68FD0)
        self.assertEqual(struct.unpack('<Q',self.read_rva(0x2715608+0x148,8))[0],0x140C67970)
        self.assertEqual(self.read_rva(0xC68E75,6).hex(),'8b9694000000')
        self.assertEqual(self.read_rva(0xC68EDD,6).hex(),'8b96a4000000')
        self.assertEqual(self.read_rva(0xC67A55,6).hex(),'89bba4000000')
        self.assertEqual(self.read_rva(0xC67AD0,12).hex(),'8b91a400000033c085d27506')


if __name__ == "__main__":
    unittest.main()
