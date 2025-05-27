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

armouredShips["AEA_OLD_GUARD_BOSS"] = {r2 = true, r3 = true, r28 = true, r30 = true}
armouredShips["AEA_OLD_FINAL_BOSS_CASUAL"] = {r2 = true, r3 = true}
armouredShips["AEA_OLD_FINAL_BOSS_NORMAL"] = {r2 = true, r3 = true}
armouredShips["AEA_OLD_FINAL_BOSS_CHALLENGE"] = {r2 = true, r3 = true}
armouredShips["AEA_OLD_FINAL_BOSS_EXTREME"] = {r2 = true, r3 = true}
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


local setSystemMaxVars = false
script.on_init(function() setSystemMaxVars = true end)
script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
	if log_events then
		--log("ON_TICK 2")
	end
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
	powerManager.currentPower.second = powerManager.currentPower.second + 1
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

script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
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
end)


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