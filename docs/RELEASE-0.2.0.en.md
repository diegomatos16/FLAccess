# FLAccess 0.2.0 — experimental — 2026-11-04

Experimental Football Life 27 compatibility, navigation/exploration improvements,
some fixes and additional known issues. Reader 52 / Gameplay 19.

## Changes

Reader and gameplay combined into one FLAccess with 31 native Sider modules.
Lists and grouping use separate components; resources use content/FlAccess,
while code/settings/DLLs use modules/FlAccess. The base reader stays enabled.
Do not load legacy Reader/Gameplay bundles alongside 0.2.0.

Exploration reads one field per I/K or right-stick vertical step; a recognized
native group title accompanies its first field. Player attributes are requested
through exploration. Automatic reading keeps name/status and recognized
standings records. Repeat removed; J selects the first field and L is unassigned.
J/L horizontal news browsing remains pending.

Includes native FL27 component discovery, selection/speech delivery adjustments,
standings ordering/indexing, career date at entry/in exploration, save slot and
overwrite-prompt changes. User-confirmed fixes cover the hexadecimal suffix in
Game Settings and Yes/No dialog choices. Other adjustments need confirmation.

Reader 52 avoids global tree invalidation from background focus redraws and
owner/guide changes. Reader 51 was still very slow;52 performance is unconfirmed.
Prism 0.18.3 built from the official repository; provenance included. Experimental
audio includes verified camera bases, Player camera ID8 body direction and
audio-session recovery changes following substitutions.

## Known issues

- Severe slowdown in team/league/player/search lists and standings, confirmed
  through 51. The final 52 adjustment still needs in-game feedback.
- On FL27, options from other Sider modules are no longer being read, according
  to the latest report. Cause and scope have not yet been investigated.
- Duplicate Master League/Become a Legend names and missing main-menu tooltips;
  silent Football Life submenu options/player details; attributes overriding
  club names. Recent fixes do not establish complete FL27 coverage.
- Player groups such as the search/Salah panel can expose separate labels and
  values. Height, weight, rating and other fields need consistent grouping.
- Master League cards/Diary, news reading and horizontal news browsing; career
  date at entry/in exploration still needs confirmation. Standings scrolling
  beyond five reported teams, updates and speed remain open.
- League/participant details should be grouped only in exploration. Calendar and
  finance coverage on FL27 variants needs verification; historical 44 approval
  does not certify all current screens.
- Verify occupied/empty save slots and automatic overwrite questions. Yes/No
  approval does not cover every dialog or return-to-main-menu option.
- Verify repeated Edit Position after substitutions and accessibility sounds
  stopping on match resume. Tackle-cue direction/lead time remains open: opponent
  has possession; cue represents ball proximity, not intent or success. Other
  camera/audio/volume flows still have unverified reports.
- Previous reports concerning countries, partial messages, tooltips and Master
  League introduction remain. The [detailed issue list](LISTA-PROBLEMAS-ATUAL.pt-BR.md)
  preserves historical approvals and unresolved reports.

## Install and validation

Download FlAccess.zip and SHA256SUMS.txt from Release v0.2.0. Package contains
content/modules/sider, compatible Sider and runtime DLLs/licenses. Follow the
[migration guide](../packaging/INSTALL.en.md); load 31 lua.module entries in order.
FLAccess resources need no cpk.root. Preserve other mods, settings and custom
WAV/camera profiles. Python is not required to play.

449 reader Lua checks passed;65 Python tests passed,1 historical-capture test
skipped, including 43 FL27 executable contracts. Integration covered 31 modules,
16 events/23 registrations/120 frames and native Prism. Automated tests do not
certify in-game FPS, audible behavior or complete game/mod compatibility.
