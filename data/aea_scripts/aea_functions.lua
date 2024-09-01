mods.aea = {}

-----------------------
-- UTILITY FUNCTIONS --
-----------------------

-- Get a table for a userdata value by name
local function userdata_table(userdata, tableName)
    if not userdata.table[tableName] then userdata.table[tableName] = {} end
    return userdata.table[tableName]
end

local function get_random_point_in_radius(center, radius)
    r = radius * math.sqrt(math.random())
    theta = math.random() * 2 * math.pi
    return Hyperspace.Pointf(center.x + r * math.cos(theta), center.y + r * math.sin(theta))
end

local function get_point_local_offset(original, target, offsetForwards, offsetRight)
    local alpha = math.atan((original.y-target.y), (original.x-target.x))
    --print(alpha)
    local newX = original.x - (offsetForwards * math.cos(alpha)) - (offsetRight * math.cos(alpha+math.rad(90)))
    --print(newX)
    local newY = original.y - (offsetForwards * math.sin(alpha)) - (offsetRight * math.sin(alpha+math.rad(90)))
    --print(newY)
    return Hyperspace.Pointf(newX, newY)
end

local function vter(cvec)
    local i = -1
    local n = cvec:size()
    return function()
        i = i + 1
        if i < n then return cvec[i] end
    end
end

-- Find ID of a room at the given location
local function get_room_at_location(shipManager, location, includeWalls)
    return Hyperspace.ShipGraph.GetShipInfo(shipManager.iShipId):GetSelectedRoom(location.x, location.y, includeWalls)
end

-- Returns a table of all crew belonging to the given ship on the room tile at the given point
local function get_ship_crew_point(shipManager, x, y, maxCount)
    res = {}
    x = x//35
    y = y//35
    for crewmem in vter(shipManager.vCrewList) do
        if crewmem.iShipId == shipManager.iShipId and x == crewmem.x//35 and y == crewmem.y//35 then
            table.insert(res, crewmem)
            if maxCount and #res >= maxCount then
                return res
            end
        end
    end
    return res
end

local function get_ship_crew_room(shipManager, roomId)
    local radCrewList = {}
    for crewmem in vter(shipManager.vCrewList) do
        if crewmem.iShipId == shipManager.iShipId and crewmem.iRoomId == roomId then
            table.insert(radCrewList, crewmem)
        end
    end
    return radCrewList
end

-- written by kokoro
local function convertMousePositionToEnemyShipPosition(mousePosition)
    local cApp = Hyperspace.Global.GetInstance():GetCApp()
    local combatControl = cApp.gui.combatControl
    local position = 0--combatControl.position -- not exposed yet
    local targetPosition = combatControl.targetPosition
    local enemyShipOriginX = position.x + targetPosition.x
    local enemyShipOriginY = position.y + targetPosition.y
    return Hyperspace.Point(mousePosition.x - enemyShipOriginX, mousePosition.y - enemyShipOriginY)
end

-- Returns a table where the indices are the IDs of all rooms adjacent to the given room
-- and the values are the rooms' coordinates
local function get_adjacent_rooms(shipId, roomId, diagonals)
    local shipGraph = Hyperspace.ShipGraph.GetShipInfo(shipId)
    local roomShape = shipGraph:GetRoomShape(roomId)
    local adjacentRooms = {}
    local currentRoom = nil
    local function check_for_room(x, y)
        currentRoom = shipGraph:GetSelectedRoom(x, y, false)
        if currentRoom > -1 and not adjacentRooms[currentRoom] then
            adjacentRooms[currentRoom] = Hyperspace.Pointf(x, y)
        end
    end
    for offset = 0, roomShape.w - 35, 35 do
        check_for_room(roomShape.x + offset + 17, roomShape.y - 17)
        check_for_room(roomShape.x + offset + 17, roomShape.y + roomShape.h + 17)
    end
    for offset = 0, roomShape.h - 35, 35 do
        check_for_room(roomShape.x - 17,               roomShape.y + offset + 17)
        check_for_room(roomShape.x + roomShape.w + 17, roomShape.y + offset + 17)
    end
    if diagonals then
        check_for_room(roomShape.x - 17,               roomShape.y - 17)
        check_for_room(roomShape.x + roomShape.w + 17, roomShape.y - 17)
        check_for_room(roomShape.x + roomShape.w + 17, roomShape.y + roomShape.h + 17)
        check_for_room(roomShape.x - 17,               roomShape.y + roomShape.h + 17)
    end
    return adjacentRooms
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

function round(num, numDecimalPlaces)
  local mult = 10^(numDecimalPlaces or 0)
  return math.floor(num * mult + 0.5) / mult
end

local spawn_temp_drone = mods.multiverse.spawn_temp_drone
--[[
int iDamage;
int iShieldPiercing;
int fireChance;
int breachChance;
int stunChance;
int iIonDamage;
int iSystemDamage;
int iPersDamage;
bool bHullBuster;
int ownerId;
int selfId;
bool bLockdown;
bool crystalShard;
bool bFriendlyFire;
int iStun;]]--

--[[script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	if shipManager:HasSystem(3) and Hyperspace.Global.GetInstance():GetCApp().world.bStartedGame then
		for weapon in vter(shipManager:GetWeaponList()) do 
            
        end 
	end
end)]]--

script.on_internal_event(Defines.InternalEvents.PROJECTILE_FIRE, function(projectile, weapon)
	if weapon.blueprint then
	    if weapon.blueprint.name == "AEA_LASER_ACID_SUPER" or weapon.blueprint.name == "AEA_LASER_ACID_SUPER_ENEMY" then
	    	local shipManager = Hyperspace.ships(1-projectile.ownerId)
	        for system in vter(shipManager.vSystemList) do
	            local roomId = system.roomId
	            local roomLoc = shipManager:GetRoomCenter(roomId)

	        	local spaceManager = Hyperspace.Global.GetInstance():GetCApp().world.space
	            local laser = spaceManager:CreateLaserBlast(
	                weapon.blueprint,
	                projectile.position,
	                projectile.currentSpace,
	                projectile.ownerId,
	                roomLoc,
	                projectile.destinationSpace,
	                projectile.heading)
	            laser.entryAngle = projectile.entryAngle
	        end
	        projectile:Kill()
	    end
	end
end)

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	if shipManager:HasAugmentation("AEA_ACID_O2SYS") > 0 and shipManager:HasSystem(2) then
		local oxygen = shipManager.oxygenSystem
		local refill = oxygen:GetRefillSpeed()

		--print("refill speed: "..tostring(refill))
		local shipGraph = Hyperspace.ShipGraph.GetShipInfo(shipManager.iShipId)
		local wipe_p = false
		if not Hyperspace.Global.GetInstance():GetCApp().world.bStartedGame then
			wipe_p = true
		end
		if refill > 0 then
			for id = 0, shipGraph:RoomCount(), 1 do
				--local id = room.iRoomId
				--print(id)
				oxygen:ModifyRoomOxygen(id, (-1*refill) - (5*(Hyperspace.FPS.SpeedFactor/16)))
				if wipe_p then
					oxygen:EmptyOxygen(id)
				end
			end
		end
	elseif shipManager:HasAugmentation("AEA_ACID_O2SYS_ENEMY") > 0 and shipManager:HasSystem(2) then
		local oxygen = shipManager.oxygenSystem
		local refill = oxygen:GetRefillSpeed()
		--print("refill speed: "..tostring(refill))
		local shipGraph = Hyperspace.ShipGraph.GetShipInfo(shipManager.iShipId)
		local wipe_e = false
		if refill > 0 then
			for id = 0, shipGraph:RoomCount(), 1 do
				--local id = room.iRoomId
				--print(id)
				oxygen:ModifyRoomOxygen(id, (-1*refill) - (2*(Hyperspace.FPS.SpeedFactor/16)))
			end
		end
	end
end)

local acidBombPrint = Hyperspace.Blueprints:GetWeaponBlueprint("AEA_BOMB_INVIS_ACID_1")
--local acidBombPrint = Hyperspace.Blueprints:GetWeaponBlueprint("BOMB_1")
function acidTrigger()
	if Hyperspace.ships.player then
	    local spaceManager = Hyperspace.Global.GetInstance():GetCApp().world.space
	    local shipManager = Hyperspace.ships.player

	    local empty_rooms = {}
	    local has_empty_rooms = false
	    local empty_rooms_size = 0
	    for room in vter(shipManager.ship.vRoomList) do
	    	local id = room.iRoomId
	    	if shipManager:GetSystemInRoom(id) == nil then
	    		has_empty_rooms = true
	    		empty_rooms_size = empty_rooms_size + 1
	    		table.insert(empty_rooms, id)
	    	end
	    end
	    if has_empty_rooms then
	    	local acidBombInvis = spaceManager:CreateBomb(
		        acidBombPrint,
		        math.abs(shipManager.iShipId-1),
		        shipManager:GetRoomCenter(empty_rooms[math.random(1,empty_rooms_size)]),
		        shipManager.iShipId)
	    end
	end
	if Hyperspace.ships.enemy then
	    local spaceManager = Hyperspace.Global.GetInstance():GetCApp().world.space
	    local shipManager = Hyperspace.ships.enemy
	    for room in vter(shipManager.ship.vRoomList) do
	    	local id = room.iRoomId
	    	if shipManager:GetSystemInRoom(id) == nil then
	    		local acidBombInvis = spaceManager:CreateBomb(
			        acidBombPrint,
			        math.abs(shipManager.iShipId-1),
			        shipManager:GetRoomCenter(id),
			        shipManager.iShipId)
	    		break
	    	end
	    end
	end
end

--"stars/nebula_large_c.png"
--"stars_acid/acid_nebula_large_c.png"
local nebulaClouds = {}

local rows = 4
local columns = 5

local xJump = 350
local yJump = 230

local minScale = 1.5
local maxScaleRandom = 2
local scaleIncrease = 0.25

local lifeTime = 10
local fadeInTime = 1
local fadeOutTime = 1

local minOpacity = 0.9
local maxOpacity = 1

local imageString = "stars_acid/nebula_large_c.png"
local eventString = "NEBULA_ACIDIC"
local playerVar = "aea_acidic_nebula"

local warningString = "warnings/danger_aea_acidic.png"
local warningImage = Hyperspace.Resources:CreateImagePrimitiveString(warningString, 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false)
local warningX = 660
local warningY = 72
local warningSizeX = 60
local warningSizeY = 58
local warningText = "You're inside an Acidic nebula. Your sensors will not function and your empty rooms will be slowly breached at random by the Acidic clouds."

local initialPosX = (math.random() * 131072) % 131 - 65
local initialPosY = (math.random() * 131072) % 81 - 40

for k = 1,(rows * columns),1 do
	--print(k)
	--print("CLOUDS START: "..tostring(k))
	nebulaClouds[k] = {x = 0, y = 0, scale = 1, timerScale = 0, opacity = 1, revOp = 0, fade = 0, exists = 1}
	nebulaClouds[k+(rows * columns)] = {x = 0, y = 0, scale = 1, timerScale = 0, opacity = 1, revOp = 0, fade = 0, exists = 0}
	local cloud = nebulaClouds[k]

	cloud.x = xJump * ((k - 1) % columns)
	cloud.y = yJump * math.floor((k-1)/columns)

	cloud.scale = (math.random() * (maxScaleRandom - minScale)) + minScale
	cloud.timerScale = math.random() * lifeTime

	cloud.opacity = (math.random() * (maxOpacity - minOpacity)) + minOpacity
	cloud.revOp = math.random(0,1)
end

local acidTimer = 1
script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
	local commandGui = Hyperspace.Global.GetInstance():GetCApp().gui
	if Hyperspace.playerVariables[playerVar] == 1 and not (commandGui.bPaused or commandGui.event_pause or commandGui.menu_pause or commandGui.bAutoPaused or commandGui.touch_pause) then
		acidTimer = acidTimer - (Hyperspace.FPS.SpeedFactor/16)
		if acidTimer <= 0 then
			--print("ACID")
			acidTimer = (math.random() * 3) + 4
			acidTrigger()
		end
	end
end)

script.on_internal_event(Defines.InternalEvents.PRE_CREATE_CHOICEBOX, function(event)
    --print(string.sub(event.eventName, 0, 13))
    if string.sub(event.eventName, 0, string.len(eventString)) == eventString and Hyperspace.playerVariables[playerVar] == 0 then
        Hyperspace.playerVariables[playerVar] = 1
		initialPosX = (math.random() * 131072) % 131 - 65
		initialPosY = (math.random() * 131072) % 81 - 40
    end
end)

script.on_internal_event(Defines.InternalEvents.JUMP_ARRIVE, function(shipManager)
    Hyperspace.playerVariables[playerVar] = 0
end)

--[[script.on_init(function()
	if Hyperspace.playerVariables[playerVar] == 1 then
		log("RESET_NEBULA_A")
		local initialPosX = (math.random() * 131072) % 131 - 65
        local initialPosY = (math.random() * 131072) % 81 - 40
        for k = 1,(rows * columns),1 do
        	--print(k)
        	nebulaClouds[k] = {x = 0, y = 0, scale = 1, timerScale = 0, opacity = 1, revOp = 0, fade = 0, exists = 1, start = 1}
        	nebulaClouds[k+(rows * columns)] = {x = 0, y = 0, scale = 1, timerScale = 0, opacity = 1, revOp = 0, fade = 0, exists = 0, start = 0}
        	local cloud = nebulaClouds[k]

        	cloud.x = initialPosX + xJump * ((k - 1) % columns)
        	cloud.y = initialPosY + yJump * math.floor((k-1)/columns)

        	cloud.scale = (math.random() * (maxScaleRandom - minScale)) + minScale
    		cloud.timerScale = lifeTime - (math.random() * 0.1) - 0.05

        	cloud.opacity = (math.random() * (maxOpacity - minOpacity)) + minOpacity
    		cloud.revOp = math.random(0,1)
	    end
	end
end)]]

script.on_render_event(Defines.RenderEvents.LAYER_FOREGROUND, function() 
	if Hyperspace.Global.GetInstance():GetCApp().world.bStartedGame and Hyperspace.playerVariables[playerVar] == 1 and Hyperspace.Settings.lowend == false then
		--log("startLoop")
		for k, cloud in ipairs(nebulaClouds) do
			--print(tostring(k)..": "..tostring(cloud.exists))
			--print("k: "..tostring(k).." x: "..tostring(round(cloud.x,2)).." y: "..tostring(round(cloud.y,2)).." scale: "..tostring(round(cloud.scale,2)).." timerScale: "..tostring(round(cloud.timerScale,2)).." opacity: "..tostring(round(cloud.opacity,2)).." revOp: "..tostring(round(cloud.revOp,2)).." fade: "..tostring(round(cloud.fade,2)))
			if cloud.exists == 1 then
				--local colourTemp = Graphics.GL_Color(1, 1, 1, 1)
				local commandGui = Hyperspace.Global.GetInstance():GetCApp().gui
	            --[[if (commandGui.bPaused or commandGui.event_pause) then
	            	colourTemp = Graphics.GL_Color(0.5, 0.5, 0.5, 1)
	            end]]
				local cloudImageTemp = Hyperspace.Resources:CreateImagePrimitiveString(imageString, -256, -200, 0, Graphics.GL_Color(1, 1, 1, 1), cloud.opacity, false)
		        
		        Graphics.CSurface.GL_PushMatrix()
		        Graphics.CSurface.GL_Translate((cloud.x + initialPosX),(cloud.y + initialPosX),0)
	            Graphics.CSurface.GL_Scale(cloud.scale,cloud.scale,0)

		        if (commandGui.bPaused or commandGui.event_pause) then
		        	Graphics.CSurface.GL_SetColorTint(Graphics.GL_Color(0.5, 0.5, 0.5, 1))
		        end
		        Graphics.CSurface.GL_RenderPrimitive(cloudImageTemp)
	        	Graphics.CSurface.GL_RemoveColorTint()
		        Graphics.CSurface.GL_PopMatrix()
		        Graphics.CSurface.GL_DestroyPrimitive(cloudImageTemp)

		        if not (commandGui.bPaused or commandGui.event_pause) then
		        	--print("k: "..tostring(k).." x: "..tostring(round(cloud.x,2)).." y: "..tostring(round(cloud.y,2)).." scale: "..tostring(round(cloud.scale,2)).." timerScale: "..tostring(round(cloud.timerScale,2)).." opacity: "..tostring(round(cloud.opacity,2)).." revOp: "..tostring(round(cloud.revOp,2)).." fade: "..tostring(round(cloud.fade,2)))
			        cloud.timerScale = cloud.timerScale + (Hyperspace.FPS.SpeedFactor/16)
			        cloud.scale = cloud.scale + ((scaleIncrease/lifeTime) * (Hyperspace.FPS.SpeedFactor/16))
			        if cloud.timerScale >= lifeTime then
	        			--print("Remove Cloud at: "..tostring(k))
		        		cloud.exists = 0
		        	end

			        if cloud.timerScale >= (lifeTime - fadeOutTime) then
			        	cloud.opacity = math.max(cloud.opacity - (0.95 * (Hyperspace.FPS.SpeedFactor/16)), 0.05)
			        	if cloud.fade == 0 then
				        	cloud.fade = 1
				        	for k2, cloudNew in ipairs(nebulaClouds) do
				        		--print("Check")
				        		if cloudNew.exists == 0 then
				        			--print("New Cloud at: "..tostring(k2))
				        			nebulaClouds[k2] = createCloud(cloud.x, cloud.y)
				        			
				        			break
				        		end
				        	end
				        	--nebulaClouds[k+20] = createCloud(cloud.x, cloud.y)
				        	--table.insert(nebulaClouds, createCloud(cloud.x, cloud.y))
				        end
			        elseif cloud.timerScale < fadeInTime then
			        	cloud.opacity = math.min(cloud.opacity + (0.95 * (Hyperspace.FPS.SpeedFactor/16)), 1)

			        elseif cloud.revOp == 0 then
			        	cloud.opacity = math.min(cloud.opacity + (0.1 * (Hyperspace.FPS.SpeedFactor/16)), 1)
			        	if cloud.opacity >= 1 then
			        		cloud.revOp = 1
			        		--print("reverse opacity to negative: "..tostring(k))
			        	end
			        else
			        	cloud.opacity = cloud.opacity - (0.1 * (Hyperspace.FPS.SpeedFactor/16))
			        	if cloud.opacity <= 0.9 then
			        		cloud.revOp = 0
			        		--print("reverse opacity to positive: "..tostring(k))
			        	end
			        end

			    end
		    end
	    end
	    
    end
end, function() end)
script.on_render_event(Defines.RenderEvents.MOUSE_CONTROL, function()
	local commandGui = Hyperspace.Global.GetInstance():GetCApp().gui
	if Hyperspace.Global.GetInstance():GetCApp().world.bStartedGame and Hyperspace.playerVariables[playerVar] == 1 and not (commandGui.menu_pause or commandGui.event_pause) then
		Graphics.CSurface.GL_PushMatrix()
        Graphics.CSurface.GL_Translate(warningX,warningY,0)
        Graphics.CSurface.GL_RenderPrimitive(warningImage)
        Graphics.CSurface.GL_PopMatrix()
        local mousePos = Hyperspace.Mouse.position
        --[[print("START")
        print(mousePos.x >= warningX)
        print(mousePos.x < (warningX + warningSizeX))
        print(mousePos.y >= warningY)
        print(mousePos.y < (warningY + warningSizeY))]]
        if mousePos.x >= warningX and mousePos.x < (warningX + warningSizeX) and mousePos.y >= warningY and mousePos.y < (warningY + warningSizeY) then
        	--print(warningText)
			Hyperspace.Mouse.tooltip = warningText
        end
    end
end, function() end)

function createCloud(x, y)
	local cloudTemp = {x = 0, y = 0, scale = 1.5, timerScale = 0, opacity = 1, revOp = 0, fade = 0, exists = 1}
	cloudTemp.x = x
	cloudTemp.y = y

	cloudTemp.scale = (math.random() * (maxScaleRandom - minScale)) + minScale
	cloudTemp.timerScale = 0

	cloudTemp.opacity = 0.05
	cloudTemp.revOp = math.random(0,1)
	return cloudTemp
end


-----------------------------------------
-----------------------------------------
--------------END OF ACIDIC--------------
-----------------------------------------
-----------------------------------------

script.on_internal_event(Defines.InternalEvents.DRONE_COLLISION, function(drone, projectile, damage, response)
	if projectile.extend.name == "AEA_LASER_NECRO_DRONE" then
		local ship = Hyperspace.ships(projectile.ownerId)
        local otherShip = Hyperspace.ships(1 - projectile.ownerId)
        if ship and otherShip then
            local drone2 = spawn_temp_drone(
                drone.blueprint,
                ship,
                otherShip,
            	nil,
                3,
                projectile.position)
            userdata_table(drone2, "mods.mv.droneStuff").clearOnJump = true
        end
	end
end)

script.on_internal_event(Defines.InternalEvents.PROJECTILE_COLLISION, function(thisProjectile, projectile, damage, response)
	if projectile.extend.name == "AEA_LASER_NECRO_DRONE" then
		local blueprint = Hyperspace.Blueprints:GetWeaponBlueprint(thisProjectile.extend.name)
		local returnShip = Hyperspace.ships(thisProjectile.ownerId)
		local pType = blueprint.typeName
		if pType == "MISSILES" and returnShip then 
        	local spaceManager = Hyperspace.Global.GetInstance():GetCApp().world.space
        	local missile = spaceManager:CreateMissile(
        		blueprint,
        		thisProjectile.position,
        		thisProjectile.currentSpace,
        		(1 - thisProjectile.ownerId),
        		returnShip:GetRandomRoomCenter(),
        		thisProjectile.ownerId,
        		thisProjectile.heading)
        end
	end
end)
local droneTable = {}

script.on_internal_event(Defines.InternalEvents.DRONE_COLLISION, function(drone, projectile, damage, response)
	if drone.blueprint.name == "AEA_COMBAT_NECRO_1_LASER" or drone.blueprint.name == "AEA_COMBAT_NECRO_1_BEAM" then
		local ship = Hyperspace.ships(drone.iShipId)
		local otherShip = Hyperspace.ships(1 - drone.iShipId)
		local droneBlueprint = Hyperspace.Blueprints:GetDroneBlueprint(drone.blueprint.name.."_TEMP")
		if ship and otherShip and not droneTable[drone.selfId] then
            local drone2 = spawn_temp_drone(
                droneBlueprint,
                ship,
                otherShip,
            	nil,
                3,
                drone.currentLocation)
            userdata_table(drone2, "mods.mv.droneStuff").clearOnJump = true
            local drone3 = spawn_temp_drone(
                droneBlueprint,
                ship,
                otherShip,
            	nil,
                3,
                drone.currentLocation)
            userdata_table(drone3, "mods.mv.droneStuff").clearOnJump = true
            droneTable[drone.selfId] = true
			drone:BlowUp(false)
        end
    end

    if drone.blueprint.name == "AEA_COMBAT_NECRO_2_LASER" or drone.blueprint.name == "AEA_COMBAT_NECRO_2_BEAM" then
		local ship = Hyperspace.ships(drone.iShipId)
		local otherShip = Hyperspace.ships(1 - drone.iShipId)
		local droneBlueprint = Hyperspace.Blueprints:GetDroneBlueprint("AEA_COMBAT_NECRO_1_LASER_TEMP")
		if drone.blueprint.name == "AEA_COMBAT_NECRO_2_BEAM" then
			droneBlueprint = Hyperspace.Blueprints:GetDroneBlueprint("AEA_COMBAT_NECRO_1_BEAM_TEMP")
		end
		if ship and otherShip and not droneTable[drone.selfId] then
            local drone2 = spawn_temp_drone(
                droneBlueprint,
                ship,
                otherShip,
            	nil,
                3,
                drone.currentLocation)
            userdata_table(drone2, "mods.mv.droneStuff").clearOnJump = true
            local drone3 = spawn_temp_drone(
                droneBlueprint,
                ship,
                otherShip,
            	nil,
                3,
                drone.currentLocation)
            userdata_table(drone3, "mods.mv.droneStuff").clearOnJump = true
            local drone4 = spawn_temp_drone(
                droneBlueprint,
                ship,
                otherShip,
            	nil,
                3,
                drone.currentLocation)
            userdata_table(drone4, "mods.mv.droneStuff").clearOnJump = true
            droneTable[drone.selfId] = true
			drone:BlowUp(false)
        end
    end
end)

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	if shipManager:HasSystem(4) then
		for drone in vter(shipManager.droneSystem.drones) do
			if drone.blueprint.name == "AEA_COMBAT_NECRO_1_LASER" or drone.blueprint.name == "AEA_COMBAT_NECRO_1_BEAM" then
				local droneBlueprint = Hyperspace.Blueprints:GetDroneBlueprint(drone.blueprint.name.."_TEMP")
				local ship = shipManager
				local otherShip = Hyperspace.ships(1 - shipManager.iShipId)
				if drone.deployed and not drone.powered and not drone.bDead and not droneTable[drone.selfId] then
					local drone2 = spawn_temp_drone(
		                droneBlueprint,
		                ship,
		                otherShip,
		            	nil,
		                3,
		                drone.currentLocation)
		            userdata_table(drone2, "mods.mv.droneStuff").clearOnJump = true
		            local drone3 = spawn_temp_drone(
		                droneBlueprint,
		                ship,
		                otherShip,
		            	nil,
		                3,
		                drone.currentLocation)
		            userdata_table(drone3, "mods.mv.droneStuff").clearOnJump = true
					--print("kill")
					drone:BlowUp(false)
            		droneTable[drone.selfId] = true
		        end
		        if drone.destroyedTimer > 0.5 and drone.destroyedTimer < 1 then
		        	droneTable[drone.selfId] = nil
		        end
			end
			if drone.blueprint.name == "AEA_COMBAT_NECRO_2_LASER" or drone.blueprint.name == "AEA_COMBAT_NECRO_2_BEAM" then
				local droneBlueprint = Hyperspace.Blueprints:GetDroneBlueprint("AEA_COMBAT_NECRO_1_LASER_TEMP")
				if drone.blueprint.name == "AEA_COMBAT_NECRO_2_BEAM" then
					droneBlueprint = Hyperspace.Blueprints:GetDroneBlueprint("AEA_COMBAT_NECRO_1_BEAM_TEMP")
				end
				local ship = shipManager
				local otherShip = Hyperspace.ships(1 - shipManager.iShipId)
				if drone.deployed and not drone.powered and not drone.bDead and not droneTable[drone.selfId] then
					local drone2 = spawn_temp_drone(
		                droneBlueprint,
		                ship,
		                otherShip,
		            	nil,
		                3,
		                drone.currentLocation)
		            userdata_table(drone2, "mods.mv.droneStuff").clearOnJump = true
		            local drone3 = spawn_temp_drone(
		                droneBlueprint,
		                ship,
		                otherShip,
		            	nil,
		                3,
		                drone.currentLocation)
		            userdata_table(drone3, "mods.mv.droneStuff").clearOnJump = true
		            local drone4 = spawn_temp_drone(
		                droneBlueprint,
		                ship,
		                otherShip,
		            	nil,
		                3,
		                drone.currentLocation)
		            userdata_table(drone4, "mods.mv.droneStuff").clearOnJump = true
					--print("kill")
					drone:BlowUp(false)
            		droneTable[drone.selfId] = true
		        end
		        if drone.destroyedTimer > 0.5 and drone.destroyedTimer < 1 then
		        	droneTable[drone.selfId] = nil
		        end
			end
		end
	end
end)

script.on_internal_event(Defines.InternalEvents.JUMP_ARRIVE, function(shipManager)
	droneTable = {}
end)

local zombieTable = {}

local necro_crew = {}
necro_crew["aea_necro_engi"] = true
necro_crew["aea_necro_lich"] = true
necro_crew["aea_necro_king"] = true

--script.on_internal_event(Defines.InternalEvents.POWER_TOOLTIP, function(power, powerState)
	--[[local crew = necro_crew[power.crew.type]
	if crew and power.def.cooldown == 20 and powerState == 1 then
		local crewTable = userdata_table(crewmem, "mods.aea.necro")
		local powerText = power.def.tooltip:GetText().."\n-Current Body: "..crewTable.lastKillName
		return powerText, false
	end]]
	--return power.def.tooltip:GetText(), false
--end)

--script.on_internal_event(Defines.InternalEvents.POWER_TOOLTIP, function()
	--return Defines.Chain.CONTINUE, false, "powerState"
--end)

local dead_crew = {}

script.on_internal_event(Defines.InternalEvents.CREW_LOOP, function(crewmem)
	if crewmem.health.first <= 0 and not (dead_crew[crewmem.extend.selfId]) and not crewmem:IsDrone() then
		--print("CREW DYING: "..tostring(crewmem.type))
		dead_crew[crewmem.extend.selfId] = true
		local crewShip = Hyperspace.ships(crewmem.currentShipId)
		local hasEngiInRoom = false
		for crew in vter(crewShip.vCrewList) do
			local crew_necro = necro_crew[crew.type]
			if crew.iShipId ~= crewmem.iShipId and crew.currentSlot.slotId == crewmem.currentSlot.slotId and crew.iRoomId == crewmem.iRoomId and crew_necro then
				--print("HAS NECRO ENGI IN SQUARE")
				local crewTable = userdata_table(crew, "mods.aea.necro")
				crewTable.lastKill = crewmem.type
				crewTable.lastKillRace = crewmem.blueprint.desc.title.data
				crewTable.lastKillName = crewmem.blueprint:GetNameShort()
				hasEngiInRoom = true
			elseif crew.iShipId ~= crewmem.iShipId and crew.iRoomId == crewmem.iRoomId and crew_necro then
				--print("HAS NECRO ENGI IN ROOM")
				hasEngiInRoom = true
			elseif crew.type == "aea_necro_king" and crew.iShipId ~= crewmem.iShipId then
				hasEngiInRoom = true
			end
		end
		if hasEngiInRoom and crewmem.iShipId == 1 then
			--print("ADD ONE")
            Hyperspace.Sounds:PlaySoundMix("levelup", -1, false)
			Hyperspace.playerVariables.aea_necro_ability_points = Hyperspace.playerVariables.aea_necro_ability_points + 1
		end
	elseif crewmem.health.first > 0 and dead_crew[crewmem.extend.selfId] then
		dead_crew[crewmem.extend.selfId] = nil
	end
	if zombieTable[crewmem.extend.selfId] then
		local textString = Hyperspace.TextString()
		textString.data = "ZOMBIE: "..tostring(math.floor(zombieTable[crewmem.extend.selfId]))
		crewmem:SetName(textString, true)
		--print("ZOMBIE TIMER: "..tostring(zombieTable[crewmem.extend.selfId]))
		zombieTable[crewmem.extend.selfId] = zombieTable[crewmem.extend.selfId] - (Hyperspace.FPS.SpeedFactor/16)
		if zombieTable[crewmem.extend.selfId] < 0 then
			--print("ZOMBIE DEATH")
			zombieTable[crewmem.extend.selfId] = nil
			crewmem:Kill(true)
		end
	end
end)

local def0XCREWSLOT = Hyperspace.StatBoostDefinition()
def0XCREWSLOT.stat = Hyperspace.CrewStat.CREW_SLOTS
def0XCREWSLOT.value = true
def0XCREWSLOT.boostType = Hyperspace.StatBoostDefinition.BoostType.MULT
def0XCREWSLOT.boostSource = Hyperspace.StatBoostDefinition.BoostSource.AUGMENT
def0XCREWSLOT.shipTarget = Hyperspace.StatBoostDefinition.ShipTarget.ALL
def0XCREWSLOT.crewTarget = Hyperspace.StatBoostDefinition.CrewTarget.ALL
def0XCREWSLOT.duration = 1
def0XCREWSLOT.priority = 999999
def0XCREWSLOT.realBoostId = Hyperspace.StatBoostDefinition.statBoostDefs:size()
Hyperspace.StatBoostDefinition.statBoostDefs:push_back(def0XCREWSLOT)

local defNOCLONE = Hyperspace.StatBoostDefinition()
defNOCLONE.stat = Hyperspace.CrewStat.NO_CLONE
defNOCLONE.value = true
defNOCLONE.boostType = Hyperspace.StatBoostDefinition.BoostType.SET
defNOCLONE.boostSource = Hyperspace.StatBoostDefinition.BoostSource.AUGMENT
defNOCLONE.shipTarget = Hyperspace.StatBoostDefinition.ShipTarget.ALL
defNOCLONE.crewTarget = Hyperspace.StatBoostDefinition.CrewTarget.ALL
defNOCLONE.duration = 99
defNOCLONE.priority = 9999
defNOCLONE.realBoostId = Hyperspace.StatBoostDefinition.statBoostDefs:size()
Hyperspace.StatBoostDefinition.statBoostDefs:push_back(defNOCLONE)

local defNOSLOT = Hyperspace.StatBoostDefinition()
defNOSLOT.stat = Hyperspace.CrewStat.NO_SLOT
defNOSLOT.value = true
defNOSLOT.boostType = Hyperspace.StatBoostDefinition.BoostType.SET
defNOSLOT.boostSource = Hyperspace.StatBoostDefinition.BoostSource.AUGMENT
defNOSLOT.shipTarget = Hyperspace.StatBoostDefinition.ShipTarget.ALL
defNOSLOT.crewTarget = Hyperspace.StatBoostDefinition.CrewTarget.ALL
defNOSLOT.duration = 99
defNOSLOT.priority = 9999
defNOSLOT.realBoostId = Hyperspace.StatBoostDefinition.statBoostDefs:size()
Hyperspace.StatBoostDefinition.statBoostDefs:push_back(defNOSLOT)

local defRMHP = Hyperspace.StatBoostDefinition()
defRMHP.stat = Hyperspace.CrewStat.MAX_HEALTH
defRMHP.amount = 0.75
defRMHP.boostType = Hyperspace.StatBoostDefinition.BoostType.MULT
defRMHP.boostSource = Hyperspace.StatBoostDefinition.BoostSource.AUGMENT
defRMHP.shipTarget = Hyperspace.StatBoostDefinition.ShipTarget.ALL
defRMHP.crewTarget = Hyperspace.StatBoostDefinition.CrewTarget.ALL
defRMHP.duration = 99
defRMHP.priority = 9999
defRMHP.realBoostId = Hyperspace.StatBoostDefinition.statBoostDefs:size()
Hyperspace.StatBoostDefinition.statBoostDefs:push_back(defRMHP)

local defNOWARNING = Hyperspace.StatBoostDefinition()
defNOWARNING.stat = Hyperspace.CrewStat.NO_WARNING
defNOWARNING.value = true
defNOWARNING.boostType = Hyperspace.StatBoostDefinition.BoostType.SET
defNOWARNING.boostSource = Hyperspace.StatBoostDefinition.BoostSource.AUGMENT
defNOWARNING.shipTarget = Hyperspace.StatBoostDefinition.ShipTarget.ALL
defNOWARNING.crewTarget = Hyperspace.StatBoostDefinition.CrewTarget.ALL
defNOWARNING.duration = 99
defNOWARNING.priority = 9999
defNOWARNING.realBoostId = Hyperspace.StatBoostDefinition.statBoostDefs:size()
Hyperspace.StatBoostDefinition.statBoostDefs:push_back(defNOWARNING)

local defRDMP = Hyperspace.StatBoostDefinition()
defRDMP.stat = Hyperspace.CrewStat.DAMAGE_MULTIPLIER
defRDMP.amount = 0.75
defRDMP.boostType = Hyperspace.StatBoostDefinition.BoostType.MULT
defRDMP.boostSource = Hyperspace.StatBoostDefinition.BoostSource.AUGMENT
defRDMP.shipTarget = Hyperspace.StatBoostDefinition.ShipTarget.ALL
defRDMP.crewTarget = Hyperspace.StatBoostDefinition.CrewTarget.ALL
defRDMP.duration = 99
defRDMP.priority = 9999
defRDMP.realBoostId = Hyperspace.StatBoostDefinition.statBoostDefs:size()
Hyperspace.StatBoostDefinition.statBoostDefs:push_back(defRDMP)

local defHMHP = Hyperspace.StatBoostDefinition()
defHMHP.stat = Hyperspace.CrewStat.MAX_HEALTH
defHMHP.amount = 0.5
defHMHP.boostType = Hyperspace.StatBoostDefinition.BoostType.MULT
defHMHP.boostSource = Hyperspace.StatBoostDefinition.BoostSource.AUGMENT
defHMHP.shipTarget = Hyperspace.StatBoostDefinition.ShipTarget.ALL
defHMHP.crewTarget = Hyperspace.StatBoostDefinition.CrewTarget.ALL
defHMHP.duration = 99
defHMHP.priority = 9999
defHMHP.realBoostId = Hyperspace.StatBoostDefinition.statBoostDefs:size()
Hyperspace.StatBoostDefinition.statBoostDefs:push_back(defHMHP)

local defHDMP = Hyperspace.StatBoostDefinition()
defHDMP.stat = Hyperspace.CrewStat.DAMAGE_MULTIPLIER
defHDMP.amount = 0.5
defHDMP.boostType = Hyperspace.StatBoostDefinition.BoostType.MULT
defHDMP.boostSource = Hyperspace.StatBoostDefinition.BoostSource.AUGMENT
defHDMP.shipTarget = Hyperspace.StatBoostDefinition.ShipTarget.ALL
defHDMP.crewTarget = Hyperspace.StatBoostDefinition.CrewTarget.ALL
defHDMP.duration = 99
defHDMP.priority = 9999
defHDMP.realBoostId = Hyperspace.StatBoostDefinition.statBoostDefs:size()
Hyperspace.StatBoostDefinition.statBoostDefs:push_back(defHDMP)

script.on_internal_event(Defines.InternalEvents.POWER_READY, function(power, powerState)
	local crew = necro_crew[power.crew.type]
	local crewmem = power.crew
	if crew and crewmem.iShipId == 0 and (power.powerCooldown.second == 20 or power.powerCooldown.second == 2) then
		local crewTable = userdata_table(crewmem, "mods.aea.necro")
		if not (Hyperspace.playerVariables.aea_necro_ability_points > 0 and crewTable.lastKill) then
			powerState = 22
		end
		if crewmem.bMindControlled then
			powerState = 22
		end
	end
	if crew and crewmem.iShipId == 0 and power.powerCooldown.second == 60 then
		local crewTable = userdata_table(crewmem, "mods.aea.necro")
		if not (Hyperspace.playerVariables.aea_necro_ability_points > 4 and crewTable.lastKill) then
			powerState = 22
		end
		if crewmem.bMindControlled then
			powerState = 22
		end
	end
	if crew and crewmem.iShipId == 0 and power.powerCooldown.second == 30 then
		local crewTable = userdata_table(crewmem, "mods.aea.necro")
		if not (Hyperspace.playerVariables.aea_necro_ability_points > 1) then
			powerState = 22
		end
		if crewmem.bMindControlled then
			powerState = 22
		end
	end
	if crew and crewmem.iShipId == 1 and crewmem.bMindControlled then
		powerState = 22
	end
	return Defines.Chain.CONTINUE, powerState
end)

enemyResurrections = RandomList:New {"human", "rebel", "rock", "zoltan", "orchid", "mantis", "engi"}

script.on_internal_event(Defines.InternalEvents.DAMAGE_BEAM, function(shipManager, projectile, location, damage, realNewTile, beamHitType)
    if projectile.extend.name == "AEA_BEAM_NECRO_1" and realNewTile then
    	local playerShip = Hyperspace.ships.player
		local enemyShip = Hyperspace.ships.enemy
		for playerCrew in vter(playerShip.vCrewList) do
			if playerCrew.iShipId == 0 then
				Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(def0XCREWSLOT), playerCrew)
			end
		end
		for playerCrew in vter(enemyShip.vCrewList) do
			if playerCrew.iShipId == 0 then
				Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(def0XCREWSLOT), playerCrew)
			end
		end
        for i, crewmem in ipairs(get_ship_crew_point(shipManager, location.x, location.y)) do
            if not crewmem:IsDrone() and (not zombieTable[crewmem.extend.selfId]) then
                local rCrew = crewmem.type
                local crewShip = Hyperspace.ships(crewmem.currentShipId)
				local intruder = true
				if crewmem.intruder then
					intruder = false
				end
				local slot = Hyperspace.ShipGraph.GetShipInfo(crewShip.iShipId):GetClosestSlot(crewmem:GetLocation(), crewShip.iShipId, intruder)
				local zombie = crewShip:AddCrewMemberFromString("Zombie", rCrew, intruder, slot.roomId, true, true)
				Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(defNOCLONE), zombie)
				Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(defNOSLOT), zombie)
				Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(defHMHP), zombie)
				Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(defNOWARNING), zombie)
				Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(defHDMP), zombie)
				zombieTable[zombie.extend.selfId] = 15
            end
        end
    end
    return Defines.Chain.CONTINUE, beamHitType
end)


script.on_internal_event(Defines.InternalEvents.ACTIVATE_POWER, function(power, shipManager)
	local crew = necro_crew[power.crew.type]
	local crewmem = power.crew
	if crew and crewmem.iShipId == 0 and (power.powerCooldown.second == 20 or power.powerCooldown.second == 2) and (not crewmem.bMindControlled) then
		--print("RESURRECT")
		local crewTable = userdata_table(crewmem, "mods.aea.necro")
		if Hyperspace.playerVariables.aea_necro_ability_points > 0 and crewTable.lastKill then
			local playerShip = Hyperspace.ships.player
			local enemyShip = Hyperspace.ships.enemy
			for playerCrew in vter(playerShip.vCrewList) do
				if playerCrew.iShipId == 0 then
					Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(def0XCREWSLOT), playerCrew)
				end
			end
			for playerCrew in vter(enemyShip.vCrewList) do
				if playerCrew.iShipId == 0 then
					Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(def0XCREWSLOT), playerCrew)
				end
			end
			Hyperspace.playerVariables.aea_necro_ability_points = Hyperspace.playerVariables.aea_necro_ability_points - 1
			local rCrew = crewTable.lastKill
			local crewShip = Hyperspace.ships(crewmem.currentShipId)
			local intruder = false
			if crewmem.intruder then
				intruder = true
			end
			local slot = Hyperspace.ShipGraph.GetShipInfo(crewShip.iShipId):GetClosestSlot(crewmem:GetLocation(), crewShip.iShipId, intruder)
			local zombie = crewShip:AddCrewMemberFromString("Zombie", rCrew, intruder, slot.roomId, true, true)
			Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(defNOCLONE), zombie)
			Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(defNOSLOT), zombie)
			--Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(defRMHP), zombie)
			Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(defNOWARNING), zombie)
			--Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(defRDMP), zombie)
			zombieTable[zombie.extend.selfId] = 90
		end
	elseif crew and power.powerCooldown.second == 20 and (not crewmem.bMindControlled) then
		local rCrew = enemyResurrections:GetItem()
		local crewShip = Hyperspace.ships(crewmem.currentShipId)
		local intruder = false
		if crewmem.intruder then
			intruder = true
		end
		local slot = Hyperspace.ShipGraph.GetShipInfo(crewShip.iShipId):GetClosestSlot(crewmem:GetLocation(), crewShip.iShipId, intruder)
		local zombie = crewShip:AddCrewMemberFromString("Zombie", rCrew, intruder, slot.roomId, true, true)
		Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(defNOCLONE), zombie)
		Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(defNOSLOT), zombie)
		Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(defHMHP), zombie)
		Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(defNOWARNING), zombie)
		Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(defHDMP), zombie)
		zombieTable[zombie.extend.selfId] = 20
	end


	if crew and crewmem.iShipId == 0 and power.powerCooldown.second == 30 and (not crewmem.bMindControlled) then
		--print("REND")
		local crewTable = userdata_table(crewmem, "mods.aea.necro")
		if Hyperspace.playerVariables.aea_necro_ability_points > 1 then
			Hyperspace.playerVariables.aea_necro_ability_points = Hyperspace.playerVariables.aea_necro_ability_points - 2
			local crewShip = Hyperspace.ships(crewmem.currentShipId)
			--print("before loop")
			local playerShip = Hyperspace.ships.player
			local enemyShip = Hyperspace.ships.enemy
			for playerCrew in vter(playerShip.vCrewList) do
				if playerCrew.iShipId == 0 then
					Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(def0XCREWSLOT), playerCrew)
				end
			end
			for playerCrew in vter(enemyShip.vCrewList) do
				if playerCrew.iShipId == 0 then
					Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(def0XCREWSLOT), playerCrew)
				end
			end
			for enemyCrew in vter(crewShip.vCrewList) do
				--print(enemyCrew.type)
				if enemyCrew.iShipId ~= crewmem.iShipId and enemyCrew.iRoomId == crewmem.iRoomId and (not zombieTable[enemyCrew.extend.selfId]) and not crewmem:IsDrone() then
					--print("REND LOOP CREW")
					local rCrew = enemyCrew.type
					local intruder = false
					if crewmem.intruder then
						intruder = true
					end
					local slot = Hyperspace.ShipGraph.GetShipInfo(crewShip.iShipId):GetClosestSlot(crewmem:GetLocation(), crewShip.iShipId, intruder)
					--print("CREATE ZOMBIE")
					local zombie = crewShip:AddCrewMemberFromString("Zombie", rCrew, intruder, slot.roomId, true, true)
					Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(defNOCLONE), zombie)
					Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(defNOSLOT), zombie)
					Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(defRMHP), zombie)
					Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(defNOWARNING), zombie)
					Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(defRDMP), zombie)
					zombieTable[zombie.extend.selfId] = 30
				end
			end
		end
	elseif crew and power.powerCooldown.second == 30 and (not crewmem.bMindControlled) then
		local crewShip = Hyperspace.ships(crewmem.currentShipId)
		for enemyCrew in vter(crewShip.vCrewList) do
			if enemyCrew.iShipId ~= crewmem.iShipId and enemyCrew.iRoomId == crewmem.iRoomId and (not zombieTable[enemyCrew.extend.selfId]) and not crewmem:IsDrone() then
				local rCrew = enemyCrew.type

				local intruder = false
				if crewmem.intruder then
					intruder = true
				end
				local slot = Hyperspace.ShipGraph.GetShipInfo(crewShip.iShipId):GetClosestSlot(crewmem:GetLocation(), crewShip.iShipId, intruder)
				local zombie = crewShip:AddCrewMemberFromString("Zombie", rCrew, intruder, slot.roomId, true, true)
				Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(defNOCLONE), zombie)
				Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(defNOSLOT), zombie)
				Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(defHMHP), zombie)
				Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(defNOWARNING), zombie)
				Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(defHDMP), zombie)
				zombieTable[zombie.extend.selfId] = 9
			end
		end
	end

	if crew and crewmem.iShipId == 0 and power.powerCooldown.second == 60 and (not crewmem.bMindControlled) then
		local crewTable = userdata_table(crewmem, "mods.aea.necro")
		if crewTable.lastKill then
			Hyperspace.playerVariables.aea_necro_ability_points = Hyperspace.playerVariables.aea_necro_ability_points - 5
			local rCrew = crewTable.lastKill
			local crewShip = Hyperspace.ships(crewmem.currentShipId)
			local intruder = false
			if crewmem.intruder then
				intruder = true
			end
			local slot = Hyperspace.ShipGraph.GetShipInfo(crewShip.iShipId):GetClosestSlot(crewmem:GetLocation(), crewShip.iShipId, intruder)
			local zombie = crewShip:AddCrewMemberFromString(crewTable.lastKillName, rCrew, intruder, slot.roomId, true, true)
			crewTable.lastKill = nil
		end
	end
end)

local xNPos = 122
local yNPos = 75
local xNText = xNPos + 51
local yNText = yNPos + 15
local widthN = 75
local heightN = 40
local naniteText = "Nanite Swarms, used by the Engi Heretics to perform various tasks.\nCurrent Last Kills:"
local tempNanitImage = Hyperspace.Resources:CreateImagePrimitiveString(
    "statusUI/aea_nanite_ui.png",
    xNPos,
    yNPos,
    0,
    Graphics.GL_Color(1, 1, 1, 1),
    1.0,
    false)
script.on_render_event(Defines.RenderEvents.SPACE_STATUS, function()
    if Hyperspace.Global.GetInstance():GetCApp().world.bStartedGame then
        local shipManager = Hyperspace.ships.player
        local naniteSwarms = Hyperspace.playerVariables.aea_necro_ability_points
        local commandGui = Hyperspace.Global.GetInstance():GetCApp().gui
        if shipManager:HasEquipment("aea_necro_engi") > 0 or shipManager:HasEquipment("aea_necro_lich") > 0 or shipManager:HasEquipment("aea_necro_king") > 0 and not (commandGui.event_pause or commandGui.menu_pause) then
            local hullHP = math.floor(naniteSwarms)
            Graphics.CSurface.GL_RenderPrimitive(tempNanitImage)
            Graphics.CSurface.GL_SetColor(Graphics.GL_Color(0.95294, 1, 0.90196, 1))
            Graphics.freetype.easy_printCenter(0, xNText, yNText, hullHP)
        	--Graphics.CSurface.GL_PopMatrix()
            local mousePos = Hyperspace.Mouse.position
	        if mousePos.x >= xNPos and mousePos.x < (xNPos + widthN) and mousePos.y >= yNPos and mousePos.y < (yNPos + heightN) then
	        	--print(warningText)
	        	local text = naniteText
	        	for crewmem in vter(shipManager.vCrewList) do
					local crew = necro_crew[crewmem.type]
	        		if crew and crewmem.iShipId == 0 then
	        			local crewTable = userdata_table(crewmem, "mods.aea.necro")
	        			if crewTable.lastKillRace then
							text = text.."\n"..crewmem:GetLongName()..": "..crewTable.lastKillRace
						end
					end
				end
				if Hyperspace.ships.enemy then
					for crewmem in vter(Hyperspace.ships.enemy.vCrewList) do
						local crew = necro_crew[crewmem.type]
		        		if crew and crewmem.iShipId == 0 then
		        			local crewTable = userdata_table(crewmem, "mods.aea.necro")
		        			if crewTable.lastKillRace then
								text = text.."\n"..crewmem:GetLongName()..": "..crewTable.lastKillRace
							end
						end
					end
				end
				Hyperspace.Mouse.tooltip = text
	        end
        end
    end
end, function() end)

mods.aea.necro_lasers = {}
local necro_lasers = mods.aea.necro_lasers
necro_lasers["AEA_LASER_NECRO_1"] = "AEA_LASER_NECRO_FRAGMENT"
necro_lasers["AEA_LASER_NECRO_2"] = "AEA_LASER_NECRO_FRAGMENT"
necro_lasers["AEA_LASER_NECRO_3"] = "AEA_LASER_NECRO_FRAGMENT"
necro_lasers["AEA_LASER_NECRO_2_LOOT"] = "AEA_LASER_NECRO_FRAGMENT"
necro_lasers["AEA_LASER_NECRO_CHARGE"] = "AEA_LASER_NECRO_FRAGMENT"

script.on_internal_event(Defines.InternalEvents.SHIELD_COLLISION, function(shipManager, projectile, damage, response) 
	local nData = nil
	if pcall(function() nData = necro_lasers[Hyperspace.Get_Projectile_Extend(projectile).name] end) and nData and shipManager.shieldSystem.shields.power.super.first <= 0 then
		local spaceManager = Hyperspace.Global.GetInstance():GetCApp().world.space
        local proj1 = spaceManager:CreateLaserBlast(
            Hyperspace.Blueprints:GetWeaponBlueprint(nData),
            projectile.position,
            projectile.currentSpace,
            projectile.ownerId,
            get_random_point_in_radius(projectile.target, 25),
            projectile.destinationSpace,
            projectile.heading)
        local proj2 = spaceManager:CreateLaserBlast(
            Hyperspace.Blueprints:GetWeaponBlueprint(nData),
            projectile.position,
            projectile.currentSpace,
            projectile.ownerId,
            get_random_point_in_radius(projectile.target, 25),
            projectile.destinationSpace,
            projectile.heading)
        if projectile.ownerId == 0 then
	        local proj3 = spaceManager:CreateLaserBlast(
	            Hyperspace.Blueprints:GetWeaponBlueprint(nData),
	            projectile.position,
	            projectile.currentSpace,
	            projectile.ownerId,
	            get_random_point_in_radius(projectile.target, 25),
	            projectile.destinationSpace,
	            projectile.heading)
	    end
	end
end)

script.on_internal_event(Defines.InternalEvents.JUMP_ARRIVE, function()
	Hyperspace.playerVariables.aea_e_has_repair = 1
end)

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	if shipManager:HasAugmentation("AEA_NECRO_SAVE_ENEMY") > 0 and Hyperspace.playerVariables.aea_e_has_repair == 1 and shipManager.ship.hullIntegrity.first <= 5 then
		for system in vter(shipManager.vSystemList) do
			if system:NeedsRepairing() then
				--print("REPAIR ENEMY SYSTEM")
				system:AddDamage(-2)
				Hyperspace.playerVariables.aea_e_has_repair = 0
			end
		end
	elseif shipManager:HasAugmentation("AEA_NECRO_SAVE_ENEMY_WEAK") > 0 and Hyperspace.playerVariables.aea_e_has_repair == 1 and shipManager.ship.hullIntegrity.first <= 5 then
		local system = shipManager:GetSystem(0)
		if system:NeedsRepairing() then
			--print("REPAIR ENEMY SHIELD SYSTEM")
			system:AddDamage(-1)
			Hyperspace.playerVariables.aea_e_has_repair = 0
		end
	end

	if shipManager.iShipId == 0 and Hyperspace.playerVariables.aea_p_has_repair == 1 and shipManager.ship.hullIntegrity.first <= 5 then
		for system in vter(shipManager.vSystemList) do
			if system:NeedsRepairing() then
				--print("REPAIR PLAYER SYSTEM")
				system:AddDamage(-10)
				Hyperspace.playerVariables.aea_p_has_repair = 0
			end
		end
	end
end)

script.on_game_event("START_BEACON_EXPLAIN", false, function()
    local shipManager = Hyperspace.Global.GetInstance():GetShipManager(0)
    if shipManager:HasAugmentation("SHIP_AEA_NECRO") > 0 then
    	Hyperspace.playerVariables.aea_necro_ability_points = Hyperspace.playerVariables.aea_necro_ability_points + 10
    end
    if shipManager:HasAugmentation("AEA_NECRO_ENGI_SLOT_C") > 0 then
    	Hyperspace.playerVariables.aea_necro_ability_points = Hyperspace.playerVariables.aea_necro_ability_points + 90
    end
end)

-----------------------------------------
-----------------------------------------
-------------END OF HERETICS-------------
-----------------------------------------
-----------------------------------------


script.on_render_event(Defines.RenderEvents.MOUSE_CONTROL, function() end, function() end)

script.on_internal_event(Defines.InternalEvents.PROJECTILE_INITIALIZE, function(projectile, weaponBlueprint) 
	if Hyperspace.ships(projectile.destinationSpace):HasAugmentation("AEA_OLD_EVASION_ENEMY") > 0 and projectile.destinationSpace ~= projectile.currentSpace then
		local dodgeFactor = Hyperspace.ships.enemy:GetDodgeFactor()
		print("ORGINAL: "..tostring(projectile.entryAngle))
		if dodgeFactor >= 5 then
			projectile.entryAngle = (projectile.entryAngle / 6) + 270 - 30
			print(tostring((360/6) + 270 - 30).." TO "..tostring(270 - 30))
		end
		print(projectile.entryAngle)
	end
	if Hyperspace.ships(projectile.destinationSpace):HasAugmentation("AEA_OLD_EVASION_ENEMY_WEAK") > 0 and projectile.destinationSpace ~= projectile.currentSpace then
		local dodgeFactor = Hyperspace.ships.enemy:GetDodgeFactor()
		if dodgeFactor >= 10 then
			projectile.entryAngle = (projectile.entryAngle / 4) + 270 - 45
			print(tostring((360/4) + 270 - 45).." TO "..tostring(270 - 45))
		end
		print(projectile.entryAngle)
	end
	if Hyperspace.ships(projectile.destinationSpace):HasAugmentation("AEA_OLD_EVASION") > 0 and projectile.destinationSpace ~= projectile.currentSpace then
		local dodgeFactor = Hyperspace.ships.player:GetDodgeFactor()
		--print("ORGINAL: "..tostring(projectile.entryAngle))
		if dodgeFactor >= 60 then
			projectile.entryAngle = (projectile.entryAngle / 32) - 5.265
			--print(tostring((360/32) - 5.265).." TO "..tostring(-5.265))
		elseif dodgeFactor >= 50 then
			projectile.entryAngle = (projectile.entryAngle / 16) - 11.25
			--print(tostring((360/16) - 11.25).." TO "..tostring(-11.25))
		elseif dodgeFactor >= 40 then
			projectile.entryAngle = (projectile.entryAngle / 12) - 15
			--print(tostring((360/12) - 15).." TO "..tostring(-15))
		elseif dodgeFactor >= 30 then
			projectile.entryAngle = (projectile.entryAngle / 8) - 22.5
			--print(tostring((360/8) - 22.5).." TO "..tostring(-22.5))
		elseif dodgeFactor >= 20 then
			projectile.entryAngle = (projectile.entryAngle / 6) - 30
			--print(tostring((360/6) - 30).." TO "..tostring(-30))
		elseif dodgeFactor >= 10 then
			projectile.entryAngle = (projectile.entryAngle / 4) - 45
			--print(tostring((360/4) - 45).." TO "..tostring(-45))
		end
		if projectile.entryAngle < 0 then
			projectile.entryAngle = projectile.entryAngle + 360
		end
		--print(projectile.entryAngle)
	end
end)

mods.aea.armouredShips = {}
local armouredShips = mods.aea.armouredShips
armouredShips["PLAYER_SHIP_AEA_OLD_ARMOUR"] = {r2 = true, r3 = true}
armouredShips["AEA_OLD_GUARD_BOSS"] = {r2 = true, r3 = true, r28 = true, r30 = true}

local playerRooms = {}
local enemyRooms = {}
script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	if shipManager.iShipId == 0 and shipManager:HasAugmentation("AEA_OLD_EVASION") > 0 then
		--print("ADD PLAYER ROOMS")
		playerRooms = armouredShips[shipManager.myBlueprint.blueprintName]
	elseif shipManager.iShipId == 1 and (shipManager:HasAugmentation("AEA_OLD_EVASION_ENEMY") > 0 or shipManager:HasAugmentation("AEA_OLD_EVASION_ENEMY_WEAK") > 0) then
		enemyRooms = armouredShips[shipManager.myBlueprint.blueprintName]
	end
end)

script.on_internal_event(Defines.InternalEvents.PROJECTILE_PRE, function(projectile) 
	--print("PROJECTILE_PRE")
	if projectile.currentSpace == projectile.destinationSpace and projectile.ownerId ~= projectile.currentSpace then
		local shipManager = Hyperspace.ships(projectile.currentSpace)
		local roomAtProjectile = get_room_at_location(shipManager, projectile.position, false)
		if shipManager:HasAugmentation("AEA_OLD_EVASION") > 0 then
			--print("ROOM: ".."r"..tostring(math.floor(roomAtProjectile)))
			local isRoom = playerRooms["r"..tostring(math.floor(roomAtProjectile))]
			--print(isRoom)
			if isRoom then 
				--print("IS ROOM")
				projectile.target = projectile.position
				projectile:ComputerHeading()
			end
		elseif shipManager:HasAugmentation("AEA_OLD_EVASION_ENEMY") > 0 or shipManager:HasAugmentation("AEA_OLD_EVASION_ENEMY_WEAK") > 0 then
			local isRoom = enemyRooms["r"..tostring(math.floor(roomAtProjectile))]
			if isRoom then 
				--print("IS ROOM")
				projectile.target = projectile.position
				projectile:ComputerHeading()
			end
		end
	end
end)

script.on_internal_event(Defines.InternalEvents.PROJECTILE_UPDATE_PRE, function(projectile) 
	--print("PROJECTILE_UPDATE_PRE")
end)
script.on_internal_event(Defines.InternalEvents.PROJECTILE_UPDATE_POST, function(projectile, preempted)  
	--print("PROJECTILE_UPDATE_POST")
end)
script.on_internal_event(Defines.InternalEvents.PROJECTILE_POST, function(projectile, preempted) 
	--print("PROJECTILE_POST")
end)

--[[script.on_internal_event(Defines.InternalEvents.CONSTRUCT_SHIP_MANAGER, function(shipManager)
	print("CONSTRUCT SHIP")
	--[[local engineInfo = shipManager.myBlueprint.systemInfo[1]
	print(engineInfo.systemId)
	pritn(engineInfo.powerLevel)
	print(engineInfo.maxPower)

	for key, value in pairs(shipManager.myBlueprint.systemInfo) do
		print("START INFO AAAAAAAAA")
		print(value.systemId)
		pritn(value.powerLevel)
		print(value.maxPower)
	end
end)]]

local setSystemMaxVars = false
script.on_init(function() setSystemMaxVars = true end)
script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    if not (setSystemMaxVars and Hyperspace.ships.player) then return end
    local sysInfo = Hyperspace.ships.player.myBlueprint.systemInfo
    --print("SYSTEM LOOP START")
    for id, sys in pairs(mods.multiverse.systemIds) do
    	local currValue = Hyperspace.playerVariables[sys.."_cap"]
    	if currValue < 0 then
    		if sys == "weapons" then Hyperspace.playerVariables[sys.."_cap_aea"] = 8 end
    		if sys == "shields" then Hyperspace.playerVariables[sys.."_cap_aea"] = 16 end
    		if sys == "engines" then Hyperspace.playerVariables[sys.."_cap_aea"] = 8 end
    		if sys == "oxygen" then Hyperspace.playerVariables[sys.."_cap_aea"] = 3 end
    		if sys == "teleporter" then Hyperspace.playerVariables[sys.."_cap_aea"] = 4 end
    		if sys == "medbay" then Hyperspace.playerVariables[sys.."_cap_aea"] = 3 end
    		if sys == "clonebay" then Hyperspace.playerVariables[sys.."_cap_aea"] = 3 end

    		if sys == "drones" then Hyperspace.playerVariables[sys.."_cap_aea"] = 15 end
    		if sys == "cloaking" then Hyperspace.playerVariables[sys.."_cap_aea"] = 3 end
    		if sys == "hacking" then Hyperspace.playerVariables[sys.."_cap_aea"] = 3 end
    		if sys == "mind" then Hyperspace.playerVariables[sys.."_cap_aea"] = 3 end
    		if sys == "artillery" then Hyperspace.playerVariables[sys.."_cap_aea"] = 5 end
    		if sys == "temporal" then Hyperspace.playerVariables[sys.."_cap_aea"] = 3 end

    		if sys == "piloting" then Hyperspace.playerVariables[sys.."_cap_aea"] = 3 end
    		if sys == "sensors" then Hyperspace.playerVariables[sys.."_cap_aea"] = 3 end
    		if sys == "doors" then Hyperspace.playerVariables[sys.."_cap_aea"] = 3 end
    		if sys == "battery" then Hyperspace.playerVariables[sys.."_cap_aea"] = 2 end
    	else
    		Hyperspace.playerVariables[sys.."_cap_aea"] = Hyperspace.playerVariables[sys.."_cap"]
    	end
    	--print(tostring(sys)..": "..tostring(Hyperspace.playerVariables[sys.."_cap"]).." & "..tostring(Hyperspace.playerVariables[sys.."_cap_aea"]))
    end

    local maxReactor = Hyperspace.CustomShipSelect.GetInstance():GetDefinition(Hyperspace.ships.player.myBlueprint.blueprintName).maxReactorLevel
    if maxReactor then
    	Hyperspace.playerVariables.reactor_cap_aea = maxReactor
    else
    	Hyperspace.playerVariables.reactor_cap_aea = 25
    end
    local powerManager = Hyperspace.PowerManager.GetPowerManager(0)
    local reactorPower = powerManager.currentPower.second
    if reactorPower >= Hyperspace.playerVariables.reactor_cap_aea then
    	Hyperspace.playerVariables.aea_can_upgrade_reactor = 1
    end
end)

script.on_game_event("INSTALL_AEA_OLD_SHIELDS", false, function()
    Hyperspace.ships.player:GetSystem(0):UpgradeSystem(1)
end)
script.on_game_event("INSTALL_AEA_OLD_ENGINES", false, function()
    Hyperspace.ships.player:GetSystem(1):UpgradeSystem(1)
end)
script.on_game_event("INSTALL_AEA_OLD_WEAPONS", false, function()
    Hyperspace.ships.player:GetSystem(3):UpgradeSystem(1)
end)
script.on_game_event("INSTALL_AEA_OLD_DRONES", false, function()
    Hyperspace.ships.player:GetSystem(4):UpgradeSystem(1)
end)
script.on_game_event("INSTALL_AEA_OLD_CLOAKING", false, function()
    Hyperspace.ships.player:GetSystem(10):UpgradeSystem(1)
end)
script.on_game_event("INSTALL_AEA_OLD_MIND", false, function()
    Hyperspace.ships.player:GetSystem(14):UpgradeSystem(1)
end)
script.on_game_event("INSTALL_AEA_OLD_HACKING", false, function()
    Hyperspace.ships.player:GetSystem(15):UpgradeSystem(1)
end)
script.on_game_event("INSTALL_AEA_OLD_MEDBAY", false, function()
    Hyperspace.ships.player:GetSystem(5):UpgradeSystem(1)
end)
script.on_game_event("INSTALL_AEA_OLD_CLONEBAY", false, function()
    Hyperspace.ships.player:GetSystem(13):UpgradeSystem(1)
end)
script.on_game_event("INSTALL_AEA_OLD_REACTOR", false, function()
    local powerManager = Hyperspace.PowerManager.GetPowerManager(0)
    --[[print("GetMaxPower(): "..tostring(powerManager:GetMaxPower()))
    print("GetAvailablePower(): "..tostring(powerManager:GetAvailablePower()))
    print("currentPower.first: "..tostring(powerManager.currentPower.first))
    print("currentPower.second: "..tostring(powerManager.currentPower.second))]]
    powerManager.currentPower.second = powerManager.currentPower.second + 1
    --local CustomShipDef = Hyperspace.CustomShipSelect.GetInstance():GetDefinition(Hyperspace.ships.player.myBlueprint.blueprintName)
end)

script.on_internal_event(Defines.InternalEvents.GET_DODGE_FACTOR, function(shipManager, value)
	if shipManager:HasSystem(1) then
		local engine = shipManager:GetSystem(1)
		if engine.powerState.first >= 9 then
			local powerExtra = engine.powerState.first - 8
			local pilot = shipManager:GetSystem(6)
			if pilot.bManned then
				value = value + 35 + (5 * powerExtra)
			elseif pilot.powerState.first == 2 then
				value = value + ((35 + (5 * powerExtra)) * 0.5)
				--print("50% ")
			elseif pilot.powerState.first == 3 then
				value = value + ((35 + (5 * powerExtra)) * 0.8)
				--print("80% ")
			end
		end
	end
	return Defines.Chain.CONTINUE, value
end)

--[[script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	if shipManager:HasSystem(6) then
		local pilot = shipManager:GetSystem(6)
		print("START -----------------")
		print(pilot.bNeedsManned)
		print(pilot.bManned)
		print(pilot.iActiveManned)
		print(pilot.bFriendlies)
		print(pilot.bOccupied)
		print(pilot.bOccupied)
		print(pilot.powerState.first)
		print("-END- -----------------")
	end
end)]]

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	if shipManager.myBlueprint.blueprintName == "AEA_OLD_GUARD_BOSS" then
		local artilleryOn = false
		for artillery in vter(shipManager.artillerySystems) do 
	        if artillery.powerState.first > 0 then
	        	artilleryOn = true
	        end
 	    end
 	    if artilleryOn == true and Hyperspace.playerVariables.aea_old_gate_guard_activated == 0 then
 	    	shipManager.ship.hullIntegrity.first = shipManager.ship.hullIntegrity.second
 	    end
 	    if Hyperspace.playerVariables.aea_old_gate_guard_activated == 0 and artilleryOn == false then
 	    	Hyperspace.playerVariables.aea_old_gate_guard_activated = 1
 	    	local worldManager = Hyperspace.Global.GetInstance():GetCApp().world
            Hyperspace.CustomEventsParser.GetInstance():LoadEvent(worldManager,"AEA_OLD_GATE_GUARD_BOSS_ACTIVATE",false,-1)
        end
	end
end)