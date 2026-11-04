# FLAccess 0.2.0 — experimental installation

One package with native Sider components. Mandatory base reader.
Back up sider.ini, settings, WAVs and camera profiles. Merge content and modules
into SiderAddons. Replace only old FLAccess lua.module entries with the 31 lines
from sider.ini.snippet in their listed order. Do not enable legacy bundles too.
Remove only the two obsolete FLAccess cpk.root lines. Preserve other mods.

Resources: content/FlAccess/{sounds,text,cameras}. Unified settings:
modules/FlAccess/FlAccess.ini. Preserve previous read_tooltips/use_text_assets
and tackle_* values, custom WAVs and camera profiles instead of overwriting
with package defaults. Developer installation:
python tools/install_flaccess.py --sider <SiderAddons>
It creates backups and migrates preferences/resources. Python is not needed
to play. Close and reopen the game normally to load the update.

Preserve the installed compatible Sider core. The sider directory includes
the same compatible DLL as 0.1.9; target is SiderAddons/sider.dll, in the root.
Do not replace an unrelated Sider version without checking compatibility.

Prism is compiled from its official repository; commit/hash in PRISM-SOURCE.json.
DLLs and licenses included. Speech remains synchronous in Lua. Per-sound and
announcement controls are future work. FL2026/Sider 7.3.3 investigated base;
FL27 compatibility is experimental and partial. Release 0.2.0 uses Reader 52/
Gameplay 19. Lists still have severe slowdown reports; other Sider module options
are no longer read on FL27. Read the release notes/known issues before updating.
Previous published releases remain available.
