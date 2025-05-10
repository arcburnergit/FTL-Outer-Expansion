-----------------------
-- UTILITY FUNCTIONS --
-----------------------

local log_events = false
function AEAlogEvents()
	log_events = not log_events
end

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

local function offset_point_direction(oldX, oldY, angle, distance)
	local newX = oldX + (distance * math.cos(math.rad(angle)))
	local newY = oldY + (distance * math.sin(math.rad(angle)))
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
	return Hyperspace.Point(mousePosition.x - enemyShipOriginX, mousePosition.y - enemyShipOriginY)
end

local function convertMousePositionToPlayerShipPosition(mousePosition)
	local cApp = Hyperspace.Global.GetInstance():GetCApp()
	local combatControl = cApp.gui.combatControl
	local playerPosition = combatControl.playerShipPosition
	return Hyperspace.Point(mousePosition.x - playerPosition.x, mousePosition.y - playerPosition.y)
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

local spawn_temp_drone = mods.multiverse.spawn_temp_drone

local node_child_iter = mods.multiverse.node_child_iter


script.on_internal_event(Defines.InternalEvents.DRONE_COLLISION, function(drone, projectile, damage, response)
	if log_events then
		log("DRONE_COLLISION 1")
	end
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
	if log_events then
		log("PROJECTILE_COLLISION 1")
	end
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
	if log_events then
		log("DRONE_COLLISION 2")
	end
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
			if drone.iShipId == 0 then
				local drone3 = spawn_temp_drone(
					droneBlueprint,
					ship,
					otherShip,
					nil,
					3,
					drone.currentLocation)
				userdata_table(drone3, "mods.mv.droneStuff").clearOnJump = true
			end
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
			if drone.iShipId == 0 then
				local drone4 = spawn_temp_drone(
					droneBlueprint,
					ship,
					otherShip,
					nil,
					3,
					drone.currentLocation)
				userdata_table(drone4, "mods.mv.droneStuff").clearOnJump = true
			end
			droneTable[drone.selfId] = true
			drone:BlowUp(false)
		end
	end
end)

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	if log_events then
		--log("SHIP_LOOP 2")
	end
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
					if drone.iShipId == 0 then
						local drone3 = spawn_temp_drone(
							droneBlueprint,
							ship,
							otherShip,
							nil,
							3,
							drone.currentLocation)
						userdata_table(drone3, "mods.mv.droneStuff").clearOnJump = true
					end
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

local tempDrones = {}
script.on_internal_event(Defines.InternalEvents.DRONE_FIRE, function(projectile, drone)
	if projectile.extend.name == "AEA_LASER_NECRO_COMBAT_BOSS" or projectile.extend.name == "AEA_LASER_NECRO_COMBAT_BOSS_CHAOS" then
		local droneBlueprint = Hyperspace.Blueprints:GetDroneBlueprint("AEA_COMBAT_NECRO_BOSS_LASER_TEMP")
		local ship = Hyperspace.ships(1- projectile.currentSpace)
		local otherShip = Hyperspace.ships(projectile.currentSpace)
		local drone2 = spawn_temp_drone(
			droneBlueprint,
			ship,
			otherShip,
			nil,
			999,
			drone.currentLocation)
		userdata_table(drone2, "mods.mv.droneStuff").clearOnJump = true
		if projectile.extend.name == "AEA_LASER_NECRO_COMBAT_BOSS" then
			if not tempDrones[drone.selfId] then
				tempDrones[drone.selfId] = {}
			end
			table.insert(tempDrones[drone.selfId], drone2)
			if #tempDrones[drone.selfId] > 3  then
				tempDrones[drone.selfId][1]:BlowUp(true)
			end
		end
		projectile:Kill()
	end
	return Defines.Chain.HALT
end)

script.on_internal_event(Defines.InternalEvents.JUMP_ARRIVE, function(shipManager)
	if log_events then
		log("JUMP_ARRIVE 2")
	end
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
	if log_events then
		--log("CREW_LOOP 1")
	end
	if crewmem.health.first <= 0 and not (dead_crew[crewmem.extend.selfId]) and not crewmem:IsDrone() then
		--print("CREW DYING: "..tostring(crewmem.type))
		dead_crew[crewmem.extend.selfId] = true


		local crewShip = Hyperspace.ships(crewmem.currentShipId)
		if crewShip:HasAugmentation("AEA_AUG_WHALE")>0 then
			crewShip:DamageHull(-1 , true)
		end
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
	if log_events then
		--log("POWER_READY 1")
	end
	local crew = necro_crew[power.crew.type]
	local crewmem = power.crew
	if crew and crewmem.iShipId == 0 and (power.powerCooldown.second == 20 or power.powerCooldown.second == 2) then
		local crewTable = userdata_table(crewmem, "mods.aea.necro")
		if not crewTable then return end
		if not (Hyperspace.playerVariables.aea_necro_ability_points > 0 and crewTable.lastKill) then
			powerState = 22
		end
		if crewmem.bMindControlled then
			powerState = 22
		end
	end
	if crew and crewmem.iShipId == 0 and power.powerCooldown.second == 60 then
		local crewTable = userdata_table(crewmem, "mods.aea.necro")
		if not crewTable then return end
		if not (Hyperspace.playerVariables.aea_necro_ability_points > 4 and crewTable.lastKill) then
			powerState = 22
		end
		if crewmem.bMindControlled then
			powerState = 22
		end
	end
	if crew and crewmem.iShipId == 0 and power.powerCooldown.second == 30 then
		local crewTable = userdata_table(crewmem, "mods.aea.necro")
		if not crewTable then return end
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
	if log_events then
		log("DAMAGE_BEAM 1")
	end
	if projectile.extend.name == "AEA_BEAM_NECRO_1" and realNewTile then
		local playerShip = Hyperspace.ships.player
		local enemyShip = Hyperspace.ships.enemy
		for playerCrew in vter(playerShip.vCrewList) do
			if playerCrew.iShipId == 0 then
				Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(def0XCREWSLOT), playerCrew)
			end
		end
		if enemyShip then
			for playerCrew in vter(enemyShip.vCrewList) do
				if playerCrew.iShipId == 0 then
					Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(def0XCREWSLOT), playerCrew)
				end
			end
		end
		for i, crewmem in ipairs(get_ship_crew_point(shipManager, location.x, location.y)) do
			if not crewmem:IsDrone() and ((not crewmem.extend.deathTimer) or (not crewmem.extend.deathTimer.running)) then
				local rCrew = crewmem.type
				if string.sub(rCrew, string.len(rCrew) - 5, string.len(rCrew)) == "_enemy" then
					rCrew = string.sub(rCrew, 1, string.len(rCrew) - 6)
				end
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
				zombie.extend.deathTimer = Hyperspace.TimerHelper(false)
    		zombie.extend.deathTimer:Start(15)
			end
		end
	end
	return Defines.Chain.CONTINUE, beamHitType
end)


script.on_internal_event(Defines.InternalEvents.ACTIVATE_POWER, function(power, shipManager)
	if log_events then
		log("ACTIVATE_POWER 2")
	end
	local crew = necro_crew[power.crew.type]
	local crewmem = power.crew
	if crew and crewmem.iShipId == 0 and (power.powerCooldown.second == 20 or power.powerCooldown.second == 2) and (not crewmem.bMindControlled) then
		--print("RESURRECT")
		local crewTable = userdata_table(crewmem, "mods.aea.necro")
		if not crewTable.lastKill then return end
		if Hyperspace.playerVariables.aea_necro_ability_points > 0 and crewTable.lastKill then
			local playerShip = Hyperspace.ships.player
			local enemyShip = Hyperspace.ships.enemy
			for playerCrew in vter(playerShip.vCrewList) do
				if playerCrew.iShipId == 0 then
					Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(def0XCREWSLOT), playerCrew)
				end
			end
			if enemyShip then
				for playerCrew in vter(enemyShip.vCrewList) do
					if playerCrew.iShipId == 0 then
						Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(def0XCREWSLOT), playerCrew)
					end
				end
			end
			Hyperspace.playerVariables.aea_necro_ability_points = Hyperspace.playerVariables.aea_necro_ability_points - 1
			local rCrew = crewTable.lastKill
			if crewmem.iShipId == 0 and string.sub(rCrew, string.len(rCrew) - 5, string.len(rCrew)) == "_enemy" then
				rCrew = string.sub(rCrew, 1, string.len(rCrew) - 6)
			end
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
			zombie.extend.deathTimer = Hyperspace.TimerHelper(false)
    	zombie.extend.deathTimer:Start(90)
		end
	elseif crew and power.powerCooldown.second == 20 and (not crewmem.bMindControlled) then
		local rCrew = enemyResurrections:GetItem()
		if crewmem.iShipId == 0 and string.sub(rCrew, string.len(rCrew) - 5, string.len(rCrew)) == "_enemy" then
			rCrew = string.sub(rCrew, 1, string.len(rCrew) - 6)
		end
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
		zombie.extend.deathTimer = Hyperspace.TimerHelper(false)
		zombie.extend.deathTimer:Start(20)
	end


	if crew and crewmem.iShipId == 0 and power.powerCooldown.second == 30 and (not crewmem.bMindControlled) then
		--print("REND")
		local crewTable = userdata_table(crewmem, "mods.aea.necro")
		if not crewTable then return end
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
			if enemyShip then
				for playerCrew in vter(enemyShip.vCrewList) do
					if playerCrew.iShipId == 0 then
						Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(def0XCREWSLOT), playerCrew)
					end
				end
			end
			for enemyCrew in vter(crewShip.vCrewList) do
				--print(enemyCrew.type)
				if enemyCrew.iShipId ~= crewmem.iShipId and enemyCrew.iRoomId == crewmem.iRoomId and ((not enemyCrew.extend.deathTimer) or (not enemyCrew.extend.deathTimer.running)) and (not crewmem:IsDrone()) then
					--print("REND LOOP CREW")
					local rCrew = enemyCrew.type
					if crewmem.iShipId == 0 and string.sub(rCrew, string.len(rCrew) - 5, string.len(rCrew)) == "_enemy" then
						rCrew = string.sub(rCrew, 1, string.len(rCrew) - 6)
					end
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
					zombie.extend.deathTimer = Hyperspace.TimerHelper(false)
    			zombie.extend.deathTimer:Start(30)
				end
			end
		end
	elseif crew and power.powerCooldown.second == 30 and (not crewmem.bMindControlled) then
		local crewShip = Hyperspace.ships(crewmem.currentShipId)
		for enemyCrew in vter(crewShip.vCrewList) do
			if enemyCrew.iShipId ~= crewmem.iShipId and enemyCrew.iRoomId == crewmem.iRoomId and ((not enemyCrew.extend.deathTimer) or (not enemyCrew.extend.deathTimer.running)) and not crewmem:IsDrone() then
				local rCrew = enemyCrew.type
				if crewmem.iShipId == 0 and string.sub(rCrew, string.len(rCrew) - 5, string.len(rCrew)) == "_enemy" then
					rCrew = string.sub(rCrew, 1, string.len(rCrew) - 6)
				end
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
				zombie.extend.deathTimer = Hyperspace.TimerHelper(false)
    		zombie.extend.deathTimer:Start(9)
			end
		end
	end

	if crew and crewmem.iShipId == 0 and power.powerCooldown.second == 60 and (not crewmem.bMindControlled) then
		local crewTable = userdata_table(crewmem, "mods.aea.necro")
		if not crewTable then return end
		if crewTable.lastKill then
			Hyperspace.playerVariables.aea_necro_ability_points = Hyperspace.playerVariables.aea_necro_ability_points - 5
			local rCrew = crewTable.lastKill
			if string.sub(rCrew, string.len(rCrew) - 5, string.len(rCrew)) == "_enemy" then
				rCrew = string.sub(rCrew, 1, string.len(rCrew) - 6)
			end
			local crewShip = Hyperspace.ships(crewmem.currentShipId)
			local intruder = false
			if crewmem.intruder then
				intruder = true
			end
			local slot = Hyperspace.ShipGraph.GetShipInfo(crewShip.iShipId):GetClosestSlot(crewmem:GetLocation(), crewShip.iShipId, intruder)
			local zombie = crewShip:AddCrewMemberFromString(crewTable.lastKillName, rCrew, intruder, slot.roomId, true, true)
			crewTable.lastKill = nil
			crewTable.lastKillName = nil
			crewTable.lastKillRace = nil
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
						if not crewTable then return end
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
							if not crewTable then return end
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
	if log_events then
		log("SHIELD_COLLISION 1")
	end
	local nData = nil
	if pcall(function() nData = necro_lasers[projectile.extend.name] end) and nData and shipManager.shieldSystem.shields.power.super.first <= 0 then

		local spaceManager = Hyperspace.Global.GetInstance():GetCApp().world.space
		if projectile.ownerId == 0 and shipManager.shieldSystem.shields.power.first <= 2 then
			local proj1 = spaceManager:CreateLaserBlast(
				Hyperspace.Blueprints:GetWeaponBlueprint(nData),
				projectile.position,
				projectile.currentSpace,
				projectile.ownerId,
				get_random_point_in_radius(projectile.target, 25),
				projectile.destinationSpace,
				projectile.heading)
		end
		if shipManager.shieldSystem.shields.power.first <= 1 then
			local proj2 = spaceManager:CreateLaserBlast(
				Hyperspace.Blueprints:GetWeaponBlueprint(nData),
				projectile.position,
				projectile.currentSpace,
				projectile.ownerId,
				get_random_point_in_radius(projectile.target, 25),
				projectile.destinationSpace,
				projectile.heading)
		end
		if shipManager.shieldSystem.shields.power.first <= 0 then
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
	if log_events then
		log("JUMP_ARRIVE 3")
	end
	Hyperspace.playerVariables.aea_e_has_repair = 1
end)

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	if log_events then
		--log("SHIP_LOOP 3")
	end
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