# PES / Football Life accessibility scanner

Released version: **0.1.5**  
Date: **September 11, 2026**

## Purpose

This project researches non-OCR menu accessibility for SP Football Life 2026, based on PES 2021. It captures strings and focus-related signals from the game's internal structures through a Sider Lua module, then sends announcements through Prism's native C API. If no compatible screen reader is active, it uses Microsoft SAPI.

Version 0.1.5 is experimental. It makes parts of the menus speak, including correct league and club selection, but it does not provide complete match accessibility. Game Plan is not considered accessible in this release and will remain under investigation for 0.1.6.

## Installing the ready-to-use package

Requirements:

- SP Football Life 2026 with a compatible `FL_2026.exe`;
- a working Sider installation;
- 64-bit Windows;
- a compatible screen reader is optional; without one, the mod uses SAPI.

Steps:

1. Close the game and Sider.
2. Back up the `SiderAddons` directory.
3. Copy the package's `sider.dll` into `SiderAddons`, replacing the 7.3.3 DLL.
4. Copy the package's `modules` directory into `SiderAddons`, merging it with
   the existing `SiderAddons/modules` directory.
5. Add this line to the `[sider]` section of `SiderAddons/sider.ini`:

```ini
lua.module = "FLAccess.lua"
```

6. Start the game through the normal Sider-enabled flow. Prism automatically
   selects a compatible reader or SAPI.

The module loads `prism.dll` directly inside the game after rendering starts.
There is no helper program, terminal, CMD, or .NET requirement.

## Confirmed behavior

- automatic loading through Sider;
- automatic Prism startup with the game;
- automatic selection among screen readers registered by Prism;
- switching to another reader or SAPI when the active reader exits;
- detecting a reader started while SAPI is active;
- speech for every Sider module that produces a textual overlay;
- full speech on a panel's first opening, then only the selected or newly changed
  content on later changes;
- a Portuguese mod panel for Brazilian and European Portuguese game text, with
  English used for every other game language;
- internal UTF-8 string capture without OCR;
- main-menu item and tooltip reading in the tested flow;
- labels, values and horizontal changes on audio sliders;
- several list and settings screens that use known widgets;
- partial labels and values in controller and general settings;
- only the new value is announced for recognized horizontal changes;
- tooltip speech after a short pause on compatible screens;
- a persistent `Read tooltips: Yes/No` option; `6` and `7` navigate, `9` and `0`
  change it, and `8` restores the default;
- a safe diagnostic mode in the same panel. It records only stable focus and
  slider changes, with no continuous memory dump;
- some `Yes`/`No` dialogs;
- native, synchronized reading of the league actually selected;
- native reading of the club actually selected, including standard and alternate/modded names;
- league and club selection confirmed in the Premier League and Brasileirão;
- safeguards against repeated or previous-screen announcements.

## Experimental coverage and limitations

Recent tests show that speech can still lose track of focus when entering or leaving a screen. In particular:

- the first submenu after the main menu can remain silent;
- the `Welcome to Football Life` screen containing local match, league, cup and co-op is not reliable on every entry;
- horizontal `Home`, `Neutral` and `Away` placement worked in the tested flow, but multi-controller combinations still need broader coverage;
- native league and club reading was validated in the tested friendly-match flow; other modes still need complete testing;
- away-team selection still needs to be retested with the new native club reader;
- the pre-match action list now handles the multiple focus bits observed on its
  first entry, but still needs validation in more modes;
- Game Plan remains broken and unpredictable: animated player and formation
  widgets share focus signals with the menu and can silence or delay commands
  on its overview and submenus;
- in Team Sheet/Edit Position, selected-player speech, starter/substitute
  classification and attribute reading are not yet reliable;
- Game Plan coverage in 0.1.5 is internal research only; structural
  investigation will continue in 0.1.6;
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
  -> native C API in prism.dll
  -> NVDA, another compatible reader, or SAPI
```

The module waits until rendering has started before loading Prism. Speech is
sent directly to the DLL: fast navigation interrupts earlier speech, while
explicitly queued messages, such as a dialog button following its message, use
Prism's own queue mode.

## Source layout

- `modules/FLAccess.lua`: main Sider module;
- `modules/FLAccess_gameplay.lua`: isolated component reserved for future
  in-match audio features; inactive in version 0.1.5;
- `modules/FLAccess-Prism/`: `prism.dll` and licenses;
- `sider-core/sider.cpp`: Sider 7.3.3 core source with the `overlay_content` event;
- `sider-core/util.asm`: the official Sider 7.3.4 stack-alignment correction
  applied to the 7.3.3 core;
- `tools/`: static-analysis utilities used during research;
- `docs/`: English and Brazilian Portuguese documentation.
- `docs/ARCHITECTURE.pt-BR.md`: component boundaries for the screen reader,
  Prism and gameplay accessibility.

Runtime-generated files:

- `SiderAddons/sider.log`: Sider and module log;
- `SiderAddons/modules/FLAccess.ini`: persistent tooltip preference.
- `SiderAddons/FLAccess-diagnostic.log`: structural capture created only while
  diagnostic mode is enabled.

The former extensive widget-capture trigger remains disabled to prevent
render-thread stalls. The new diagnostic records the selected widget pointer
and vtable, the RVA of the caller that assigned its text, focus fields, label,
value, control type, links to known widgets, and a bounded inventory of recent
screen text. The file is opened only for stable events.

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

## Minimum test route

1. Confirm that the main menu item and its tooltip are spoken. Open the mod panel,
   disable `Read tooltips`, and confirm that tooltips are no longer announced.
2. Enter and leave Football Life, Master League and Settings submenus.
3. Navigate slowly and then rapidly, checking for delay, silence, repetition and out-of-order speech.
4. Test audio sliders and confirm horizontal changes speak only the new value.
5. Test side placement, leagues, clubs, away team, pre-match, language, camera and game speed.
   In pre-match, specifically confirm that navigation no longer closes the game.
6. In Stadium, confirm speech in `name, selector, value` form. Game Plan tests
   are exploratory only in 0.1.5: record silence, incorrect commands and player
   names spoken out of context separately for the 0.1.6 investigation.
   FLAccess does not intercept `R3`.
7. Leave pre-match and test `Yes` and `No` in the lost-settings warning.
8. If something fails, close the game and preserve `SiderAddons/sider.log` before the next run.

## Structural screen diagnostic

1. Open the mod panel with `Space`.
2. Use `6` or `7` until you hear `Diagnostic mode`.
3. Use `9` or `0` to enable it. The previous file is replaced at this point.
4. Close Sider and reproduce only the problematic screen, visiting each relevant
   option once.
5. Open the panel again, select `Diagnostic mode`, and use `9` or `0` to disable it.
6. Send `SiderAddons/FLAccess-diagnostic.log` with the keys you pressed and what
   should have been spoken.

Diagnostic mode always starts disabled after restarting the game. `8` restores
its default, which is `No`.

While the Sider panel is visible, game speech and structural collection are
paused to avoid mixing two interfaces. This is expected: close the panel with
`Space` after enabling diagnostics.

## Recovery

Hooks exist only in memory and disappear when the game closes. To disable the mod for the next run, comment out its line in `sider.ini`:

```ini
; lua.module = "FLAccess.lua"
```

The mod does not modify `FL_2026.exe`.

## Distribution and licenses

The 0.1.5 test package contains a modified Sider 7.3.3 `sider.dll`, built from
the official source at commit `112627c`. The upstream repository does not state
a redistribution license, so this build is for local testing only and must not
be published without the Sider maintainer's permission. The package does not
contain the game or proprietary Football Life/PES files. Prism retains the
notices and licenses under `modules/FLAccess-Prism/licenses`.
