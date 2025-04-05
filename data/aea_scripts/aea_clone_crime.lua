
local function global_pos_to_player_pos(mousePosition)
    local cApp = Hyperspace.Global.GetInstance():GetCApp()
    local combatControl = cApp.gui.combatControl
    local playerPosition = combatControl.playerShipPosition
    return Hyperspace.Point(mousePosition.x - playerPosition.x, mousePosition.y - playerPosition.y)
end

local function get_room_at_location(shipManager, location, includeWalls)
    return Hyperspace.ShipGraph.GetShipInfo(shipManager.iShipId):GetSelectedRoom(location.x, location.y, includeWalls)
end

local RandomList = {
    New = function(self, table)
        table = table or {}
        self.__index = self
        setmetatable(table, self)
        return table
    end,

    GetItem = function(self)
        local index = Hyperspace.random32() % #self + 1
        return self[index]
    end,
}

local function vter(cvec)
    local i = -1
    local n = cvec:size()
    return function()
        i = i + 1
        if i < n then return cvec[i] end
    end
end

--Handles tooltips and mousever descriptions per level
local function get_level_description_aea_clone_crime(systemId, level, tooltip)
    if systemId == Hyperspace.ShipSystem.NameToSystemId("aea_clone_crime") then
        return string.format("Crew per jump: %i", level)
    end
end

script.on_internal_event(Defines.InternalEvents.GET_LEVEL_DESCRIPTION, get_level_description_aea_clone_crime)

--Utility function to check if the SystemBox instance is for our customs system
local function is_aea_clone_crime(systemBox)
    local systemName = Hyperspace.ShipSystem.SystemIdToName(systemBox.pSystem.iSystemType)
    return systemName == "aea_clone_crime" and systemBox.bPlayerUI
end

--Utility function to check if the SystemBox instance is for our customs system
local function is_aea_clone_crime_enemy(systemBox)
    local systemName = Hyperspace.ShipSystem.SystemIdToName(systemBox.pSystem.iSystemType)
    return systemName == "aea_clone_crime" and not systemBox.bPlayerUI
end
 
local function fillSlot(systemName, shipManager)
    local sysId = Hyperspace.ShipSystem.NameToSystemId(systemName)
    if shipManager and shipManager:HasSystem(sysId) then
        local sysRoom = nil
        local aea_clone_crime_system = shipManager:GetSystem(sysId)
        for room in vter(shipManager.ship.vRoomList) do
            if room.iRoomId == aea_clone_crime_system.roomId then
                sysRoom = room
            end
        end
        local slot = shipManager.myBlueprint.systemInfo[sysId].slot
        if sysRoom and slot then
            sysRoom:FillSlot(slot, false)
            sysRoom:FillSlot(slot, true)
            return true
        end
    end
    return false
end

--Handles initialization of custom system box
local function aea_clone_crime_construct_system_box(systemBox)
    if is_aea_clone_crime(systemBox) then
        systemBox.extend.xOffset = 36

        systemBox.pSystem.bBoostable = false -- make the system unmannable
    elseif is_aea_clone_crime_enemy(systemBox) then
        systemBox.pSystem.bBoostable = false
    end
end

script.on_internal_event(Defines.InternalEvents.CONSTRUCT_SYSTEM_BOX, aea_clone_crime_construct_system_box)

local needsFillSlot = false
script.on_internal_event(Defines.InternalEvents.CONSTRUCT_SHIP_SYSTEM, function(system)
    if Hyperspace.ShipSystem.SystemIdToName(system.iSystemType) == "aea_clone_crime" then
        --fillSlot("aea_clone_crime", Hyperspace.ships(system.iShipId))
        needsFillSlot = true
    end
end)

script.on_internal_event(Defines.InternalEvents.CREW_LOOP, function(crewmem)
    if needsFillSlot then
        if fillSlot("aea_clone_crime", Hyperspace.ships.player) then
            needsFillSlot = false
        end
    end
end)

--Utility function to see if the system is ready for use
local function aea_clone_crime_ready(shipSystem)
   return not shipSystem:GetLocked() and shipSystem:Functioning()
end

randomCloneCrew = RandomList:New {"aea_sac_human", "aea_sac_engi", "aea_sac_mantis", "aea_sac_slug", "aea_sac_rock"}

local healthBoost = Hyperspace.StatBoostDefinition()
healthBoost.stat = Hyperspace.CrewStat.MAX_HEALTH
healthBoost.amount = 0
healthBoost.duration = -1
healthBoost.maxStacks = 99
healthBoost.cloneClear = true
healthBoost.boostType = Hyperspace.StatBoostDefinition.BoostType.FLAT
healthBoost.boostSource = Hyperspace.StatBoostDefinition.BoostSource.AUGMENT
healthBoost.shipTarget = Hyperspace.StatBoostDefinition.ShipTarget.ALL
healthBoost.crewTarget = Hyperspace.StatBoostDefinition.CrewTarget.ALL
healthBoost:GiveId()
--[[healthBoost.powerScaling:push_back(Hyperspace.ShipSystem.NameToSystemId("aea_clone_crime"))
healthBoost.powerScalingNoSys = 0
healthBoost.powerScalingHackedSys = -1
for i = 0, 4 do
   healthBoost.powerScaling:push_back(i)
end]]
script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	if shipManager:HasSystem(Hyperspace.ShipSystem.NameToSystemId("aea_clone_crime")) then
        --fillSlot("aea_clone_crime", shipManager)
		local aea_clone_crime_system = shipManager:GetSystem(Hyperspace.ShipSystem.NameToSystemId("aea_clone_crime"))
        --aea_clone_crime_system.bNeedsManned = false
        if not aea_clone_crime_ready(aea_clone_crime_system) then 
            if aea_clone_crime_system.iHackEffect > 0 then 
                healthBoost.amount = -20
            else
                healthBoost.amount = 0
            end
            return 
        end
        healthBoost.amount = aea_clone_crime_system:GetEffectivePower() * 20
        for crewmem in vter(shipManager.vCrewList) do
            if crewmem.extend.deathTimer and crewmem.extend.deathTimer:Running() and crewmem.iShipId == shipManager.iShipId then
                --print("INCREASE TIMER:"..tostring(crewmem.extend.deathTimer.currTime).." goal:"..tostring(crewmem.extend.deathTimer.currGoal))
                crewmem.extend.deathTimer.currTime = crewmem.extend.deathTimer.currTime - Hyperspace.FPS.SpeedFactor/16
            end
        end
	end
end)

script.on_internal_event(Defines.InternalEvents.JUMP_ARRIVE, function(shipManager)
    if shipManager:HasSystem(Hyperspace.ShipSystem.NameToSystemId("aea_clone_crime")) then
        local aea_clone_crime_system = shipManager:GetSystem(Hyperspace.ShipSystem.NameToSystemId("aea_clone_crime"))
        if not aea_clone_crime_ready(aea_clone_crime_system) then 
            return 
        end
        for i = 1, aea_clone_crime_system:GetEffectivePower() do
            local cloneCrewType = randomCloneCrew:GetItem()
            local clone = shipManager:AddCrewMemberFromString("Clone", cloneCrewType, false, aea_clone_crime_system.roomId, true, true)
            local deathTime = 30
            if shipManager:HasAugmentation("UPG_AEA_CLONE_CRIME_LIFETIME") > 0 or shipManager:HasAugmentation("EX_AEA_CLONE_CRIME_LIFETIME") > 0 then
                --print(shipManager:GetAugmentationValue("UPG_AEA_CLONE_CRIME_LIFETIME"))
                deathTime = 30 + 20 * (shipManager:GetAugmentationValue("UPG_AEA_CLONE_CRIME_LIFETIME") + shipManager:GetAugmentationValue("EX_AEA_CLONE_CRIME_LIFETIME"))
            end
            if shipManager:HasAugmentation("UPG_AEA_CLONE_CRIME_BUFF") > 0 or shipManager:HasAugmentation("EX_AEA_CLONE_CRIME_BUFF") > 0 then
                --print("APPLY BUFF")
                Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(healthBoost), clone)
            end
            clone.extend.deathTimer = Hyperspace.TimerHelper(false)
            clone.extend.deathTimer:Start(deathTime)
        end
        aea_clone_crime_system:LockSystem(2)
    end
end)

local cloneImageBottom = Hyperspace.Resources:CreateImagePrimitiveString("ship/interior/aea_clone_bottom.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
local cloneImageTop = Hyperspace.Resources:CreateImagePrimitiveString("ship/interior/clone_top.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)

script.on_render_event(Defines.RenderEvents.SHIP_FLOOR, function() end, function(ship)
    local shipManager = Hyperspace.ships(ship.iShipId)
    if shipManager:HasSystem(Hyperspace.ShipSystem.NameToSystemId("aea_clone_crime")) then
        local sysId = Hyperspace.ShipSystem.NameToSystemId("aea_clone_crime")
        local aea_clone_crime_system = shipManager:GetSystem(sysId)
        local slot = shipManager.myBlueprint.systemInfo[sysId].slot
        local roomShape = Hyperspace.ShipGraph.GetShipInfo(shipManager.iShipId):GetRoomShape(aea_clone_crime_system.roomId)
        local w = roomShape.w/35
        local h = roomShape.h/35
        local x = roomShape.x + (35 * (slot%w))
        local y = roomShape.y + (35 * math.floor(slot/h))
        Graphics.CSurface.GL_PushMatrix()
        Graphics.CSurface.GL_Translate(x, y)
        Graphics.CSurface.GL_RenderPrimitive(cloneImageBottom)
        Graphics.CSurface.GL_RenderPrimitive(cloneImageTop)
        Graphics.CSurface.GL_PopMatrix()
    end
end)

script.on_internal_event(Defines.InternalEvents.JUMP_LEAVE, function(shipManager)
    if shipManager.iShipId == 0 and shipManager:HasSystem(Hyperspace.ShipSystem.NameToSystemId("aea_clone_crime")) then
        local system = shipManager:GetSystem(Hyperspace.ShipSystem.NameToSystemId("aea_clone_crime"))
        local gui = Hyperspace.App.gui
        if system:GetLocked() and (gui.upgradeButton.bActive and not gui.event_pause) then
            system:LockSystem(0)
        end
    end
end)

local systemIcons = {}
local function system_icon(name)
    local tex = Hyperspace.Resources:GetImageId("icons/s_"..name.."_overlay.png")
    return Graphics.CSurface.GL_CreateImagePrimitive(tex, 0, 0, 32, 32, 0, Graphics.GL_Color(1, 1, 1, 0.5))
end
systemIcons[Hyperspace.ShipSystem.NameToSystemId("aea_clone_crime")] = system_icon("aea_clone_crime")

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
        render_icon(Hyperspace.ShipSystem.NameToSystemId("aea_clone_crime"), shipManager, sysInfo)
    end
    return Defines.Chain.CONTINUE
end)
