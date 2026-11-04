# FLAccess 0.2.0 — experimental

Experimental Football Life 27 compatibility, navigation/exploration improvements,
some fixes and additional known issues. Reader 52 / Gameplay 19. One FLAccess mod
with 31 native Sider modules and an always-active base reader.

- [Download 0.2.0](https://github.com/diegomatos16/FLAccess/releases/tag/v0.2.0)
- [Português: instalação, controles e limites](docs/README.pt-BR.md)
- [English: installation, controls and limitations](docs/README.en.md)
- [Notas da versão e pendências](docs/RELEASE-0.2.0.pt-BR.md)
- [Release notes and known issues](docs/RELEASE-0.2.0.en.md)
- [Changelog](CHANGELOG.md)

Native game text/focus and Prism on Windows x64, without OCR. Resources live in
content/FlAccess; code, settings and DLLs in modules/FlAccess. Package includes
the compatible modified Sider 7.3.3 DLL. Read the migration guide; preserve other
Sider modules and personal settings. Python is not required to play.

**Known issues:** team/league/player lists and standings can make the game very
slow. Player fields can still be read as separate labels/numbers. Main-menu
duplicates/tooltips, silent screens, Master League diary/news/date/standings
scrolling, save dialogs and gameplay audio have unresolved or unconfirmed
reports. On FL27, options from other Sider modules are no longer being read,
according to the latest report. Final performance adjustment 52 is unconfirmed.
See the release notes for details.

I/K and right stick up/down explore one field per step. A recognized native group
title accompanies its first field. Attributes are requested through exploration;
automatic selection keeps name/status and recognized standings records. Repeat
removed. J currently selects the first field; L unassigned; J/L news browsing pending.

[Architecture](docs/ARQUITETURA-0.2.0.pt-BR.md),
[implementation/tests](docs/IMPLEMENTACAO-0.2.0.pt-BR.md), and
[latest performance adjustment](docs/READER52-ULTIMA-TENTATIVA-LISTAS-2026-11-04.pt-BR.md).
Historical 0.1.9 sources remain for reference; do not load legacy bundles
alongside 0.2.0. Previous releases remain available.
