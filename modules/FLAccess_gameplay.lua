-- FLAccess 0.1.5
-- Reserved Sider component for future in-match accessibility audio.
-- Keep gameplay hooks and sound logic here instead of adding them to the
-- menu/screen-reader component. This module intentionally registers no events
-- until the first gameplay feature is implemented.

local m = {}

function m.init(ctx)
    log("[FLAccess-gameplay] component ready; no gameplay features in 0.1.5")
end

return m
