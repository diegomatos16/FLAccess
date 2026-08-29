# Changelog

## 0.1.4 - 2026-08-29

- Added reliable native focus reading for league lists. The module now reads
  the center record selected by the game's nine-cell list renderer instead of
  estimating focus from recycled UI-widget fields.
- Added native club reading for both standard database names and alternate or
  modded team names.
- Confirmed correct navigation through Premier League and Brasileirão league
  and club selections.
- Preserved automatic Sider integration and Prism/NVDA speech.
- Generalized code-cave installation for safe 14-, 15- and 16-byte hook sites.
- Disabled the old file-triggered widget capture, which could stall the render
  thread during large captures.
- Retained protections against stale widgets, repeated announcements and
  speech while the game is not the foreground window.

Known limitation: this remains menu-accessibility research for the studied
`FL_2026.exe`. Several dialogs, transitions, settings screens, pre-match menus
and all gameplay information still require additional work.

## 0.1.2 - 2026-08-28

- Normalized the public version number from `0.1.02` to `0.1.2`.
- Kept the scanner integrated with Sider and the Prism bridge startup automatic.
- Reduced the bridge polling interval to 5 ms for faster controller navigation.
- Added navigation-generation resets and delayed focus checks to reduce stale speech.
- Improved semantic announcements for selectors, sliders, tooltips and known dialogs.
- Added experimental handling for side placement and several menu transitions.
- Disabled verbose tracing in the distributable module.
- Reworked the English and Brazilian Portuguese documentation.
- Added source and installable-package layouts suitable for GitHub releases.

Known limitation: submenu transitions, side placement, leagues, clubs, away-team selection and pre-match screens are not yet reliable across every navigation path.
