local ADDON_NAME, Ufo = ...

---@class L10N -- IntelliJ-EmmyLua annotation
---@field CONFIRM_DELETE
---@field NEW_FLYOUT
---@field TOY
---@field CAN_NOT_MOVE
---@field BARTENDER_BAR_DISABLED
---@field DETECTED
---@field LOADED
Ufo.L10N = {}

Ufo.Wormhole(Ufo.L10N) -- Lua voodoo magic that replaces the current Global namespace with the Ufo.L10N object
-- Now, FOO = "bar" is equivilent to Ufo.L10N.FOO = "bar" - Even though they all look like globals, they are not.

CONFIRM_DELETE = "Are you sure you want to delete the flyout set %s?"
NEW_FLYOUT = "New\nFlyout"
TOY = "Toy"
CAN_NOT_MOVE = "cannot be used, moved, or removed by this toon."
BARTENDER_BAR_DISABLED = "A UFO is on a disabled Bartender4 bar.  Re-enable the bar and reload the UI to activate the UFO."
DETECTED = "detected"
LOADED = "loaded"
