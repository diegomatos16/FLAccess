# FLAccess 0.1.7

Released October 21, 2026. Experimental non-OCR menu accessibility for SP Football
Life 2026 / PES 2021. Reads native game text and focus through Sider and Prism.
This is not complete match accessibility.

## Installation

Requires Windows x64, the compatible `FL_2026.exe` and working Sider 7.3.3.
NVDA or another supported screen reader is recommended; Prism can fall back to SAPI.

1. Close the game and Sider; back up the files you will replace.
2. Extract `FLAccess-0.1.7-sider.zip` and merge its `modules` folder into
   `SiderAddons/modules`.
3. Copy the included `sider.dll` into `SiderAddons`, replacing only the compatible
   Sider 7.3.3 core. Do not use this DLL with another Sider version.
4. Add `lua.module = "FLAccess.lua"` once under `[sider]` in `sider.ini`.
5. Start through Sider. Do not replace your entire configuration.

Includes Lua, Prism with its licenses and PT/EN text indices. Python is not
required to use the mod. Includes the locally tested modified Sider 7.3.3 DLL,
with the `overlay_content` event for reading other modules' textual overlays and
the stack-alignment fix. See `sider-core` for source and binary identification.
Game-menu reading uses its own hooks.
