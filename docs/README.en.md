# PES / Football Life accessibility scanner

Version: **0.1.4**  
Package date: **August 29, 2026**

## Purpose

This project researches non-OCR menu accessibility for SP Football Life 2026, based on PES 2021. It captures strings and focus-related signals from the game's internal structures through a Sider Lua module, then sends announcements to NVDA through Prism. If no compatible screen reader is active, Prism attempts to use Microsoft SAPI.

Version 0.1.4 is experimental. It makes parts of the menus speak, including correct league and club selection, but it does not provide complete match accessibility.

## Installing the ready-to-use package

Requirements:

- SP Football Life 2026 with a compatible `FL_2026.exe`;
- a working Sider installation;
- 64-bit Windows with the .NET 8 runtime;
- NVDA is recommended, although the bridge can select another backend exposed by Prism.

Steps:

1. Close the game and Sider.
2. Back up the `SiderAddons` directory.
3. Copy the package's `SiderAddons` contents into the game's `SiderAddons` directory.
4. Add this line to the `[sider]` section of `SiderAddons/sider.ini`:

```ini
lua.module = "pes_a11y_menu_string_probe.lua"
```

5. Start the game through the normal Sider-enabled flow and keep NVDA running.

The bridge starts automatically after the game begins rendering. A terminal and the included `start-pes-a11y.cmd` are not required; the script is retained for diagnostics.

## Confirmed behavior

- automatic loading through Sider;
- automatic bridge startup and shutdown with the game;
- NVDA speech through Prism;
- an implemented SAPI fallback;
- internal UTF-8 string capture without OCR;
- main-menu item and tooltip reading in the tested flow;
- labels, values and horizontal changes on audio sliders;
- several list and settings screens that use known widgets;
- partial labels and values in controller and general settings;
- only the new value is announced for recognized horizontal changes;
- tooltip speech after a short pause on compatible screens;
- some `Yes`/`No` dialogs;
- native, synchronized reading of the league actually selected;
- native reading of the club actually selected, including standard and alternate/modded names;
- league and club selection confirmed in the Premier League and Brasileirão;
- startup cleanup of the speech handoff file and safeguards against repeated or previous-screen announcements.

## Experimental coverage and limitations

Recent tests show that speech can still lose track of focus when entering or leaving a screen. In particular:

- the first submenu after the main menu can remain silent;
- the `Welcome to Football Life` screen containing local match, league, cup and co-op is not reliable on every entry;
- horizontal `Home`, `Neutral` and `Away` placement worked in the tested flow, but multi-controller combinations still need broader coverage;
- native league and club reading was validated in the tested friendly-match flow; other modes still need complete testing;
- away-team selection still needs to be retested with the new native club reader;
- pre-match items do not have stable coverage yet;
- some settings menus read only the following screen or values without their labels;
- language, camera, game-speed and dialog screens use different implementations and have partial coverage;
- objects from earlier screens can remain alive in memory, causing delay or incorrect speech despite the current safeguards;
- internal addresses are specific to the studied `FL_2026.exe` build;
- controlled player, ball, field direction and other gameplay information are not implemented.

## Architecture

```text
FL_2026.exe
  -> native hooks installed by the Sider Lua module
  -> string, widget, value and focus association
  -> SiderAddons/pes_a11y_speech.txt
  -> .NET/Prism bridge
  -> NVDA, another compatible reader, or SAPI
```

The module waits for 120 `display_frame` calls before starting the bridge. This avoids the loader lock observed when launching an external process during `init`. The bridge checks the handoff file every 5 ms, interrupts earlier speech during fast navigation, and exits when the game process ends.

## Source layout

- `modules/pes_a11y_menu_string_probe.lua`: main Sider module;
- `prism-bridge/Program.cs`: speech bridge;
- `prism-bridge/PesA11yPrismBridge.csproj`: .NET 8 project;
- `prism-bridge/vendor/`: Prism DLL and third-party notices;
- `tools/`: static-analysis utilities used during research;
- `docs/`: English and Brazilian Portuguese documentation.

Runtime-generated files:

- `SiderAddons/pes_a11y_speech.txt`: latest bridge message;
- `SiderAddons/sider.log`: Sider and module log;

The former extensive widget-capture trigger is disabled in version 0.1.4 to prevent render-thread stalls.

## Identified addresses

These RVAs apply only to the studied executable:

| Routine | RVA | Purpose |
|---|---:|---|
| Localization resolver output | `0x1496A3C` | UTF-8 text, length and ID |
| Slider initialization | `0xE59F80` | Object, minimum, maximum and value |
| Slider value change | `0xE5A190` | New value |
| Final UI-text setter | `0xE48BF0` | Dynamic text associated with a widget |
| League-list center item | `0xC97408` | Record of the league actually selected |
| Alternate center-club name | `0xC97C32` | Modified name of the selected club |
| Standard center-club name | `0xC97CA8` | Database name of the selected club |
| Game-text language change | `0xB22A50` | Language index |
| Commentary-language change | `0xB229F0` | Language index |
| Game-text language navigation | `0xB22871` | Selector movement |

The resolver returns the string pointer in `RAX`, its length in `R8`, and the localization ID in `EDI`. Generic widget focus fields are recycled and do not reliably identify the visible item. For leagues and clubs, version 0.1.4 intercepts the native nine-cell renderers and announces center record index `4`, which the game itself treats as selected. Other controls continue to combine stabilization, navigation generations, recent text and control-specific signals.

## Building the bridge

From `prism-bridge`:

```powershell
dotnet publish -c Release -r win-x64 --self-contained false
```

Test backend selection manually:

```powershell
pes-a11y-prism-bridge.exe --test
```

## Minimum test route

1. Confirm that the main menu item and its tooltip are spoken.
2. Enter and leave Football Life, Master League and Settings submenus.
3. Navigate slowly and then rapidly, checking for delay, silence, repetition and out-of-order speech.
4. Test audio sliders and confirm horizontal changes speak only the new value.
5. Test side placement, leagues, clubs, away team, pre-match, language, camera and game speed.
6. If something fails, close the game and preserve `SiderAddons/sider.log` before the next run.

## Recovery

Hooks exist only in memory and disappear when the game closes. To disable the mod for the next run, comment out its line in `sider.ini`:

```ini
; lua.module = "pes_a11y_menu_string_probe.lua"
```

The mod does not modify `FL_2026.exe`.

## Distribution and licenses

The package does not contain the game, Sider, or proprietary Football Life/PES files. Prism and its components retain the notices and licenses under `prism-bridge/vendor`. The repository does not yet declare a project license for the mod's own code; choose one before accepting contributions or external redistribution.
