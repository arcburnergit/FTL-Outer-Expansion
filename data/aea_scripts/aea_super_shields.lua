
local function global_pos_to_player_pos(mousePosition)
    local cApp = Hyperspace.Global.GetInstance():GetCApp()
    local combatControl = cApp.gui.combatControl
    local playerPosition = combatControl.playerShipPosition
    return Hyperspace.Point(mousePosition.x - playerPosition.x, mousePosition.y - playerPosition.y)
end

local function get_room_at_location(shipManager, location, includeWalls)
    return Hyperspace.ShipGraph.GetShipInfo(shipManager.iShipId):GetSelectedRoom(location.x, location.y, includeWalls)
end

local function vter(cvec)
    local i = -1
    local n = cvec:size()
    return function()
        i = i + 1
        if i < n then return cvec[i] end
    end
end

--Handles tooltips and mousever descriptions per level
local function get_level_description_aea_super_shields(systemId, level, tooltip)
    if systemId == Hyperspace.ShipSystem.NameToSystemId("aea_super_shields") then
        if level%4 == 1 then
            return string.format("Layers: %i / Speed: %ix", 2 + math.ceil(level/2), math.floor(0.75 + level / 4))
        else
            return string.format("Layers: %i / Speed: %sx", 2 + math.ceil(level/2), tostring(0.75 + level / 4))
        end
    end
end

script.on_internal_event(Defines.InternalEvents.GET_LEVEL_DESCRIPTION, get_level_description_aea_super_shields)

--Utility function to check if the SystemBox instance is for our customs system
local function is_aea_super_shields(systemBox)
    local systemName = Hyperspace.ShipSystem.SystemIdToName(systemBox.pSystem.iSystemType)
    return systemName == "aea_super_shields" and systemBox.bPlayerUI
end

--Utility function to check if the SystemBox instance is for our customs system
local function is_aea_super_shields_enemy(systemBox)
    local systemName = Hyperspace.ShipSystem.SystemIdToName(systemBox.pSystem.iSystemType)
    return systemName == "aea_super_shields" and not systemBox.bPlayerUI
end
 
--Handles initialization of custom system box
local function aea_super_shields_construct_system_box(systemBox)
    if is_aea_super_shields(systemBox) then
        systemBox.extend.xOffset = 36
    end
end

script.on_internal_event(Defines.InternalEvents.CONSTRUCT_SYSTEM_BOX, aea_super_shields_construct_system_box)

--Utility function to see if the system is ready for use
local function aea_super_shields_ready(shipSystem)
   return not shipSystem:GetLocked() and shipSystem:Functioning()
end

local shieldTimer = {}
shieldTimer[0] = 0
shieldTimer[1] = 0

local shield_ui = Hyperspace.Resources:CreateImagePrimitiveString("statusUI/top_aea_aux_on.png", 25, 86, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)

script.on_internal_event(Defines.InternalEvents.JUMP_ARRIVE, function(shipManager)
    shieldTimer[0] = 0
    shieldTimer[1] = 0
    if shipManager:HasSystem(Hyperspace.ShipSystem.NameToSystemId("aea_super_shields")) and shipManager:HasAugmentation("UPG_AEA_SUPER_SHIELD_OVERCHARGER") > 0 then
        local aea_super_shields_system = shipManager:GetSystem(Hyperspace.ShipSystem.NameToSystemId("aea_super_shields"))
        local maxLayers = 2 + math.ceil(aea_super_shields_system:GetEffectivePower()/2) - shipManager.shieldSystem.shields.power.super.first
        if maxLayers > 0 then
            for i = 1, maxLayers do
                shipManager.shieldSystem:AddSuperShield(shipManager.shieldSystem.superUpLoc)
            end
        end
    end
end)

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	if shipManager:HasSystem(Hyperspace.ShipSystem.NameToSystemId("aea_super_shields")) then
		local aea_super_shields_system = shipManager:GetSystem(Hyperspace.ShipSystem.NameToSystemId("aea_super_shields"))
        if not aea_super_shields_ready(aea_super_shields_system) then 
            shieldTimer[shipManager.iShipId] = 0 
            return 
        end
        local manningCrew = nil
        for crew in vter(shipManager.vCrewList) do
            if crew.bActiveManning and crew.currentSystem == aea_super_shields_system then
                aea_super_shields_system.iActiveManned = crew:GetSkillLevel(2)
                manningCrew = crew
            end
        end
		local maxLayers = 2 + math.ceil(aea_super_shields_system:GetEffectivePower()/2)
        local multiplier =  0.75 + aea_super_shields_system:GetEffectivePower() / 4 + aea_super_shields_system.iActiveManned * 0.1
        if shipManager.iShipId == 1 then multiplier = multiplier * 0.7 end
        if shipManager.shieldSystem.shields.power.super.first < maxLayers then
            shieldTimer[shipManager.iShipId] = math.min(5, shieldTimer[shipManager.iShipId] + multiplier * Hyperspace.FPS.SpeedFactor/16)
            if shieldTimer[shipManager.iShipId] >= 5 then
                if manningCrew then
                    manningCrew:IncreaseSkill(2)
                end
                --if maxLayers > 5 then shipManager.shieldSystem.shields.power.super.second = maxLayers end
                shipManager.shieldSystem:AddSuperShield(shipManager.shieldSystem.superUpLoc)
                shieldTimer[shipManager.iShipId] = 0
                --shipManager.shieldSystem.shields.power.super.second = shipManager.shieldSystem.shields.power.super.first
            end
        else
            shieldTimer[shipManager.iShipId] = 0
        end
	end
end)

script.on_render_event(Defines.RenderEvents.SPACE_STATUS, function() end, function()
    if Hyperspace.ships.player:HasSystem(Hyperspace.ShipSystem.NameToSystemId("aea_super_shields")) then
        if Hyperspace.ships.player.shieldSystem.shields.power.second == 0 then
            Graphics.CSurface.GL_RenderPrimitive(shield_ui)
        else
            Graphics.CSurface.GL_RenderPrimitive(shield_ui)
        end
        Graphics.CSurface.GL_DrawRect(25+7, 87+2, (shieldTimer[0]/(5)) * 94, 4, Graphics.GL_Color(1, 1, 1, 1));
    end
end)

--[[script.on_internal_event(Defines.InternalEvents.GET_AUGMENTATION_VALUE, function(shipManager, augName, augValue)
	if shipManager and augName == "SHIELD_RECHARGE" and shipManager:HasSystem(Hyperspace.ShipSystem.NameToSystemId("aea_super_shields")) then
		local manning_level = shipManager:GetSystem(Hyperspace.ShipSystem.NameToSystemId("aea_super_shields")).iActiveManned
		augValue = augValue + manning_level * 0.1
	end
	return Defines.Chain.CONTINUE, augValue
end, -100)]]

local systemIcons = {}
local function system_icon(name)
    local tex = Hyperspace.Resources:GetImageId("icons/s_"..name.."_overlay.png")
    return Graphics.CSurface.GL_CreateImagePrimitive(tex, 0, 0, 32, 32, 0, Graphics.GL_Color(1, 1, 1, 0.5))
end
systemIcons[Hyperspace.ShipSystem.NameToSystemId("aea_super_shields")] = system_icon("aea_super_shields")

-- Render icons
local function render_icon(sysId, ship, sysInfo)
    -- Special logic for medbay and clonebay
    local skipBackground = false
    
    -- Render logic
    if not ship:HasSystem(sysId) and sysInfo:has_key(sysId) then
        local sysRoomShape = Hyperspace.ShipGraph.GetShipInfo(ship.iShipId):GetRoomShape(sysInfo[sysId].location[0])
        local iconRenderX = sysRoomShape.x + sysRoomShape.w//2 - 16
        local iconRenderY = sysRoomShape.y + sysRoomShape.h//2 - 16
        if sysInfo:has_key(10) and sysInfo[sysId].location[0] == sysInfo[10].location[0] then
            iconRenderY = iconRenderY + 18
            skipBackground = true
        end
        if not skipBackground then
            local outlineSize = 2
            Graphics.CSurface.GL_DrawRect(
                sysRoomShape.x,
                sysRoomShape.y,
                sysRoomShape.w,
                sysRoomShape.h,
                Graphics.GL_Color(0, 0, 0, 0.3))
            Graphics.CSurface.GL_DrawRectOutline(
                sysRoomShape.x + outlineSize,
                sysRoomShape.y + outlineSize,
                sysRoomShape.w - 2*outlineSize,
                sysRoomShape.h - 2*outlineSize,
                Graphics.GL_Color(0.8, 0, 0, 0.5), outlineSize)
        end
        Graphics.CSurface.GL_PushMatrix()
        Graphics.CSurface.GL_Translate(iconRenderX, iconRenderY)
        Graphics.CSurface.GL_RenderPrimitive(systemIcons[sysId])
        Graphics.CSurface.GL_PopMatrix()
    end
end
script.on_render_event(Defines.RenderEvents.SHIP_SPARKS, function() end, function(ship)
    if not Hyperspace.App.world.bStartedGame then
        local shipManager = Hyperspace.ships(ship.iShipId)
        local sysInfo = shipManager.myBlueprint.systemInfo
        render_icon(Hyperspace.ShipSystem.NameToSystemId("aea_super_shields"), shipManager, sysInfo)
    end
    return Defines.Chain.CONTINUE
end)
