# Installation — FlAccess.zip — 0.1.9

The archive has three folders: livecpk, modules and sider. FlAccessReader handles
menus; FlAccessGameplay handles the radar and future in-match announcements.
Time/score announcements are not implemented by this reorganization.

1. Close the game and Sider. Back up sider.ini and sider.dll.
2. Merge livecpk and modules into SiderAddons, preserving other mods.
3. Copy sider/sider.dll from the archive to SiderAddons/sider.dll. It belongs in
   that root, not a sider subfolder. This core targets the documented compatible
   Sider 7.3.3 only; verify compatibility before installing over another version.
4. Add sider/sider.ini.snippet entries to the existing [sider] section. Do not
   replace the entire configuration. The two lua.module entries can be enabled
   independently.
5. Remove only old FLAccess.lua, FLAccess_audio.lua, FLAccess_match_registry.lua
   and FLAccess_gameplay_live.lua entries. Never enable old and new copies together.
6. To migrate preferences, copy modules/FLAccess.ini to
   modules/FlAccessReader/FlAccessReader.ini before first use.
7. Start the game through Sider normally.

Editable unencrypted WAVs: livecpk/FlAccessGameplay/sounds. Replace an existing
filename and restart the game to reload it. New filenames need event wiring.
Reader text assets: livecpk/FlAccessReader/text. Modules read their WAV/TSV assets
directly; LiveCPK itself does not play loose WAV files.

This release was investigated for FL 2026/FL_2026.exe and compatible Sider
7.3.3. FL 27 requires a separate compatibility check. Reader0.1.9 (base 42);
Gameplay experimental 16. Audible ball approval predates
this layout change; other new gameplay behavior still awaits real listening tests.
Prism and OpenAL licenses accompany their respective modules.

Back up custom WAVs/INIs before updating: the package includes defaults.
Do not add separate module entries for internal engine/ files.
