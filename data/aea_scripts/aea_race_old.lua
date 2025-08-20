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


script.on_internal_event(Defines.InternalEvents.PROJECTILE_INITIALIZE, function(projectile, weaponBlueprint) 
	if Hyperspace.ships(projectile.destinationSpace):HasAugmentation("AEA_OLD_EVASION_ENEMY") > 0 and projectile.destinationSpace ~= projectile.currentSpace then
		local dodgeFactor = Hyperspace.ships.enemy:GetDodgeFactor()
		if dodgeFactor >= 5 then
			projectile.entryAngle = (projectile.entryAngle / 6) + 270 - 30
		end
	end
	if Hyperspace.ships(projectile.destinationSpace):HasAugmentation("AEA_OLD_EVASION_ENEMY_WEAK") > 0 and projectile.destinationSpace ~= projectile.currentSpace then
		local dodgeFactor = Hyperspace.ships.enemy:GetDodgeFactor()
		if dodgeFactor >= 10 then
			projectile.entryAngle = (projectile.entryAngle / 4) + 270 - 45
		end
	end
	if Hyperspace.ships(projectile.destinationSpace):HasAugmentation("AEA_OLD_EVASION") > 0 and projectile.destinationSpace ~= projectile.currentSpace then
		local dodgeFactor = Hyperspace.ships.player:GetDodgeFactor()
		if dodgeFactor >= 60 then
			projectile.entryAngle = (projectile.entryAngle / 32) - 5.265
		elseif dodgeFactor >= 50 then
			projectile.entryAngle = (projectile.entryAngle / 16) - 11.25
		elseif dodgeFactor >= 40 then
			projectile.entryAngle = (projectile.entryAngle / 12) - 15
		elseif dodgeFactor >= 30 then
			projectile.entryAngle = (projectile.entryAngle / 8) - 22.5
		elseif dodgeFactor >= 20 then
			projectile.entryAngle = (projectile.entryAngle / 6) - 30
		elseif dodgeFactor >= 10 then
			projectile.entryAngle = (projectile.entryAngle / 4) - 45
		end
		if projectile.entryAngle < 0 then
			projectile.entryAngle = projectile.entryAngle + 360
		end
	end
end)

mods.aea.armouredShips = {}
local armouredShips = mods.aea.armouredShips
armouredShips["PLAYER_SHIP_AEA_OLD_ARMOUR"] = {r2 = true, r3 = true}
armouredShips["PLAYER_SHIP_AEA_OLD_ARMOUR_2"] = {r4 = true}

armouredShips["PLAYER_SHIP_AEA_OLD_HAMMER"] = {r1 = true, r2 = true}
armouredShips["PLAYER_SHIP_AEA_OLD_HAMMER_2"] = {r1 = true, r2 = true, r3 = true, r4 = true}

armouredShips["PLAYER_SHIP_AEA_OLD_UNIA"] = {r17 = true, r19 = true}
armouredShips["PLAYER_SHIP_AEA_OLD_UNIA_2"] = {r13 = true, r15 = true}
armouredShips["PLAYER_SHIP_AEA_OLD_UNIA_3"] = {r17 = true, r18 = true}

armouredShips["PLAYER_SHIP_AEA_OLD_UNIB_2"] = {r21 = true}

armouredShips["PLAYER_SHIP_AEA_OLD_FLAGSHIP"] = {r5 = true, r6 = true, r7 = true, r8 = true}
armouredShips["PLAYER_SHIP_AEA_OLD_FLAGSHIP"] = {r5 = true, r6 = true, r7 = true}
armouredShips["PLAYER_SHIP_AEA_OLD_FLAGSHIP"] = {r5 = true, r6 = true}

--[[armouredShips["AEA_OLD_GUARD_BOSS"] = {r2 = true, r3 = true, r28 = true, r30 = true}
armouredShips["AEA_OLD_FINAL_BOSS_ONE_CASUAL"] = {r2 = true, r3 = true}
armouredShips["AEA_OLD_FINAL_BOSS_ONE_NORMAL"] = {r2 = true, r3 = true}
armouredShips["AEA_OLD_FINAL_BOSS_ONE_CHALLENGE"] = {r2 = true, r3 = true}
armouredShips["AEA_OLD_FINAL_BOSS_ONE_EXTREME"] = {r2 = true, r3 = true}]]

armouredShips["AEA_OLD_FINAL_BOSS_ONE_CASUAL"] = {r13 = true, r14 = true, r2 = true, r4 = true}
armouredShips["AEA_OLD_FINAL_BOSS_ONE_NORMAL"] = {r13 = true, r14 = true, r2 = true, r4 = true}
armouredShips["AEA_OLD_FINAL_BOSS_ONE_CHALLENGE"] = {r13 = true, r14 = true, r2 = true, r4 = true}
armouredShips["AEA_OLD_FINAL_BOSS_ONE_EXTREME"] = {r13 = true, r14 = true, r2 = true, r4 = true}

armouredShips["AEA_OLD_FINAL_BOSS_ONE_CASUAL"] = {r13 = true, r14 = true, r4 = true}
armouredShips["AEA_OLD_FINAL_BOSS_ONE_NORMAL"] = {r13 = true, r14 = true, r4 = true}
armouredShips["AEA_OLD_FINAL_BOSS_ONE_CHALLENGE"] = {r13 = true, r14 = true, r4 = true}
armouredShips["AEA_OLD_FINAL_BOSS_ONE_EXTREME"] = {r13 = true, r14 = true, r4 = true}

armouredShips["AEA_OLD_FINAL_BOSS_ONE_CASUAL"] = {r13 = true, r14 = true}
armouredShips["AEA_OLD_FINAL_BOSS_ONE_NORMAL"] = {r13 = true, r14 = true}
armouredShips["AEA_OLD_FINAL_BOSS_ONE_CHALLENGE"] = {r13 = true, r14 = true}
armouredShips["AEA_OLD_FINAL_BOSS_ONE_EXTREME"] = {r13 = true, r14 = true}

armouredShips["AEA_OLD_BATTLESHIP"] = {r8 = true}
armouredShips["AEA_OLD_ASSAULT"] = {r7 = true, r8 = true}
armouredShips["AEA_OLD_RIGGER"] = {r8 = true, r9 = true}
armouredShips["AEA_OLD_STATION"] = {r6 = true, r7 = true}
armouredShips["AEA_OLD_PROTECTOR"] = {r11 = true}
armouredShips["AEA_OLD_ENFORCER"] = {r3 = true, r4 = true}
armouredShips["AEA_OLD_ASSAULT_ELITE"] = {r7 = true, r8 = true}
armouredShips["AEA_OLD_RIGGER_ELITE"] = {r8 = true, r9 = true}
armouredShips["AEA_OLD_PROTECTOR_ELITE"] = {r11 = true}
armouredShips["AEA_OLD_ENFORCER_ELITE"] = {r3 = true, r4 = true}
armouredShips["AEA_BEAM_MASTER_OLD"] = {r14 = true, r5 = true, r16 = true, r9 = true, r13 = true, r12 = true, r1 = true, r17 = true, r6 = true, r11 = true, r10 = true, r8 = true, r15 = true}


local playerRooms = {}
local enemyRooms = {}
script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	if shipManager.iShipId == 0 then
		playerRooms = armouredShips[shipManager.myBlueprint.blueprintName]
	elseif shipManager.iShipId == 1 then
		enemyRooms = armouredShips[shipManager.myBlueprint.blueprintName]
	end
end)

local reducedProjectiles = {}


script.on_internal_event(Defines.InternalEvents.PROJECTILE_PRE, function(projectile)
	if projectile.currentSpace == projectile.destinationSpace and projectile.ownerId ~= projectile.currentSpace then
		local shipManager = Hyperspace.ships(projectile.currentSpace)
		if not shipManager then return end
		local roomAtProjectile = get_room_at_location(shipManager, projectile.position, false)
		local roomAtTarget = get_room_at_location(shipManager, projectile.position, false)
		if shipManager.iShipId == 0 and playerRooms then
			local isRoom = playerRooms["r"..tostring(math.floor(roomAtProjectile))]
			if isRoom and (not reducedProjectiles[projectile.selfId]) then 
				if projectile.damage.iDamage <= 1 then
					projectile.target = projectile.position
				else
					reducedProjectiles[projectile.selfId] = true
					local damageNew = projectile.damage
					damageNew.iDamage = damageNew.iDamage - 1
					projectile:SetDamage(damageNew)
				end
			end
		elseif shipManager.iShipId == 1 and enemyRooms then
			local isRoom = enemyRooms["r"..tostring(math.floor(roomAtProjectile))]
			if isRoom and (not reducedProjectiles[projectile.selfId]) then 
				if projectile.damage.iDamage <= 1 then
					projectile.target = projectile.position
				else
					reducedProjectiles[projectile.selfId] = true
					local damageNew = projectile.damage
					damageNew.iDamage = damageNew.iDamage - 1
					projectile:SetDamage(damageNew)
				end
			end
		end
		if shipManager:HasAugmentation("AEA_OLD_ARMOUR_ALLOY") > 0 and roomAtProjectile == roomAtTarget and projectile.currentSpace == projectile.destinationSpace and (not reducedProjectiles[projectile.selfId]) then
			reducedProjectiles[projectile.selfId] = true
			local damageNew = projectile.damage
			damageNew.iDamage = damageNew.iDamage - 1
			projectile:SetDamage(damageNew)
		end
	end
end)
script.on_internal_event(Defines.InternalEvents.JUMP_ARRIVE, function(shipManager)
	reducedProjectiles = {}
end)

mods.aea.systemIds = {
    [0] = "shields",
    [1] = "engines",
    [2] = "oxygen",
    [3] = "weapons",
    [4] = "drones",
    [5] = "medbay",
    [9] = "teleporter",
    [10] = "cloaking",
    [12] = "battery",
    [13] = "clonebay",
    [14] = "mind",
    [20] = "temporal",
    [Hyperspace.ShipSystem.NameToSystemId("aea_super_shields")] = "aea_super_shields",
    [Hyperspace.ShipSystem.NameToSystemId("aea_clone_crime")] = "aea_clone_crime"
}
-- system blueprints not being exposed smh!
local maxLevels = {
	shields = 16,
	engines = 8,
	oxygen = 3,
	weapons = 8,
	drones = 15,
	medbay = 3,
	teleporter = 3,
	cloaking = 3,
	battery = 2,
	clonebay = 3,
	mind = 3,
	temporal = 3,
	aea_super_shields = 3,
	aea_clone_crime = 3
}
local maxUpgrades = {
	shields = 2,
	engines = 4,
	weapons = 3,
	drones = 3,
}

local systemBlueprintList = {}
local node_child_iter = mods.multiverse.node_child_iter
for _, file in ipairs(mods.multiverse.blueprintFiles) do
	local doc = RapidXML.xml_document(file)
	for node in node_child_iter(doc:first_node("FTL") or doc) do
		if node:name() == "systemBlueprint" then
			systemBlueprintList[node:first_attribute("name"):value()] = {}
			for systemNode in node_child_iter(node) do
				if systemNode:name() == "type" then
					systemBlueprintList[node:first_attribute("name"):value()].shortTitle = systemNode:value()
				elseif systemNode:name() == "title" then
					systemBlueprintList[node:first_attribute("name"):value()].title = systemNode:value()
				end
			end
		end
	end
	doc:clear()
end

local setSystemMaxVars = false
script.on_init(function() setSystemMaxVars = true end)
script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
	if log_events then
		--log("ON_TICK 2")
	end
	if not (setSystemMaxVars and Hyperspace.ships.player) then return end
	local sysInfo = Hyperspace.ships.player.myBlueprint.systemInfo
	--print("SYSTEM LOOP START")
	for id, sys in pairs(mods.aea.systemIds) do
		local currValue = Hyperspace.playerVariables[sys.."_cap"]
		if currValue < 0 then
			Hyperspace.playerVariables[sys.."_cap_aea"] = maxLevels[sys]
		else
			Hyperspace.playerVariables[sys.."_cap_aea"] = Hyperspace.playerVariables[sys.."_cap"]
		end
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

script.on_internal_event(Defines.InternalEvents.GET_DODGE_FACTOR, function(shipManager, value)
	if shipManager:HasSystem(1) then
		local engine = shipManager:GetSystem(1)
		if engine:GetEffectivePower() >= 9 then
			local powerExtra = engine:GetEffectivePower() - 8
			local pilot = shipManager:GetSystem(6)
			if pilot.bManned then
				value = value + 35 + (5 * powerExtra)
			elseif pilot.powerState.first == 2 then
				value = value + ((35 + (5 * powerExtra)) * 0.5)
			elseif pilot.powerState.first == 3 then
				value = value + ((35 + (5 * powerExtra)) * 0.8)
			end
		end
	end
	return Defines.Chain.CONTINUE, value
end)
--Handles tooltips and mousever descriptions per level
local function get_level_description_aea_engines(systemId, level, tooltip)
    if systemId == Hyperspace.ShipSystem.NameToSystemId("engines") then
        if level > 8 then
        	if level%4 == 1 then
	            return string.format("Dodge: %i / FTL: %ix", 5*level - 5, math.floor(0.75 + level/4))
	        else
	            return string.format("Dodge: %i / FTL: %sx", 5*level - 5, tostring(0.75 + level/4))
	        end
        end
    end
end

script.on_internal_event(Defines.InternalEvents.GET_LEVEL_DESCRIPTION, get_level_description_aea_engines)

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

-- https://gist.github.com/jaredallard/ddb152179831dd23b230
function string:split(delimiter)
  local result = { }
  local from  = 1
  local delim_from, delim_to = string.find( self, delimiter, from  )
  while delim_from do
    table.insert( result, string.sub( self, from , delim_from-1 ) )
    from  = delim_to + 1
    delim_from, delim_to = string.find( self, delimiter, from  )
  end
  table.insert( result, string.sub( self, from  ) )
  return result
end

local hackingBombBlueprint = Hyperspace.Blueprints:GetWeaponBlueprint("AEA_OLD_HACK_BOMB")
local fireBombBlueprint = Hyperspace.Blueprints:GetWeaponBlueprint("BOMB_FIRE")
script.on_internal_event(Defines.InternalEvents.ACTIVATE_POWER, function(power, shipManager)
	local crewmem = power.crew
	local spaceManager = Hyperspace.Global.GetInstance():GetCApp().world.space

	if crewmem.type == "aea_old_unique_1" then
		--print("UNIFEX_BOMB")
		local crewShip = Hyperspace.ships(crewmem.currentShipId)
		local hackingBomb = spaceManager:CreateBomb(
			hackingBombBlueprint,
			crewmem.iShipId,
			crewShip:GetRoomCenter(crewmem.iRoomId),
			crewmem.currentShipId)

	elseif crewmem.type == "aea_old_unique_2" then
		--print("UNI2")
		local crewShip = Hyperspace.ships(crewmem.currentShipId)
		local system = crewShip:GetSystemInRoom(crewmem.iRoomId)
		if system then
			system:LockSystem(0)
		end

	elseif crewmem.type == "aea_old_unique_3" then
		--print("UNI3")
		local crewShip = Hyperspace.ships(crewmem.currentShipId)
		local enemyShip = Hyperspace.ships(1-crewmem.iShipId)
		--local crewCount = 0
		local fireBomb = spaceManager:CreateBomb(
			fireBombBlueprint,
			1 - crewmem.iShipId,
			enemyShip:GetRandomRoomCenter(),
			enemyShip.iShipId)
		for crew in vter(crewShip.vCrewList) do
			if crew.iShipId ~= crewmem.iShipId and crew.iRoomId == crewmem.iRoomId then
				--crewCount = crewCount + 1
				--print("BOMB")
				local fireBomb = spaceManager:CreateBomb(
					fireBombBlueprint,
					1 - crewmem.iShipId,
					enemyShip:GetRandomRoomCenter(),
					enemyShip.iShipId)
			end
		end

	elseif crewmem.type == "aea_old_unique_5" then
		--print("UNI5")
		crewShip = Hyperspace.ships(crewmem.iShipId)
		if crewShip:HasSystem(0) then
			crewShip.shieldSystem:AddSuperShield(crewShip.shieldSystem.superUpLoc)
			crewShip.shieldSystem:AddSuperShield(crewShip.shieldSystem.superUpLoc)
		end
	end
end)

local attachedTimer = 0

script.on_internal_event(Defines.InternalEvents.DAMAGE_BEAM, function(shipManager, projectile, location, damage, realNewTile, beamHitType)
	if projectile then
		if projectile.extend.name == "ARTILLERY_AEA_GRAPPLE" then
			attachedTimer = 25
		end
	end
end)

script.on_internal_event(Defines.InternalEvents.SHIELD_COLLISION, function(shipManager, projectile, damage, response)
	if projectile then
		if projectile.extend.name == "ARTILLERY_AEA_GRAPPLE" then
			shipManager.shieldSystem.shields.power.super.first = 0
		end
	end
end)

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	if shipManager.iShipId == 0 then
		attachedTimer = attachedTimer - Hyperspace.FPS.SpeedFactor/16
	end
	if attachedTimer > 0 then
		Hyperspace.playerVariables.aea_old_gate_guard_attached = 1
	else
		Hyperspace.playerVariables.aea_old_gate_guard_attached = 0
	end
end)

--[[script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
	local map = Hyperspace.App.world.starMap
	local startBeacon = nil
	local bossBeacon = nil
	local exitBeacon = nil
	for loc in vter(map.locations) do
		if loc.event then
			if loc.event.eventName == "ENTER_AEA_OLD_3" then
				--print("FOUND ENTER")
				startBeacon = loc
			elseif loc.event.eventName == "AEA_OLD_VICTORY" then
				--print("FOUND EXIT")
				exitBeacon = loc
			elseif loc.event.eventName == "AEA_OLD_3_BOSS" then
				--print("FOUND BOSS")
				bossBeacon = loc
			end
		end
	end

	if (startBeacon or bossBeacon or exitBeacon) and (not startBeacon) then
		--error("NO START BEACON PRESENT")
	end
	if (startBeacon or bossBeacon or exitBeacon) and (not bossBeacon) then
		--error("NO BOSS BEACON PRESENT")
	end
	if (startBeacon or bossBeacon or exitBeacon) and (not exitBeacon) then
		--error("NO EXIT BEACON PRESENT")
	end
	if (startBeacon and bossBeacon and exitBeacon) then
		--print("START")
		for loc in vter(map.locations) do
			loc.connectedLocations:clear()
		end

		startBeacon.connectedLocations:push_back(bossBeacon)

		bossBeacon.connectedLocations:push_back(startBeacon)
		bossBeacon.connectedLocations:push_back(exitBeacon)

		exitBeacon.connectedLocations:push_back(bossBeacon)
	end
end)]]


local uniqueCrewEnd = {}
local uniqueCrewIndex = {}
local eventToUniqueCrew = {}
local doc = RapidXML.xml_document("data/events_sector_showdown.xml")
for node in node_child_iter(doc:first_node("FTL") or doc) do
	if node:name() == "event" and node:first_attribute("name"):value() == "TRUE_VICTORY_CREW" then
		--print("found event")
		for choiceNode in node_child_iter(node) do
			if choiceNode:name() == "choice" and choiceNode:first_attribute("req"):value() then
				--print("found choice for unique crew:"..tostring(choiceNode:first_attribute("req"):value()))
				uniqueCrewEnd[choiceNode:first_attribute("req"):value()] = {}
				local tab = uniqueCrewEnd[choiceNode:first_attribute("req"):value()]
				table.insert(uniqueCrewIndex, choiceNode:first_attribute("req"):value())
				for textNode in node_child_iter(choiceNode) do
					if textNode:name() == "text" then
						tab.text = textNode:value()
					elseif textNode:name() == "event" and textNode:first_attribute("load"):value() then
						tab.event = textNode:first_attribute("load"):value()
						eventToUniqueCrew[textNode:first_attribute("load"):value()] = choiceNode:first_attribute("req"):value()
					end
				end
			end
		end
	end
end
for node in node_child_iter(doc:first_node("FTL") or doc) do
	if node:name() == "event" and eventToUniqueCrew[node:first_attribute("name"):value()] then
		--print("found event for unique crew:"..tostring(eventToUniqueCrew[node:first_attribute("name"):value()]))
		local crewId = eventToUniqueCrew[node:first_attribute("name"):value()]
		for choiceNode in node_child_iter(node) do
			if choiceNode:name() == "text-aea-alternative" then
				uniqueCrewEnd[crewId].eventText = choiceNode:value()
			elseif choiceNode:name() == "unlockCustomShip" then
				uniqueCrewEnd[crewId].ship = choiceNode:value()
				--print("add ship:"..choiceNode:value())
			end
		end
	end
end
doc:clear()

local genericResponse = {
	{format = false, text = "\"That was a close call, I'm glad we go out of there alive.\""},
	{format = false, text = "\"It would have been mighty disapointing if we had gone down there. And to think it would have happened when we were that close to escape.\""},
	{format = false, text = "\"Well, After that fight I'm convinved the rebel flagship stands no chance!\""},
	{format = true, text = "Well this certainly isn't the mission %s signed up for, but they're glad to be here either way."},
	{format = true, text = "You find %s drinking with the rest of the crew, \"Well, Even if we went down back there I don't think it would have been all that bad to be doing it with all of you.\""}
}

local hookedEvents = {}

script.on_internal_event(Defines.InternalEvents.PRE_CREATE_CHOICEBOX, function(event)
	local eventManager = Hyperspace.Event
	if event.eventName == "AEA_OLD_VICTORY_CREW" then
		event:RemoveChoice(0)
		for _, crewId in ipairs(uniqueCrewIndex) do
			local crewTable = uniqueCrewEnd[crewId]
			local pageEvent = eventManager:CreateEvent("AEA_OLD_VICTORY_", 0, false)
			pageEvent.eventName = "AEA_OLD_VICTORY_"..string.sub(crewTable.event, 19, string.len(crewTable.event))
			--print("create event:"..pageEvent.eventName)
			if not hookedEvents[pageEvent.eventName] then
				hookedEvents[pageEvent.eventName] = true
				script.on_game_event(pageEvent.eventName, false, function()
					Hyperspace.CustomShipUnlocks.instance:UnlockShip(crewTable.ship, false, true, true)
				end)
			end
			if crewTable.eventText then
				pageEvent.text.data = crewTable.eventText
			else
				local randomSelect = math.random(#genericResponse)
				if genericResponse[randomSelect].format then
					pageEvent.text.data = string.format(genericResponse[randomSelect].text, string.sub(crewTable.text, 5, string.len(crewTable.text) - 12))
				else
					pageEvent.text.data = genericResponse[randomSelect].text
				end
			end
			pageEvent.text.isLiteral = true
			local blueReq = Hyperspace.ChoiceReq()
			blueReq.object = crewId
			blueReq.blue = true
			blueReq.min_level = 1
			blueReq.max_level = mods.multiverse.INT_MAX
			blueReq.max_group = -1
			event:AddChoice(pageEvent, crewTable.text, blueReq, true)
		end
	end
end)

local function createBeam(projectile, weapon)
    local spaceManager = Hyperspace.App.world.space
    local beam = spaceManager:CreateBeam(
        weapon.blueprint,
        projectile.position,
        projectile.currentSpace,
        projectile.ownerId,
        projectile.target1,
        projectile.target2,
        projectile.destinationSpace,
        projectile.length,
        projectile.heading)
    spaceManager.projectiles:pop_back()
    beam.sub_start = projectile.sub_start
    beam.weapAnimation = projectile.weapAnimation
    return beam
end

mods.aea.burstBeams = {}
local burstBeams = mods.aea.burstBeams
burstBeams["AEA_FOCUS_OLD_1"] = 2
burstBeams["AEA_FOCUS_OLD_2"] = 3
burstBeams["AEA_FOCUS_OLD_3"] = 5
burstBeams["ARTILLERY_AEA_FOCUS_OLD"] = 3

script.on_internal_event(Defines.InternalEvents.PROJECTILE_FIRE, function(projectile, weapon)
	local burstData = burstBeams[projectile and projectile.extend and projectile.extend.name]
	if burstData and not userdata_table(projectile, "mods.aea.burstBeam").wasDuplicated then
		--print("start loop")
		local projectileNew = createBeam(projectile, weapon)
		if projectileNew then
            userdata_table(projectileNew, "mods.aea.burstBeam").wasDuplicated = 2
            weapon.queuedProjectiles:push_back(projectileNew)
        end
	elseif burstData and userdata_table(projectile, "mods.aea.burstBeam").wasDuplicated < burstData then
		--print("loop "..tostring(userdata_table(projectile, "mods.aea.burstBeam").wasDuplicated))
		local projectileNew = createBeam(projectile, weapon)
		if projectileNew then
            userdata_table(projectileNew, "mods.aea.burstBeam").wasDuplicated = userdata_table(projectile, "mods.aea.burstBeam").wasDuplicated + 1
            weapon.queuedProjectiles:push_back(projectileNew)
        end
	end
end)

local function update_burstBeam_text(blueprint, desc)
	if burstBeams[blueprint.name] then
		local descTable = desc:split("\n")
		local line = "Shots Per Charge: "..tostring(burstBeams[blueprint.name])
		desc = ""
		for s in ipairs(descTable) do
			desc = desc..s.."\n"
			if string.sub(s, 1, 11) == "Beam Speed:" then
				desc = desc..line.."\n"
			end
		end
	end
	return desc
end

script.on_internal_event(Defines.InternalEvents.WEAPON_DESCBOX, update_burstBeam_text)

script.on_internal_event(Defines.InternalEvents.WEAPON_STATBOX, update_burstBeam_text)

mods.aea.popPinpoints = {}
local popPinpoints = mods.aea.popPinpoints
popPinpoints["AEA_FOCUS_OLD_1"] = {endDamage = {count = 1, countSuper = 1}}
popPinpoints["AEA_FOCUS_OLD_2"] = {endDamage = {count = 1, countSuper = 1}}
popPinpoints["AEA_FOCUS_OLD_3"] = {endDamage = {count = 1, countSuper = 1}}
popPinpoints["ARTILLERY_AEA_FOCUS_OLD"] = {endDamage = {count = 1, countSuper = 1}}
-- Pop shield bubbles
local shieldsTouching = {}
local shieldsTouchingLast = {}

script.on_internal_event(Defines.InternalEvents.SHIELD_COLLISION, function(shipManager, projectile, damage, response)
    local shieldPower = shipManager.shieldSystem.shields.power
    local popData = popPinpoints[projectile and projectile.extend and projectile.extend.name]
    if popData and popData.startDamage and not userdata_table(projectile, "mods.aea.popBeams").startDamage then
    	local popDataStart = popData.startDamage
        if shieldPower.super.first > 0 then
            if popDataStart.countSuper > 0 then
                shipManager.shieldSystem:CollisionReal(projectile.shield_end.x, projectile.shield_end.y, Hyperspace.Damage(), true)
                shieldPower.super.first = math.max(0, shieldPower.super.first - popDataStart.countSuper)
            end
        else
            shipManager.shieldSystem:CollisionReal(projectile.shield_end.x, projectile.shield_end.y, Hyperspace.Damage(), true)
            shieldPower.first = math.max(0, shieldPower.first - popDataStart.count)
        end
        userdata_table(projectile, "mods.aea.popBeams").startDamage = true
    end
    if popData and popData.endDamage then
    	local popDataEnd = popData.endDamage
    	shieldsTouching[projectile.selfId] = {ship = shipManager.iShipId, count = popDataEnd.count, countSuper = popDataEnd.countSuper, position = {x=projectile.shield_end.x, y=projectile.shield_end.y}}
    end
end)

script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
	for id, tab in pairs(shieldsTouchingLast) do
		if not shieldsTouching[id] then
			local shipManager = Hyperspace.ships(tab.ship)
    		local shieldPower = shipManager.shieldSystem.shields.power
    		if shieldPower.super.first > 0 then
	            if tab.countSuper > 0 then
	                shipManager.shieldSystem:CollisionReal(tab.position.x, tab.position.y, Hyperspace.Damage(), true)
	                shieldPower.super.first = math.max(0, shieldPower.super.first - tab.countSuper)
	            end
	        else
	            shipManager.shieldSystem:CollisionReal(tab.position.x, tab.position.y, Hyperspace.Damage(), true)
	            shieldPower.first = math.max(0, shieldPower.first - tab.count)
	        end
		end
	end
	shieldsTouchingLast = {}
	for id, tab in pairs(shieldsTouching) do
		shieldsTouchingLast[id] = tab
	end
	shieldsTouching = {}
end)

local precursorList = {}
for blueprint in vter(Hyperspace.Blueprints:GetBlueprintList("BLUELIST_PRECURSOR_TECH")) do
	local weaponDesc = Hyperspace.Blueprints:GetWeaponBlueprint(blueprint).desc
	precursorList[blueprint] = {long = weaponDesc.title.data, short = weaponDesc.shortTitle.data, desc = weaponDesc.description.data, tip = weaponDesc.tip}
end

local function setPrecursorNames(original)
	for blueprint, blueTable in pairs(precursorList) do
		if original then
			local weaponDesc = Hyperspace.Blueprints:GetWeaponBlueprint(blueprint).desc
			weaponDesc.title.data = blueTable.long
			weaponDesc.shortTitle.data = blueTable.short
			weaponDesc.description.data = blueTable.desc
			--weaponDesc.tip = blueTable.tip
		else
			local weaponDesc = Hyperspace.Blueprints:GetWeaponBlueprint(blueprint).desc
			weaponDesc.title.data = "???"
			weaponDesc.shortTitle.data = "???"
			weaponDesc.description.data = "???"
			--weaponDesc.tip = "tip_aea_old_unknown"
		end
	end
end

local loadName = false
script.on_init(function(newGame)
    if newGame then
        setPrecursorNames(false)
    else
        loadName = true
    end
end)
script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    if loadName and Hyperspace.playerVariables.aea_test_variable == 1 then
        loadName = false
    	setPrecursorNames(Hyperspace.playerVariables.aea_old_activated_cell == 1)
    end
end)

script.on_game_event("AEA_GATE_NAME_SET", false, function()
	setPrecursorNames(true)
end)

local emptyReq = Hyperspace.ChoiceReq()
local blueReq = Hyperspace.ChoiceReq()
blueReq.object = "pilot"
blueReq.blue = true
blueReq.max_level = mods.multiverse.INT_MAX
blueReq.max_group = -1

local hookedUpgradeEvents = {}
script.on_internal_event(Defines.InternalEvents.PRE_CREATE_CHOICEBOX, function(event)
	if event.eventName == "STORAGE_CHECK_SYSTEM_AEA_OLD" then
		local player = Hyperspace.ships.player
		local eventManager = Hyperspace.Event
		for id, sys in pairs(mods.aea.systemIds) do
			local blueprint = systemBlueprintList[sys]
			local baseText = "Upgrade " .. blueprint.title .. "."
			if player:HasSystem(id) then
				local maxLevel = maxUpgrades[sys] or 1
				if Hyperspace.playerVariables["aea_old_"..sys.."_upgrades"] >= maxLevel or player:GetSystem(id):GetMaxPower() - (Hyperspace.playerVariables["aea_old_"..sys.."_upgrades"] or 0) > math.min(maxLevels[sys], Hyperspace.playerVariables[sys.."_cap_aea"]) then
					local tempEvent = eventManager:CreateEvent("OPTION_INVALID", 0, false)
					event:AddChoice(tempEvent, baseText.." [MAXED]", emptyReq, true)
				elseif Hyperspace.playerVariables.aea_old_activated_cell == 0 then
					local tempEvent = eventManager:CreateEvent("OPTION_INVALID", 0, false)
					event:AddChoice(tempEvent, baseText.." [TECH INACTIVE]", emptyReq, true)
				else
					local tempEvent = eventManager:CreateEvent("STORAGE_CHECK_SYSTEM_AEA_OLD_TEMPLATE", 0, false)
					tempEvent:RemoveChoice(0)
					tempEvent.eventName = "STORAGE_CHECK_SYSTEM_AEA_OLD_"..sys
					tempEvent.text.data = "You are about to install a "..blueprint.title.." system upgrade.\n[Effects: Upgrades "..blueprint.shortTitle.." beyond it's maximum level, cannot be done more than "..tostring(maxLevel).." times]."
					
					if player:GetSystem(id):GetMaxPower() >= Hyperspace.playerVariables[sys.."_cap_aea"] and player:HasEquipment("AEA_COMPONENT_OLD", true) > 0 then
						local upgradeEvent = eventManager:CreateEvent("STORAGE_CHECK_SYSTEM_AEA_OLD_TEMPLATE_UPGRADE", 0, false)
						upgradeEvent.eventName = "STORAGE_CHECK_SYSTEM_AEA_OLD_"..sys.."UPGRADE"
						upgradeEvent:RemoveChoice(0)

						local installEvent = eventManager:CreateEvent("INSTALL_AEA_OLD_TEMPLATE", 0, false)
						installEvent.eventName = "INSTALL_AEA_OLD_"..sys
						if not hookedUpgradeEvents[installEvent.eventName] then
							hookedUpgradeEvents[installEvent.eventName] = true
							script.on_game_event(installEvent.eventName, false, function()
								Hyperspace.playerVariables["aea_old_"..sys.."_upgrades"] = Hyperspace.playerVariables["aea_old_"..sys.."_upgrades"] + 1
								Hyperspace.ships.player:GetSystem(id):UpgradeSystem(1)
							end)
						end

						upgradeEvent:AddChoice(installEvent, "Continue...", emptyReq, true)
						tempEvent:AddChoice(upgradeEvent, "Perform the upgrade. [Cost: 120~, High Tech Component]", emptyReq, true)
					elseif player:GetSystem(id):GetMaxPower() >= Hyperspace.playerVariables[sys.."_cap_aea"] then
						local invalidEvent = eventManager:CreateEvent("OPTION_INVALID", 0, false)
						tempEvent:AddChoice(invalidEvent, "Perform the upgrade. [Cost: 120~, High Tech Component]", emptyReq, true)
					else
						local invalidEvent = eventManager:CreateEvent("OPTION_INVALID", 0, false)
						tempEvent:AddChoice(invalidEvent, "This upgrade is unavailable. You need to upgrade your "..blueprint.shortTitle.." to it's natural maximum.", emptyReq, true)
					end

					local neverEvent = eventManager:CreateEvent("STORAGE_CHECK_SYSTEM_LOAD", 0, false)
					tempEvent:AddChoice(neverEvent, "Nevermind", emptyReq, true)
					event:AddChoice(tempEvent, baseText.." [Cost: 120~, High Tech Component]", emptyReq, true)
				end
			elseif sys ~= "aea_clone_crime" then
				local tempEvent = eventManager:CreateEvent("OPTION_INVALID", 0, false)
				event:AddChoice(tempEvent, baseText.." [NO SYSTEM]", emptyReq, true)
			end
		end
	end
end)

script.on_game_event("INSTALL_AEA_OLD_REACTOR", false, function()
	local powerManager = Hyperspace.PowerManager.GetPowerManager(0)
	powerManager.currentPower.second = powerManager.currentPower.second + 1
end)

mods.aea.afterDamage = {}
local afterDamage = mods.aea.afterDamage
afterDamage["AEA_MISSILE_OLD_1"] = Hyperspace.Damage()
afterDamage["AEA_MISSILE_OLD_1"].iDamage = 2
afterDamage["AEA_MISSILE_OLD_2"] = Hyperspace.Damage()
afterDamage["AEA_MISSILE_OLD_2"].iDamage = 3
afterDamage["AEA_MISSILE_OLD_3"] = Hyperspace.Damage()
afterDamage["AEA_MISSILE_OLD_3"].iDamage = 4
afterDamage["AEA_MISSILE_OLD_3"].breachChance = 10

afterDamage["AEA_MISSILE_OLD_1_ENEMY"] = Hyperspace.Damage()
afterDamage["AEA_MISSILE_OLD_1_ENEMY"].iDamage = 1
afterDamage["AEA_MISSILE_OLD_2_ENEMY"] = Hyperspace.Damage()
afterDamage["AEA_MISSILE_OLD_2_ENEMY"].iDamage = 2
afterDamage["AEA_MISSILE_OLD_3_ENEMY"] = Hyperspace.Damage()
afterDamage["AEA_MISSILE_OLD_3_ENEMY"].iDamage = 3

afterDamage["ARTILLERY_AEA_MISSILE_OLD"] = Hyperspace.Damage()
afterDamage["ARTILLERY_AEA_MISSILE_OLD"].iDamage = 3
afterDamage["ARTILLERY_AEA_MISSILE_OLD"].breachChance = 10

script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA_HIT, function(shipManager, projectile, location, damage, shipFriendlyFire)
    if projectile and projectile.extend.name and afterDamage[projectile.extend.name] and not userdata_table(projectile, "mods.aea.afterDamage").damaged then
    	userdata_table(projectile, "mods.aea.afterDamage").damaged = true
    	shipManager:DamageArea(location, afterDamage[projectile.extend.name], true)
    end
end)

mods.aea.afterDamageRepeats = {}
local afterDamageRepeats = mods.aea.afterDamageRepeats
afterDamageRepeats["AEA_MISSILE_OLD_3"] = {damage = Hyperspace.Damage(), times = 4}
afterDamageRepeats["AEA_MISSILE_OLD_3"].damage.breachChance = 10

script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA_HIT, function(shipManager, projectile, location, damage, shipFriendlyFire)
    if projectile and projectile.extend.name and afterDamageRepeats[projectile.extend.name] and (userdata_table(projectile, "mods.aea.afterDamageRepeats").damaged or 0) < afterDamageRepeats[projectile.extend.name].times then
    	userdata_table(projectile, "mods.aea.afterDamageRepeats").damaged = (userdata_table(projectile, "mods.aea.afterDamageRepeats").damaged or 0) + 1
    	shipManager:DamageArea(location, afterDamageRepeats[projectile.extend.name].damage, true)
    end
end)

local is_first_shot = mods.multiverse.is_first_shot

mods.aea.fuelPowerCost = {}
local fuelPowerCost = mods.aea.fuelPowerCost
fuelPowerCost["AEA_MISSILE_OLD_1"] = 1
fuelPowerCost["AEA_MISSILE_OLD_2"] = 1
fuelPowerCost["AEA_MISSILE_OLD_3"] = 1

local function depowerWeapon(weapon, shipManager, powerManager)
	local shouldSetPower = true
	local weaponSystem = shipManager.weaponSystem
	if not powerManager then
		print("NO POWER MANAGER")
		return
	end
	for i = 1, weapon.requiredPower - weapon.iBonusPower do
		local required = weaponSystem.iRequiredPowewr
		--TODO: Lua needs to add an INOUT typemap for pass-by-pointer vars
		local powerState = weaponSystem.powerState

		local ret = true --powerManager:DecreasePower(powerState, weaponSystem.iBatteryPower, weaponSystem.requiredPower)

		local batteryPower = weaponSystem.iBatteryPower
		if powerState.first < 1 and batteryPower < 1 then 
			ret = false 
		elseif batteryPower < 1 then
			powerState.first = powerState.first - 1
			powerManager.currentPower.first = powerManager.currentPower.first - 1
		else
			if 0 < powerManager.batteryPower.first then
				powerManager.batteryPower.first = powerManager.batteryPower.first - 1
			end
			weaponSystem.iBatteryPower = weaponSystem.iBatteryPower - 1
		end

		weaponSystem.powerState = powerState
		if not ret then
			error("Failed to depower weapon")
		    shouldSetPower = false
		    break
		end
	end

	if shouldSetPower then
	  	weapon.powered = false
	end
end


script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(ship)
	local shipManager = Hyperspace.ships(ship.iShipId)
	local powerManager = Hyperspace.PowerManager.GetPowerManager(ship.iShipId)
	if shipManager and powerManager and shipManager:HasSystem(3) and shipManager.iShipId == 0 then
		for weapon in vter(shipManager.weaponSystem.weapons) do
			if fuelPowerCost[weapon.blueprint.name] and weapon.powered and not userdata_table(weapon, "mods.aea.fuelPowerCost").fueled then
				if shipManager.fuel_count - fuelPowerCost[weapon.blueprint.name] < 0 then
					depowerWeapon(weapon, shipManager, powerManager)
					userdata_table(weapon, "mods.aea.fuelPowerCost").warningMessage = 3
				else
					shipManager.fuel_count = shipManager.fuel_count - fuelPowerCost[weapon.blueprint.name]
					userdata_table(weapon, "mods.aea.fuelPowerCost").fueled = true
				end
			end
		end
	end
end)

script.on_internal_event(Defines.InternalEvents.WEAPON_RENDERBOX, function(weapon, cooldown, maxCooldown, firstLine, secondLine, thirdLine)
	local shipManager = Hyperspace.ships(weapon.iShipId)
	if fuelPowerCost[weapon.blueprint.name] and userdata_table(weapon, "mods.aea.fuelPowerCost").fueled then
		secondLine = "Fueled"
	elseif fuelPowerCost[weapon.blueprint.name] then
		secondLine = "Unfueled"
	end
	if fuelPowerCost[weapon.blueprint.name] and userdata_table(weapon, "mods.aea.fuelPowerCost").warningMessage then
		local powerTable = userdata_table(weapon, "mods.aea.fuelPowerCost")
		powerTable.warningMessage = powerTable.warningMessage - Hyperspace.FPS.SpeedFactor/16
		thirdLine = "No Fuel!"
		if powerTable.warningMessage <= 0 then
			userdata_table(weapon, "mods.aea.fuelPowerCost").warningMessage = nil
		end
	end

	return Defines.Chain.HALT, firstLine, secondLine, thirdLine
end)

script.on_internal_event(Defines.InternalEvents.JUMP_ARRIVE, function(shipManager)
	if shipManager and shipManager:HasSystem(3) and shipManager.iShipId == 0 then
		for weapon in vter(shipManager.weaponSystem.weapons) do
			if userdata_table(weapon, "mods.aea.fuelPowerCost").fueled then
				userdata_table(weapon, "mods.aea.fuelPowerCost").fueled = nil
			end
		end
	end
end)

mods.aea.fuelAmmoCost = {}
local fuelAmmoCost = mods.aea.fuelAmmoCost

script.on_internal_event(Defines.InternalEvents.PROJECTILE_FIRE, function(projectile, weapon)
	if fuelAmmoCost[weapon.blueprint.name] and is_first_shot(weapon, true) and shipManager.iShipId == 0 and not weapon.isArtillery then
		local shipManager = Hyperspace.ships(weapon.iShipId)
		shipManager.fuel_count = shipManager.fuel_count - 1
	end
end)

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(ship)
	local shipManager = Hyperspace.ships(ship.iShipId)
	local powerManager = Hyperspace.PowerManager.GetPowerManager(ship.iShipId)
	if shipManager and shipManager:HasSystem(3) and shipManager.iShipId == 0 then
		for weapon in vter(shipManager.weaponSystem.weapons) do
			if fuelAmmoCost[weapon.blueprint.name] and shipManager.fuel_count - fuelAmmoCost[weapon.blueprint.name] < 0 and weapon.powered then
				depowerWeapon(weapon, shipManager, powerManager)
			end
		end
	end
end)

script.on_internal_event(Defines.InternalEvents.WEAPON_RENDERBOX, function(weapon, cooldown, maxCooldown, firstLine, secondLine, thirdLine)
	local shipManager = Hyperspace.ships(weapon.iShipId)
	if fuelAmmoCost[weapon.blueprint.name] and shipManager.fuel_count - fuelAmmoCost[weapon.blueprint.name] < 0 and shipManager.iShipId == 0 then
		secondLine = "Out of Fuel"
	end
	return Defines.Chain.HALT, firstLine, secondLine, thirdLine
end)

mods.aea.customFiringSound = {}
local customFiringSound = mods.aea.customFiringSound
customFiringSound["AEA_MISSILE_OLD_1"] = "aea_halo_railgun"
customFiringSound["AEA_MISSILE_OLD_2"] = "aea_halo_railgun"
customFiringSound["AEA_MISSILE_OLD_3"] = "aea_halo_railgun"
customFiringSound["AEA_MISSILE_OLD_1_ENEMY"] = "aea_halo_railgun"
customFiringSound["AEA_MISSILE_OLD_2_ENEMY"] = "aea_halo_railgun"
customFiringSound["AEA_MISSILE_OLD_3_ENEMY"] = "aea_halo_railgun"
customFiringSound["ARTILLERY_AEA_MISSILE_OLD"] = "aea_halo_railgun"

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(ship)
	local shipManager = Hyperspace.ships(ship.iShipId)
	if shipManager and shipManager:HasSystem(3) then
		for weapon in vter(shipManager.weaponSystem.weapons) do
			if customFiringSound[weapon.blueprint.name] and weapon.weaponVisual.bFiring and not userdata_table(weapon, "mods.aea.customFiringSound").fired then
				userdata_table(weapon, "mods.aea.customFiringSound").fired = true
				Hyperspace.Sounds:PlaySoundMix(customFiringSound[weapon.blueprint.name], -1, false)
			elseif customFiringSound[weapon.blueprint.name] and userdata_table(weapon, "mods.aea.customFiringSound").fired and not weapon.weaponVisual.bFiring then
				userdata_table(weapon, "mods.aea.customFiringSound").fired = nil
			end
		end
	end
	if shipManager and shipManager:HasSystem(11) then
		for artillery in vter(shipManager.artillerySystems) do
			local weapon = artillery.projectileFactory
			if customFiringSound[weapon.blueprint.name] and weapon.weaponVisual.bFiring and not userdata_table(weapon, "mods.aea.customFiringSound").fired then
				userdata_table(weapon, "mods.aea.customFiringSound").fired = true
				Hyperspace.Sounds:PlaySoundMix(customFiringSound[weapon.blueprint.name], -1, false)
			elseif customFiringSound[weapon.blueprint.name] and userdata_table(weapon, "mods.aea.customFiringSound").fired and not weapon.weaponVisual.bFiring then
				userdata_table(weapon, "mods.aea.customFiringSound").fired = nil
			end
		end
	end
end)

mods.aea.doorSmash = {}
local doorSmash = mods.aea.doorSmash
doorSmash["AEA_MISSILE_OLD_3"] = true
doorSmash["AEA_MISSILE_OLD_3_ENEMY"] = true
doorSmash["ARTILLERY_AEA_MISSILE_OLD"] = true

mods.aea.smashedRooms = {[0] = {}, [1] = {}}
local smashedRooms = mods.aea.smashedRooms

script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA_HIT, function(shipManager, projectile, location, damage, shipFriendlyFire)
    if projectile and projectile.extend.name and doorSmash[projectile.extend.name] and not userdata_table(projectile, "mods.aea.doorSmash").smashed then
    	userdata_table(projectile, "mods.aea.doorSmash").smashed = true
    	local roomId = get_room_at_location(shipManager, location, false)
    	smashedRooms[shipManager.iShipId][roomId] = {time = 7}
    	local animationsTable = {}
    	for door in vter(shipManager.ship.vDoorList) do
			if door.iRoom1 == roomId or door.iRoom2 == roomId then
				door.forcedOpen:Start(0)

				local name = "aea_door_sparks_hor"
				if door.bVertical then name = "aea_door_sparks_ver" end

				local anim = Hyperspace.Animations:GetAnimation(name)
				anim.position.x = door.x - anim.info.frameWidth/2
				anim.position.y = door.y - anim.info.frameHeight/2
				anim.tracker.loop = true
				anim:Start(true)
				local randomFrame = math.random(15)
				anim:SetCurrentFrame(randomFrame)
				table.insert(animationsTable, anim)
			end
		end
		smashedRooms[shipManager.iShipId][roomId].animations = animationsTable
    end
end)

script.on_internal_event(Defines.InternalEvents.JUMP_LEAVE, function()
	smashedRooms[1] = {}
end)

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	local smRooms = smashedRooms[shipManager.iShipId]
	for room in vter(shipManager.ship.vRoomList) do
		if smRooms[room.iRoomId] then
			for _, anim in ipairs(smRooms[room.iRoomId].animations) do
				anim:Update()
			end
			smRooms[room.iRoomId].time = smRooms[room.iRoomId].time - Hyperspace.FPS.SpeedFactor/16
			if smRooms[room.iRoomId].time <= 0 then
				smRooms[room.iRoomId] = nil
			end
		end
	end
end)

script.on_render_event(Defines.RenderEvents.SHIP_SPARKS, function(ship) 
	local shipManager = Hyperspace.ships(ship.iShipId)
	local smRooms = smashedRooms[shipManager.iShipId]
	for room in vter(shipManager.ship.vRoomList) do
		if smRooms[room.iRoomId] then
			for _, anim in ipairs(smRooms[room.iRoomId].animations) do
				anim:OnRender(1, Graphics.GL_Color(1, 1, 1, 1), false)
			end
		end
	end
end, function(ship) end)

local function blueprint_set(name)
    local set = {}
    local bpList = Hyperspace.Blueprints:GetBlueprintList(name)
    for name in vter(bpList) do
       set[name] = true
    end
    return set
end
local lylmik_crew = blueprint_set("LIST_CREW_AEA_OLD")
script.on_internal_event(Defines.InternalEvents.CREW_LOOP, function(crew)
	if lylmik_crew[crew.type] and crew.bDead and crew.currentShipId == 0 then
		local crewLoc = crew:GetPosition()
		userdata_table(crew, "mods.aea.lylmik_revive").revive_loc = {x = crewLoc.x, y = crewLoc.y}
	end
end)

local offline = Hyperspace.Resources:CreateImagePrimitiveString("people/aea_old_1_offline.png", -17, -17, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false)

script.on_render_event(Defines.RenderEvents.SHIP_FLOOR, function() end, function(ship) 
	if ship.iShipId == 0 then
        for crew in vter(Hyperspace.CrewFactory.crewMembers) do
            if crew.iShipId == ship.iShipId and not crew:IsDrone() and lylmik_crew[crew.type] then
                if (crew.bOutOfGame or crew.crewAnim.status == 3) and not crew.clone_ready then
                    local userTable = userdata_table(crew, "mods.aea.lylmik_revive")
                    if userTable.revive_loc and not userTable.once_this_beacon then
                    	Graphics.CSurface.GL_PushMatrix()
						Graphics.CSurface.GL_Translate(userTable.revive_loc.x,userTable.revive_loc.y,0)
						Graphics.CSurface.GL_RenderPrimitiveWithAlpha(offline, 0.5)
						Graphics.CSurface.GL_PopMatrix()
                    end
                end
            end
        end
    end
end)

local function revive(shipManager)
    if shipManager.iShipId == 0 then
        for crew in vter(Hyperspace.CrewFactory.crewMembers) do
            if crew.iShipId == shipManager.iShipId and not crew:IsDrone() and lylmik_crew[crew.type] and not userdata_table(crew, "mods.aea.lylmik_revive").dismissed then
                

                if (crew.bOutOfGame or crew.crewAnim.status == 3) and not crew.clone_ready then
                	if userdata_table(crew, "mods.aea.lylmik_revive").once_this_beacon then
                		userdata_table(crew, "mods.aea.lylmik_revive").dismissed = true
                		return
                	end
                    if crew.bOutOfGame then
                        crew:SetCurrentShip(shipManager.iShipId)
                        crew.ship = shipManager.ship
                        crew:SetRoom(0)
                        shipManager.vCrewList:push_back(crew)
                    end
                    crew.bOutOfGame = false
                    crew.bDead = false
                    crew.health.first = crew.health.second
                    crew.crewAnim.status = 0
                    local userTable = userdata_table(crew, "mods.aea.lylmik_revive")
                    if userTable.revive_loc then
                    	local roomSpawn = get_room_at_location(shipManager, userTable.revive_loc, true)
                    	if roomSpawn then
                    		crew:SetRoom(roomSpawn)
                    	end
                    end
                    userdata_table(crew, "mods.aea.lylmik_revive").once_this_beacon = true
                end
            end
        end
    end
end
script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	local gui = Hyperspace.App.gui
	if shipManager.iShipId == 0 and gui.upgradeButton.bActive and not gui.event_pause then
		revive(shipManager)
	end
end)
script.on_internal_event(Defines.InternalEvents.JUMP_LEAVE, revive)
script.on_internal_event(Defines.InternalEvents.ON_WAIT, revive)

local function revive_reset(shipManager)
	if shipManager.iShipId == 0 then
		for crewmem in vter(shipManager.vCrewList) do
			if userdata_table(crewmem, "mods.aea.lylmik_revive").once_this_beacon then
				userdata_table(crewmem, "mods.aea.lylmik_revive").once_this_beacon = false
			end
		end
	end
end
script.on_internal_event(Defines.InternalEvents.JUMP_LEAVE, revive_reset)
script.on_internal_event(Defines.InternalEvents.ON_WAIT, revive_reset)

local gate_image = Hyperspace.Resources:CreateImagePrimitiveString("map/map_icon_aea_old_gate.png", -32, -32, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false)
gate_image.textureAntialias = true

local gateEvents = {}
gateEvents["AEA_OLD_VICTORY"] = true
gateEvents["AEA_OLD_GATE"] = true

script.on_render_event(Defines.RenderEvents.GUI_CONTAINER, function() end, function()
	local map = Hyperspace.App.world.starMap
	if map.bOpen and not map.bChoosingNewSector then
		for beacon in vter(map.locations) do
			if gateEvents[beacon.event.eventName] then
				Graphics.CSurface.GL_PushMatrix()
				Graphics.CSurface.GL_Translate(beacon.loc.x + 385 + 9, beacon.loc.y + 123 + 9, 0)
				Graphics.CSurface.GL_RenderPrimitive(gate_image)
				Graphics.CSurface.GL_PopMatrix()
			end
		end
	end
end)