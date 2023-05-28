-- UFO.lua
-- addon lifecycle methods, coordination between submodules, etc.

--[[

TODO
* implement UFO_SV_FLYOUTS as array of self-contained button objects rather than each button spread across multiple parallel arrays
* encapsulate as FlyoutConfigData
* encapsulate as PlacementConfigData
* NUKE all OO syntax that's not actual OO.  Foo:Bar() doesn't need "self" if there is never an instance foo:Bar()
* DONE: NUKE all function paramsNamed(self) and rename them with actual NAMES
* DONE: identify which Ufo:Foo() methods actually need to be global
* DONE: eliminate as many Ufo:Foo() -> foo()
* make germs glow when you mouseover their flyouts in the catalog (same way spells on the actionbars glow when you point at them in the spellbook)
* optimize handlers so that everything isn't always updating ALL germs.  Only update the affected ones.
* eliminate all "legacy data" fixes
* eliminate any support for classic
* BUG: OnDragStart needs to accomodate when there is already something on the cursor
* - steps to recreate: pick up any spell, release the mouse button over thin air such that the spell stays on the cursor, then hover over a germ, hold down left-mouse, begin dragging
]]

-------------------------------------------------------------------------------
-- Module Loading
-------------------------------------------------------------------------------

local ADDON_NAME, Ufo = ...
local L10N = Ufo.L10N

Ufo.Wormhole() -- Lua voodoo magic that replaces the current Global namespace with the Ufo object

---@type Debug -- IntelliJ-EmmyLua annotation
local debugTrace, debugInfo, debugWarn, debugError = Debug:new(Debug.TRACE)

-------------------------------------------------------------------------------
-- Data
-------------------------------------------------------------------------------

local isUfoInitialized = false

-------------------------------------------------------------------------------
-- Event Handlers
-------------------------------------------------------------------------------

local EventHandlers = { }

function EventHandlers:ADDON_LOADED(addonName)
    if addonName == ADDON_NAME then
        debugTrace:print("ADDON_LOADED", addonName)
    end
end

function EventHandlers:PLAYER_LOGIN()
    debugTrace:print("PLAYER_LOGIN")
    DEFAULT_CHAT_FRAME:AddMessage( "|cffd78900"..ADDON_NAME.." v"..VERSION.."|r loaded." )
    initalizeAddonStuff()
    updateAllGerms()
end

function EventHandlers:PLAYER_ENTERING_WORLD(isInitialLogin, isReloadingUi)
    debugTrace:out("",1,"PLAYER_ENTERING_WORLD", "isInitialLogin",isInitialLogin, "isReloadingUi",isReloadingUi)
end

function EventHandlers:ACTIONBAR_SLOT_CHANGED(actionBarSlotId)
    if not isUfoInitialized then return end
    debugTrace:out("",1,"ACTIONBAR_SLOT_CHANGED","actionBarSlotId",actionBarSlotId)
    handleActionBarSlotChanged(actionBarSlotId)
end

function EventHandlers:PLAYER_SPECIALIZATION_CHANGED()
    if not isUfoInitialized then return end
    debugTrace:print("PLAYER_SPECIALIZATION_CHANGED")
    updateAllGerms()
end

-------------------------------------------------------------------------------
-- Event Handler Registration
-------------------------------------------------------------------------------

function createEventListener(targetSelfAsProxy, eventHandlers)
    debugInfo:print(ADDON_NAME .. " EventListener:Activate() ...")

    local dispatcher = function(listenerFrame, eventName, ...)
        -- ignore the listenerFrame and instead
        eventHandlers[eventName](targetSelfAsProxy, ...)
    end

    local eventListenerFrame = CreateFrame("Frame")
    eventListenerFrame:SetScript("OnEvent", dispatcher)

    for eventName, _ in pairs(eventHandlers) do
        debugInfo:print("EventListener:activate() - registering " .. eventName)
        eventListenerFrame:RegisterEvent(eventName)
    end
end

-------------------------------------------------------------------------------
-- Random stuff - TODO: tidy up
-------------------------------------------------------------------------------

function getIdForCurrentToon()
    local name, realm = UnitFullName("player") -- FU Bliz, realm is arbitrarily nil sometimes but not always
    realm = GetRealmName()
    return name.." - "..realm
end

function getPlacementIdForToonSpecialization()
    return GetSpecialization() or NON_SPEC_SLOT
end

function getPetNameAndIcon(petGuid)
    --print("getPetNameAndIcon(): petGuid =",petGuid)
    local speciesID, customName, level, xp, maxXp, displayID, isFavorite, name, icon, petType, creatureID, sourceText, description, isWild, canBattle, tradable, unique, obtainable = C_PetJournal.GetPetInfoByPetID(petGuid)
    --print("getPetNameAndIcon(): petGuid =",petGuid, "| name =", name, "| icon =", icon)
    return name, icon
end

function getTexture(actionType, spellId, petId)
    local id = pickSpellIdOrPetId(actionType, spellId, petId)
    --print("getTexture(): actionType =",actionType, "| spellId =",spellId, "| petId =",petId, "| id =",id)
    if actionType == "spell" then
        return GetSpellTexture(id)
    elseif actionType == "item" then
        return GetItemIcon(id)
    elseif actionType == "macro" then
        local _, texture, _ = GetMacroInfo(id)
        return texture
    elseif actionType == "battlepet" then
        local _, icon = getPetNameAndIcon(id)
        return icon
    end
end

function pickSpellIdOrPetId(type, spellId, petId)
    return ((type == "battlepet") and petId) or spellId
end

function getThingyNameById(actionType, id)
    if actionType == "spell" then
        return GetSpellInfo(id)
    elseif actionType == "item" then
        return GetItemInfo(id)
    elseif actionType == "macro" then
        local name, _, _ = GetMacroInfo(id)
        return name
    elseif actionType == "battlepet" then
        return getPetNameAndIcon(id)
    end
end

function isThingyUsable(id, actionType, mountId, macroOwner,petId)
    if mountId or petId then
        -- TODO: figure out how to find a mount
        return true -- GetMountInfoByID(mountId)
    elseif actionType == "spell" then
        return IsSpellKnown(id)
    elseif  actionType == "item" then
        local n = GetItemCount(id)
        local t = PlayerHasToy(id) -- TODO: update the config code so it sets actionType = toy
        return t or n > 0
    elseif actionType == "macro" then
        return isMacroGlobal(id) or getIdForCurrentToon() == macroOwner
    end
end

function isMacroGlobal(macroId)
    return macroId <= MAX_GLOBAL_MACRO_ID
end

-- I had to create this function to replace lua's strjoin() because
-- lua poops the bed in the strsplit(strjoin(array)) roundtrip whenever the "array" is actually a table because an element was set to nil
function fknJoin(array)
    array = array or {}
    local n = lastIndex(array)
    --print ("OOOOO fknJoin() n =",n, "| array -->")
    --DevTools_Dump(array)
    local omfgDumbAssLanguage = {}
    for i=1,n,1 do
        --print("$$$$$ fknJoin() i =",i, "| array[",i,"] =",array[i])
        omfgDumbAssLanguage[i] = array[i] or EMPTY_ELEMENT
    end
    local result = strjoin(DELIMITER,unpack(omfgDumbAssLanguage,1,n)) or ""
    --print("$$$$= fknJoin() #omfgDumbAssLanguage =",#omfgDumbAssLanguage, "result =",result)
    return result
end

-- because lua arrays turn into tables when an element = nil
function lastIndex(table)
    local biggest = 0
    for k,v in pairs(table) do
        if (k > biggest) then
            biggest = k
        end
    end
    return biggest
end

-- ensures then special characters introduced by fknJoin()
function fknSplit(str)
    local omfgDumbassLanguage = { strsplit(DELIMITER, str or "") }
    omfgDumbassLanguage = stripEmptyElements(omfgDumbassLanguage)
    return omfgDumbassLanguage
end

function stripEmptyElements(table)
    for k,v in ipairs(table) do
        if (v == EMPTY_ELEMENT) then
            table[k] = nil
        end
    end
    return table
end

-- TODO: fix this
Ufo.mountIndex = nil;
function saveMountJournalSelection(index)
    Ufo.mountIndex = index;
end

-------------------------------------------------------------------------------
-- Utility Functions
-------------------------------------------------------------------------------

function deepcopy(src, target)
    local orig_type = type(src)
    local copy
    if orig_type == 'table' then
        copy = target or {}
        for orig_key, orig_value in next, src, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        --setmetatable(copy, deepcopy(getmetatable(src)))
    else -- number, string, boolean, etc
        copy = src
    end
    return copy
end

function isEmpty(s)
    return s == nil or s == ''
end

function exists(s)
    return not isEmpty(s)
end

function serialize(val, name, skipnewlines, depth)
    skipnewlines = skipnewlines or false
    depth = depth or 0

    local tmp = string.rep(" ", depth)

    if name then tmp = tmp .. name .. " = " end

    if type(val) == "table" then
        tmp = tmp .. "{" .. (not skipnewlines and "\n" or "")

        for k, v in pairs(val) do
            tmp =  tmp .. serialize(v, k, skipnewlines, depth + 1) .. "," .. (not skipnewlines and "\n" or "")
        end

        tmp = tmp .. string.rep(" ", depth) .. "}"
    elseif type(val) == "number" or type(val) == "boolean" then
        tmp = tmp .. tostring(val)
    elseif type(val) == "string" then
        tmp = tmp .. string.format("%q", val)
    else
        tmp = tmp .. "\"[inserializeable datatype:" .. type(val) .. "]\""
    end

    return tmp
end

local QUOTE = "\""
local EOL = "\n"

-- useful for injecting tables into secure functions because SFs don't allow tables
function serializeAsAssignments(name, val, isRecurse)
    assert(val, "val is required")
    assert(name, "name is required")

    local tmp
    if isRecurse then
        tmp = ""
    else
        tmp = "local "
    end
    tmp = tmp .. name .. " = "

    local typ = type(val)
    if "table" == typ then
        tmp = tmp .. "{}" .. EOL
        -- trust that if there is an index #1 then all other indices are also numbers.  Otherwise, this will fail.
        local iterFunc = val[1] and ipairs or pairs
        for k, v in iterFunc(val) do
            if type(k) ~= "number" then
                k = string.format("%q", k)
            end
            local nextName = name .. "["..k.."]"
            tmp = tmp .. serializeAsAssignments(nextName, v, true)
        end
    elseif "number" == typ or "boolean" == typ then
        tmp = tmp .. tostring(val) .. EOL
    elseif "string" == typ then
        tmp = tmp .. string.format("%q", val) .. EOL
    else
        tmp = tmp .. QUOTE .. "INVALID" .. QUOTE .. EOL
    end

    return tmp
end

-------------------------------------------------------------------------------
-- Addon Lifecycle
-------------------------------------------------------------------------------

function initalizeAddonStuff()
    defineCatalogPopupDialogs()
    Config:initializeFlyouts()
    Config:initializePlacements()
    initializeOnClickHandlersForFlyouts()
    hooksecurefunc(C_MountJournal, "Pickup", saveMountJournalSelection);
    isUfoInitialized = true
end

-------------------------------------------------------------------------------
-- OK, Go for it!
-------------------------------------------------------------------------------

createEventListener(Ufo, EventHandlers)
