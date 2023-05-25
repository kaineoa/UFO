-- BlizConfigOpts.lua
-- config options at ESC -> Blizzard Options -> Addons -> UFO
-- NOT IN USE

local ADDON_NAME, Ufo = ...
local debug = Ufo.DEBUG.newDebugger(Ufo.DEBUG.TRACE)
local L10N = Ufo.L10N

-------------------------------------------------------------------------------
-- Ace -> Bliz Config UI definition
-------------------------------------------------------------------------------

local escMenuConfigDef = {
    name = ADDON_NAME,
    type = "group",
    args = {
        respectSpec = {
            name = "Swap with spec",
            desc = "Auto swap flyout locations on the action bars when you change your class spec.",
            type = "toggle",
            set = function(info, val)
                Db.profile.respectSpec = val
            end,
            get = function()
                return Db.profile.respectSpec
            end
        },
        debug = {
            name = "Show debug info",
            desc = "Enable / disable debug information",
            type = "toggle",
            set = function(info, val)
                Db.profile.debug = val
            end,
            get = function()
                return Db.profile.debug
            end
        },
        --aceProfileUi = {} -- will be populated by Ace in OnInitialize()
    }
}

local defaultConfigOptions = {
    profile = { -- required by AceDB
        debug = false,
        respectSpec = true,
    }
}
