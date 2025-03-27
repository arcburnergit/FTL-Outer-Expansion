
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
local function get_level_description_aea_shields(systemId, level, tooltip)
    if systemId == Hyperspace.ShipSystem.NameToSystemId("aea_shields") then
    	if level == 2 then
        	return "One Shield Barrier"
        elseif level == 4 then
        	return "Two Shield Barriers"
        elseif level == 6 then
        	return "Three Shield Barriers"
        elseif level == 8 then
        	return "Four Shield Barriers"
    	elseif level == 10 then
        	return "Five Shield Barriers"
        elseif level == 12 then
        	return "Six Shield Barriers"
        elseif level == 14 then
        	return "Seven Shield Barriers"
        elseif level == 16 then
        	return "Eight Shield Barriers"
        elseif level%2 == 0 then
        	return string.format("%i Shield Barriers", math.floor(level/2))
        else
        	return ""
        end
    end
end

script.on_internal_event(Defines.InternalEvents.GET_LEVEL_DESCRIPTION, get_level_description_aea_shields)

--Utility function to check if the SystemBox instance is for our customs system
local function is_aea_shields(systemBox)
    local systemName = Hyperspace.ShipSystem.SystemIdToName(systemBox.pSystem.iSystemType)
    return systemName == "aea_shields" and systemBox.bPlayerUI
end

--Utility function to check if the SystemBox instance is for our customs system
local function is_aea_shields_enemy(systemBox)
    local systemName = Hyperspace.ShipSystem.SystemIdToName(systemBox.pSystem.iSystemType)
    return systemName == "aea_shields" and not systemBox.bPlayerUI
end
 
--Handles initialization of custom system box
local function aea_shields_construct_system_box(systemBox)
    if is_aea_shields(systemBox) then
        systemBox.extend.xOffset = 36
    end
end

script.on_internal_event(Defines.InternalEvents.CONSTRUCT_SYSTEM_BOX, aea_shields_construct_system_box)

--Utility function to see if the system is ready for use
local function aea_shields_ready(shipSystem)
   return not shipSystem:GetLocked() and shipSystem:Functioning()
end

local shieldTimer = {}
shieldTimer[0] = 0
shieldTimer[1] = 0

local shieldExtra = {}
shieldExtra[0] = 0
shieldExtra[1] = 0

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	if shipManager:HasSystem(Hyperspace.ShipSystem.NameToSystemId("aea_shields")) then
		local aea_shields_system = shipManager:GetSystem(Hyperspace.ShipSystem.NameToSystemId("aea_shields"))
		local shieldPower = math.floor(aea_shields_system:GetEffectivePower()/2)
		local normalCap = 0
		if shipManager:HasSystem(0) then 
			shieldPower = shieldPower + math.floor(shipManager:GetSystem(0):GetEffectivePower()/2) 
			normalCap = math.floor(shipManager:GetSystem(0):GetEffectivePower()/2) 
		end
		shipManager.shieldSystem.shields.power.second = shieldPower
		--print(" SHIELD POWER:"..tostring(shipManager.shieldSystem.shields.power.first).." MAX:"..tostring(shipManager.shieldSystem.shields.power.second).." shieldPower:"..shieldPower.." normalCap:"..normalCap)
		if shieldPower > normalCap and shipManager.shieldSystem.shields.power.first >= normalCap and shipManager.shieldSystem.shields.power.first + shieldExtra[shipManager.iShipId] < shieldPower then
			--print("CHARGE TIME")
			print("CHARGER START:"..shipManager.shieldSystem.shields.charger)
			--local timer = shieldTimer[shipManager.iShipId]
			shieldTimer[shipManager.iShipId] = math.min(2, shieldTimer[shipManager.iShipId] + Hyperspace.FPS.SpeedFactor/16)
			shipManager.shieldSystem.shields.charger = shieldTimer[shipManager.iShipId]
			if shipManager.shieldSystem.shields.charger >= 2 then
				shipManager.shieldSystem.shields.charger = 0
				shieldTimer[shipManager.iShipId] = 0
				shieldExtra[shipManager.iShipId] = shieldExtra[shipManager.iShipId] + 1
			end
			print("CHARGER END:"..shipManager.shieldSystem.shields.charger)
			--[[print("CHARGER START:"..shipManager.shieldSystem.shields.charger)
			if shipManager.shieldSystem.shields.charger == 0 then 
				print("SET")
				shipManager.shieldSystem.shields.charger = 1.99
			else
				shipManager.shieldSystem.shields.charger = shipManager.shieldSystem.shields.charger + Hyperspace.FPS.SpeedFactor/16
			end
			print("CHARGER END:"..shipManager.shieldSystem.shields.charger)]]
		else
			shieldTimer[shipManager.iShipId] = shipManager.shieldSystem.shields.charger%2
		end
		shipManager.shieldSystem.shields.power.first = shipManager.shieldSystem.shields.power.first + shieldExtra[shipManager.iShipId]
		print("TIMER:"..shieldTimer[shipManager.iShipId])
	end
end)

script.on_internal_event(Defines.InternalEvents.GET_AUGMENTATION_VALUE, function(shipManager, augName, augValue)
	if shipManager and augName == "SHIELD_RECHARGE" and shipManager:HasSystem(Hyperspace.ShipSystem.NameToSystemId("aea_shields")) then
		local manning_level = shipManager:GetSystem(Hyperspace.ShipSystem.NameToSystemId("aea_shields")).iActiveManned
		augValue = augValue + manning_level * 0.1
	end
	return Defines.Chain.CONTINUE, augValue
end, -100)

local systemIcons = {}
local function system_icon(name)
    local tex = Hyperspace.Resources:GetImageId("icons/s_"..name.."_overlay.png")
    return Graphics.CSurface.GL_CreateImagePrimitive(tex, 0, 0, 32, 32, 0, Graphics.GL_Color(1, 1, 1, 0.5))
end
systemIcons[Hyperspace.ShipSystem.NameToSystemId("aea_shields")] = system_icon("aea_shields")

-- Render icons
local function render_icon(sysId, ship, sysInfo)
    -- Special logic for medbay and clonebay
    local skipBackground = false
    
    -- Render logic
    if not ship:HasSystem(sysId) and sysInfo:has_key(sysId) then
        local sysRoomShape = Hyperspace.ShipGraph.GetShipInfo(ship.iShipId):GetRoomShape(sysInfo[sysId].location[0])
        local iconRenderX = sysRoomShape.x + sysRoomShape.w//2 - 16
        local iconRenderY = sysRoomShape.y + sysRoomShape.h//2 - 16
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
        render_icon(Hyperspace.ShipSystem.NameToSystemId("aea_shields"), shipManager, sysInfo)
    end
    return Defines.Chain.CONTINUE
end)