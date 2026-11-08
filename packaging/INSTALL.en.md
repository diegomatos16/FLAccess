# FLAccess 0.2.2 — experimental installation

Use a Windows installation of Football Life 27 with a SiderAddons folder.
Extract FlAccess.zip into a temporary folder. Close the game and Sider. Back up
sider.ini, sider.dll, settings, WAVs, and camera profiles. Merge content and
modules into SiderAddons.

Open SiderAddons/sider.ini and check that lua.enabled, luajit.ext.enabled, and
match-stats.enabled are set to 1 in the [sider] section. Add the 31 lua.module
lines from sider/sider.ini.snippet in their listed order. When upgrading,
replace the previous FLAccess lines with this block. Remove the old
FlAccessReader and FlAccessGameplay cpk.root entries if present.

Resources: content/FlAccess/{sounds,text,cameras}. Unified settings:
modules/FlAccess/FlAccess.ini. Preserve previous read_tooltips/use_text_assets
and tackle_* values, custom WAVs and camera profiles instead of overwriting
with package defaults. Developer installation:
python tools/install_flaccess.py --sider <SiderAddons>
It creates backups and migrates preferences/resources. Python is not needed
to play. Close and reopen the game normally to load the update.

On compatible Sider 7.3.3 installations, copy sider/sider.dll from the ZIP (or
sider-core/sider.dll from the checkout) to SiderAddons/sider.dll. This core
update enables F1 help in other modules.

Prism is compiled from its official repository; commit/hash in PRISM-SOURCE.json.
DLLs and licenses included. Football Life 27 support remains experimental. See RELEASE.en.md for current features and known issues.
