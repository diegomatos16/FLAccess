# Installing FLAccess 0.1.5

1. Close the game and Sider.
2. Back up the installation's `SiderAddons` directory.
3. Copy `sider.dll` into `SiderAddons`, replacing only the existing 7.3.3 DLL.
4. Copy this package's `modules` directory into `SiderAddons`, merging it with
   the existing `SiderAddons/modules` directory.
5. Add the line from `sider.ini.snippet` to the `[sider]` section of your `sider.ini`.
6. Start the game normally with Sider.

Do not replace your complete `sider.ini`. The Lua module, `prism.dll`, and its
licenses all live under `SiderAddons/modules`. The module loads Prism directly;
there is no EXE, CMD, terminal, or .NET requirement.
The included `sider.dll` is the official 7.3.3 core with one accessibility
event added so every module's overlay text can be spoken, plus the official
7.3.4 stack-alignment fix. Do not use this DLL with another Sider version.

In the Sider accessibility panel, use `6` and `7` to navigate options, `9` and
`0` to change one, and `8` to restore its default. `Read tooltips` is saved in
`SiderAddons/modules/FLAccess.ini`; diagnostics always start disabled.

Compatibility: experimental build made for the studied `FL_2026.exe`. See `docs/README.en.md` for limitations and recovery.

Known 0.1.5 limitation: Game Plan, its submenus and player selection in Edit
Position remain unreliable and will be investigated in 0.1.6.
