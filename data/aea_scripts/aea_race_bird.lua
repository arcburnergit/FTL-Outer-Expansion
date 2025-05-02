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


mods.aea.burstDrones = {}
local burstDrones = mods.aea.burstDrones
burstDrones["AEA_BEAM_BIRD_BURST_1"] = 2
burstDrones["AEA_BEAM_BIRD_BURST_2"] = 3
burstDrones["AEA_BEAM_BIRD_BURST_3"] = 4


script.on_internal_event(Defines.InternalEvents.DRONE_FIRE, function(projectile, drone)
	local burstAmount = burstDrones[projectile.extend.name]
	if burstAmount then
		userdata_table(drone, "mods.aea.burstDrones").table = {0.0, burstAmount, projectile.position.x, projectile.position.y, projectile.currentSpace, projectile.target1, projectile.destinationSpace, projectile.heading, projectile.entryAngle}
		projectile:Kill()
	end
	return Defines.Chain.CONTINUE
end)

local burstLaserBlueprint = Hyperspace.Blueprints:GetWeaponBlueprint("DRONE_LASER_COMBAT")
burstSounds = RandomList:New {"lightLaser1", "lightLaser2", "lightLaser3"}

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	for drone in vter(shipManager.spaceDrones) do
		local burstDrone = userdata_table(drone, "mods.aea.burstDrones")
		if burstDrone.table then
			burstDrone.table[1] = math.max(burstDrone.table[1] - Hyperspace.FPS.SpeedFactor/16, 0)
			if burstDrone.table[1] == 0 then
				--print("DRONE_BURST_FIRE")
				local soundName = burstSounds:GetItem()
				Hyperspace.Sounds:PlaySoundMix(soundName, -1, false)
				local spaceManager = Hyperspace.Global.GetInstance():GetCApp().world.space
				local laser = spaceManager:CreateLaserBlast(
					burstLaserBlueprint,
					Hyperspace.Pointf(burstDrone.table[3],burstDrone.table[4]),
					burstDrone.table[5],
					shipManager.iShipId,
					burstDrone.table[6],
					burstDrone.table[7],
					burstDrone.table[8])
				laser.entryAngle = burstDrone.table[9]

				if burstDrone.table[2] <= 1 then
					burstDrone.table = nil
				else
					burstDrone.table[1] = 0.25
					burstDrone.table[2] = burstDrone.table[2] -1
				end
			end
		end
	end
end)

mods.aea.bioDrones = {}
local bioDrones = mods.aea.bioDrones
bioDrones["AEA_LASER_BIO_DRONE"] = true
bioDrones["AEA_LASER_BIO_DRONE_3"] = true


script.on_internal_event(Defines.InternalEvents.DRONE_FIRE, function(projectile, drone)
	local bioAmount = bioDrones[projectile.extend.name]
	if bioAmount then
		local random = math.random()
		if drone.iShipId == 1 and random > 0.66 then return Defines.Chain.CONTINUE end
		local shipManager = Hyperspace.ships(projectile.destinationSpace)
		local crewList = shipManager.vCrewList
		local crewListEnemy = {}
		local crewListSize = 0
		for crewmem in vter(crewList) do
			if not crewmem.intruder then
				crewListSize = crewListSize + 1
				table.insert(crewListEnemy, crewmem)
			end
		end
		if crewListSize > 0 then
			local random = math.random(crewListSize)
			local crew = crewListEnemy[random]
			drone.targetLocation = Hyperspace.Pointf(crew.x,crew.y)
		end
	end
	return Defines.Chain.CONTINUE
end)


mods.aea.sweepDrones = {}
local sweepDrones = mods.aea.sweepDrones
sweepDrones["AEA_BEAM_BIRD_SWEEP"] = true
local sweeperBlueprint = Hyperspace.Blueprints:GetDroneBlueprint("AEA_COMBAT_BIRD_SWEEP_DELETE")

local sweepSpawns = {}

script.on_internal_event(Defines.InternalEvents.DRONE_FIRE, function(projectile, drone)
	local sweeper = sweepDrones[projectile.extend.name]
	local ship = Hyperspace.ships(drone.iShipId)
	local otherShip = Hyperspace.ships(1 - drone.iShipId)
	if ship and otherShip and sweeper then
		local drone1 = spawn_temp_drone(
			sweeperBlueprint,
			ship,
			otherShip,
			drone.targetLocation,
			99999,
			drone.currentLocation)
		userdata_table(drone1, "mods.mv.droneStuff").clearOnJump = true
		sweepSpawns[drone1] = {20, projectile}
	end
	return Defines.Chain.CONTINUE
end)

script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
	for drone, tab in pairs(sweepSpawns) do
		tab[1] = tab[1] - Hyperspace.FPS.SpeedFactor/16
		local projectile = tab[2]
		if tab[1] <= 0 then
			drone:BlowUp(false)
			sweepSpawns[drone] = nil
		elseif projectile then
			drone:SetCurrentLocation(projectile.position)
			drone:UpdateAimingAngle(projectile.target, nil, nil);
			drone.targetLocation = projectile.target
		end
	end
end)

script.on_internal_event(Defines.InternalEvents.DRONE_FIRE, function(projectile, drone)
	if (projectile.extend.name == "AEA_BEAM_BIRD_SWEEP_DELETE") then
		projectile:Kill()
	end
	return Defines.Chain.CONTINUE
end)


mods.aea.multiDrones = {}
local multiDrones = mods.aea.multiDrones
multiDrones["AEA_DRONE_LASER_COMBAT_MULTI"] = Hyperspace.Blueprints:GetWeaponBlueprint("AEA_DRONE_WION_COMBAT_MULTI")
multiDrones["AEA_DRONE_BEAM_COMBAT_MULTI"] = Hyperspace.Blueprints:GetWeaponBlueprint("AEA_DRONE_WION_COMBAT_MULTI")

multiDrones["AEA_DRONE_LASER_COMBAT_MULTI_LOOT"] = Hyperspace.Blueprints:GetWeaponBlueprint("AEA_DRONE_LOOT_COMBAT_MULTI")
multiDrones["AEA_DRONE_BEAM_COMBAT_MULTI_LOOT"] = Hyperspace.Blueprints:GetWeaponBlueprint("AEA_DRONE_LOOT_COMBAT_MULTI")


script.on_internal_event(Defines.InternalEvents.DRONE_FIRE, function(projectile, drone)
	if log_events then
		log("DRONE_FIRE 1")
	end
	local multi = multiDrones[projectile.extend.name]
	if multi then
		local spaceManager = Hyperspace.Global.GetInstance():GetCApp().world.space

		local ionPoint = get_point_local_offset(projectile.position,projectile.target or projectile.target1, 0, 17)
		local ion = spaceManager:CreateLaserBlast(
			multi,
			ionPoint,
			projectile.currentSpace,
			drone.iShipId,
			projectile.target or projectile.target1,
			projectile.destinationSpace,
			projectile.heading)
		ion:ComputeHeading()
	end
	return Defines.Chain.CONTINUE
end)

local weakIonDamage = Hyperspace.Damage()
weakIonDamage.iIonDamage = 1
script.on_internal_event(Defines.InternalEvents.SHIELD_COLLISION, function(shipManager, projectile, damage, response) 
	if projectile and projectile.extend.name == "AEA_DRONE_WION_COMBAT_MULTI" then
		if shipManager:HasSystem(0) then
			local shieldSystem = shipManager.shieldSystem
			print(shieldSystem.shields.power.super.first)
			if shieldSystem.shields.power.super.first >= 1 then return end
			local roomPos = shipManager:GetRoomCenter(shieldSystem.roomId)
			shipManager:DamageArea(roomPos, weakIonDamage, true)
		end
	end
end)


mods.aea.birdCrew = {}
local birdCrew = mods.aea.birdCrew
birdCrew["aea_bird_avali"] = 0.5
birdCrew["aea_bird_illuminant"] = 1
birdCrew["aea_bird_unique"] = 0.5

mods.aea.birdCrewFull = {}
local birdCrewFull = mods.aea.birdCrewFull
birdCrewFull["aea_bird_unique"] = 1

script.on_internal_event(Defines.InternalEvents.CREW_LOOP, function(crewmem)
	if birdCrew[crewmem.type] and crewmem.iShipId == crewmem.currentShipId then
		local shipManager = Hyperspace.ships(crewmem.iShipId)
		if not shipManager then return end
		local system = shipManager:GetSystemInRoom(crewmem.iRoomId)
		if system then
			local speed = birdCrew[crewmem.type]
			if crewmem.iShipId == 1 then
				speed = speed / 2
			end
			system:PartialRepair(speed, false)
		end
	end

	if birdCrewFull[crewmem.type] and crewmem.iShipId == crewmem.currentShipId then
		local shipManager = Hyperspace.ships(crewmem.iShipId)
		if not shipManager then return end
		for system in vter(shipManager.vSystemList) do
			local speed = birdCrewFull[crewmem.type]
			if crewmem.iShipId == 1 then
				speed = speed / 2
			end
			system:PartialRepair(speed, false)
		end
	end
end)

-- Make enemy effectors target only systems
local systemTargetWeapons = {}
local sysWeights = {}
sysWeights.weapons = 6
sysWeights.shields = 6
sysWeights.drones = 5
sysWeights.pilot = 3
sysWeights.engines = 3
sysWeights.teleporter = 2
sysWeights.hacking = 2
sysWeights.medbay = 2
sysWeights.clonebay = 2
systemTargetWeapons.AEA_DRONE_LASER_COMBAT_SMART = sysWeights

mods.aea.intelDrones = {}
local intelDrones = mods.aea.intelDrones
intelDrones["AEA_DRONE_LASER_COMBAT_SMART"] = true


local combatLaserBlueprint = Hyperspace.Blueprints:GetWeaponBlueprint("DRONE_LASER_COMBAT")

script.on_internal_event(Defines.InternalEvents.DRONE_FIRE, function(projectile, drone)
	local thisShip = Hyperspace.ships(drone.iShipId)
	local otherShip = Hyperspace.ships(1 - drone.iShipId)

	local sysWeights = systemTargetWeapons[projectile.extend.name]

	if thisShip and otherShip and sysWeights then

		local random = math.random()
		if drone.iShipId == 1 and random > 0.66 then return Defines.Chain.CONTINUE end

		local sysTargets = {}
		local weightSum = 0
		
		-- Collect all player systems and their weights
		for system in vter(otherShip.vSystemList) do
			local sysId = system:GetId()
			if otherShip:HasSystem(sysId) then
				local weight = sysWeights[Hyperspace.ShipSystem.SystemIdToName(sysId)] or 1
				if weight > 0 then
					weightSum = weightSum + weight
					table.insert(sysTargets, {
						id = sysId,
						weight = weight
					})
				end
			end
		end
		
		-- Pick a random system using the weights
		if #sysTargets > 0 then
			local rnd = math.random(weightSum);
			for i = 1, #sysTargets do
				if rnd <= sysTargets[i].weight then
					drone.targetLocation = otherShip:GetRoomCenter(otherShip:GetSystemRoom(sysTargets[i].id))
					return Defines.Chain.CONTINUE
				end
				rnd = rnd - sysTargets[i].weight
			end
			error("Weighted selection error - reached end of options without making a choice!")
		end
	end
	return Defines.Chain.CONTINUE
end)

script.on_internal_event(Defines.InternalEvents.DRONE_FIRE, function(projectile, drone)
	local intel = intelDrones[projectile.extend.name]
	if intel then
		local spaceManager = Hyperspace.Global.GetInstance():GetCApp().world.space

		local ionPoint = get_point_local_offset(projectile.position,projectile.target or projectile.target1, 0, 20)
		local ionTarget = get_point_local_offset(projectile.target or projectile.target1, projectile.position, 0, -15)
		local ion = spaceManager:CreateLaserBlast(
			combatLaserBlueprint,
			ionPoint,
			projectile.currentSpace,
			drone.iShipId,
			ionTarget,
			projectile.destinationSpace,
			projectile.heading)
		ion:ComputeHeading()
		
		local ionPoint2 = get_point_local_offset(projectile.position,projectile.target or projectile.target1, 0, -20)
		local ionTarget2 = get_point_local_offset(projectile.target or projectile.target1, projectile.position, 0, 15)
		local ion2 = spaceManager:CreateLaserBlast(
			combatLaserBlueprint,
			ionPoint2,
			projectile.currentSpace,
			drone.iShipId,
			ionTarget2,
			projectile.destinationSpace,
			projectile.heading)
		ion2:ComputeHeading()
		projectile:Kill()
	end	
	return Defines.Chain.CONTINUE
end)

local function rollEnemy()
	Hyperspace.playerVariables.aea_bird_roulette_result = math.random(1,6)
	log("THE GI SHIP ROLLED A: "..tostring(Hyperspace.playerVariables.aea_bird_roulette_result))
end
local function rollPlayer()
	Hyperspace.playerVariables.aea_bird_roulette_result_player = math.random(1,6)
	log("THE PLAYER ROLLED A: "..tostring(Hyperspace.playerVariables.aea_bird_roulette_result_player))
end
local function rollStart()
	Hyperspace.playerVariables.aea_bird_roulette_result_start = math.random(1,2)
	log("THE COIN ROLLED A: "..tostring(Hyperspace.playerVariables.aea_bird_roulette_result_start))
end
script.on_game_event("AEA_BIRD_RUSSIAN_ROLL_ENEMY_1", false, function() rollEnemy() end)
script.on_game_event("AEA_BIRD_RUSSIAN_ROLL_ENEMY_2", false, function() rollEnemy() end)
script.on_game_event("AEA_BIRD_RUSSIAN_ROLL_ENEMY_3", false, function() rollEnemy() end)
script.on_game_event("AEA_BIRD_RUSSIAN_ROLL_ENEMY_4", false, function() rollEnemy() end)

script.on_game_event("AEA_BIRD_RUSSIAN_ROULETTE_SPIN", false, function() rollPlayer() end)
script.on_game_event("AEA_BIRD_RUSSIAN_ROLL_PLAYER_1", false, function() rollPlayer() end)
script.on_game_event("AEA_BIRD_RUSSIAN_ROLL_PLAYER_2", false, function() rollPlayer() end)

script.on_game_event("AEA_BIRD_ROULETTE_ROLL_START", false, function() rollStart() end)
script.on_game_event("AEA_BIRD_ROULETTE_LOSE", false, function() rollStart() end)