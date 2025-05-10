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

local function is_first_shot(weapon, afterFirstShot)
    local shots = weapon.numShots
    if weapon.weaponVisual.iChargeLevels > 0 then shots = shots*(weapon.weaponVisual.boostLevel + 1) end
    if weapon.blueprint.miniProjectiles:size() > 0 then shots = shots*weapon.blueprint.miniProjectiles:size() end
    if afterFirstShot then shots = shots - 1 end
    return shots == weapon.queuedProjectiles:size()
end

local spawn_temp_drone = mods.multiverse.spawn_temp_drone

local node_child_iter = mods.multiverse.node_child_iter



local hasWarp = false
local protectionTable = {}
local protectionTableEnemy = {}
local protectionImage = Hyperspace.Resources:CreateImagePrimitiveString("people/energy_shield_buff.png", -16, -18, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
local crosshairImage = Hyperspace.Resources:CreateImagePrimitiveString("misc/crosshairs_placed_aea_magic.png", -20, -20, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
local crosshairImage2 = Hyperspace.Resources:CreateImagePrimitiveString("misc/crosshairs_placed_aea_magic_yellow.png", -20, -20, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)

local function checkforWarp()
	if Hyperspace.ships.player then
		for crewp in vter(Hyperspace.ships.player.vCrewList) do
			if crewp.type == "aea_cult_wizard_a07" or crewp.type == "aea_cult_wizard_s08" or crewp.type == "aea_cult_tiny_a07" or crewp.type == "aea_cult_tiny_s08" then
				hasWarp = true
				return
			end
		end
	end
	if Hyperspace.ships.enemy then
		if Hyperspace.ships.enemy.vCrewList then
			for crewe in vter(Hyperspace.ships.enemy.vCrewList) do
				if crewe.type == "aea_cult_wizard_a07" or crewe.type == "aea_cult_wizard_s08" or crewe.type == "aea_cult_tiny_a07" or crewe.type == "aea_cult_tiny_s08" then
					hasWarp = true
					return
				end
			end
		end
	end
	hasWarp = false
end

script.on_internal_event(Defines.InternalEvents.JUMP_ARRIVE, function()
	if log_events then
		log("JUMP_ARRIVE 6")
	end
	checkforWarp()
	protectionTable = {}
	protectionTableEnemy = {}
end)

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(ship)
	if log_events then
		--log("SHIP_LOOP 8")
	end
	if ship.iShipId == 0 then
		for room, tab in pairs(protectionTable) do
			--print(room)
			local shipManager = Hyperspace.ships.player
			tab[1] = tab[1] - Hyperspace.FPS.SpeedFactor/16
			if tab[1] <= 0 then
				--print("END")
				local crewRoom = nil
				for roomLoop in vter(shipManager.ship.vRoomList) do
					if roomLoop.iRoomId == room then
						crewRoom = roomLoop
					end
				end
				if crewRoom then
					--print("HULL ORIG: "..tostring(tab[2]).."SYS ORIG: "..tostring(tab[3]))
					crewRoom.extend.hullDamageResistChance = tab[2]
					crewRoom.extend.sysDamageResistChance = tab[3]
				end
				protectionTable[room] = nil
			end
		end
	end

	if ship.iShipId == 1 then
		for room, tab in pairs(protectionTableEnemy) do
			local shipManager = Hyperspace.ships.enemy
			tab[1] = tab[1] - Hyperspace.FPS.SpeedFactor/16
			if tab[1] <= 0 then
				--print("END")
				local crewRoom = nil
				for roomLoop in vter(shipManager.ship.vRoomList) do
					if roomLoop.iRoomId == room then
						crewRoom = roomLoop
					end
				end
				if crewRoom then
					--print("HULL ORIG: "..tostring(tab[2]).."SYS ORIG: "..tostring(tab[3]))
					crewRoom.extend.hullDamageResistChance = tab[2]
					crewRoom.extend.sysDamageResistChance = tab[3]
				end
				protectionTable[room] = nil
			end
		end
	end
end)

script.on_render_event(Defines.RenderEvents.SHIP_SPARKS, function() end, function(ship)
	if ship.iShipId == 0 then
		for room, tab in pairs(protectionTable) do
			--print(room)
			local shipManager = Hyperspace.ships.player
			local roomPos = shipManager:GetRoomCenter(room)
			Graphics.CSurface.GL_PushMatrix()
			Graphics.CSurface.GL_Translate(roomPos.x,roomPos.y,0)
			Graphics.CSurface.GL_RenderPrimitive(protectionImage)
			Graphics.CSurface.GL_PopMatrix()
		end
	end

	if ship.iShipId == 1 then
		for room, tab in pairs(protectionTableEnemy) do
			local shipManager = Hyperspace.ships.enemy
			local roomPos = shipManager:GetRoomCenter(room)
			Graphics.CSurface.GL_PushMatrix()
			Graphics.CSurface.GL_Translate(roomPos.x,roomPos.y,0)
			Graphics.CSurface.GL_RenderPrimitive(protectionImage)
			Graphics.CSurface.GL_PopMatrix()
		end
	end
end)

local function fire_spell(crewmem, targetManager, spell, target_room, bTarget_crew)
	local spaceManager = Hyperspace.Global.GetInstance():GetCApp().world.space
	local spellLaser = Hyperspace.Blueprints:GetWeaponBlueprint("AEA_LASER_SFAKE")
	local target_pos = targetManager:GetRandomRoomCenter()
	if target_room then
		target_pos = targetManager:GetRoomCenter(target_room)
	elseif bTarget_crew then
		local cTab = targetManager.vCrewList
		if cTab:size() > 1 then
			target_pos = targetManager:GetRoomCenter(cTab[math.random(0, cTab:size() - 1)].iRoomId)
		elseif cTab:size() == 1 then
			target_pos = targetManager:GetRoomCenter(cTab[0].iRoomId)
		end
	end

	local laser = spaceManager:CreateLaserBlast(
		spellLaser,
		Hyperspace.Pointf(crewmem.x, crewmem.y),
		crewmem.currentShipId,
		1-targetManager.iShipId,
		target_pos,
		targetManager.iShipId,
		0)
	userdata_table(laser, "mods.aea.spell").owner = crewmem.iShipId
	userdata_table(laser, "mods.aea.spell").spellName = spell
end

script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA_HIT, function(shipManager, projectile, location, damage, shipFriendlyFire)
	if log_events then
		log("DAMAGE_AREA_HIT 2")
	end
	if not projectile then return Defines.Chain.CONTINUE end
	local spaceManager = Hyperspace.Global.GetInstance():GetCApp().world.space
	local spellTable = userdata_table(projectile, "mods.aea.spell")
	if spellTable.owner then
		local spellprint = Hyperspace.Blueprints:GetWeaponBlueprint(spellTable.spellName)
		local bomb = spaceManager:CreateBomb(
			spellprint,
			spellTable.owner,
			location,
			shipManager.iShipId)
	end
	return Defines.Chain.CONTINUE
end)

local function activate_magic(crewmem, magic, target_room, target_ship)
	local shipManager = Hyperspace.ships(crewmem.currentShipId)
	local otherManager = Hyperspace.ships(1-crewmem.currentShipId)
	local crewManager = Hyperspace.ships(crewmem.iShipId)
	local enemyManager = Hyperspace.ships(1-crewmem.iShipId)
	local spaceManager = Hyperspace.Global.GetInstance():GetCApp().world.space

	

	if magic == "01" then
		Hyperspace.Sounds:PlaySoundMix("ampere_zap", -1, false)
		local crewRoom = nil
		for room in vter(shipManager.ship.vRoomList) do
			if room.iRoomId == crewmem.iRoomId then
				crewRoom = room
				--print("GET ROOM")
			end
		end
		if crewRoom then
			if crewmem.currentShipId == 0 then
				if protectionTable[crewmem.iRoomId] then
					protectionTable[crewmem.iRoomId] = {20, protectionTable[crewmem.iRoomId][2], protectionTable[crewmem.iRoomId][3]}
					--print("HULL ORIG: "..tostring(protectionTable[crewmem.iRoomId][2]).."SYS ORIG: "..tostring(protectionTable[crewmem.iRoomId][3]))
				else
					local hullRes = 0.0
					local sysRes = 0.0
					if crewRoom.extend.hullDamageResistChance then
						hullRes = crewRoom.extend.hullDamageResistChance
					end
					if crewRoom.extend.sysDamageResistChance then
						sysRes = crewRoom.extend.sysDamageResistChance
					end
					protectionTable[crewmem.iRoomId] = {20, hullRes, sysRes}
					crewRoom.extend.hullDamageResistChance = 100
					crewRoom.extend.sysDamageResistChance = 100
					--print("HULL ORIG: "..tostring(protectionTable[crewmem.iRoomId][2]).."SYS ORIG: "..tostring(protectionTable[crewmem.iRoomId][3]))
				end
			else
				if protectionTableEnemy[crewmem.iRoomId] then
					protectionTableEnemy[crewmem.iRoomId] = {20, protectionTableEnemy[crewmem.iRoomId][2], protectionTableEnemy[crewmem.iRoomId][3]}
					--print("HULL ORIG: "..tostring(protectionTable[crewmem.iRoomId][2]).."SYS ORIG: "..tostring(protectionTable[crewmem.iRoomId][3]))
				else
					local hullRes = 0.0
					local sysRes = 0.0
					if crewRoom.extend.hullDamageResistChance then
						hullRes = crewRoom.extend.hullDamageResistChance
					end
					if crewRoom.extend.sysDamageResistChance then
						sysRes = crewRoom.extend.sysDamageResistChance
					end
					protectionTableEnemy[crewmem.iRoomId] = {20, hullRes, sysRes}
					crewRoom.extend.hullDamageResistChance = 100
					crewRoom.extend.sysDamageResistChance = 100
					--print("HULL ORIG: "..tostring(protectionTable[crewmem.iRoomId][2]).."SYS ORIG: "..tostring(protectionTable[crewmem.iRoomId][3]))
				end
			end
			
		end
	elseif magic == "02" then
		Hyperspace.Sounds:PlaySoundMix("ampere_zap", -1, false)
		for projectile in vter(spaceManager.projectiles) do
			if projectile.ownerId == (1 - crewmem.iShipId) and projectile.destinationSpace == crewmem.currentShipId then
				projectile.target = shipManager:GetRoomCenter(crewmem.iRoomId)
				projectile:ComputeHeading()
			end
		end
	elseif magic == "03" then
		local targetManager = Hyperspace.ships(1-crewmem.iShipId)
		if target_ship then
			targetManager = Hyperspace.ships(target_ship)
		end
		Hyperspace.Sounds:PlaySoundMix("fire_blast", -1, false)
		fire_spell(crewmem, targetManager, "AEA_LASER_SPELL_03", target_room, true)
	elseif magic == "04" then
		local targetManager = Hyperspace.ships(1-crewmem.iShipId)
		if target_ship then
			targetManager = Hyperspace.ships(target_ship)
		end
		Hyperspace.Sounds:PlaySoundMix("fire_blast", -1, false)
		fire_spell(crewmem, targetManager, "AEA_LASER_SPELL_04", target_room, false)
	elseif magic == "05" then
		local targetManager = Hyperspace.ships(1-crewmem.iShipId)
		if target_ship then
			targetManager = Hyperspace.ships(target_ship)
		end
		Hyperspace.Sounds:PlaySoundMix("fire_blast", -1, false)
		fire_spell(crewmem, targetManager, "AEA_LASER_SPELL_04", target_room, false)
		fire_spell(crewmem, targetManager, "AEA_LASER_SPELL_04", target_room, false)
		fire_spell(crewmem, targetManager, "AEA_LASER_SPELL_04", target_room, false)
	elseif magic == "06" then
		local targetManager = Hyperspace.ships(1-crewmem.iShipId)
		if target_ship then
			targetManager = Hyperspace.ships(target_ship)
		end
		Hyperspace.Sounds:PlaySoundMix("fire_blast", -1, false)
		fire_spell(crewmem, targetManager, "AEA_LASER_SPELL_06", target_room, false)
	elseif magic == "07" then
		local target_pos = otherManager:GetRandomRoomCenter()
		for crewRoom in vter(shipManager.vCrewList) do
			if crewRoom.iRoomId == crewmem.iRoomId and crewRoom.extend.selfId ~= crewmem.extend.selfId and not crewmem:IsDrone() then
				crewRoom.extend:InitiateTeleport(otherManager.iShipId, get_room_at_location(otherManager,target_pos,false), 0)
			end
		end
		crewmem.extend:InitiateTeleport(otherManager.iShipId, get_room_at_location(otherManager,target_pos,false), 0)
	elseif magic == "08" then
		local targetManager = Hyperspace.ships(1-crewmem.iShipId)
		if target_ship then
			targetManager = Hyperspace.ships(target_ship)
		end
		Hyperspace.Sounds:PlaySoundMix("fire_blast", -1, false)
		fire_spell(crewmem, targetManager, "AEA_LASER_SPELL_08", target_room, true)
	elseif magic == "09" then
		local targetManager = Hyperspace.ships(crewmem.iShipId)
		if target_ship then
			targetManager = Hyperspace.ships(target_ship)
		end
		Hyperspace.Sounds:PlaySoundMix("fire_blast", -1, false)
		fire_spell(crewmem, targetManager, "AEA_LASER_SPELL_09", target_room, true)
	elseif magic == "10" then
		Hyperspace.Sounds:PlaySoundMix("fire_blast", -1, false)
		local spellprint = Hyperspace.Blueprints:GetWeaponBlueprint("AEA_LASER_SPELL_10")
		local target_pos = shipManager:GetRoomCenter(crewmem.iRoomId)
		local bomb = spaceManager:CreateBomb(
			spellprint,
			crewmem.iShipId,
			target_pos,
			crewmem.currentShipId)
	elseif magic == "11" then
		local droneBlueprint = Hyperspace.Blueprints:GetDroneBlueprint("AEA_COMBAT_SPELL_11")
		local drone2 = spawn_temp_drone(
				droneBlueprint,
				crewManager,
				enemyManager,
				nil,
				9999,
				nil)
		userdata_table(drone2, "mods.mv.droneStuff").clearOnJump = true
	elseif magic == "12" then
		local targetManager = Hyperspace.ships(crewmem.iShipId)
		if target_ship then
			targetManager = Hyperspace.ships(target_ship)
		end
		Hyperspace.Sounds:PlaySoundMix("fire_blast", -1, false)
		fire_spell(crewmem, targetManager, "AEA_LASER_SPELL_12", target_room, true)
	elseif magic == "13" then
		local targetManager = Hyperspace.ships(1-crewmem.iShipId)
		if target_ship then
			targetManager = Hyperspace.ships(target_ship)
		end
		Hyperspace.Sounds:PlaySoundMix("fire_blast", -1, false)
		fire_spell(crewmem, targetManager, "AEA_LASER_SPELL_13", target_room, true)
	elseif magic == "14" then
		local targetManager = Hyperspace.ships(1-crewmem.iShipId)
		if target_ship then
			targetManager = Hyperspace.ships(target_ship)
		end
		Hyperspace.Sounds:PlaySoundMix("fire_blast", -1, false)
		fire_spell(crewmem, targetManager, "AEA_LASER_SPELL_14", target_room, true)
	elseif magic == "15" then
		local targetManager = Hyperspace.ships(1-crewmem.iShipId)
		if target_ship then
			targetManager = Hyperspace.ships(target_ship)
		end
		Hyperspace.Sounds:PlaySoundMix("fire_blast", -1, false)
		fire_spell(crewmem, targetManager, "AEA_LASER_SPELL_15", target_room, true)
	elseif magic == "16" then
	elseif magic == "17" then
	elseif magic == "18" then
	elseif magic == "19" then
	elseif magic == "20" then
	else
		Hyperspace.Sounds:PlaySoundMix("fire_blast", -1, false)
	end
end

randomOffSpells = RandomList:New {"AEA_LASER_SPELL_04", "AEA_LASER_SPELL_04", "AEA_LASER_SPELL_06", "AEA_COMBAT_SPELL_11", "AEA_LASER_SPELL_13"}
randomSupSpells = RandomList:New {"AEA_LASER_SPELL_12", "AEA_LASER_SPELL_14", "AEA_LASER_SPELL_01"}
randomBorSpells = RandomList:New {"AEA_LASER_SPELL_03", "AEA_LASER_SPELL_08", "AEA_LASER_SPELL_14", "AEA_LASER_SPELL_15"}

local function activate_priest(crewmem, target_room, target_ship, type)
	local shipManager = Hyperspace.ships(crewmem.currentShipId)
	local otherManager = Hyperspace.ships(1-crewmem.currentShipId)
	local crewManager = Hyperspace.ships(crewmem.iShipId)
	local enemyManager = Hyperspace.ships(1-crewmem.iShipId)
	local spaceManager = Hyperspace.Global.GetInstance():GetCApp().world.space

	local targetManager = Hyperspace.ships(1-crewmem.iShipId)
	if target_ship then
		targetManager = Hyperspace.ships(target_ship)
	end

	if type == "off" then
		Hyperspace.Sounds:PlaySoundMix("fire_blast", -1, false)
		local spell = randomOffSpells:GetItem()
		if spell == "AEA_COMBAT_SPELL_11" then
			local droneBlueprint = Hyperspace.Blueprints:GetDroneBlueprint("AEA_COMBAT_SPELL_11")
			local drone2 = spawn_temp_drone(
					droneBlueprint,
					crewManager,
					enemyManager,
					nil,
					9999,
					nil)
			userdata_table(drone2, "mods.mv.droneStuff").clearOnJump = true
		else
			--print("FIRE OFF:"..spell)
			fire_spell(crewmem, targetManager, spell, target_room, false)
		end
	elseif type == "sup" then
		Hyperspace.Sounds:PlaySoundMix("fire_blast", -1, false)
		local spell = randomSupSpells:GetItem()
		if spell == "AEA_LASER_SPELL_01" then
			Hyperspace.Sounds:PlaySoundMix("ampere_zap", -1, false)
			local crewRoom = nil
			for room in vter(shipManager.ship.vRoomList) do
				if room.iRoomId == crewmem.iRoomId then
					crewRoom = room
					--print("GET ROOM")
				end
			end
			if crewRoom then
				if crewmem.currentShipId == 0 then
					if protectionTable[crewmem.iRoomId] then
						protectionTable[crewmem.iRoomId] = {20, protectionTable[crewmem.iRoomId][2], protectionTable[crewmem.iRoomId][3]}
						--print("HULL ORIG: "..tostring(protectionTable[crewmem.iRoomId][2]).."SYS ORIG: "..tostring(protectionTable[crewmem.iRoomId][3]))
					else
						local hullRes = 0.0
						local sysRes = 0.0
						if crewRoom.extend.hullDamageResistChance then
							hullRes = crewRoom.extend.hullDamageResistChance
						end
						if crewRoom.extend.sysDamageResistChance then
							sysRes = crewRoom.extend.sysDamageResistChance
						end
						protectionTable[crewmem.iRoomId] = {20, hullRes, sysRes}
						crewRoom.extend.hullDamageResistChance = 100
						crewRoom.extend.sysDamageResistChance = 100
						--print("HULL ORIG: "..tostring(protectionTable[crewmem.iRoomId][2]).."SYS ORIG: "..tostring(protectionTable[crewmem.iRoomId][3]))
					end
				else
					if protectionTableEnemy[crewmem.iRoomId] then
						protectionTableEnemy[crewmem.iRoomId] = {20, protectionTableEnemy[crewmem.iRoomId][2], protectionTableEnemy[crewmem.iRoomId][3]}
						--print("HULL ORIG: "..tostring(protectionTable[crewmem.iRoomId][2]).."SYS ORIG: "..tostring(protectionTable[crewmem.iRoomId][3]))
					else
						local hullRes = 0.0
						local sysRes = 0.0
						if crewRoom.extend.hullDamageResistChance then
							hullRes = crewRoom.extend.hullDamageResistChance
						end
						if crewRoom.extend.sysDamageResistChance then
							sysRes = crewRoom.extend.sysDamageResistChance
						end
						protectionTableEnemy[crewmem.iRoomId] = {20, hullRes, sysRes}
						crewRoom.extend.hullDamageResistChance = 100
						crewRoom.extend.sysDamageResistChance = 100
						--print("HULL ORIG: "..tostring(protectionTable[crewmem.iRoomId][2]).."SYS ORIG: "..tostring(protectionTable[crewmem.iRoomId][3]))
					end
				end
			end
		else
			local targetManager = Hyperspace.ships(crewmem.iShipId)
			if target_ship then
				targetManager = Hyperspace.ships(target_ship)
			end
			--print("FIRE SUP:"..spell)
			fire_spell(crewmem, targetManager, spell, target_room, true)
		end
	else
		Hyperspace.Sounds:PlaySoundMix("fire_blast", -1, false)
		local spell = randomBorSpells:GetItem()
		--print("FIRE BOR:"..spell)
		fire_spell(crewmem, targetManager, spell, target_room, true)
	end
end

mods.aea.magicCrew = {}
local magicCrew = mods.aea.magicCrew
magicCrew["aea_cult_wizard"] = true
magicCrew["aea_cult_tiny"] = true

local target_power = false
local target_crew = nil

script.on_internal_event(Defines.InternalEvents.CREW_LOOP, function(crewmem) 
	if log_events then
		--log("CREW_LOOP 2")
	end
	--print(string.sub(crewmem.type, 0, string.len(crewmem.type) - 4))
	local magicTable = userdata_table(crewmem, "mods.aea.cultmagic")
	if magicTable.hp then
		
		if (target_crew == crewmem.extend.selfId) then
			--print("SFASFASFAS")
			for power in vter(crewmem.extend.crewPowers) do
				--print("TARGETTING FIRST ".. tostring(power.temporaryPowerDuration.first).."SECOND ".. tostring(power.temporaryPowerDuration.second))
				power.temporaryPowerDuration.first = power.temporaryPowerDuration.second
			end
			return
		end
		if crewmem.health.first < magicTable.hp or not crewmem:AtGoal() then
			for power in vter(crewmem.extend.crewPowers) do
				power:CancelPower(true)
				power.powerCharges.first = power.powerCharges.first + 1
				userdata_table(crewmem, "mods.aea.cultmagic").hp = nil
				if magicTable.room then
					userdata_table(crewmem, "mods.aea.cultmagic").room = nil
					userdata_table(crewmem, "mods.aea.cultmagic").ship = nil
				end
			end
			return
		end
		magicTable.hp = crewmem.health.first
		for power in vter(crewmem.extend.crewPowers) do
			if not power.temporaryPowerActive and power.enabled then
				--activate power
				--print(string.sub(crewmem.type, string.len(crewmem.type) - 1, string.len(crewmem.type)))

				userdata_table(crewmem, "mods.aea.cultmagic").hp = nil
				local target_room = nil
				local target_ship = nil
				if magicTable.room then
					target_room	= magicTable.room
					target_ship = magicTable.ship
					userdata_table(crewmem, "mods.aea.cultmagic").room = nil
					userdata_table(crewmem, "mods.aea.cultmagic").ship = nil
					--print("SET ROOM "..tostring(target_room))
				end
				if string.sub(crewmem.type, 0, string.len(crewmem.type) - 4) == "aea_cult_priest" then
					activate_priest(crewmem, target_room, target_ship, string.sub(crewmem.type, string.len(crewmem.type) - 2, string.len(crewmem.type)))
				else
					activate_magic(crewmem, string.sub(crewmem.type, string.len(crewmem.type) - 1, string.len(crewmem.type)), target_room, target_ship)
				end
			elseif crewmem.iShipId == 1 or (crewmem.iShipId == 1 and crewmem.bMindControlled) then
				power.temporaryPowerDuration.first = power.temporaryPowerDuration.first + Hyperspace.FPS.SpeedFactor/32
			end
		end
	end
end)

script.on_internal_event(Defines.InternalEvents.ACTIVATE_POWER, function(power, shipManager)
	if log_events then
		log("ACTIVATE_POWER 4")
	end
	checkforWarp()
	local crewmem = power.crew
	if magicCrew[crewmem.type] or magicCrew[string.sub(crewmem.type, 0, string.len(crewmem.type) - 4)] then
		if crewmem.bMindControlled then
			for power in vter(crewmem.extend.crewPowers) do
				power:CancelPower(true)
				power.powerCharges.first = power.powerCharges.first + 1
			end
			return
		end
		userdata_table(crewmem, "mods.aea.cultmagic").hp = crewmem.health.first
		--print(string.sub(crewmem.type, string.len(crewmem.type) - 2, string.len(crewmem.type) - 2))
		if string.sub(crewmem.type, string.len(crewmem.type) - 2, string.len(crewmem.type) - 2) == "s" and (crewmem.iShipId == 0 or (crewmem.iShipId == 1 and crewmem.bMindControlled)) then
			if target_power == true then
				local crewmem = nil
				for crewp in vter(Hyperspace.ships.player.vCrewList) do
					if crewp.extend.selfId == target_crew then
						crewmem = crewp
					end
				end
				if Hyperspace.ships.enemy then
					if Hyperspace.ships.enemy.vCrewList then
						for crewe in vter(Hyperspace.ships.enemy.vCrewList) do
							if crewe.extend.selfId == target_crew then
								crewmem = crewe
							end
						end
					end
				end
				if crewmem then
					target_power = false
					target_crew = nil
					roomAtMouse = -1
					shipAtMouse = -1
					for power in vter(crewmem.extend.crewPowers) do
						power:CancelPower(true)
						power.powerCharges.first = power.powerCharges.first + 1
						power.powerCooldown.first = power.powerCooldown.second - 0.1
						userdata_table(crewmem, "mods.aea.cultmagic").hp = nil
					end
				end
			end
			target_power = true
			target_crew = crewmem.extend.selfId
		end
		--userdata_table(crewmem, "mods.aea.cultmagic").active = power.temporaryPowerActive
	elseif string.sub(crewmem.type, 0, string.len(crewmem.type) - 4) == "aea_cult_priest" then
		if crewmem.bMindControlled then
			for power in vter(crewmem.extend.crewPowers) do
				power:CancelPower(true)
				power.powerCharges.first = power.powerCharges.first + 1
			end
			return
		end
		userdata_table(crewmem, "mods.aea.cultmagic").hp = crewmem.health.first
		if (crewmem.iShipId == 0 or (crewmem.iShipId == 1 and crewmem.bMindControlled)) then
			if target_power == true then
				local crewmem = nil
				for crewp in vter(Hyperspace.ships.player.vCrewList) do
					if crewp.extend.selfId == target_crew then
						crewmem = crewp
					end
				end
				if Hyperspace.ships.enemy then
					if Hyperspace.ships.enemy.vCrewList then
						for crewe in vter(Hyperspace.ships.enemy.vCrewList) do
							if crewe.extend.selfId == target_crew then
								crewmem = crewe
							end
						end
					end
				end
				if crewmem then
					target_power = false
					target_crew = nil
					roomAtMouse = -1
					shipAtMouse = -1
					for power in vter(crewmem.extend.crewPowers) do
						power:CancelPower(true)
						power.powerCharges.first = power.powerCharges.first + 1
						power.powerCooldown.first = power.powerCooldown.second - 0.1
						userdata_table(crewmem, "mods.aea.cultmagic").hp = nil
					end
				end
			end
			target_power = true
			target_crew = crewmem.extend.selfId
		end
	end
	return Defines.Chain.CONTINUE
end)

local roomAtMouse = -1
local shipAtMouse = -1
local cursorImage = Hyperspace.Resources:CreateImagePrimitiveString("mouse/pointer_aea_magic.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)

script.on_render_event(Defines.RenderEvents.MOUSE_CONTROL, function()
	if target_power then
		local mousePos = Hyperspace.Mouse.position
		local mousePosLocal = convertMousePositionToEnemyShipPosition(mousePos)
		--print("MOUSE POS X:"..mousePos.x.." Y:"..mousePos.y.." LOCAL X:"..mousePosLocal.x.." Y:"..mousePosLocal.y)
		if Hyperspace.ships.enemy and mousePosLocal.x >= 0 then
			shipAtMouse = 1
			roomAtMouse = get_room_at_location(Hyperspace.ships.enemy, mousePosLocal, true)
			--if roomAtMouse >= 0 then 
				--print(roomAtMouse)
			--end
		else
			shipAtMouse = 0
			mousePosLocal = convertMousePositionToPlayerShipPosition(mousePos)
			roomAtMouse = get_room_at_location(Hyperspace.ships.player, mousePosLocal, true)
		end
		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(mousePos.x,mousePos.y,0)
		Graphics.CSurface.GL_RenderPrimitive(cursorImage)
		Graphics.CSurface.GL_PopMatrix()
	end
end, function() end)

script.on_internal_event(Defines.InternalEvents.ON_MOUSE_L_BUTTON_DOWN, function(x,y) 
	if log_events then
		--log("ON_MOUSE_L_BUTTON_DOWN 1")
	end
	if Hyperspace.Global.GetInstance():GetCApp().world.bStartedGame and target_power then 
		local crewmem = nil
		for crewp in vter(Hyperspace.ships.player.vCrewList) do
			if crewp.extend.selfId == target_crew then
				crewmem = crewp
			end
		end
		if Hyperspace.ships.enemy then
			if Hyperspace.ships.enemy.vCrewList then
				for crewe in vter(Hyperspace.ships.enemy.vCrewList) do
					if crewe.extend.selfId == target_crew then
						crewmem = crewe
					end
				end
			end
		end
		if roomAtMouse >= 0 then 
			--print("SET ROOM AT"..tostring(roomAtMouse))
			userdata_table(crewmem, "mods.aea.cultmagic").room = roomAtMouse
			userdata_table(crewmem, "mods.aea.cultmagic").ship = shipAtMouse
			target_power = false
			target_crew = nil
			roomAtMouse = -1
			shipAtMouse = -1
		else 
			--print("SET ROOM FAIL")
			target_power = false
			target_crew = nil
			roomAtMouse = -1
			shipAtMouse = -1
			for power in vter(crewmem.extend.crewPowers) do
				power:CancelPower(true)
				power.powerCharges.first = power.powerCharges.first + 1
				power.powerCooldown.first = power.powerCooldown.second - 0.1
				userdata_table(crewmem, "mods.aea.cultmagic").hp = nil
			end
		end 
	end
	return Defines.Chain.CONTINUE
end)

script.on_render_event(Defines.RenderEvents.SHIP_SPARKS, function() end, function(shipManager)
	if shipManager.iShipId == 1 then
		for crewmem in vter(Hyperspace.ships.player.vCrewList) do
			local magicTable = userdata_table(crewmem, "mods.aea.cultmagic")
			if magicTable.room then
				if magicTable.ship == 1 then
					local pos = shipManager:GetRoomCenter(magicTable.room)
					Graphics.CSurface.GL_PushMatrix()
					Graphics.CSurface.GL_Translate(pos.x,pos.y,0)
					Graphics.CSurface.GL_RenderPrimitive(crosshairImage)
					Graphics.CSurface.GL_PopMatrix()
				end
			end
		end
		for crewmem in vter(Hyperspace.ships.enemy.vCrewList) do
			local magicTable = userdata_table(crewmem, "mods.aea.cultmagic")
			if magicTable.room then
				if magicTable.ship == 1 then
					local pos = shipManager:GetRoomCenter(magicTable.room)
					Graphics.CSurface.GL_PushMatrix()
					Graphics.CSurface.GL_Translate(pos.x,pos.y,0)
					Graphics.CSurface.GL_RenderPrimitive(crosshairImage)
					Graphics.CSurface.GL_PopMatrix()
				end
			end
		end

		if roomAtMouse >= 0 and shipAtMouse == 1 then
			local pos = shipManager:GetRoomCenter(roomAtMouse)
			Graphics.CSurface.GL_PushMatrix()
			Graphics.CSurface.GL_Translate(pos.x,pos.y,0)
			Graphics.CSurface.GL_RenderPrimitive(crosshairImage2)
			Graphics.CSurface.GL_PopMatrix()
		end
	else
		for crewmem in vter(Hyperspace.ships.player.vCrewList) do
			local magicTable = userdata_table(crewmem, "mods.aea.cultmagic")
			if magicTable.room then
				if magicTable.ship == 0 then
					local pos = shipManager:GetRoomCenter(magicTable.room)
					Graphics.CSurface.GL_PushMatrix()
					Graphics.CSurface.GL_Translate(pos.x,pos.y,0)
					Graphics.CSurface.GL_RenderPrimitive(crosshairImage)
					Graphics.CSurface.GL_PopMatrix()
				end
			end
		end
		if Hyperspace.ships.enemy then
			for crewmem in vter(Hyperspace.ships.enemy.vCrewList) do
				local magicTable = userdata_table(crewmem, "mods.aea.cultmagic")
				if magicTable.room then
					if magicTable.ship == 0 then
						local pos = shipManager:GetRoomCenter(magicTable.room)
						Graphics.CSurface.GL_PushMatrix()
						Graphics.CSurface.GL_Translate(pos.x,pos.y,0)
						Graphics.CSurface.GL_RenderPrimitive(crosshairImage)
						Graphics.CSurface.GL_PopMatrix()
					end
				end
			end
		end

		if roomAtMouse >= 0 and shipAtMouse == 0 then
			local pos = shipManager:GetRoomCenter(roomAtMouse)
			Graphics.CSurface.GL_PushMatrix()
			Graphics.CSurface.GL_Translate(pos.x,pos.y,0)
			Graphics.CSurface.GL_RenderPrimitive(crosshairImage2)
			Graphics.CSurface.GL_PopMatrix()
		end

		--[[local mousePos = Hyperspace.Mouse.position
		local pos = convertMousePositionToPlayerShipPosition(mousePos)
		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(pos.x,pos.y,0)
		Graphics.CSurface.GL_RenderPrimitive(crosshairImage2)
		Graphics.CSurface.GL_PopMatrix()]]
	end
end)

local barrierTablePlayer = {}
local barrierTableEnemy = {}
local barrierTablePlayerLen = 0
local barrierTableEnemyLen = 0

script.on_internal_event(Defines.InternalEvents.JUMP_ARRIVE, function()
	if log_events then
		log("JUMP_ARRIVE 7")
	end
	barrierTablePlayer = {}
	barrierTableEnemy = {}
	barrierTablePlayerLen = 0
	barrierTableEnemyLen = 0
end)

script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA_HIT, function(shipManager, projectile, location, damage, shipFriendlyFire)
	if log_events then
		log("DAMAGE_AREA_HIT 3")
	end
	local weaponName = false
	pcall(function() weaponName = projectile.extend.name == "AEA_LASER_SPELL_08" or projectile.extend.name == "AEA_LASER_CULT_08" end)
	if weaponName then
		local otherManager = Hyperspace.ships(1 - shipManager.iShipId)
		local room = get_room_at_location(shipManager, location, true)
		local target_pos = otherManager:GetRandomRoomCenter()
		local target_room = get_room_at_location(otherManager,target_pos,false)
		for crewmem in vter(shipManager.vCrewList) do
			if crewmem.iRoomId == room and not crewmem:IsDrone() then
				local otherManager = Hyperspace.ships(1 - crewmem.currentShipId)
				crewmem.extend:InitiateTeleport(otherManager.iShipId, target_room, 0)
			end
		end
	end

	weaponName = false
	pcall(function() weaponName = projectile.extend.name == "AEA_LASER_SPELL_12" or projectile.extend.name == "AEA_LASER_CULT_12" end)
	if weaponName then
		--log("ADD BARRIER FROM: "..projectile.extend.name)
		local room = get_room_at_location(shipManager, location, true)
		if shipManager.iShipId == 0 then

			if not barrierTablePlayer[room] then 
				if barrierTablePlayerLen >= 8 then return end
				barrierTablePlayerLen = barrierTablePlayerLen + 1 
			end
			barrierTablePlayer[room] = 2
		else

			if not barrierTableEnemy[room] then
				if barrierTableEnemyLen >= 8 then return end
				 barrierTableEnemyLen = barrierTableEnemyLen + 1 
			end
			barrierTableEnemy[room] = 2
		end
	end

	return Defines.Chain.CONTINUE
end)

--[[script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA, function(shipManager, projectile, location, damage, shipFriendlyFire)
	if not projectile then return Defines.Chain.CONTINUE, false, shipFriendlyFire end
	local room = get_room_at_location(shipManager, location, true)
	if shipManager.iShipId == 0 then
		if protectionTable[room] then
			local newDamage = projectile.damage
			newDamage.iDamage = 0
			newDamage.iSystemDamage = 0
			damage = newDamage
			projectile:SetDamage(newDamage)
		end
	else
		if protectionTableEnemy[room] then
			local newDamage = projectile.damage
			newDamage.iDamage = 0
			newDamage.iSystemDamage = 0
			damage = newDamage
			projectile:SetDamage(newDamage)
		end
	end
	return Defines.Chain.CONTINUE, false, shipFriendlyFire
end)]]

--[[script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA, function(shipManager, projectile, location, damage, shipFriendlyFire)
	if not projectile then return Defines.Chain.CONTINUE, false, shipFriendlyFire end
	--print(string.sub(projectile.extend.name, 0, 15))
	if string.sub(projectile.extend.name, 0, 15) == "AEA_LASER_SPELL" then
		return Defines.Chain.CONTINUE, true, true
	end
	return Defines.Chain.CONTINUE, false, shipFriendlyFire
end)]]


local barrierImage = Hyperspace.Resources:CreateImagePrimitiveString("effects/aea_barrier.png", -53, -53, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
local barrierImage2 = Hyperspace.Resources:CreateImagePrimitiveString("effects/aea_barrier2.png", -53, -53, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)

script.on_render_event(Defines.RenderEvents.SHIP, function() end, function(shipManager)
	if shipManager.iShipId == 0 then
		for room, health in pairs(barrierTablePlayer) do
			local pos = shipManager:GetRoomCenter(room)
			Graphics.CSurface.GL_PushMatrix()
			Graphics.CSurface.GL_Translate(pos.x,pos.y,0)
			if health > 1 then
				Graphics.CSurface.GL_RenderPrimitive(barrierImage)
			else
				Graphics.CSurface.GL_RenderPrimitive(barrierImage2)
			end
			Graphics.CSurface.GL_PopMatrix()
		end
	else
		for room, health in pairs(barrierTableEnemy) do
			local pos = shipManager:GetRoomCenter(room)
			Graphics.CSurface.GL_PushMatrix()
			Graphics.CSurface.GL_Translate(pos.x,pos.y,0)
			if health > 1 then
				Graphics.CSurface.GL_RenderPrimitive(barrierImage)
			else
				Graphics.CSurface.GL_RenderPrimitive(barrierImage2)
			end
			Graphics.CSurface.GL_PopMatrix()
		end
	end
end)
script.on_internal_event(Defines.InternalEvents.PROJECTILE_PRE, function(projectile) 
	if log_events then
		--log("PROJECTILE_PRE 2")
	end
	local spellTable = userdata_table(projectile, "mods.aea.spell")
	if spellTable.owner then
		return Defines.Chain.CONTINUE
	end
	if projectile.currentSpace == 0 and projectile.ownerId == 1 and not projectile.missed then
		shipManager = Hyperspace.ships.player
		for room, health in pairs(barrierTablePlayer) do
			local pos = shipManager:GetRoomCenter(room)
			if get_distance(projectile.position, pos) < 55 and get_distance(projectile.position, pos) > 40 then
				projectile:Kill()
				Hyperspace.Sounds:PlaySoundMix("hitShield1", -1, false)
				local newHealth = health - 1
				if newHealth <= 0 then
					barrierTablePlayer[room] = nil
					barrierTablePlayerLen = barrierTablePlayerLen - 1
				else
					barrierTablePlayer[room] = newHealth
				end
			end
		end
	elseif projectile.currentSpace == 1 and projectile.ownerId == 0  and not projectile.missed then
		shipManager = Hyperspace.ships.enemy
		for room, health in pairs(barrierTableEnemy) do
			local pos = shipManager:GetRoomCenter(room)
			if get_distance(projectile.position, pos) < 55 and get_distance(projectile.position, pos) > 40 then
				projectile:Kill()
				Hyperspace.Sounds:PlaySoundMix("hitShield1", -1, false)
				local newHealth = health - 1
				if newHealth <= 0 then
					barrierTableEnemy[room] = nil
					barrierTableEnemyLen = barrierTableEnemyLen - 1
				else
					barrierTableEnemy[room] = newHealth
				end
			end
		end
	end
	return Defines.Chain.CONTINUE
end)

script.on_init(checkforWarp)

local recallPos = {x=632, y=78, w=125, h=34, p=5}
local recallBOff = Hyperspace.Resources:CreateImagePrimitiveString("combatUI/aea_button_recall_off.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
local recallBOn = Hyperspace.Resources:CreateImagePrimitiveString("combatUI/aea_button_recall_on.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
local recallBSelect = Hyperspace.Resources:CreateImagePrimitiveString("combatUI/aea_button_recall_select2.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
local recallSelected = false

script.on_render_event(Defines.RenderEvents.MOUSE_CONTROL, function()
	if Hyperspace.ships.enemy then 
		if Hyperspace.ships.enemy.bContainsPlayerCrew and hasWarp and not Hyperspace.ships.enemy._targetable.hostile then
			local mousePos = Hyperspace.Mouse.position
			Graphics.CSurface.GL_PushMatrix()
			Graphics.CSurface.GL_Translate(recallPos.x,recallPos.y,0)
			if mousePos.x >= recallPos.x - recallPos.p and mousePos.x < recallPos.x + recallPos.w + recallPos.p and mousePos.y >= recallPos.y - recallPos.p and mousePos.y < recallPos.y + recallPos.h + recallPos.p then
				recallSelected = true
				Graphics.CSurface.GL_RenderPrimitive(recallBSelect)
			else
				recallSelected = false
				Graphics.CSurface.GL_RenderPrimitive(recallBOn)
			end
			Graphics.CSurface.GL_PopMatrix()
		end
	end
end, function() end)

script.on_internal_event(Defines.InternalEvents.ON_MOUSE_L_BUTTON_DOWN, function(x,y) 
	if log_events then
		--log("ON_MOUSE_L_BUTTON_DOWN 2")
	end
	if recallSelected then
		if Hyperspace.ships.enemy and Hyperspace.ships.enemy.bContainsPlayerCrew and hasWarp and not Hyperspace.ships.enemy._targetable.hostile then
			for crewmem in vter(Hyperspace.ships.enemy.vCrewList) do
				if crewmem.iShipId == 0 and not crewmem:IsDrone() then
					crewmem.extend:InitiateTeleport(0, 0, 0)
				end
			end
		end
		recallSelected = false
	end
	return Defines.Chain.CONTINUE
end)

local summonImage1 = Hyperspace.Resources:CreateImagePrimitiveString("effects/aea_summon1.png", -17, -17, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
local summonImage2 = Hyperspace.Resources:CreateImagePrimitiveString("effects/aea_summon2.png", -17, -17, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
local summonImage3 = Hyperspace.Resources:CreateImagePrimitiveString("effects/aea_summon3.png", -17, -17, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
local summonImage4 = Hyperspace.Resources:CreateImagePrimitiveString("effects/aea_summon4.png", -17, -17, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
local summonImageTimer = 0
script.on_render_event(Defines.RenderEvents.SHIP_SPARKS, function() end, function(ship) 
	local shipManager = Hyperspace.ships(ship.iShipId)
	for crewmem in vter(shipManager.vCrewList) do
		local magicTable = userdata_table(crewmem, "mods.aea.cultmagic")
		if magicTable.hp then
			local pos = crewmem:GetLocation()
			Graphics.CSurface.GL_PushMatrix()
			Graphics.CSurface.GL_Translate(pos.x,pos.y,0)
			if summonImageTimer <= 0.2 then
				Graphics.CSurface.GL_RenderPrimitive(summonImage1)
			elseif summonImageTimer <= 0.4 then
				Graphics.CSurface.GL_RenderPrimitive(summonImage2)
			elseif summonImageTimer <= 0.6 then
				Graphics.CSurface.GL_RenderPrimitive(summonImage3)
			else
				Graphics.CSurface.GL_RenderPrimitive(summonImage4)
			end
			Graphics.CSurface.GL_PopMatrix()
		end
	end
	summonImageTimer = summonImageTimer + Hyperspace.FPS.SpeedFactor/16
	if summonImageTimer > 0.8 then
		summonImageTimer = summonImageTimer - 0.8
	end
end)

randomArtySpells = RandomList:New {"AEA_LASER_SPELL_03", "AEA_LASER_SPELL_04", "AEA_LASER_SPELL_04", "AEA_LASER_SPELL_04", "AEA_LASER_SPELL_06", "AEA_LASER_SPELL_08", "AEA_LASER_SPELL_10", "AEA_LASER_SPELL_13", "AEA_LASER_SPELL_14", "AEA_LASER_SPELL_15"}

script.on_internal_event(Defines.InternalEvents.PROJECTILE_FIRE, function(projectile, weapon)
	if log_events then
		log("PROJECTILE_FIRE 2")
	end
	if weapon.blueprint then
		if weapon.blueprint.name == "AEA_LASER_SPELL_ARTILLERY" then
			local spell = randomArtySpells:GetItem()
			userdata_table(projectile, "mods.aea.spell").owner = projectile.ownerId
			userdata_table(projectile, "mods.aea.spell").spellName = spell
		end
	end
end)



script.on_internal_event(Defines.InternalEvents.JUMP_ARRIVE, function()
	if log_events then
		log("JUMP_ARRIVE 8")
	end
	if Hyperspace.ships.player:HasAugmentation("AEA_CULT_MAGIC_BOOST") > 0 then
		--print("REMOVE AUG")
		Hyperspace.ships.player:RemoveItem("HIDDEN AEA_CULT_MAGIC_BOOST")
	end
end)

script.on_init(function() 
	barrierTablePlayer = {}
	barrierTableEnemy = {}
	barrierTablePlayerLen = 0
	barrierTableEnemyLen = 0
end)

script.on_internal_event(Defines.InternalEvents.PROJECTILE_FIRE, function(projectile, weapon)
	if log_events then
		log("PROJECTILE_FIRE 3")
	end
	if weapon and is_first_shot(weapon, true) then
		local shipManager = Hyperspace.ships(weapon.iShipId)
		if shipManager:HasAugmentation("AEA_BARRIER_RELAY") > 0 or shipManager:HasAugmentation("AEA_BARRIER_RELAY_CHAOS") > 0 then
			local room = get_room_at_location(shipManager, shipManager:GetRandomRoomCenter(), false)
			if shipManager.iShipId == 0 then
				if not barrierTablePlayer[room] then 
					if barrierTablePlayerLen >= 6 and shipManager:HasAugmentation("AEA_BARRIER_RELAY_CHAOS") == 0 then return end
					barrierTablePlayerLen = barrierTablePlayerLen + 1 
				end
				barrierTablePlayer[room] = 2
			else
				if not barrierTableEnemy[room] then 
					if barrierTableEnemyLen >= 6 and shipManager:HasAugmentation("AEA_BARRIER_RELAY_CHAOS") == 0 then return end
					barrierTableEnemyLen = barrierTableEnemyLen + 1 
				end
				barrierTableEnemy[room] = 2
			end
		end
	end
end)

script.on_internal_event(Defines.InternalEvents.GET_AUGMENTATION_VALUE, function(shipManager, augName, augValue)
	if log_events then
		--log("GET_AUGMENTATION_VALUE 1")
	end
	if shipManager and (augName == "SHIELD_RECHARGE" or augName == "AUTO_COOLDOWN") and shipManager:HasAugmentation("AEA_AUG_WHALE")>0 then
		local breaches = shipManager.ship:GetHullBreaches(true):size()
		augValue = augValue - math.min(breaches, 10)*0.05
	end
	return Defines.Chain.CONTINUE, augValue
end, -100)


local code_entered = "XXXX"

local goal_code = Hyperspace.playerVariables.aea_cult_code_goal

script.on_game_event("START_BEACON_EXPLAIN", false, function()
	Hyperspace.playerVariables.aea_cult_code_goal = math.random(0, 9999)
	goal_code = Hyperspace.playerVariables.aea_cult_code_goal
end)

-- Init and complete gatling naming
script.on_internal_event(Defines.InternalEvents.POST_CREATE_CHOICEBOX, function(choiceBox, event)
	if log_events then
		log("POST_CREATE_CHOICEBOX 2")
	end
	if event.eventName == "AEA_CULT_CON_ENTER_CODE" then
		goal_code = Hyperspace.playerVariables.aea_cult_code_goal
		choiceBox.mainText = "Entering Code: "..code_entered
	elseif event.eventName == "AEA_CULT_CON_GENERATOR_CODE" then
		goal_code = Hyperspace.playerVariables.aea_cult_code_goal
		local goalString = tostring(goal_code)
		if #goalString > 2 and goalString:sub(#goalString - 1) == ".0" then
			goalString = goalString:sub(1, #goalString - 2)
		end
		if #goalString == 1 then
			goalString = "000" .. goalString
		elseif #goalString == 2 then
			goalString = "00" .. goalString
		elseif #goalString == 3 then
			goalString = "0" .. goalString
		end
		choiceBox.mainText = choiceBox.mainText..goalString..". You quickly note it down."
	end
end)

local function setNextCodeChar(char)
	for i = 1, #code_entered do
		local c = code_entered:sub(i,i)
		if c == "X" then
			code_entered = code_entered:sub(1, i-1) .. char .. code_entered:sub(i+1)
			break
		elseif i == 4 then
			code_entered = code_entered:sub(2) .. char
		end
	end
	local goalString = tostring(goal_code)
	if #goalString > 2 and goalString:sub(#goalString - 1) == ".0" then
		goalString = goalString:sub(1, #goalString - 2)
	end
	if #goalString == 1 then
		goalString = "000" .. goalString
	elseif #goalString == 2 then
		goalString = "00" .. goalString
	elseif #goalString == 3 then
		goalString = "0" .. goalString
	end
	if code_entered == goalString then
		Hyperspace.playerVariables.aea_cult_code = 1
	else
		Hyperspace.playerVariables.aea_cult_code = 0
	end
end

script.on_game_event("AEA_CULT_CON_ENTER_CODE_1", false, function()
	setNextCodeChar("1")
end)
script.on_game_event("AEA_CULT_CON_ENTER_CODE_2", false, function()
	setNextCodeChar("2")
end)
script.on_game_event("AEA_CULT_CON_ENTER_CODE_3", false, function()
	setNextCodeChar("3")
end)
script.on_game_event("AEA_CULT_CON_ENTER_CODE_4", false, function()
	setNextCodeChar("4")
end)
script.on_game_event("AEA_CULT_CON_ENTER_CODE_5", false, function()
	setNextCodeChar("5")
end)
script.on_game_event("AEA_CULT_CON_ENTER_CODE_6", false, function()
	setNextCodeChar("6")
end)
script.on_game_event("AEA_CULT_CON_ENTER_CODE_7", false, function()
	setNextCodeChar("7")
end)
script.on_game_event("AEA_CULT_CON_ENTER_CODE_8", false, function()
	setNextCodeChar("8")
end)
script.on_game_event("AEA_CULT_CON_ENTER_CODE_9", false, function()
	setNextCodeChar("9")
end)
script.on_game_event("AEA_CULT_CON_ENTER_CODE_0", false, function()
	setNextCodeChar("0")
end)

mods.aea.magicCrewSpells = {}
local magicCrewSpells = mods.aea.magicCrewSpells
magicCrewSpells["aea_cult_wizard_a01"] = true
magicCrewSpells["aea_cult_wizard_a02"] = true
magicCrewSpells["aea_cult_wizard_s03"] = true
magicCrewSpells["aea_cult_wizard_s04"] = true
magicCrewSpells["aea_cult_wizard_s05"] = true
magicCrewSpells["aea_cult_wizard_s06"] = true
magicCrewSpells["aea_cult_wizard_a07"] = true
magicCrewSpells["aea_cult_wizard_s08"] = true
magicCrewSpells["aea_cult_wizard_s09"] = true
magicCrewSpells["aea_cult_wizard_a10"] = true
magicCrewSpells["aea_cult_wizard_a11"] = true
magicCrewSpells["aea_cult_wizard_s12"] = true
magicCrewSpells["aea_cult_wizard_s13"] = true
magicCrewSpells["aea_cult_wizard_s14"] = true
magicCrewSpells["aea_cult_wizard_s15"] = true
magicCrewSpells["aea_cult_tiny_a01"] = true
magicCrewSpells["aea_cult_tiny_a02"] = true
magicCrewSpells["aea_cult_tiny_s03"] = true
magicCrewSpells["aea_cult_tiny_s04"] = true
magicCrewSpells["aea_cult_tiny_s05"] = true
magicCrewSpells["aea_cult_tiny_s06"] = true
magicCrewSpells["aea_cult_tiny_a07"] = true
magicCrewSpells["aea_cult_tiny_s08"] = true
magicCrewSpells["aea_cult_tiny_s09"] = true
magicCrewSpells["aea_cult_tiny_a10"] = true
magicCrewSpells["aea_cult_tiny_a11"] = true
magicCrewSpells["aea_cult_tiny_s12"] = true
magicCrewSpells["aea_cult_tiny_s13"] = true
magicCrewSpells["aea_cult_tiny_s14"] = true
magicCrewSpells["aea_cult_tiny_s15"] = true

local cultist_count = 0
local cultist_countTimer = 0

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	cultist_countTimer = cultist_countTimer + Hyperspace.FPS.SpeedFactor/16
	for weapon in vter(shipManager:GetWeaponList()) do
		if weapon.blueprint.name == "AEA_LASER_CULT_LOOT" then
			if cultist_countTimer >= 0.1 then
				cultist_countTimer = 0
				cultist_count = 0
				if Hyperspace.ships.player then
					for crew in vter(Hyperspace.ships.player.vCrewList) do
						if magicCrewSpells[crew.type] and crew.iShipId == shipManager.iShipId then
							cultist_count = cultist_count + 1
						end
					end
				end
				if Hyperspace.ships.enemy then
					for crew in vter(Hyperspace.ships.enemy.vCrewList) do
						if magicCrewSpells[crew.type] and crew.iShipId == shipManager.iShipId then
							cultist_count = cultist_count + 1
						end
					end
				end
			end
			
			weapon.boostLevel = math.min(cultist_count, 10)
		end
	end
end)

local cultLaserNames = {}
cultLaserNames["AEA_LASER_CULT_03"] = 3
cultLaserNames["AEA_LASER_CULT_04"] = 2
cultLaserNames["AEA_LASER_CULT_05"] = 2
cultLaserNames["AEA_LASER_CULT_06"] = 2
cultLaserNames["AEA_LASER_CULT_09"] = 3
cultLaserNames["AEA_LASER_CULT_12"] = 3
cultLaserNames["AEA_LASER_CULT_13"] = 3
cultLaserNames["AEA_LASER_CULT_14"] = 2
cultLaserNames["AEA_LASER_CULT_15"] = 3

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	for weapon in vter(shipManager:GetWeaponList()) do
		if cultLaserNames[weapon.blueprint.name] then
			local sporeTable = userdata_table(weapon, "mods.aea.spellSpores")
			if sporeTable.shots and sporeTable.shots > weapon.boostLevel then
				weapon.boostLevel = sporeTable.shots
			end
		end
	end
end)

script.on_internal_event(Defines.InternalEvents.JUMP_ARRIVE, function(shipManager)
	for weapon in vter(shipManager:GetWeaponList()) do
		local sporeTable = userdata_table(weapon, "mods.aea.spellSpores")
		if sporeTable.shots then
			--print("SPELLSPORE SHOTS"..tostring(sporeTable.shots))
			sporeTable.shots = nil
		end
	end
end)

script.on_internal_event(Defines.InternalEvents.PROJECTILE_FIRE, function(projectile, weapon)
	if log_events then
		log("PROJECTILE_FIRE 4")
	end

	--print("NAME: "..weapon.blueprint.name.." BOOST: "..tostring(weapon.boostLevel).." BASE COOLDOWN: "..tostring(weapon.baseCooldown))
	if cultLaserNames[weapon.blueprint.name] and weapon.boostLevel == cultLaserNames[weapon.blueprint.name] then
		--print("SET_COOLDOWN")
		weapon.boostLevel = 50
	end

	if cultLaserNames[weapon.blueprint.name] then
		userdata_table(weapon, "mods.aea.spellSpores").shots = weapon.boostLevel
	end

	if weapon.blueprint.name == "AEA_LASER_CULT_RANDOM" then
		local random = math.random(9)
		random = random + 2
		if random >= 7 then
			random = random + 2
		end
		if random >= 10 then
			random = random + 2
		end

		local randomString = tostring(random)
		if #randomString > 2 and randomString:sub(#randomString - 1) == ".0" then
			randomString = randomString:sub(1, #randomString - 2)
		end
		if #randomString == 1 then
			randomString = "0" .. randomString
		end

		local weaponString = "AEA_LASER_CULT_"..randomString
		--print("REPLACE WITH:"..weaponString)

		local spaceManager = Hyperspace.Global.GetInstance():GetCApp().world.space
		local spellLaser = Hyperspace.Blueprints:GetWeaponBlueprint(weaponString)

		local laser = spaceManager:CreateLaserBlast(
			spellLaser,
			projectile.position,
			projectile.currentSpace,
			projectile.ownerId,
			projectile.target,
			projectile.destinationSpace,
			projectile.heading)
		projectile:Kill()
	end

	if weapon.blueprint.name == "AEA_LASER_OLDP_3_LOOT" then
		if weapon.queuedProjectiles:size() <= 0 then
			local newDamage = Hyperspace.Damage()
			newDamage.iDamage = 1
			newDamage.breachChance = 10
			projectile:SetDamage(newDamage)
			--print("SET DAMAGE")
		end
	end
end)

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	if shipManager:HasAugmentation("AEA_AUG_WHALE") > 0 and shipManager:HasSystem(2) then
		local oxygen = shipManager.oxygenSystem
		local shipGraph = Hyperspace.ShipGraph.GetShipInfo(shipManager.iShipId)
		for id = 0, shipGraph:RoomCount(), 1 do
			--print("EMPTY:"..tostring(id))
			oxygen:ModifyRoomOxygen(id, -100.0)
		end
	end
end)


mods.aea.allMagicCrew = {}
local allMagicCrew = mods.aea.allMagicCrew
allMagicCrew["aea_cult_wizard_a01"] = true
allMagicCrew["aea_cult_wizard_a02"] = true
allMagicCrew["aea_cult_wizard_s03"] = true
allMagicCrew["aea_cult_wizard_s04"] = true
allMagicCrew["aea_cult_wizard_s05"] = true
allMagicCrew["aea_cult_wizard_s06"] = true
allMagicCrew["aea_cult_wizard_a07"] = true
allMagicCrew["aea_cult_wizard_s08"] = true
allMagicCrew["aea_cult_wizard_s09"] = true
allMagicCrew["aea_cult_wizard_a10"] = true
allMagicCrew["aea_cult_wizard_a11"] = true
allMagicCrew["aea_cult_wizard_s12"] = true
allMagicCrew["aea_cult_wizard_s13"] = true
allMagicCrew["aea_cult_wizard_s14"] = true
allMagicCrew["aea_cult_wizard_s15"] = true
allMagicCrew["aea_cult_priest_sup"] = true
allMagicCrew["aea_cult_priest_off"] = true
allMagicCrew["aea_cult_priest_bor"] = true
allMagicCrew["aea_cult_tiny_a01"] = true
allMagicCrew["aea_cult_tiny_a02"] = true
allMagicCrew["aea_cult_tiny_s03"] = true
allMagicCrew["aea_cult_tiny_s04"] = true
allMagicCrew["aea_cult_tiny_s05"] = true
allMagicCrew["aea_cult_tiny_s06"] = true
allMagicCrew["aea_cult_tiny_a07"] = true
allMagicCrew["aea_cult_tiny_s08"] = true
allMagicCrew["aea_cult_tiny_s09"] = true
allMagicCrew["aea_cult_tiny_a10"] = true
allMagicCrew["aea_cult_tiny_a11"] = true
allMagicCrew["aea_cult_tiny_s12"] = true
allMagicCrew["aea_cult_tiny_s13"] = true
allMagicCrew["aea_cult_tiny_s14"] = true
allMagicCrew["aea_cult_tiny_s15"] = true

script.on_internal_event(Defines.InternalEvents.PROJECTILE_PRE, function(projectile)
	if projectile.bBroadcastTarget then return end
	local shipManager = Hyperspace.ships(projectile.destinationSpace) 
	if not shipManager then return end
	local room = get_room_at_location(shipManager, projectile.target, true)
	if projectile.ownerId ~= shipManager.iShipId then
		for crewmem in vter(shipManager.vCrewList) do
			if allMagicCrew[crewmem.type] and crewmem.iShipId == shipManager.iShipId and crewmem.iRoomId == room then
				projectile.bBroadcastTarget = true
			end
		end
	end
end)