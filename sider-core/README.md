# Accessible Sider core

FLAccess 0.2.2 build 96 uses the compatible Sider 7.3.3 core below for F1 help.
Components are installed under modules/FlAccess and resources under content/FlAccess.

This directory records the Sider core modification required to expose every
module's textual overlay to the PES accessibility module.

- Upstream: https://github.com/pes-modding/sider7
- Base tag: `v7.3.3`
- Base commit: `112627c10c0daec47485a746e1fa6ca7fffc4efc`
- Modified files: `sider.cpp`, `util.asm`
- Added Lua event: `overlay_content`
- Callback signature: `handler(ctx, module_filename, rendered_text, visible, help_requested)`

The event is sent when the active module, rendered text, or overlay visibility
changes. With the overlay open, F1 also sends the current panel with
`help_requested` set to true. Ctrl+F1 forwards the original F1 shortcut to
the active module. The extra argument is optional for existing handlers.

`util.asm` also carries the upstream Sider 7.3.4 stack-alignment correction,
without the unrelated 7.3.4 goal event. It fixes the 0xc0000005 access violation
observed in the locally built 7.3.3 DLL while keeping the 7.3.3 ABI and exports.
Upstream fix: https://github.com/pes-modding/sider7/releases/tag/v7.3.4

The 0.1.7 installer includes the locally tested modified DLL at the FLAccess
project owner's explicit request. It targets Sider 7.3.3 only. The upstream
repository does not state a redistribution license; this inclusion does not
assert that upstream granted a new license.

Binary SHA256:
`e9e40f3dca9e17c05eff8f17c52e8e2c2c8e209d18567ff1c52c8c89c027e830`.

The tested binary is versioned here as `sider.dll`. Every future publication must
include this compatible core and `modules/FlAccessReader/bin/prism.dll` in both
the repository and installer. The new FlAccess.zip has livecpk, modules and sider
folders. Copy `sider/sider.dll` from the ZIP to `SiderAddons/sider.dll` (the root).
Do not leave the runtime DLL in a sider subfolder. Build with
`python tools/build_release.py`; missing DLLs stop packaging.
