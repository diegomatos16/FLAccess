"""Read-only contracts against this installed executable, not simulated UI proof."""
from pathlib import Path
import struct
import unittest

EXE = Path(__file__).resolve().parents[2] / "FL_2026.exe"


@unittest.skipUnless(EXE.exists(), "local executable unavailable")
class NativeContracts(unittest.TestCase):
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
        for table in (0x2673558,0x2715608,0x261F788,0x27D65C8):
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
