# FLAccess 0.2.0 — experimental

Experimental Football Life 27 compatibility, navigation/exploration improvements,
some fixes and additional known issues. Reader 52 / Gameplay 19. Reader and gameplay
form one mod with 31 native Sider components. Base reader always active. Windows
x64, native game text/focus and Prism, without OCR.

## Installation

Download [FlAccess.zip and SHA256SUMS.txt](https://github.com/diegomatos16/FLAccess/releases/tag/v0.2.0)
and follow the [migration guide](../packaging/INSTALL.en.md). ZIP contains
content/modules/sider, compatible Sider 7.3.3 and runtime DLLs/licenses. Preserve
other mods, settings, WAVs and camera profiles. Do not replace the entire
sider.ini. FLAccess resources need no cpk.root. Do not load the legacy
FlAccessReader/FlAccessGameplay bundles alongside 0.2.0. Python not needed to play.

## Controls

Use normal game controls to move selection. I/right stick UP explores the previous
field; K/right stick DOWN the next. J selects the first field; L is unassigned.
Repeat removed. J/L and horizontal right-stick news browsing still pending.
One complete field per step; a recognized native group title accompanies its
first field when entering the group.

Attributes are requested only through exploration. Automatic reading keeps
name/status and recognized standings records. Questions/messages expose their
content; choose answers using normal game controls. Y/Triangle opens player
information in supported flows.

On the Sider FLAccess panel,6/7 select an option,9/0 change its value,8 restores
default. Diagnostics and mod insertion echo start disabled. Deletion/caret
movement may have feedback. Screen-reader echo is independent.
Unified settings: modules/FlAccess/FlAccess.ini. Editable sounds/camera profiles:
content/FlAccess/sounds and content/FlAccess/cameras. Gameplay uses experimental
HRTF/OpenAL audio; individual sound toggles remain future work.

## Known issues

Severe slowdown remains reported in team/league/player lists and standings;
Reader 52 has no real-game confirmation. Other reports cover duplicate main-menu
names/missing tooltips, silent Football Life submenus/player panels, inconsistent
field grouping, Master League Diary/news/date/scrolling, save/overwrite prompts,
and audio recovery after substitutions/tackle cue direction.

Latest FL27 report: options from other Sider modules are no longer being read.
Passing automated tests does not close these reports. See
[release notes](RELEASE-0.2.0.en.md) and the
[detailed issue history](LISTA-PROBLEMAS-ATUAL.pt-BR.md).
