# Installation — FLAccess 0.2.3 — experimental

For Football Life 27 on Windows with SiderAddons and compatible Sider 7.3.3.
FlAccess.zip contains only content, modules and sider.dll.

1. Close the game and Sider. Back up sider.ini, sider.dll and customized settings, WAVs and camera profiles.
2. Merge content and modules into SiderAddons, preserving other mods. When updating, preserve modules/FlAccess/FlAccess.ini and customized resources.
3. Copy sider.dll from the ZIP root to SiderAddons/sider.dll.
4. In the [sider] section of SiderAddons/sider.ini, check lua.enabled = 1, luajit.ext.enabled = 1 and match-stats.enabled = 1. Replace older FLAccess entries with all 32 lua.module lines from [sider.ini.snippet](sider.ini.snippet), in order. Also remove any old standalone FlAccessOpeningTrace.lua entry before adding the block to prevent duplicates. Preserve other mods' entries.
5. Remove only old FlAccessReader and FlAccessGameplay cpk.root entries. Current resources are read from content/FlAccess.
6. Launch normally with Sider and your screen reader. F1 reads help for the active module; I/K or the right stick explore fields. Audio description settings control opening scenes and lineups. Kits follow normal navigation; replay descriptions are disabled.

The last entry, lua.module = "FlAccessOpeningTrace.lua", is required for audio description despite its historical filename.

From a checkout: python tools/install_flaccess.py --sider <SiderAddons-path>. The installer backs up and preserves settings and resources. Update the core by copying sider-core/sider.dll as in step 3. Python is not required to play.

Runtime DLLs are in modules/FlAccess/bin. Source and licenses remain in the repository, including modules/FlAccess/licenses, COPYING.OpenAL and PRISM-SOURCE.json. See the [release notes](../docs/RELEASE-0.2.3.en.md).
