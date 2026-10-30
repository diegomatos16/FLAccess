# FLAccess 0.1.9

Experimental screen-reader menus for SP Football Life2026/PES2021, using native
text/focus through Sider and Prism, without OCR. Includes optional experimental
match audio. Requires Windows x64, compatible FL_2026.exe and Sider 7.3.3. FL 27
compatibility has not been established.

## Installation

Download [FlAccess.zip and SHA256SUMS.txt](https://github.com/diegomatos16/FLAccess/releases/tag/v0.1.9)
and follow the [installation/migration guide](../packaging/INSTALL.en.md). Merge
livecpk/modules into SiderAddons; copy sider/sider.dll to the SiderAddons root.
Use the snippet inside the existing [sider] section. Remove old FLAccess module
entries, preserve other mods and back up custom settings, WAVs and camera profiles.
Reader/Gameplay can be enabled independently. Python is not required to play.

## Controls

Use normal game navigation. I/right stick up reviews the previous useful entry;
K/right stick down advances; J starts at the first entry; L repeats. One complete
label/value per step. Questions/dialogs expose only the message in review; use
game controls for answers. Recognized lists/tables review only the selected record.
Y/Triangle opens player details and announces its title; help/back captions stay
out of the attribute review. Reader's Sider panel uses6/7 to select,9/0 to change
and8 to restore defaults. Diagnostics and mod insertion echo start disabled.

Gameplay adds no controls and targets one local player. It provides experimental
HRTF/OpenAL ball/boundary/goal/possession cues, configurable tackle proximity and
camera profiles. Remove its lua.module entry to disable it. WAVs are editable;
restart after changing settings/assets. See the Gameplay README for details.

## Changes and limitations

Improved squads/substitutions, labeled player attributes, training tabs, audio
fields/commentary-language title, pause options and shared useful-text review.
Incorrect original/secondary-position announcements were removed; on-pitch position
remains. Playing styles and original positions are future work.

Rapid navigation, the first menu entry, countries, partial messages, some tables
and tooltips still have open reports. Latest internal fixes await real confirmation.
Gameplay camera orientation and cues remain experimental, including known reports
in Dynamic Wide/Stadium. No complete match accessibility, autowalk or universal menu
coverage is promised. See [full Portuguese release notes](RELEASE-0.1.9.pt-BR.md).
