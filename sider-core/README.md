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

The upstream repository does not state a redistribution license. The compiled
DLL is therefore intended for local testing and must not be published without
permission from the Sider maintainer.
