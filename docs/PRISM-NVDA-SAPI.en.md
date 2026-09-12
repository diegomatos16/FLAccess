# Prism: runtime switch from NVDA to SAPI

## Integration details

Our accessibility mod now calls the native C ABI exported by `prism.dll`
directly from the Sider LuaJIT process through FFI. It does not use a .NET
helper or Prism's Lua, Python, or Godot binding. The DLL currently comes from
Prismatoid 0.17.3.

At startup, the module calls `prism_init(NULL)`, enumerates the registry,
retains the chosen `PrismBackend`, and calls `prism_backend_speak()` for each
announcement. Its interrupt argument is false for queued dialog follow-ups.

## What happened

When NVDA was running at startup, Prism selected NVDA. After NVDA exited, the
retained backend did not automatically become a SAPI backend. Our original
code tried `prism_registry_create_best()` again only when
`prism_backend_speak()` returned a non-zero error, so the change was not
detected reliably.

The current Prism documentation explains why: backend instances are owned by
the application, a backend can quietly lose runtime availability, and
availability monitoring is opt-in through `PrismConfig.availability_callback`.
Therefore, backend replacement is application policy rather than an automatic
operation performed by Prism.

There is a second detail: `create_best()` does not mean "screen reader, then
SAPI." In the current registry, OneCore has priority 98 while SAPI has priority
97. An application that specifically requires SAPI as its non-screen-reader
fallback must explicitly create `PRISM_BACKEND_SAPI`.

## Workaround implemented in our module

Immediately before speaking, we now:

1. Enumerate the screen-reader backends registered by the loaded Prism build.
2. For the active reader, call `prism_backend_get_features()` and check
   `PRISM_BACKEND_IS_SUPPORTED_AT_RUNTIME`. If that bit disappears, discard the
   backend and probe every registered reader in priority order.
3. If no screen reader is available, explicitly create and initialize the SAPI
   backend instead of accepting OneCore/UIA from `create_best()`.
4. While SAPI is active, probe all registered screen readers before an
   announcement and switch as soon as one can initialize.
5. Keep the speech-error retry as a final recovery path, excluding the backend
   that just failed and then falling back to SAPI.

## Questions for the Prism developer

Is polling `prism_backend_get_features()` the recommended compatibility
strategy for Prismatoid/Prism 0.17.3, or should we upgrade and use
`PrismConfig.availability_callback`? When using the callback, is the intended
pattern still to free the application-owned backend and explicitly construct a
new one? Finally, does the Godot integration recreate its backend or configure
availability monitoring automatically? That could explain why the same NVDA
shutdown scenario appeared to work in Godot while our direct C-ABI integration
did not.
