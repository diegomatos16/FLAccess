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
3. Add `lua.module = "FLAccess.lua"` once under `[sider]` in `sider.ini`.
4. Start through Sider. Do not replace your entire configuration.

Includes Lua, Prism with its licenses and PT/EN text indices. Python is not
required to use the mod. No `sider.dll` is distributed. Reading other Sider
modules' textual overlays requires the modified core's `overlay_content` event;
see `sider-core` for source and redistribution restrictions. Game-menu reading
uses its own hooks. Existing compatible custom cores can be retained.
