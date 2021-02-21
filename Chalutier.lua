Chalutier_STATE_IDLE      = 0 --Running around, neither looking at an interactable nor fighting
Chalutier_STATE_LOOKAWAY  = 1 --Looking at an interactable which is NOT a fishing hole
Chalutier_STATE_LOOKING   = 2 --Looking at a fishing hole
Chalutier_STATE_DEPLETED  = 3 --fishing hole just depleted
Chalutier_STATE_NOBAIT    = 5 --Looking at a fishing hole, with NO bait equipped
Chalutier_STATE_FISHING   = 6 --Fishing
Chalutier_STATE_REELIN    = 7 --Reel in!
Chalutier_STATE_LOOT      = 8 --Lootscreen open, only right after Reel in!
Chalutier_STATE_INVFULL   = 9 --No free inventory slots
Chalutier_STATE_FIGHT     = 14 --Fighting / Enemys taunted
Chalutier_STATE_DEAD      = 15 --Dead

Chalutier =
{
    name        = "Chalutier",

    currentState = 0,
    angle       = 0,
    swimming    = false,

    defaults    =
    {
        enabled = true,
        posx    = GuiRoot:GetWidth() / 2 - 485,
        posy    = 0
    }
}

--local logger = LibDebugLogger(Chalutier.name)

local function changeState(state, overwrite)
    if Chalutier.currentState == state then return end

    if Chalutier.currentState == Chalutier_STATE_FIGHT and not overwrite then return end

    if Chalutier.swimming and state == Chalutier_STATE_LOOKING then state = Chalutier_STATE_LOOKAWAY end

    EVENT_MANAGER:UnregisterForUpdate(Chalutier.name .. "STATE_REELIN")
    EVENT_MANAGER:UnregisterForUpdate(Chalutier.name .. "STATE_FISHING")
    EVENT_MANAGER:UnregisterForUpdate(Chalutier.name .. "STATE_DEPLETED")
    EVENT_MANAGER:UnregisterForEvent(Chalutier.name .. "OnSlotUpdate", EVENT_INVENTORY_SINGLE_SLOT_UPDATE)

    if state == Chalutier_STATE_IDLE then
        Chalutier.UI.Icon:SetTexture("Chalutier/textures/idle.dds")
        Chalutier.UI.blocInfo:SetColor(1, 1, 1)

    elseif state == Chalutier_STATE_LOOKAWAY then
        Chalutier.UI.Icon:SetTexture("Chalutier/textures/idle.dds")
        Chalutier.UI.blocInfo:SetColor(0.3, 0, 0.3)

    elseif state == Chalutier_STATE_LOOKING then
        Chalutier.UI.Icon:SetTexture("Chalutier/textures/looking.dds")
        Chalutier.UI.blocInfo:SetColor(0.3961, 0.2706, 0)

    elseif state == Chalutier_STATE_DEPLETED then
        Chalutier.UI.Icon:SetTexture("Chalutier/textures/depleted.dds")
        Chalutier.UI.blocInfo:SetColor(0, 0.3, 0.3)
        EVENT_MANAGER:RegisterForUpdate(Chalutier.name .. "STATE_DEPLETED", 3000, function()
            if Chalutier.currentState == Chalutier_STATE_DEPLETED then changeState(Chalutier_STATE_IDLE) end
        end)

    elseif state == Chalutier_STATE_NOBAIT then
        Chalutier.UI.Icon:SetTexture("Chalutier/textures/nobait.dds")
        Chalutier.UI.blocInfo:SetColor(0, 0, 0)

    elseif state == Chalutier_STATE_FISHING then
        Chalutier.UI.Icon:SetTexture("Chalutier/textures/fishing.dds")
        Chalutier.UI.blocInfo:SetColor(0.2980, 0.6118, 0.8392)

        Chalutier.angle = (math.deg(GetPlayerCameraHeading())-180) % 360

        LOOT_SCENE:RegisterCallback("StateChange", _LootSceneCB)
        EVENT_MANAGER:RegisterForEvent(Chalutier.name .. "OnSlotUpdate", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, function()
            if Chalutier.currentState == Chalutier_STATE_FISHING then changeState(Chalutier_STATE_REELIN) end
        end)
        EVENT_MANAGER:RegisterForUpdate(Chalutier.name .. "STATE_FISHING", 28000, function()
            if Chalutier.currentState == Chalutier_STATE_FISHING then changeState(Chalutier_STATE_IDLE) end
        end)

    elseif state == Chalutier_STATE_REELIN then
        Chalutier.UI.Icon:SetTexture("Chalutier/textures/reelin.dds")
        Chalutier.UI.blocInfo:SetColor(0, 0.8, 0)

        EVENT_MANAGER:RegisterForUpdate(Chalutier.name .. "STATE_REELIN", 3000, function()
            if Chalutier.currentState == Chalutier_STATE_REELIN then changeState(Chalutier_STATE_IDLE) end
        end)

    elseif state == Chalutier_STATE_LOOT then
        Chalutier.UI.Icon:SetTexture("Chalutier/textures/loot.dds")
        Chalutier.UI.blocInfo:SetColor(0, 0, 0.8)

    elseif state == Chalutier_STATE_INVFULL then
        Chalutier.UI.Icon:SetTexture("Chalutier/textures/invfull.dds")
        Chalutier.UI.blocInfo:SetColor(0, 0, 0)

    elseif state == Chalutier_STATE_FIGHT then
        Chalutier.UI.Icon:SetTexture("Chalutier/textures/fight.dds")
        Chalutier.UI.blocInfo:SetColor(0.8, 0, 0)

    elseif state == Chalutier_STATE_DEAD then
        Chalutier.UI.Icon:SetTexture("Chalutier/textures/dead.dds")
        Chalutier.UI.blocInfo:SetColor(0, 0, 0)

    end
    Chalutier.currentState = state
    Chalutier.CallbackManager:FireCallbacks(Chalutier.name .. "StateChange", Chalutier.currentState)
end

local function lootRelease()
    local action, _, _, _, additionalInfo = GetGameCameraInteractableActionInfo()
    local angleDiv = ((math.deg(GetPlayerCameraHeading())-180) % 360) - Chalutier.angle

    if action and additionalInfo == ADDITIONAL_INTERACT_INFO_FISHING_NODE then
        changeState(Chalutier_STATE_LOOKING)
    elseif action then
        changeState(Chalutier_STATE_LOOKAWAY)
    elseif -30 < angleDiv and angleDiv < 30 then
        changeState(Chalutier_STATE_DEPLETED)
    else
        changeState(Chalutier_STATE_IDLE)
    end
end

function _LootSceneCB(oldState, newState)
    if newState == "showing" then -- LOOT, INVFULL
        if (GetBagUseableSize(BAG_BACKPACK) - GetNumBagUsedSlots(BAG_BACKPACK)) <= 0 then
            changeState(Chalutier_STATE_INVFULL)
        else
            changeState(Chalutier_STATE_LOOT)
        end
    end
    if newState == "hiding" then -- IDLE
        lootRelease()
        LOOT_SCENE:UnregisterCallback("StateChange", _LootSceneCB)
    end
end

local tmpInteractableName = ""
local tmpNotMoving = true
function Chalutier_OnAction()
    local action, interactableName, _, _, additionalInfo = GetGameCameraInteractableActionInfo()

    if action and IsPlayerTryingToMove() and Chalutier.currentState < Chalutier_STATE_FISHING then
        changeState(Chalutier_STATE_LOOKAWAY)
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
            changeState(Chalutier_STATE_NOBAIT)
        elseif Chalutier.currentState < Chalutier_STATE_FISHING and tmpNotMoving then
            changeState(Chalutier_STATE_LOOKING)
            tmpInteractableName = interactableName
        end

    elseif action and tmpInteractableName == interactableName then -- FISHING, REELIN+
        if Chalutier.currentState > Chalutier_STATE_FISHING then return end
        changeState(Chalutier_STATE_FISHING)

    elseif action then -- LOOKAWAY
        changeState(Chalutier_STATE_LOOKAWAY)
        tmpInteractableName = ""

    elseif Chalutier.currentState ~= Chalutier_STATE_DEPLETED then -- IDLE
        changeState(Chalutier_STATE_IDLE)
        tmpInteractableName = ""
    end
end

local function Chalutier_OnAddOnLoad(eventCode, addOnName)
    if (Chalutier.name ~= addOnName) then return end
    EVENT_MANAGER:UnregisterForEvent(Chalutier.name, EVENT_ADD_ON_LOADED)

--TODO remove with minion 4
    if libMainMenuSubcategoryButton then
        libMainMenuSubcategoryButton:SetDrawLayer(DL_MIN_VALUE)
        libMainMenuSubcategoryButton:SetDrawTier(DT_MIN_VALUE)
    end

    Chalutier.vars = ZO_SavedVars:NewAccountWide("ChalutierSV", 1, nil, Chalutier.defaults)

    Chalutier.CallbackManager = ZO_CallbackObject:New()

    Chalutier.UI = WINDOW_MANAGER:CreateControl(nil, GuiRoot, CT_TOPLEVELCONTROL)
    Chalutier.UI:SetMouseEnabled(true)
    Chalutier.UI:SetClampedToScreen(true)
    Chalutier.UI:SetMovable(true)
    Chalutier.UI:SetDimensions(64, 92)
    Chalutier.UI:SetDrawLevel(0)
    Chalutier.UI:SetDrawLayer(DL_MAX_VALUE-1)
    Chalutier.UI:SetDrawTier(DT_MAX_VALUE-1)

    Chalutier.UI:SetHidden(not Chalutier.vars.enabled)
    Chalutier.UI:ClearAnchors()
    Chalutier.UI:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 0, 0)

    Chalutier.UI.blocInfo = WINDOW_MANAGER:CreateControl(nil, Chalutier.UI, CT_TEXTURE)
    Chalutier.UI.blocInfo:SetDimensions(64, 6)
    Chalutier.UI.blocInfo:SetColor(1, 1, 1)
    Chalutier.UI.blocInfo:SetAnchor(TOP, Chalutier.UI, TOP, 0, blocInfo)
    Chalutier.UI.blocInfo:SetHidden(false)
    Chalutier.UI.blocInfo:SetDrawLevel(0)
    Chalutier.UI.blocInfo:SetDrawLayer(DL_MAX_VALUE)
    Chalutier.UI.blocInfo:SetDrawTier(DT_MAX_VALUE)

    Chalutier.UI.Icon = WINDOW_MANAGER:CreateControl(nil, Chalutier.UI, CT_TEXTURE)
    Chalutier.UI.Icon:SetBlendMode(TEX_BLEND_MODE_ALPHA)
    Chalutier.UI.Icon:SetTexture("Chalutier/textures/idle.dds")
    Chalutier.UI.Icon:SetDimensions(64, 64)
    Chalutier.UI.Icon:SetAnchor(TOPLEFT, Chalutier.UI, TOPLEFT, 0, 18)
    Chalutier.UI.Icon:SetHidden(false)
    Chalutier.UI.Icon:SetDrawLevel(0)
    Chalutier.UI.blocInfo:SetDrawLayer(DL_MAX_VALUE)
    Chalutier.UI.blocInfo:SetDrawTier(DT_MAX_VALUE)
    Chalutier.currentState = Chalutier_STATE_IDLE

    local chalutier_fragment = ZO_SimpleSceneFragment:New(Chalutier.UI)
    HUD_SCENE:AddFragment(chalutier_fragment)
    HUD_UI_SCENE:AddFragment(chalutier_fragment)
    LOOT_SCENE:AddFragment(chalutier_fragment)

    ZO_PreHookHandler(RETICLE.interact, "OnEffectivelyShown", Chalutier_OnAction)
    ZO_PreHookHandler(RETICLE.interact, "OnHide", Chalutier_OnAction)

    EVENT_MANAGER:RegisterForEvent(Chalutier.name, EVENT_PLAYER_SWIMMING, function(eventCode) Chalutier.swimming = true end)
    EVENT_MANAGER:RegisterForEvent(Chalutier.name, EVENT_PLAYER_NOT_SWIMMING, function(eventCode) Chalutier.swimming = false end)
    EVENT_MANAGER:RegisterForEvent(Chalutier.name, EVENT_PLAYER_DEAD, function(eventCode) changeState(Chalutier_STATE_DEAD, true) end)
    EVENT_MANAGER:RegisterForEvent(Chalutier.name, EVENT_PLAYER_ALIVE, function(eventCode) changeState(Chalutier_STATE_IDLE) end)
    EVENT_MANAGER:RegisterForEvent(Chalutier.name, EVENT_PLAYER_COMBAT_STATE, function(eventCode, inCombat)
        if inCombat then
            changeState(Chalutier_STATE_FIGHT)
        elseif Chalutier.currentState == Chalutier_STATE_FIGHT then
            changeState(Chalutier_STATE_IDLE, true)
        end
    end)
end

EVENT_MANAGER:RegisterForEvent(Chalutier.name, EVENT_ADD_ON_LOADED, function(...) Chalutier_OnAddOnLoad(...) end)
