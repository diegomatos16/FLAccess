# FLAccess 0.1.8

Released October 26, 2026. Experimental non-OCR menu accessibility for SP Football
Life 2026 / PES 2021. Reads native game text and focus through Sider and Prism.
This is not complete match accessibility.

## Installation

Requires Windows x64, the compatible `FL_2026.exe` and working Sider 7.3.3.
NVDA or another supported screen reader is recommended; Prism can fall back to SAPI.

1. Close the game and Sider; back up the files you will replace.
2. Extract `FLAccess-0.1.8-sider.zip` and merge its `modules` folder into
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

## Controls and limitations

Use normal game navigation. I/K/J/L review available text in one sequence without
categories. Right-stick review is used only where it does not conflict with the
game. In the Sider accessibility panel, 6/7 select an option, 9/0 change it and
8 restores its default. Diagnostics start disabled. The mod does not echo inserted
characters; deletion/caret feedback is provided when detected. Screen-reader
typing echo is a separate setting.

This release incorporates dev 25's shared focus/name/value/context decisions,
delivery-time validation, stale-speech rejection, text review and native component
handling. Prior user approvals include camera, stadium, ML values and second-stage
confirmation, coach-name contents and Champions settings. Final live-game
regression testing remains incomplete.

Open reports include the initial title, training tabs, country selection, initial
league/club selection, club roster review, coach confirmation after editing,
the actual Skip button, ML introduction/home, roster status and Home/Neutral/Away.
Internal tests are not proof of live speech. See the Portuguese release notes
and issue matrix for the detailed implementation, evidence and limits.

Player review: K/right stick down starts on number/name, then primary position,
full/partial secondary positions and actual pitch position (or Not on the pitch).
I/right stick up moves backwards. Squad status is announced only during player
navigation. Game Plan options and Edit Position names were confirmed by the user;
dev 25 player details/status still require live validation.
