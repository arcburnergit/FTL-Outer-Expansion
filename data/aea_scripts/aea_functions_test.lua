local vter = mods.multiverse.vter

local toggleEvent = false
local removedDroneTimer = nil
local droneTimers = {}
local lastDroneTimers = {}
local lastLastDroneTimers = {}

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
    if not shipManager == 0 then return end
    lastLastDroneTimers = lastDroneTimers
    lastDroneTimers = droneTimers
	droneTimers = {}
	if Hyperspace.ships.player and Hyperspace.ships.player:HasSystem(4) then
		for drone in vter(Hyperspace.ships.player.droneSystem.drones) do
			droneTimers[drone.selfId] = drone.destroyedTimer
		end
	end
	
	-- Find the new drone and apply the old timer to it
	if toggleEvent then
		toggleEvent = false
		local newDrone = nil
		for droneId, _ in pairs(droneTimers) do
			if not lastDroneTimers[droneId] then
				newDrone = droneId
				break
			end
		end
		if newDrone then
			if Hyperspace.ships.player:HasSystem(4) then
				for drone in vter(Hyperspace.ships.player.droneSystem.drones) do
					if drone.selfId == newDrone then
						drone.destroyedTimer = removedDroneTimer
					end
				end
			end
		end
		removedDroneTimer = nil
	end
end)

script.on_game_event("COMBAT_CHECK_TOGGLE_LOAD", false, function() 
	-- Get the timer from the old drone when removed

	for droneId, deathTimer in pairs(lastLastDroneTimers) do
		if not droneTimers[droneId] then
			removedDroneTimer = deathTimer
		end
	end
	if removedDroneTimer then
		toggleEvent = true
	end
end)



--[[mods.aea = {}

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

local function get_distance(point1, point2)
	return math.sqrt(((point2.x - point1.x)^ 2)+((point2.y - point1.y) ^ 2))
end

local function midPoint(point1, point2)
	return Hyperspace.Pointf((point1.x + point2.x)/2, (point1.y + point2.y)/2)
end

-- Check if a weapon's current shot is its first
local function is_first_shot(weapon, afterFirstShot)
	local shots = weapon.numShots
	if weapon.weaponVisual.iChargeLevels > 0 then shots = shots*(weapon.weaponVisual.boostLevel + 1) end
	if weapon.blueprint.miniProjectiles:size() > 0 then shots = shots*weapon.blueprint.miniProjectiles:size() end
	if afterFirstShot then shots = shots - 1 end
	return shots == weapon.queuedProjectiles:size()
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
	local position = combatControl.position
	local targetPosition = combatControl.targetPosition
	local enemyShipOriginX = position.x + targetPosition.x
	local enemyShipOriginY = position.y + targetPosition.y
	return Hyperspace.Pointf(mousePosition.x - enemyShipOriginX, mousePosition.y - enemyShipOriginY)
end

-- written by kokoro
local function enemyToGlobalSpace(pos)
	local cApp = Hyperspace.Global.GetInstance():GetCApp()
	local combatControl = cApp.gui.combatControl
	local position = combatControl.position
	local targetPosition = combatControl.targetPosition
	local enemyShipOriginX = position.x + targetPosition.x
	local enemyShipOriginY = position.y + targetPosition.y
	return Hyperspace.Pointf(pos.x + enemyShipOriginX, pos.y + enemyShipOriginY)
end

local function convertMousePositionToPlayerShipPosition(mousePosition)
	local cApp = Hyperspace.Global.GetInstance():GetCApp()
	local combatControl = cApp.gui.combatControl
	local playerPosition = combatControl.playerShipPosition
	return Hyperspace.Pointf(mousePosition.x - playerPosition.x, mousePosition.y - playerPosition.y)
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
		check_for_room(roomShape.x - 17,			   roomShape.y + offset + 17)
		check_for_room(roomShape.x + roomShape.w + 17, roomShape.y + offset + 17)
	end
	if diagonals then
		check_for_room(roomShape.x - 17,			   roomShape.y - 17)
		check_for_room(roomShape.x + roomShape.w + 17, roomShape.y - 17)
		check_for_room(roomShape.x + roomShape.w + 17, roomShape.y + roomShape.h + 17)
		check_for_room(roomShape.x - 17,			   roomShape.y + roomShape.h + 17)
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

local function round(num, numDecimalPlaces)
  local mult = 10^(numDecimalPlaces or 0)
  return math.floor(num * mult + 0.5) / mult
end


local toggleEvent = false
local removedDroneTimer = nil
local droneTimers = {}
local lastDroneTimers = {}

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function()
	for k, v in pairs(droneTimers) do
		lastDroneTimers[k] = v
	end 
	droneTimers = {}
	if Hyperspace.ships.player and Hyperspace.ships.player:HasSystem(4) then
		for drone in vter(Hyperspace.ships.player.droneSystem.drones) do
			print(drone.blueprint.typeName.." timer:"..tostring(drone.destroyedTimer).. " id:"..tostring(drone.selfId))
			droneTimers[drone.selfId] = drone.destroyedTimer
		end
	end
	if toggleEvent then
		print("toggle_event "..tostring(removedDroneTimer))
		toggleEvent = false
		local newDrone = nil
		for k1, v1 in pairs(droneTimers) do
			local droneNew = false
			for k2, v2 in pairs(lastDroneTimers) do
				if k1 == k2 then droneNew = true end
			end
			if not droneNew then
				print("NEW DRONE timer:"..tostring(v1).. " id:"..tostring(k1))
				newDrone = k1
			end
		end
		if newDrone then
			if Hyperspace.ships.player:HasSystem(4) then
				for drone in vter(Hyperspace.ships.player.droneSystem.drones) do
					if drone.selfId == newDrone then
						print("SET TIMER "..drone.blueprint.typeName.." timer:"..tostring(drone.destroyedTimer).." new timer:"..tostring(removedDroneTimer).. " id:"..tostring(drone.selfId))
						drone.destroyedTimer = removedDroneTimer
						print("afterSet Timer:"..tostring(drone.destroyedTimer))
					end
				end
			end
		end
		removedDroneTimer = nil
	end
end)


script.on_game_event("COMBAT_CHECK_TOGGLE_LOAD", false, function() 
	for k1, v1 in pairs(lastDroneTimers) do
		local droneStillHere = false
		for k2, v2 in pairs(droneTimers) do
			if k1 == k2 then droneStillHere = true end
		end
		if not droneStillHere then
			print("REMOVED DRONE timer:"..tostring(v1).. " id:"..tostring(k1))
			removedDroneTimer = v1
		end
	end
	if removedDroneTimer then
		toggleEvent = true
		print("set toggle event "..tostring(removedDroneTimer))
	end
end)]]