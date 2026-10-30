# Accessible Sider core

This directory records the Sider core modification required to expose every
module's textual overlay to the PES accessibility module.

- Upstream: https://github.com/pes-modding/sider7
- Base tag: `v7.3.3`
- Base commit: `112627c10c0daec47485a746e1fa6ca7fffc4efc`
- Modified files: `sider.cpp`, `util.asm`
- Added Lua event: `overlay_content`
- Callback signature: `handler(ctx, module_filename, rendered_text, visible)`

The event is sent only when the active module, rendered text, or overlay
visibility changes. This prevents a callback on every rendered frame.

`util.asm` also carries the upstream Sider 7.3.4 stack-alignment correction,
without the unrelated 7.3.4 goal event. It fixes the 0xc0000005 access violation
observed in the locally built 7.3.3 DLL while keeping the 7.3.3 ABI and exports.
Upstream fix: https://github.com/pes-modding/sider7/releases/tag/v7.3.4

The 0.1.7 installer includes the locally tested modified DLL at the FLAccess
project owner's explicit request. It targets Sider 7.3.3 only. The upstream
repository does not state a redistribution license; this inclusion does not
assert that upstream granted a new license.

Binary SHA256:
`57005a0e5977e699c8053293163599508616fd78e044b0f4ccd8ca8e2ccab116`.

The tested binary is versioned here as `sider.dll`. Every future publication must
include this compatible core and `modules/FlAccessReader/bin/prism.dll` in both
the repository and installer. The new FlAccess.zip has livecpk, modules and sider
folders. Copy `sider/sider.dll` from the ZIP to `SiderAddons/sider.dll` (the root).
Do not leave the runtime DLL in a sider subfolder. Build with
`python tools/build_release.py`; missing DLLs stop packaging.
