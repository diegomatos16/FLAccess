"""Read-only evidence for UI traversal gaps; never attaches to the game.

Reads the local executable, its existing RTTI inventory and a Sider capture.
Outputs native inheritance and decoded routines, not inferred UI visibility.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import struct
from pathlib import Path

import capstone
import pefile


ROUTINES = {
    "cursor_dispatch": (0xE72960, 0xA6),
    "indexed_child": (0xE8DC40, 0x2A),
    "normal_event": (0xE8F4A0, 0x66),
    "container_event": (0xE8E310, 0x90),
    "holder_primary_map": (0xE4DB00, 0xC0),
    "holder_secondary_map": (0xE4DBD0, 0xC0),
}


def collect(exe: Path, inventory: Path, capture: Path) -> dict:
    pe = pefile.PE(str(exe), fast_load=True)
    try:
        base = pe.OPTIONAL_HEADER.ImageBase
        types = []
        for entry in json.loads(inventory.read_text(encoding="utf-8"))["vtables"]:
            if entry["object_offset"] or "Node" not in entry["type"]:
                continue
            col = struct.unpack("<6I", pe.get_data(int(entry["col_rva"], 16), 24))
            hierarchy = struct.unpack("<4I", pe.get_data(col[4], 16))
            count = hierarchy[2]
            if not 0 < count <= 128:
                raise ValueError("Unexpected RTTI base count")
            descriptors = struct.unpack("<" + "I" * count, pe.get_data(hierarchy[3], count * 4))
            bases = []
            for descriptor in descriptors:
                td, _, offset, vbptr, vbdisp, _ = struct.unpack("<IIiiiI", pe.get_data(descriptor, 24))
                name = pe.get_data(td + 16, 200).split(b"\0", 1)[0].decode("ascii")
                bases.append({"type": name, "offset": offset, "vbptr": vbptr, "vbdisp": vbdisp})
            if any(b["type"] == ".?AVNodeRectHolder@menusystem@@" for b in bases):
                types.append({"type": entry["type"], "vtable": entry["vtable_rva"], "bases": bases})
        decoder = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_64)
        routines = {}
        for name, (rva, size) in ROUTINES.items():
            data = pe.get_data(rva, size)
            routines[name] = {
                "rva": hex(rva), "bytes": data.hex(),
                "assembly": [f"{ins.address - base:#x} {ins.mnemonic} {ins.op_str}" for ins in decoder.disasm(data, base + rva)],
            }
        text = capture.read_text(encoding="utf-8", errors="replace")
        cursors = re.findall(r"native-cursor frame=(\d+) text-widgets=([^\r\n]*)", text)
        windows = re.findall(r"native-windows frame=(\d+)([^\r\n]*)", text)
        return {
            "executable_sha256": hashlib.sha256(exe.read_bytes()).hexdigest(),
            "image_base": hex(base),
            "holder_types": types,
            "routines": routines,
            "capture": str(capture),
            "capture_counts": {
                "window_changes": len(windows), "cursor_changes": len(cursors),
                "cursor_changes_with_text": sum(bool(value.strip()) for _, value in cursors),
                "unbound_speech": text.count("source=legacy-or-system"),
            },
            "limits": "Static native event paths and inheritance do not prove current visibility or selection in the running game.",
        }
    finally:
        pe.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("exe", "inventory", "capture", "output"):
        parser.add_argument(name, type=Path)
    args = parser.parse_args()
    result = collect(args.exe, args.inventory, args.capture)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"holder_types": len(result["holder_types"]), **result["capture_counts"]}))
