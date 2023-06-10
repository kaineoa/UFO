-- FlyoutMenu
-- methods and functions for flyout creation, behavior, etc

-------------------------------------------------------------------------------
-- Module Loading
-------------------------------------------------------------------------------

local ADDON_NAME, Ufo = ...
Ufo.Wormhole() -- Lua voodoo magic that replaces the current Global namespace with the Ufo object

local debug = Debug:new(DEBUG_OUTPUT.WARN)

---@class FlyoutMenu -- IntelliJ-EmmyLua annotation
---@field ufoType string The classname
---@field isForGerm boolean
---@field isForCatalog boolean
local FlyoutMenu = {
    ufoType = "FlyoutMenu",
    isForGerm = false,
    isForCatalog = false,
}
Ufo.FlyoutMenu = FlyoutMenu

FlyoutMenuForCatalog = nil

-------------------------------------------------------------------------------
-- Functions / Methods
-------------------------------------------------------------------------------

function FlyoutMenu:oneOfUs(fomu)
    -- merge the Bliz ActionButton object
    -- with this class's methods, functions, etc
    deepcopy(self, fomu)
end

function FlyoutMenu:getButtonFor(i)
    return _G[ self:GetName().."Button"..i ]
end

function FlyoutMenu:forEachButton(handler)
    for i, button in ipairs({self:GetChildren()}) do
        if button:GetObjectType() == "CheckButton" then
            handler(button)
        end
    end
end

function FlyoutMenu:initializeOnClickHandlersForFlyouts()
    --for i, button in ipairs({UIUFO_FlyoutMenuForGerm:GetChildren()}) do
    --    if button:GetObjectType() == "CheckButton" then
    --        SecureHandlerWrapScript(button, "OnClick", button, "self:GetParent():Hide()")
    --    end
    --end

    UIUFO_FlyoutMenuForGerm:forEachButton(function(button)
        SecureHandlerWrapScript(button, "OnClick", button, "self:GetParent():Hide()")
    end)
    UIUFO_FlyoutMenuForCatalog.IsConfig = true
end

-------------------------------------------------------------------------------
-- GLOBAL Functions Supporting FlyoutMenu XML Callbacks
-------------------------------------------------------------------------------

---@param flyoutMenu FlyoutMenu
function GLOBAL_UIUFO_FlyoutMenuForGerm_OnLoad(flyoutMenu)
    -- call Blizzard handler
    SpellFlyout_OnLoad(flyoutMenu)

    -- initialize fields
    FlyoutMenu:oneOfUs(flyoutMenu)
    Germ.flyoutMenu = flyoutMenu
    flyoutMenu.isForGerm = true
end

---@param flyoutMenu FlyoutMenu
function GLOBAL_UIUFO_FlyoutMenuForCatalog_OnLoad(flyoutMenu)
    -- call Blizzard handler
    SpellFlyout_OnLoad(flyoutMenu)

    -- initialize fields
    FlyoutMenu:oneOfUs(flyoutMenu)
    FlyoutMenuForCatalog = flyoutMenu
    flyoutMenu.isForCatalog = true
end

---@param flyoutMenu FlyoutMenu
function GLOBAL_UIUFO_FlyoutMenuForGerm_OnShow(flyoutMenu)
    debug.trace:out("/",20,"GLOBAL_UIUFO_FlyoutMenuForGerm_OnShow")
    SpellFlyout_OnShow(flyoutMenu) -- call Blizzard handler

    -- TODO: the below probably aren't needed anymore
    --flyoutMenu:RegisterEvent("BAG_UPDATE_COOLDOWN"); -- to support items
    --flyoutMenu:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN"); -- to support items

    ---@param btn ButtonOnFlyoutMenu -- IntelliJ-EmmyLua annotation
    flyoutMenu:forEachButton(function(btn)
        debug.trace:out("~",40, "btn updatery from FlyoutMenu:OnShow()")
        btn:updateCooldownsAndCountsAndStatesEtc()
    end)

end

function GLOBAL_UIUFO_FlyoutMenuForGerm_OnHide(self)
    SpellFlyout_OnHide(self) -- call Blizzard handler
    if (self.eventsRegistered == true) then
        --self:UnregisterEvent("BAG_UPDATE_COOLDOWN"); -- to support items
        --self:UnregisterEvent("ACTIONBAR_UPDATE_COOLDOWN"); -- to support items
    end
end

-- TODO: consolidate these two wet ass procedures
-- TODO: merge updateFlyoutMenuForCatalog() and updateFlyoutMenuForGerm()

function FlyoutMenu:updateFlyoutMenuForCatalog(flyoutId)
    local direction = "RIGHT"
    local parent = self.parent

    self.idFlyout = flyoutId

    -- Update all spell buttons for this flyout
    local prevButton = nil;
    local numButtons = 0;
    local flyoutConfig = getFlyoutConfig(flyoutId)
    local spells = flyoutConfig and flyoutConfig.spells
    local actionTypes = flyoutConfig and flyoutConfig.actionTypes
    local mounts = flyoutConfig and flyoutConfig.mounts
    local pets = flyoutConfig and flyoutConfig.pets

    for i=1, math.min(#actionTypes+1, MAX_FLYOUT_SIZE) do
        local spellId    = spells[i]
        local itemId     = (type == "item") and spellId
        local actionType = actionTypes[i]
        local mountId    = mounts[i]
        local pet        = pets[i]
        local button     = self:getButtonFor(numButtons+1)

        button:ClearAllPoints()
        if direction == "UP" then
            if prevButton then
                button:SetPoint("BOTTOM", prevButton, "TOP", 0, SPELLFLYOUT_DEFAULT_SPACING)
            else
                button:SetPoint("BOTTOM", 0, SPELLFLYOUT_INITIAL_SPACING)
            end
        elseif direction == "DOWN" then
            if prevButton then
                button:SetPoint("TOP", prevButton, "BOTTOM", 0, -SPELLFLYOUT_DEFAULT_SPACING)
            else
                button:SetPoint("TOP", 0, -SPELLFLYOUT_INITIAL_SPACING)
            end
        elseif direction == "LEFT" then
            if prevButton then
                button:SetPoint("RIGHT", prevButton, "LEFT", -SPELLFLYOUT_DEFAULT_SPACING, 0)
            else
                button:SetPoint("RIGHT", -SPELLFLYOUT_INITIAL_SPACING, 0)
            end
        elseif direction == "RIGHT" then
            if prevButton then
                button:SetPoint("LEFT", prevButton, "RIGHT", SPELLFLYOUT_DEFAULT_SPACING, 0)
            else
                button:SetPoint("LEFT", SPELLFLYOUT_INITIAL_SPACING, 0)
            end
        end

        button:Show()

        if actionType then
            button.spellID = spellId -- this is read by Bliz code in SpellFlyout.lua which expects only numbers
            button.actionType = actionType
            button.mountId = mountId
            button.battlepet  = pet
            local texture = getTexture(actionType, spellId, pet)
            button:setIconTexture(texture)
            if spellId then
                button:updateCooldownsAndCountsAndStatesEtc()
            end
        else
            button:setIconTexture(nil)
            button.spellID = nil
            button.actionType = nil
            button.mountId = nil
        end

        prevButton = button
        numButtons = numButtons+1
    end

    -- Hide unused buttons
    local unusedButtonIndex = numButtons+1
    local button = self:getButtonFor(unusedButtonIndex)
    while button do
        button:Hide()
        unusedButtonIndex = unusedButtonIndex+1
        button = self:getButtonFor(unusedButtonIndex)
    end

    if numButtons == 0 then
        self:Hide()
        return
    end

    -- Show the flyout
    self:SetFrameStrata("DIALOG")
    self:ClearAllPoints()

    local distance = 3

    self.Background.End:ClearAllPoints()
    self.Background.Start:ClearAllPoints()
    if (direction == "UP") then
        self:SetPoint("BOTTOM", parent, "TOP");
        self.Background.End:SetPoint("TOP", 0, SPELLFLYOUT_INITIAL_SPACING);
        SetClampedTextureRotation(self.Background.End, 0);
        SetClampedTextureRotation(self.Background.VerticalMiddle, 0);
        self.Background.Start:SetPoint("TOP", self.Background.VerticalMiddle, "BOTTOM");
        SetClampedTextureRotation(self.Background.Start, 0);
        self.Background.HorizontalMiddle:Hide();
        self.Background.VerticalMiddle:Show();
        self.Background.VerticalMiddle:ClearAllPoints();
        self.Background.VerticalMiddle:SetPoint("TOP", self.Background.End, "BOTTOM");
        self.Background.VerticalMiddle:SetPoint("BOTTOM", 0, distance);
    elseif (direction == "DOWN") then
        self:SetPoint("TOP", parent, "BOTTOM");
        self.Background.End:SetPoint("BOTTOM", 0, -SPELLFLYOUT_INITIAL_SPACING);
        SetClampedTextureRotation(self.Background.End, 180);
        SetClampedTextureRotation(self.Background.VerticalMiddle, 180);
        self.Background.Start:SetPoint("BOTTOM", self.Background.VerticalMiddle, "TOP");
        SetClampedTextureRotation(self.Background.Start, 180);
        self.Background.HorizontalMiddle:Hide();
        self.Background.VerticalMiddle:Show();
        self.Background.VerticalMiddle:ClearAllPoints();
        self.Background.VerticalMiddle:SetPoint("BOTTOM", self.Background.End, "TOP");
        self.Background.VerticalMiddle:SetPoint("TOP", 0, -distance);
    elseif (direction == "LEFT") then
        self:SetPoint("RIGHT", parent, "LEFT");
        self.Background.End:SetPoint("LEFT", -SPELLFLYOUT_INITIAL_SPACING, 0);
        SetClampedTextureRotation(self.Background.End, 270);
        SetClampedTextureRotation(self.Background.HorizontalMiddle, 180);
        self.Background.Start:SetPoint("LEFT", self.Background.HorizontalMiddle, "RIGHT");
        SetClampedTextureRotation(self.Background.Start, 270);
        self.Background.VerticalMiddle:Hide();
        self.Background.HorizontalMiddle:Show();
        self.Background.HorizontalMiddle:ClearAllPoints();
        self.Background.HorizontalMiddle:SetPoint("LEFT", self.Background.End, "RIGHT");
        self.Background.HorizontalMiddle:SetPoint("RIGHT", -distance, 0);
    elseif (direction == "RIGHT") then
        self:SetPoint("LEFT", parent, "RIGHT");
        self.Background.End:SetPoint("RIGHT", SPELLFLYOUT_INITIAL_SPACING, 0);
        SetClampedTextureRotation(self.Background.End, 90);
        SetClampedTextureRotation(self.Background.HorizontalMiddle, 0);
        self.Background.Start:SetPoint("RIGHT", self.Background.HorizontalMiddle, "LEFT");
        SetClampedTextureRotation(self.Background.Start, 90);
        self.Background.VerticalMiddle:Hide();
        self.Background.HorizontalMiddle:Show();
        self.Background.HorizontalMiddle:ClearAllPoints();
        self.Background.HorizontalMiddle:SetPoint("RIGHT", self.Background.End, "LEFT");
        self.Background.HorizontalMiddle:SetPoint("LEFT", distance, 0);
    end

    if direction == "UP" or direction == "DOWN" then
        self:SetWidth(prevButton:GetWidth())
        self:SetHeight((prevButton:GetHeight()+SPELLFLYOUT_DEFAULT_SPACING) * numButtons - SPELLFLYOUT_DEFAULT_SPACING + SPELLFLYOUT_INITIAL_SPACING + SPELLFLYOUT_FINAL_SPACING)
    else
        self:SetHeight(prevButton:GetHeight())
        self:SetWidth((prevButton:GetWidth()+SPELLFLYOUT_DEFAULT_SPACING) * numButtons - SPELLFLYOUT_DEFAULT_SPACING + SPELLFLYOUT_INITIAL_SPACING + SPELLFLYOUT_FINAL_SPACING)
    end

    self.direction = direction;
    self:SetBorderColor(0.7, 0.7, 0.7);
    self:SetBorderSize(47);
end

-- TODO: refactor this into a germ:Method() then the remainder in this flyoutMenu:Method()
---@param germ Germ
function FlyoutMenu:updateFlyoutMenuForGerm(germ, whichMouseButton, down)
    debug.trace:out("~",3,"updateFlyoutMenuForGerm")

    germ:SetChecked(not germ:GetChecked())

    local direction = germ:GetAttribute("flyoutDirection");
    local spellList = fknSplit(germ:GetAttribute("spelllist"))
    local typeList = fknSplit(germ:GetAttribute("typelist"))
    local pets     = fknSplit(germ:GetAttribute("petlist"))

    local buttonFrames = { UIUFO_FlyoutMenuForGerm:GetChildren() }
    table.remove(buttonFrames, 1)
    ---@param buttonFrame ButtonOnFlyoutMenu
    for i, buttonFrame in ipairs(buttonFrames) do
        local type = typeList[i]
        if not isEmpty(type) then
            local spellId = spellList[i]
            local itemId = (type == "item") and spellId or nil
            local pet = pets[i]
            debug.trace:out("~",5,"updateFlyoutMenuForGerm", "i",i, "spellId",spellId, "type", type)
            --print("Germ_PreClick(): i =",i, "| spellID =",spellId,  "| type =",type, "| pet =", pet)

            -- fields recognized by Bliz internal UI code
            buttonFrame.spellID = spellId
            buttonFrame.itemID = itemId
            buttonFrame.actionID = spellId
            buttonFrame.actionType = type
            buttonFrame.battlepet = pet

            local icon = getTexture(type, spellId, pet)
            buttonFrame:setIconTexture(icon)

            buttonFrame:updateCooldownsAndCountsAndStatesEtc()
        end
    end
    UIUFO_FlyoutMenuForGerm.Background.End:ClearAllPoints()
    UIUFO_FlyoutMenuForGerm.Background.Start:ClearAllPoints()
    local distance = 3
    if (direction == "UP") then
        UIUFO_FlyoutMenuForGerm.Background.End:SetPoint("TOP", 0, SPELLFLYOUT_INITIAL_SPACING);
        SetClampedTextureRotation(UIUFO_FlyoutMenuForGerm.Background.End, 0);
        SetClampedTextureRotation(UIUFO_FlyoutMenuForGerm.Background.VerticalMiddle, 0);
        UIUFO_FlyoutMenuForGerm.Background.Start:SetPoint("TOP", UIUFO_FlyoutMenuForGerm.Background.VerticalMiddle, "BOTTOM");
        SetClampedTextureRotation(UIUFO_FlyoutMenuForGerm.Background.Start, 0);
        UIUFO_FlyoutMenuForGerm.Background.HorizontalMiddle:Hide();
        UIUFO_FlyoutMenuForGerm.Background.VerticalMiddle:Show();
        UIUFO_FlyoutMenuForGerm.Background.VerticalMiddle:ClearAllPoints();
        UIUFO_FlyoutMenuForGerm.Background.VerticalMiddle:SetPoint("TOP", UIUFO_FlyoutMenuForGerm.Background.End, "BOTTOM");
        UIUFO_FlyoutMenuForGerm.Background.VerticalMiddle:SetPoint("BOTTOM", 0, distance);
    elseif (direction == "DOWN") then
        UIUFO_FlyoutMenuForGerm.Background.End:SetPoint("BOTTOM", 0, -SPELLFLYOUT_INITIAL_SPACING);
        SetClampedTextureRotation(UIUFO_FlyoutMenuForGerm.Background.End, 180);
        SetClampedTextureRotation(UIUFO_FlyoutMenuForGerm.Background.VerticalMiddle, 180);
        UIUFO_FlyoutMenuForGerm.Background.Start:SetPoint("BOTTOM", UIUFO_FlyoutMenuForGerm.Background.VerticalMiddle, "TOP");
        SetClampedTextureRotation(UIUFO_FlyoutMenuForGerm.Background.Start, 180);
        UIUFO_FlyoutMenuForGerm.Background.HorizontalMiddle:Hide();
        UIUFO_FlyoutMenuForGerm.Background.VerticalMiddle:Show();
        UIUFO_FlyoutMenuForGerm.Background.VerticalMiddle:ClearAllPoints();
        UIUFO_FlyoutMenuForGerm.Background.VerticalMiddle:SetPoint("BOTTOM", UIUFO_FlyoutMenuForGerm.Background.End, "TOP");
        UIUFO_FlyoutMenuForGerm.Background.VerticalMiddle:SetPoint("TOP", 0, -distance);
    elseif (direction == "LEFT") then
        UIUFO_FlyoutMenuForGerm.Background.End:SetPoint("LEFT", -SPELLFLYOUT_INITIAL_SPACING, 0);
        SetClampedTextureRotation(UIUFO_FlyoutMenuForGerm.Background.End, 270);
        SetClampedTextureRotation(UIUFO_FlyoutMenuForGerm.Background.HorizontalMiddle, 180);
        UIUFO_FlyoutMenuForGerm.Background.Start:SetPoint("LEFT", UIUFO_FlyoutMenuForGerm.Background.HorizontalMiddle, "RIGHT");
        SetClampedTextureRotation(UIUFO_FlyoutMenuForGerm.Background.Start, 270);
        UIUFO_FlyoutMenuForGerm.Background.VerticalMiddle:Hide();
        UIUFO_FlyoutMenuForGerm.Background.HorizontalMiddle:Show();
        UIUFO_FlyoutMenuForGerm.Background.HorizontalMiddle:ClearAllPoints();
        UIUFO_FlyoutMenuForGerm.Background.HorizontalMiddle:SetPoint("LEFT", UIUFO_FlyoutMenuForGerm.Background.End, "RIGHT");
        UIUFO_FlyoutMenuForGerm.Background.HorizontalMiddle:SetPoint("RIGHT", -distance, 0);
    elseif (direction == "RIGHT") then
        UIUFO_FlyoutMenuForGerm.Background.End:SetPoint("RIGHT", SPELLFLYOUT_INITIAL_SPACING, 0);
        SetClampedTextureRotation(UIUFO_FlyoutMenuForGerm.Background.End, 90);
        SetClampedTextureRotation(UIUFO_FlyoutMenuForGerm.Background.HorizontalMiddle, 0);
        UIUFO_FlyoutMenuForGerm.Background.Start:SetPoint("RIGHT", UIUFO_FlyoutMenuForGerm.Background.HorizontalMiddle, "LEFT");
        SetClampedTextureRotation(UIUFO_FlyoutMenuForGerm.Background.Start, 90);
        UIUFO_FlyoutMenuForGerm.Background.VerticalMiddle:Hide();
        UIUFO_FlyoutMenuForGerm.Background.HorizontalMiddle:Show();
        UIUFO_FlyoutMenuForGerm.Background.HorizontalMiddle:ClearAllPoints();
        UIUFO_FlyoutMenuForGerm.Background.HorizontalMiddle:SetPoint("RIGHT", UIUFO_FlyoutMenuForGerm.Background.End, "LEFT");
        UIUFO_FlyoutMenuForGerm.Background.HorizontalMiddle:SetPoint("LEFT", distance, 0);
    end
    UIUFO_FlyoutMenuForGerm:SetBorderColor(0.7, 0.7, 0.7)
    UIUFO_FlyoutMenuForGerm:SetBorderSize(47);
end
