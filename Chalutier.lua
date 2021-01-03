ProvCha_STATE_IDLE      = 0 --Running around, neither looking at an interactable nor fighting
ProvCha_STATE_LOOKAWAY  = 1 --Looking at an interactable which is NOT a fishing hole
ProvCha_STATE_LOOKING   = 2 --Looking at a fishing hole
ProvCha_STATE_NOBAIT    = 3 --Looking at a fishing hole, with NO bait equipped
ProvCha_STATE_FISHING   = 4 --Fishing
ProvCha_STATE_REELIN    = 5 --Reel in!
ProvCha_STATE_LOOT      = 6 --Lootscreen open, only right after Reel in!
ProvCha_STATE_INVFULL   = 7 --No free inventory slots
ProvCha_STATE_FIGHT     = 8 --TODO

--[[
- register event combat ->
    if "fight started" then changeState(ProvCha_STATE_FIGHTING)
    if "fight stopped" then changeState(ProvCha_STATE_IDLE)
- new images for LOOKAWAY, FIGHT
]]--
--local logger = LibDebugLogger(ProvCha.name)

local function changeState(state, arg2)
    if ProvCha.currentState == state then return end
    EVENT_MANAGER:UnregisterForUpdate(ProvCha.name .. "antiJobFictif")
    EVENT_MANAGER:UnregisterForEvent(ProvCha.name .. "OnSlotUpdate", EVENT_INVENTORY_SINGLE_SLOT_UPDATE)

    if state == ProvCha_STATE_IDLE then
        ProvCha.UI.Icon:SetTexture("ProvisionsChalutier/textures/icon_dds/waiting.dds")
        ProvCha.UI.blocInfo:SetColor(1, 1, 1)

    elseif state == ProvCha_STATE_LOOKAWAY then
        ProvCha.UI.Icon:SetTexture("ProvisionsChalutier/textures/icon_dds/waiting.dds")
        ProvCha.UI.blocInfo:SetColor(0.3, 0, 0.3)

    elseif state == ProvCha_STATE_LOOKING then
        ProvCha.UI.Icon:SetTexture("ProvisionsChalutier/textures/icon_dds/looking.dds")
        ProvCha.UI.blocInfo:SetColor(0.3961, 0.2706, 0)

    elseif state == ProvCha_STATE_NOBAIT then
        ProvCha.UI.Icon:SetTexture("ProvisionsChalutier/textures/icon_dds/nobait.dds")
        ProvCha.UI.blocInfo:SetColor(0, 0, 0)

    elseif state == ProvCha_STATE_FISHING then
        ProvCha.UI.Icon:SetTexture("ProvisionsChalutier/textures/icon_dds/fishing.dds")
        ProvCha.UI.blocInfo:SetColor(0.2980, 0.6118, 0.8392)

        LOOT_SCENE:RegisterCallback("StateChange", _LootSceneCB)
        EVENT_MANAGER:RegisterForEvent(ProvCha.name .. "OnSlotUpdate", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, function()
            if ProvCha.currentState == ProvCha_STATE_FISHING then changeState(ProvCha_STATE_REELIN) end
        end)

    elseif state == ProvCha_STATE_REELIN then
        ProvCha.UI.Icon:SetTexture("ProvisionsChalutier/textures/icon_dds/reelin.dds")
        ProvCha.UI.blocInfo:SetColor(0, 0.8, 0)

        EVENT_MANAGER:RegisterForUpdate(ProvCha.name .. "antiJobFictif", 3000, function()
            if ProvCha.currentState == ProvCha_STATE_REELIN then changeState(ProvCha_STATE_IDLE) end
        end)

    elseif state == ProvCha_STATE_LOOT then
        ProvCha.UI.Icon:SetTexture("ProvisionsChalutier/textures/icon_dds/loot.dds")
        ProvCha.UI.blocInfo:SetColor(0.8, 0, 0)

    elseif state == ProvCha_STATE_INVFULL then
        ProvCha.UI.Icon:SetTexture("ProvisionsChalutier/textures/icon_dds/invfull.dds")
        ProvCha.UI.blocInfo:SetColor(1, 0, 1)

    elseif state == ProvCha_STATE_FIGHT then -- TODO
        ProvCha.UI.Icon:SetTexture("ProvisionsChalutier/textures/icon_dds/fight.dds")
        ProvCha.UI.blocInfo:SetColor(1, 1, 1)

    end
    ProvCha.currentState = state
end

function _LootSceneCB(oldState, newState)
    if newState == "showing" then -- LOOT, INVFULL
        if (GetBagUseableSize(BAG_BACKPACK) - GetNumBagUsedSlots(BAG_BACKPACK)) <= 0 then
            changeState(ProvCha_STATE_INVFULL)
        else
            changeState(ProvCha_STATE_LOOT)
        end
    end
    if newState == "hiding" then -- IDLE
        changeState(ProvCha_STATE_IDLE)
        LOOT_SCENE:UnregisterCallback("StateChange", _LootSceneCB)
    end
end

local tmpInteractableName = ""
function Chalutier_OnAction()
    local action, interactableName, _, _, additionalInfo = GetGameCameraInteractableActionInfo()

    if action and additionalInfo == ADDITIONAL_INTERACT_INFO_FISHING_NODE then -- NOBAIT, LOOKING
        if not GetFishingLure() then
            changeState(ProvCha_STATE_NOBAIT)
        elseif ProvCha.currentState < ProvCha_STATE_FISHING then
            changeState(ProvCha_STATE_LOOKING)
            tmpInteractableName = interactableName
        end

    elseif action and tmpInteractableName == interactableName then -- FISHING, REELIN+
        if ProvCha.currentState > ProvCha_STATE_FISHING then return end
        changeState(ProvCha_STATE_FISHING)

    elseif action then -- LOOKAWAY
        changeState(ProvCha_STATE_LOOKAWAY)
        tmpInteractableName = ""

    else -- IDLE
        changeState(ProvCha_STATE_IDLE)
        tmpInteractableName = ""
    end
end

local function Chalutier_OnAddOnLoad(eventCode, addOnName)
    if (ProvCha.name ~= addOnName) then return end

    ProvCha.vars = ZO_SavedVars:NewAccountWide("ProvChaSV", 1, nil, ProvCha.defaults)

    ProvCha.UI = WINDOW_MANAGER:CreateControl(nil, GuiRoot, CT_TOPLEVELCONTROL)
    ProvCha.UI:SetMouseEnabled(true)
    ProvCha.UI:SetClampedToScreen(true)
    ProvCha.UI:SetMovable(true)
    ProvCha.UI:SetDimensions(64, 92)
    ProvCha.UI:SetDrawLevel(0)
    ProvCha.UI:SetDrawLayer(0)
    ProvCha.UI:SetDrawTier(0)

    ProvCha.UI:SetHidden(not ProvCha.vars.enabled)
    ProvCha.UI:ClearAnchors()
    ProvCha.UI:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 0, 0)

    ProvCha.UI.blocInfo = WINDOW_MANAGER:CreateControl(nil, ProvCha.UI, CT_TEXTURE)
    ProvCha.UI.blocInfo:SetDimensions(64, 6)
    ProvCha.UI.blocInfo:SetColor(1, 1, 1)
    ProvCha.UI.blocInfo:SetAnchor(TOP, ProvCha.UI, TOP, 0, blocInfo)
    ProvCha.UI.blocInfo:SetHidden(false)
    ProvCha.UI.blocInfo:SetDrawLevel(1)

    ProvCha.UI.Icon = WINDOW_MANAGER:CreateControl(nil, ProvCha.UI, CT_TEXTURE)
    ProvCha.UI.Icon:SetBlendMode(TEX_BLEND_MODE_ALPHA)
    ProvCha.UI.Icon:SetTexture("ProvisionsChalutier/textures/icon_dds/waiting.dds")
    ProvCha.UI.Icon:SetDimensions(64, 64)
    ProvCha.UI.Icon:SetAnchor(TOPLEFT, ProvCha.UI, TOPLEFT, 0, 18)
    ProvCha.UI.Icon:SetHidden(false)
    ProvCha.UI.Icon:SetDrawLevel(1)

    local chalutier_fragment = ZO_SimpleSceneFragment:New(ProvCha.UI)
    HUD_SCENE:AddFragment(chalutier_fragment)
    HUD_UI_SCENE:AddFragment(chalutier_fragment)
    LOOT_SCENE:AddFragment(chalutier_fragment)

    EVENT_MANAGER:UnregisterForEvent(ProvCha.name, EVENT_ADD_ON_LOADED)

    ZO_PreHookHandler(RETICLE.interact, "OnEffectivelyShown", Chalutier_OnAction)
    ZO_PreHookHandler(RETICLE.interact, "OnHide", Chalutier_OnAction)

    ProvCha.currentState = ProvCha_STATE_IDLE
end

EVENT_MANAGER:RegisterForEvent(ProvCha.name, EVENT_ADD_ON_LOADED, function(...) Chalutier_OnAddOnLoad(...) end)
