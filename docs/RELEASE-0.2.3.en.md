# FLAccess 0.2.3

Initial support for team entrance audio description and kit descriptions.
Football Life 27 support on Windows remains experimental.

- Describes recognized stadium, tunnel, entrance, ceremony and team photo scenes.
- Reads starting lineups by position group, from goalkeeper to forwards, finishing even after the lineup panel disappears.
- Audio description settings include a master switch, opening scenes and lineups.
- Kit selection descriptions follow navigation independently of the audio description switch.
- Replay audio description is disabled internally and has no settings entry. Research code remains for future development.
- Standings selection jumps and slowdowns were corrected and confirmed by the user.
- Game Plan exploration reads overall before playing style and available energy after field position. Injuries are announced when verified.
- Control configuration follows native focus and reads recognized button symbols. Physical PlayStation controller support has not been validated.

## Installation

Download **FlAccess.zip** from this release. Its only root entries are **content**, **modules** and **sider.dll**.

1. Close the game and Sider. Back up sider.ini, sider.dll and customized FLAccess settings and resources.
2. Merge content and modules into SiderAddons, preserving your customized FlAccess.ini, sounds and camera profiles when updating.
3. For a compatible Sider 7.3.3 installation, copy sider.dll to SiderAddons/sider.dll.
4. In the [sider.ini snippet for this version](https://github.com/diegomatos16/FLAccess/blob/v0.2.3/packaging/sider.ini.snippet), check the three options and replace your previous FLAccess block in the [sider] section with all 32 module entries in order, without duplicates. The final FlAccessOpeningTrace.lua entry enables audio description.
5. Launch normally with Sider and your screen reader.

[Full installation guide](https://github.com/diegomatos16/FLAccess/blob/v0.2.3/packaging/INSTALL.en.md). Python is not required to play. Source and licenses remain in the repository.

Automated checks cover reader behavior, settings, synthetic scenes, local executable signatures, installation migration and archive contents. Opening scenes, photos and lineups were tested in game during development. Recognition of every scene, stadium, kit or controller is not guaranteed. Replay descriptions remain unfinished and disabled.
