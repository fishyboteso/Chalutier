Chalutier =
{
    name            = "Chalutier",
    currentState    = 0,
    angle           = 0,
    swimming        = false,
    SavedVariables  = nil,
    state           = {},
    defaults        = {}
}
Chalutier.state     = {
    idle      =  0, --Running around, neither looking at an interactable nor fighting
    lookaway  =  1, --Looking at an interactable which is NOT a fishing hole
    looking   =  2, --Looking at a fishing hole
    depleted  =  3, --fishing hole just depleted
    nobait    =  5, --Looking at a fishing hole, with NO bait equipped
    fishing   =  6, --Fishing
    reelin    =  7, --Reel in!
    loot      =  8, --Lootscreen open, only right after Reel in!
    invfull   =  9, --No free inventory slots
    fight     = 14, --Fighting / Enemys taunted
    dead      = 15  --Dead
}
Chalutier.defaults  = {
    enabled = true,
    posx        = 0,
    posy        = 0,
    anchor      = 3,
    anchorRel   = 3,
    colors      = {
        [ 0] = { icon = "idle", text = "Idle",  r = 1, g = 1, b = 1, a = 1 },
        [ 1] = { icon = "idle", text = "Looking Away", r = 0.3, g = 0, b = 0.3, a = 1 },
        [ 2] = { icon = "looking", text = "Looking at Fishing Hole", r = 0.3961, g = 0.2706, b = 0, a = 1 },
        [ 3] = { icon = "depleted", text = "Fishing Hole Depleted", r = 0, g = 0.3, b = 0.3, a = 1 },
        [ 5] = { icon = "nobait", text = "No Bait Equipped", r = 1, g = 0.8, b = 0, a = 1 },
        [ 6] = { icon = "fishing", text = "Fishing", r = 0.2980, g = 0.6118, b = 0.8392, a = 1 },
        [ 7] = { icon = "reelin", text = "Reel In!", r = 0, g = 0.8, b = 0, a = 1 },
        [ 8] = { icon = "loot", text = "Loot Menu", r = 0, g = 0, b = 0.8, a = 1 },
        [ 9] = { icon = "invfull", text = "Inventory Full", r = 0, g = 0, b = 0.2, a = 1 },
        [14] = { icon = "fight", text = "Fighting", r = 0.8, g = 0, b = 0, a = 1 },
        [15] = { icon = "dead", text = "Dead", r = 0.2, g = 0.2, b = 0.2, a = 1 }
    }
}

--local logger = LibDebugLogger(Chalutier.name)
local LAM2 = LibAddonMenu2

local function _changeState(state, overwrite)
    if Chalutier.currentState == state then return end

    if Chalutier.currentState == Chalutier.state.fight and not overwrite then return end

    if Chalutier.swimming and state == Chalutier.state.looking then state = Chalutier.state.lookaway end

    EVENT_MANAGER:UnregisterForUpdate(Chalutier.name .. "STATE_REELIN")
    EVENT_MANAGER:UnregisterForUpdate(Chalutier.name .. "STATE_FISHING")
    EVENT_MANAGER:UnregisterForUpdate(Chalutier.name .. "STATE_DEPLETED")
    EVENT_MANAGER:UnregisterForEvent(Chalutier.name .. "OnSlotUpdate", EVENT_INVENTORY_SINGLE_SLOT_UPDATE)

    if state == Chalutier.state.depleted then
        EVENT_MANAGER:RegisterForUpdate(Chalutier.name .. "STATE_DEPLETED", 3000, function()
            if Chalutier.currentState == Chalutier.state.depleted then _changeState(Chalutier.state.idle) end
        end)

    elseif state == Chalutier.state.fishing then
        Chalutier.angle = (math.deg(GetPlayerCameraHeading())-180) % 360

        if not GetSetting_Bool(SETTING_TYPE_LOOT, LOOT_SETTING_AUTO_LOOT) then -- false = auto_loot off
            LOOT_SCENE:RegisterCallback("StateChange", _LootSceneCB)
        end
        EVENT_MANAGER:RegisterForEvent(Chalutier.name .. "OnSlotUpdate", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, function()
            if Chalutier.currentState == Chalutier.state.fishing then _changeState(Chalutier.state.reelin) end
        end)
        EVENT_MANAGER:RegisterForUpdate(Chalutier.name .. "STATE_FISHING", 28000, function()
            if Chalutier.currentState == Chalutier.state.fishing then _changeState(Chalutier.state.idle) end
        end)

    elseif state == Chalutier.state.reelin then
        EVENT_MANAGER:RegisterForUpdate(Chalutier.name .. "STATE_REELIN", 3000, function()
            if Chalutier.currentState == Chalutier.state.reelin then _changeState(Chalutier.state.idle) end
        end)
    end

    Chalutier.UI.Icon:SetTexture("Chalutier/textures/" .. Chalutier.SavedVariables.colors[state].icon .. ".dds")
    Chalutier.UI.blocInfo:SetColor(Chalutier.SavedVariables.colors[state].r, Chalutier.SavedVariables.colors[state].g, Chalutier.SavedVariables.colors[state].b, Chalutier.SavedVariables.colors[state].a)
    Chalutier.currentState = state
    Chalutier.CallbackManager:FireCallbacks(Chalutier.name .. "StateChange", Chalutier.currentState)
end

local function _lootRelease()
    local action, _, _, _, additionalInfo = GetGameCameraInteractableActionInfo()
    local angleDiv = ((math.deg(GetPlayerCameraHeading())-180) % 360) - Chalutier.angle

    if action and additionalInfo == ADDITIONAL_INTERACT_INFO_FISHING_NODE then
        _changeState(Chalutier.state.looking)
    elseif action then
        _changeState(Chalutier.state.lookaway)
    elseif -30 < angleDiv and angleDiv < 30 then
        _changeState(Chalutier.state.depleted)
    else
        _changeState(Chalutier.state.idle)
    end
end

function _LootSceneCB(oldState, newState)
    if newState == "showing" then -- LOOT, INVFULL
        if (GetBagUseableSize(BAG_BACKPACK) - GetNumBagUsedSlots(BAG_BACKPACK)) <= 0 then
            _changeState(Chalutier.state.invfull)
        else
            _changeState(Chalutier.state.loot)
        end
    end
    if newState == "hiding" then -- IDLE
        _lootRelease()
        LOOT_SCENE:UnregisterCallback("StateChange", _LootSceneCB)
    end
end

local tmpInteractableName = ""
local tmpNotMoving = true
function Chalutier_OnAction()
    local action, interactableName, _, _, additionalInfo = GetGameCameraInteractableActionInfo()

    if action and IsPlayerTryingToMove() and Chalutier.currentState < Chalutier.state.fishing then
        _changeState(Chalutier.state.lookaway)
        tmpInteractableName = ""
        tmpNotMoving = false
        EVENT_MANAGER:RegisterForUpdate(Chalutier.name .. "MOVING", 400, function()
            EVENT_MANAGER:UnregisterForUpdate(Chalutier.name .. "MOVING")
            if not IsPlayerTryingToMove() then
                tmpNotMoving = true
            end
        end)

    elseif action and additionalInfo == ADDITIONAL_INTERACT_INFO_FISHING_NODE then -- NOBAIT, LOOKING
        if not GetFishingLure() then
            _changeState(Chalutier.state.nobait)
        elseif Chalutier.currentState < Chalutier.state.fishing and tmpNotMoving then
            _changeState(Chalutier.state.looking)
            tmpInteractableName = interactableName
        end

    elseif action and tmpInteractableName == interactableName then -- FISHING, REELIN+
        if Chalutier.currentState > Chalutier.state.fishing then return end
        _changeState(Chalutier.state.fishing)

    elseif action then -- LOOKAWAY
        _changeState(Chalutier.state.lookaway)
        tmpInteractableName = ""

    elseif Chalutier.currentState == Chalutier.state.reelin and GetSetting_Bool(SETTING_TYPE_LOOT, LOOT_SETTING_AUTO_LOOT) then --DEPLETED
        _lootRelease()

    elseif Chalutier.currentState ~= Chalutier.state.depleted then -- IDLE
        _changeState(Chalutier.state.idle)
        tmpInteractableName = ""
    end
end

local function _createUI()
    Chalutier.UI = WINDOW_MANAGER:CreateControl(nil, GuiRoot, CT_TOPLEVELCONTROL)
    Chalutier.UI:SetMouseEnabled(true)
    Chalutier.UI:SetClampedToScreen(true)
    Chalutier.UI:SetMovable(true)
    Chalutier.UI:SetDimensions(64, 92)
    Chalutier.UI:SetDrawLevel(0)
    Chalutier.UI:SetDrawLayer(DL_MAX_VALUE-1)
    Chalutier.UI:SetDrawTier(DT_MAX_VALUE-1)
    Chalutier.UI:SetHidden(not Chalutier.SavedVariables.enabled)

    Chalutier.UI:ClearAnchors()
    Chalutier.UI:SetAnchor(Chalutier.SavedVariables.anchorRel, GuiRoot, Chalutier.SavedVariables.anchor, Chalutier.SavedVariables.posx, Chalutier.SavedVariables.posy)

    Chalutier.UI.blocInfo = WINDOW_MANAGER:CreateControl(nil, Chalutier.UI, CT_TEXTURE)
    Chalutier.UI.blocInfo:SetDimensions(64, 6)
    Chalutier.UI.blocInfo:SetColor(Chalutier.SavedVariables.colors[Chalutier.currentState].r, Chalutier.SavedVariables.colors[Chalutier.currentState].g, Chalutier.SavedVariables.colors[Chalutier.currentState].b, Chalutier.SavedVariables.colors[Chalutier.currentState].a)
    Chalutier.UI.blocInfo:SetAnchor(TOP, Chalutier.UI, TOP, 0, blocInfo)
    Chalutier.UI.blocInfo:SetHidden(not Chalutier.SavedVariables.enabled)
    Chalutier.UI.blocInfo:SetDrawLevel(0)
    Chalutier.UI.blocInfo:SetDrawLayer(DL_MAX_VALUE)
    Chalutier.UI.blocInfo:SetDrawTier(DT_MAX_VALUE)

    Chalutier.UI.Icon = WINDOW_MANAGER:CreateControl(nil, Chalutier.UI, CT_TEXTURE)
    Chalutier.UI.Icon:SetBlendMode(TEX_BLEND_MODE_ALPHA)
    Chalutier.UI.Icon:SetTexture("Chalutier/textures/" .. Chalutier.SavedVariables.colors[Chalutier.currentState].icon .. ".dds")
    Chalutier.UI.Icon:SetDimensions(64, 64)
    Chalutier.UI.Icon:SetAnchor(TOPLEFT, Chalutier.UI, TOPLEFT, 0, 18)
    Chalutier.UI.Icon:SetHidden(not Chalutier.SavedVariables.enabled)
    Chalutier.UI.Icon:SetDrawLevel(0)
    Chalutier.UI.blocInfo:SetDrawLayer(DL_MAX_VALUE)
    Chalutier.UI.blocInfo:SetDrawTier(DT_MAX_VALUE)

    Chalutier.UI:SetHandler("OnMoveStop", function()
        _, Chalutier.SavedVariables.anchorRel, _, Chalutier.SavedVariables.anchor, Chalutier.SavedVariables.posx, Chalutier.SavedVariables.posy, _ = Chalutier.UI:GetAnchor()
    end, Chalutier.name)

    local chalutier_fragment = ZO_SimpleSceneFragment:New(Chalutier.UI)
    HUD_SCENE:AddFragment(chalutier_fragment)
    HUD_UI_SCENE:AddFragment(chalutier_fragment)
    LOOT_SCENE:AddFragment(chalutier_fragment)
end

local function _createMenu()
    local panelName = "ChalutierSettingsPanel"

    local panelData = {
        type = "panel",
        name = Chalutier.name,
        displayName = Chalutier.name,
        author = "Provision, Sem",
        registerForRefresh = true,
        registerForDefaults = true,
    }
    local panel = LAM2:RegisterAddonPanel(panelName, panelData)
    local optionsData = {
        {
            type = "description",
            text = "Here you can setup Chalutiers configs."
        },
        {
            type = "checkbox",
            name = "Enabled",
            default = true,
            disabled = false,
            getFunc = function() return Chalutier.SavedVariables.enabled end,
            setFunc = function(value)
                Chalutier.SavedVariables.enabled = value
                Chalutier.UI:SetHidden(not Chalutier.SavedVariables.enabled)
                Chalutier.UI.blocInfo:SetHidden(not Chalutier.SavedVariables.enabled)
                Chalutier.UI.Icon:SetHidden(not Chalutier.SavedVariables.enabled)
            end
        },
        {
            type = "button",
            name = "move to top left corner",
            default = true,
            disabled = false,
            func = function()
                Chalutier.SavedVariables.anchor, Chalutier.SavedVariables.anchorRel = 3, 3
                Chalutier.SavedVariables.posx, Chalutier.SavedVariables.posy = 0, 0
                Chalutier.UI:ClearAnchors()
                Chalutier.UI:SetAnchor(Chalutier.SavedVariables.anchorRel, GuiRoot, Chalutier.SavedVariables.anchor, Chalutier.SavedVariables.posx, Chalutier.SavedVariables.posy)
            end
        },
        {
            type = "header",
            name = "Colors"
        },
    }

    for k,v in pairs(Chalutier.defaults.colors) do
        local def = Chalutier.defaults.colors[k]
        local sav = Chalutier.SavedVariables.colors[k]
        optionsData[#optionsData + 1] = {
            type = "colorpicker",
            name = def.text,
            getFunc = function()
                return sav.r, sav.g, sav.b, sav.a
            end,
            setFunc = function(r,g,b,a)
                sav.r, sav.g, sav.b, sav.a = r, g, b, a
                Chalutier.SavedVariables.colors[k] = sav
                Chalutier.UI.blocInfo:SetColor(sav.r, sav.g, sav.b, sav.a)
            end,
            default = {["r"] = def.r, ["g"] = def.g, ["b"] = def.b, ["a"] = def.a},
        }
    end

    LAM2:RegisterOptionControls(panelName, optionsData)
end

local function _onAddOnLoad(eventCode, addOnName)
    if (Chalutier.name ~= addOnName) then return end
    EVENT_MANAGER:UnregisterForEvent(Chalutier.name, EVENT_ADD_ON_LOADED)

--TODO remove with minion 4
    if libMainMenuSubcategoryButton then
        libMainMenuSubcategoryButton:SetDrawLayer(DL_MIN_VALUE)
        libMainMenuSubcategoryButton:SetDrawTier(DT_MIN_VALUE)
    end

    Chalutier.SavedVariables = ZO_SavedVars:NewAccountWide("ChalutierSV", 2, nil, Chalutier.defaults)
    Chalutier.CallbackManager = ZO_CallbackObject:New()
    Chalutier.currentState = Chalutier.state.idle

    _createUI()
    _createMenu()

    ZO_PreHookHandler(RETICLE.interact, "OnEffectivelyShown", Chalutier_OnAction)
    ZO_PreHookHandler(RETICLE.interact, "OnHide", Chalutier_OnAction)

    EVENT_MANAGER:RegisterForEvent(Chalutier.name, EVENT_PLAYER_SWIMMING, function(eventCode) Chalutier.swimming = true end)
    EVENT_MANAGER:RegisterForEvent(Chalutier.name, EVENT_PLAYER_NOT_SWIMMING, function(eventCode) Chalutier.swimming = false end)
    EVENT_MANAGER:RegisterForEvent(Chalutier.name, EVENT_PLAYER_DEAD, function(eventCode) _changeState(Chalutier.state.dead, true) end)
    EVENT_MANAGER:RegisterForEvent(Chalutier.name, EVENT_PLAYER_ALIVE, function(eventCode) _changeState(Chalutier.state.idle) end)
    EVENT_MANAGER:RegisterForEvent(Chalutier.name, EVENT_PLAYER_COMBAT_STATE, function(eventCode, inCombat)
        if inCombat then
            _changeState(Chalutier.state.fight)
        elseif Chalutier.currentState == Chalutier.state.fight then
            _changeState(Chalutier.state.idle, true)
        end
    end)
    
    EVENT_MANAGER:RegisterForUpdate(Chalutier.name .. "SET_HIDDEN", 4000, function() Chalutier.UI:SetHidden(not Chalutier.SavedVariables.enabled) end)
end

EVENT_MANAGER:RegisterForEvent(Chalutier.name, EVENT_ADD_ON_LOADED, function(...) _onAddOnLoad(...) end)
