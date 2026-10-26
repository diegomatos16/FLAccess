# Changelog

## 0.1.8 - 2026-10-26

- Corrigidos bugs na leitura de alguns menus e implementado suporte inicial
  à leitura de jogadores no plano de jogo.
- Revisão do jogador com I/K e analógico direito: nome, posição principal,
  secundárias completas/parciais e posição no campo.
- Incluídas as DLLs compatíveis do Sider e Prism no repositório e no instalador;
  empacotamento passa a exigir ambas em todas as publicações.
- Base dev 25 preservada; confirmações audíveis e pendências registradas nas
  notas da versão. Testes internos não encerram relatos reais.

## 0.1.7 - 2026-10-21

- Consolidate native component ownership, shared focus/name/value/context
  decisions, text review, editing and dialog handling from local dev 21.
- Revalidate queued and paragraph-deferred speech before delivery; reject
  stale values, recycled objects and previous-context output.
- Include regression tests and implementation reports. Internal tests passed;
  final live-game validation is incomplete and known reports remain open.
- Public package includes Lua, PT/EN indices, Prism licenses and the compatible
  modified Sider 7.3.3 DLL (installer updated at the project owner's request).
- See docs/RELEASE-0.1.7.pt-BR.md for evidence and unresolved reports.


## 0.1.6 - 2026-09-28

Experimental release: text catalog and runtime lexicons are included. Game Plan
navigation has improved but still needs bug fixes and in-game validation.

- Capture long, catalogued presentation dialogs from the localization resolver
  even when no ordinary UI text widget is assigned. Parameterized dialog and
  instruction templates now keep their runtime roles. Recognize short
  imperative catalog titles such as `Escolha sua aparência` automatically.
- Keep focused rows eligible after title/dialog speech and preserve the full
  reading hold during navigation. Fresh `0x104` focus after directional input
  uses a faster path, including return to an earlier item. Shortened the
  screen-title hold and speech deduplication window.
- Suppress duplicate modal `OK` focus during the paragraph; announce its
  queued action once as `Avançar`/`Next`. A title followed by an isolated OK
  gets a brief grace period for the later dialog text hook. Generic mapped
  label/value rows can speak their current value on first focus.
- Prioritized modal dialog paragraphs across all speech routes. Focus captured
  while a dialog is pending waits; focus changes during reading are coalesced
  and delivered through Prism's non-interrupting queue afterward. New dialogs
  displace stale focus commands from the same render slice, and rapid tutorial
  pages retain their order.
- Delayed newly focused dialog buttons briefly so the game's text hook can
  arrive first. The extra `OK` cell in the Champions League group-assignment
  grid is suppressed as a focus announcement. Added regression tests based on
  the observed `sider.log` sequence for this screen.

- Added a maintained offline behavior suite and an explicit in-game validation
  plan. It covers text extraction, runtime roles, speech ordering, reset state,
  overlay updates, Game Plan navigation, Cup groups, and Prism selection.
- Fixed noninteractive status text being promoted to a message by the runtime
  lexicon; stale queued speech surviving `context_reset`; and a forward Lua
  reference that could stop Game Plan A/B navigation.
- Synchronized maintained and deployed Lua modules. Both relevant screen
  transitions now clear Cup group-table state.

- Added compact Portuguese and English runtime text-role lexicons generated from
  the complete `textAssets` catalog. FLAccess now uses exact game text metadata
  for dialogs, controls, instructions, status messages, tooltips, menus and labels
  before falling back to its existing runtime heuristics.

- Announce the `Selecionar time` title used by Cup mode after its competition
  settings are confirmed, and protect it from immediate interruption by the
  transient OK control or first league row.
- Read the Cup group-assignment introduction immediately and enable focused
  group/team cells in its dense table, whose rows do not use the native league
  or club carousel renderers.
- Track the eight four-team group cells through directional navigation. Team
  focus now announces `Grupo A` through `Grupo H` when movement crosses into a
  different group, without repeating the group inside the same four-team cell.

## 0.1.5 - 2026-09-11

Release status: Game Plan remains an unresolved experimental area. Its overview
commands, submenus and Edit Position player selection can still become silent
or announce unrelated animated players. These paths are not claimed as working
in 0.1.5 and are deferred to structural investigation in 0.1.6.

- On the Normal Game Plan overview, animated numbered player cards can no
  longer activate Edit Position mode. The focus resolver now searches for a
  selected-player heading only after Edit Position has actually been entered,
  leaving the bottom Game Plan commands authoritative on the overview.
- Capture and announce the initially selected Team Sheet/Edit Position command
  in the same render frame in which Normal Game Plan appears. Confirming the
  first-use tutorial can no longer leave player navigation in overview context.
- Clear selected-player and tooltip/control ownership at each Normal Game Plan
  entry. Generic value discovery is now time-bounded and disabled throughout
  Game Plan, preventing controls from an earlier screen from consuming menu
  commands such as Data Management or Support Settings as their values.
- Fixed the normal Game Plan overview treating the two formations drawn on the
  pitch as an opened formation list. Display-only formations and players are now
  suppressed there, while the five bottom commands retain focus priority.
- Track a confirmed Game Plan command as the destination context when the user
  presses A. This restores vertical submenu speech even when that submenu does
  not reuse the previously discovered title widget.
- Restrict formation speech and Formation mode to the actual Change Formation
  context; returning with B clears that mode before reading the parent menu.
- The Game Text language screen now repeats the control label and role with
  every selected language instead of announcing an ambiguous bare value.
- Recognize the normal Game Plan surface by its unique Team Sheet/Edit Position
  command, since this screen does not publish its visible caption through the
  submenu title widget. This restores its five horizontal commands on re-entry.
- Accept every live Basic Settings title transition, clearing Formation state
  when returning so the vertical instructions/formation menu speaks again.
- Make vertical Game Plan menus and formation lists respond to the current
  up/down input before animated background player cards can steal focus.
- Ignore recycled Game Plan focus bits while pre-match is active and use the
  real navigation direction to resolve Stadium immediately between Kick Off and
  Uniform. Gamepad navigation is sampled once per render frame so quick D-pad
  taps are not lost.
- Replaced the artificial ten-row tactical index with structural control
  signals. Selectors use the live `label : value` heading; Support Range,
  Defensive Line and Compactness use the game's native 1-to-10 slider events.
- Fixed tactical speech ordering. Vertical navigation announces label, role and
  value before queueing its tooltip; horizontal changes announce only the new
  value. A tooltip rendered before its heading is held until that heading speaks.
- Restored Normal Game Plan focus immediately after Escape/controller B leaves a
  tactical sub-screen, clearing the stale tactical row that previously silenced
  the menu.
- Expanded diagnostic semantic roles for screen titles, menu items, tactical
  headings, selected-player headings, dialog instructions and tooltip/message
  text, while retaining native slider and dialog-button detection.
- Isolated Game Plan sub-screens from recycled focus widgets. Edit Position no
  longer announces the stale `Use Basic Settings` command, and returning from a
  sub-screen resets the previous focus so the first arrow press speaks again.
- Made numbered player headings accept either one or multiple spaces and made
  live `pitchPlayerName` / `subPlayerName` markers authoritative. Player names
  and starter/substitute transitions are now reevaluated on every selection.
- Stabilized Basic Tactical Settings navigation with its fixed ten-row order.
  Up/down now associates the live combined value and tooltip with the selected
  control instead of a hidden row from the shared carousel renderer.
- Routed formation carousels exclusively through the effective formation
  formatter and suppressed background tactics/player rows. A row such as
  `4-4-2 (4-2-2-2)` now announces only `Formation 4-2-2-2`.
- Fixed the visible-lineup command mixing both teams. The studied build reports
  `team_id=65535` for these live player records, so the reader requires live
  pitch/bench markers and exactly eleven starters. It can use the eleven players
  authoritatively observed while navigating rather than guessing a team.
- Fixed silence in the first Basic Settings Menu. `Change Player Icon` was a
  controller hint, not the selected command; the focus resolver now follows
  the real Basic Tactical Settings and Team Sheet/Edit Position items.
- Fixed Basic Settings Menu silence by binding Game Plan context only to the
  two live title widgets. Hidden tactical/player labels can no longer switch
  the reader into Edit Position while the basic menu remains open. Its selected
  command is now followed through the dedicated in-place heading instead of
  the stale Help/Confirm focus bits.
- Refined lineup classification: a parent `subPlayerName` marker overrides a
  child `pitchPlayerName`, unclassified players no longer inherit the previous
  spoken section, and every selection is classified again from the live card.
  Removed the remembered "first goalkeeper" assumption because it became stale
  as soon as a goalkeeper moved between the bench and the starting eleven.
- Retired the Basic Settings prompt after its real dialog closes. Its recycled
  `Use` widget can no longer interrupt player names with repeated selections.
- Added a read-only visible-lineup command on keyboard `O` and right-stick left.
  It is strictly limited to Team Sheet/Edit Position and Normal Game Plan
  contexts. FLAccess does not intercept or assign right-stick click (`R3`).
- Classified Edit Position players as starters or substitutes from the live
  `pitchPlayerName` / `subPlayerName` UI object marker. The section is announced
  on entry and whenever navigation crosses the starter/bench boundary, without
  relying on player tables and therefore remaining compatible with Option Files.
- Cleared stale attribute-panel suppression when the numbered selected-player
  heading resumes, and added keyboard Y as a close signal. Player navigation no
  longer remains silent after viewing attributes.
- Restricted the Basic Settings Menu focus resolver to real Game Plan commands
  and its Use/Do not use buttons, excluding team and player cards rendered in
  the background.
- Read Basic Tactical Settings from its authoritative combined heading. Focus
  now reports control name, selector role and value; changed values queue their
  matching tooltip when tooltip reading is enabled.
- Removed a second speech route for the noninteractive `Carregando a bola`
  status, which could still announce it while opening player attributes.
- Applied low-latency focus handling across the reader engine. Ordinary menus
  using the verified `0x104` focus bank and known controls now settle in four
  frames, the unique Edit Position heading settles in two, and dialog buttons
  are sampled every two frames. Ambiguous banks and animated roster objects
  retain their longer safety windows.
- Added same-frame Prism flushing after focus, dialog and delayed-speech
  processing. Confirmed announcements no longer wait for the next render frame;
  all Prism calls remain serialized on `display_frame`.
- Reduced focus stabilization for verified controls and the Audio Settings
  menu from 12 frames to 4. Audio-option navigation now responds much closer
  to the direct league/team hooks while generic unknown widgets keep the safer
  debounce.
- Fixed the extended player-card diagnostic's forward references to guarded
  memory helpers. Normal speech was unaffected, but the previous diagnostic
  run stopped before recording pitch/bench object data.
- Fixed a per-frame Lua failure in paged-dialog polling. The early callback now
  calls the exported `a11y.read_msvc_string` helper instead of an unavailable
  global, restoring Game Plan titles, focused items and later tutorial pages.
- Preserved the Game Plan tutorial markers for controller A, the left stick and
  the directional pad, with Portuguese and English spoken names. Instructions
  no longer degrade into phrases such as “hold” without naming the control.
- Extended Game Plan diagnostics to correlate the numbered selected-player
  heading with its live pitch/bench card and parent object. This targets a
  structural starter/reserve classifier that remains valid with Option Files.
- Fixed complete speech loss in the first native-Prism build. Sider's restricted
  LuaJIT does not implicitly convert Lua strings to C `char*` arguments, so the
  path conversion failed on every frame. DLL paths, export names, and speech
  text now use explicit FFI buffers.
- Serialized every Prism backend operation on `display_frame`. Game text hooks
  can invoke Lua callbacks from several threads, while individual Prism backend
  instances are explicitly not thread-safe; hook callbacks now enqueue only,
  and the render callback delivers interrupting and queued speech in order.
- Expanded the compatibility harness from module initialization to 120 runtime
  frames with the real Prism DLL, catching failures in delayed native startup.
- Replaced the out-of-process .NET speech bridge and file polling with direct
  LuaJIT FFI calls to Prism's native C API. FLAccess now needs only
  `modules/FLAccess-Prism/prism.dll` and its licenses, preserves queued speech,
  and has no EXE, CMD, terminal, speech-handoff file, or .NET requirement.
- Kept automatic reader selection and runtime switching: supported screen
  readers are preferred, SAPI is the explicit fallback, and readers are probed
  again while SAPI is active.
- Removed obsolete bridge sources/build outputs, temporary Prism and dt20
  extraction trees, the downloaded wheel cache, and the historical 0.2.0 test
  note from the maintained project and release packages.

- Enabled focused language choices, standard-controller presets and confirmation
  buttons during Football Life's first-run setup. These screens precede the
  main menu, so the former startup guard incorrectly silenced their real focus
  events even though dialogs were already readable.
- Allowed verified controls, dialog buttons and language options through the
  dense-list filter while retaining it for unrelated background text.
- Recognized the Basic Tactical Settings screen from its live control labels,
  preventing the previous Edit Position context from silencing its selected
  items after choosing `Use`.
- Followed the in-place numbered player heading independently of the generic
  focus debounce. Edit Position now announces every settled player selection,
  and opening attributes with Y binds to that current player instead of a stale
  previously announced name.
- Correlated attribute-panel creation with an actual recent Y press, preventing
  background `Height` widgets from opening false attribute readers, and fully
  suppressed the spurious `Carregando a bola` announcement.
- Added polling for direct mutations of a paged tutorial's existing string
  object, covering the second instruction page that bypasses the normal text
  setter. Consecutive instruction pages are now queued independently.
- Expanded Game Plan diagnostics with correlated keyboard, D-pad, left-stick,
  Y/B, numbered-selection, player pointer, player ID, team ID, registered
  position, visit count, and before/after timing events. This provides the data
  needed to locate the live starter/bench boundary without requiring a sighted
  tester to identify it manually.
- Replaced the Edit Position `0xfc` redraw heuristic with the unique numbered
  player heading exposed by the game. Background roster cards can no longer be
  mistaken for arrow-key selection changes.
- Matched the game's validated 15-byte player-record name against the complete
  UI name by prefix, fixing position lookup for long and accented names such as
  Ryan Gravenberch and Ibrahima Konaté.
- Suppressed `Carregando a bola` only while Game Plan is active.
- Queued each Edit Position tutorial independently and kept player/status text
  from being appended to its instructional paragraph.
- Separated Game Plan menu/formation focus (`0x104`) from the animated player
  roster bank (`0xfc`), preventing background players from replacing the real
  selected menu item.
- Queued formation explanations after the selected formation instead of
  interrupting it.
- Promoted Edit Position control instructions (such as “while holding…”) to
  mandatory dialog speech, independent of the optional tooltip setting.
- Locked the attribute panel to the player who opened it and suppressed player
  cards rendered in the background. Closing with Escape, controller B, or Y
  restores ordinary player navigation immediately.
- Added the selected player's registered/primary position to Edit Position
  announcements, using the validated live player record rather than a fixed
  public player-name table.
- Fixed a complete module startup regression caused by using `pcall`, which is
  deliberately absent from Sider's restricted Lua environment.
- Added a repeatable Sider-compatibility gate that executes `init` inside a
  matching restricted sandbox, enforces LuaJIT's 200-local limit, and verifies
  all 12 hook prologues directly against `FL_2026.exe` before packaging.
- Fixed the directional pre-match gap from `Kick Off` left to `Stadium`.
- Made Game Plan submenu focus follow the most recently activated control bank,
  instead of assuming every submenu uses `0x104`.
- Prioritized the live `0xfc` roster bank in Edit Position so player names are
  announced while moving through the pitch.
- Routed formation rows through the formation formatter before generic selector
  pairing, so only the effective parenthesized formation is announced.
- Added contextual Game Plan screen-title prefixes to the first focused item.
- Added individual player-panel navigation with `I`/`K` and right-stick up/down.
  Keyboard state and XInput are polled while the Sider overlay is closed.
- Located both unique FL 2026 player-record paths and validates each captured
  record before use. The attribute panel now exposes 25 real numeric abilities,
  including passing, finishing, speed, physical, defensive and goalkeeper stats.
- Renamed the complete mod to `FLAccess`, including Sider modules, Prism bridge,
  runtime directory, configuration, speech stream, diagnostics and packages.
- Split context cleanup into namespace-backed routines so the complete module
  stays within LuaJIT's per-function upvalue and per-chunk local-variable limits.
  This fixes the 0.1.5 startup failure where Sider skipped `FLAccess.lua` and
  consequently no interface speech or Prism bridge was initialized.
- Preserved the pre-match `Stadium` command label when Football Life recycles
  its widget with transient kickoff, club, or stadium text.
- Expired the stale `Yes`/`No` dialog objects as soon as a destination-screen
  control receives focus. Cancelling the warning now re-announces the pre-match
  notice and queues the selected command after it.
- Added Game Plan context to the first focused item after each mode change,
  identified formation values explicitly, and suppressed consecutive duplicate
  focus speech caused by several widgets exposing the same selection.
- Queued the initial pre-match command behind the complete readiness message so
  it no longer interrupts the paragraph. Other returns keep their existing
  immediate focus behavior.
- Recovered the pre-match `Stadium` command from its position between `Uniform`
  and `Game Plan` when the game exposes only a very stale club-name widget.
- Treated the parenthesized value in formation-list rows as the effective
  formation, avoiding announcements containing two formation numbers.
- Suppressed residual player widgets while the Game Plan settings menu is being
  constructed and waited for its unique selected entry.
- Added an initial `Y` player-attributes summary for Squad/Edit Position. Exact
  numeric attribute values remain a separate memory-mapping task.

- Moved the complete Prism runtime under `SiderAddons/modules` so installation
  only needs one directory merge plus the `sider.ini` module line.
- Generalized live screen-reader switching to every reader backend registered
  by the Prism build. If the active reader exits, another available reader is
  selected by priority or the bridge falls back explicitly to SAPI. While SAPI
  is active, newly started readers are detected on the next announcement.
- Added an accessible Sider entry panel. Opening the overlay on this module
  speaks its title, current status, and the keys for closing or changing module.
- Added an accessibility event to the exact Sider 7.3.3 core used by Football
  Life. The active module filename and rendered overlay text are now forwarded
  to the accessibility module whenever the panel opens or its contents change.
  Closing the overlay is also announced without confusing it with module changes.
- Applied the official Sider 7.3.4 stack-alignment correction to the modified
  7.3.3 core. This fixes the access violation observed when navigating the
  pre-match screen, while retaining the 7.3.3 interface and exports.
- Changed Sider panel speech so later option and menu changes announce only the
  selected or newly changed content instead of repeating the complete panel.
- Added the persistent `Read tooltips` option to the accessibility panel. It can
  be selected with `6`/`7`, changed with `9`/`0`, and restored with `8`. It
  suppresses delayed tooltip speech when disabled.
- Localized the accessibility panel in Portuguese for Brazilian and European
  Portuguese game text; all other game languages use English. Translation tables
  are structured so more languages can be added later.
- Ignored the obsolete Football Life online-server item.
- Preferred the game's reliable `0x104` focus state in ordinary menus, fixing
  continuously refreshed hidden widgets that could suppress pre-match items.
- Added label hints for cup settings and the first audio-volume controls.
- Registered the stadium-screen labels `Período`, `Estação do ano/Clima`, and
  `Condições do campo`, allowing their focused values to be announced together.
- Confirmed from `dt20_bra_x64.cpk` and `dt20_eng_x64.cpk` that the two apparent
  extra entries after `Configurações de volume` are blank strings in Football
  Life itself, not labels missed by the screen reader.
- Made the initial pre-match readiness notice speak on entry.
- Made the pre-match action list speak on its first visit even though Football
  Life leaves all six action widgets marked with the same focus bit.
- Fixed stadium settings to consult both sides of the existing label/value map,
  so known rows announce their name, selector role, and selected value. Added
  `Grass Length` to the recognized stadium rows.
- Added contextual Game Plan focus. The roster bank is now used only while the
  active screen is Team Sheet/Edit Position or Change Player Icon; controls in
  tactical, help, player, marking, set-piece and data screens use their own focus.
  Dense stale widgets no longer silence valid Game Plan controls, and roster
  stabilization was reduced from 50 to 18 frames so the final player is spoken.
- Re-enabled `Yes`/`No` navigation specifically for the destructive-back dialog,
  without restoring the stale-dialog behavior on unrelated screens.
- Added an opt-in structural diagnostic to the Sider panel. It records only
  stable focus and slider changes, including widget pointer, vtable signature,
  text-set caller RVA, focus fields, known label/value/type mappings, links to
  known widgets and a bounded recent-screen inventory. It starts disabled on
  every game launch and writes `SiderAddons/FLAccess-diagnostic.log`.
- Split future responsibilities inside the single distribution: the existing
  module is the screen-reader component, while `FLAccess_gameplay.lua` is an
  inactive, isolated home for later in-match audio features.
- Changed the speech handoff from a single overwritten message to an append-only
  sequenced command stream. Rapid updates are no longer lost between bridge
  polls, and dialog buttons use Prism's non-interrupting queue mode after the
  dialog message.
- Fixed the accessibility overlay remaining logically open after it was closed,
  which had stopped both ordinary menu speech and diagnostic collection.
- Added a bounded diagnostic snapshot every 90 frames when unstable focus never
  settles, allowing problematic multi-focus screens to produce useful evidence.
- Removed use of `pcall`, which is unavailable in Sider's Lua sandbox and had
  broken display-frame speech whenever diagnostics were enabled. Diagnostic
  events now also include the complete known label/value control inventory.
- Made known pre-match actions speak immediately when their selected widget is
  recreated, instead of losing every selection to repeated debounce resets.
- Replaced the stadium screen's creation-order guess with a screen-specific
  five-row map verified from the capture: Stadium, Time, Season/Weather, Grass
  Length and Pitch Conditions. Each row now retains its own value widget.

Still requiring in-game validation: the contextual Game Plan and stadium focus
changes, plus the pre-match crash correction.

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
