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

local playerRoomsSlugPlayer = {}
local playerRoomsSlugEnemy = {}
local enemyRoomsSlugPlayer = {}
local enemyRoomsSlugEnemy = {}

local playerRoomsSlugPlayerUnique = {}
local playerRoomsSlugEnemyUnique = {}
local enemyRoomsSlugPlayerUnique = {}
local enemyRoomsSlugEnemyUnique = {}

script.on_internal_event(Defines.InternalEvents.ACTIVATE_POWER, function(power, shipManager)
	if log_events then
		log("ACTIVATE_POWER 6")
	end
	local crewmem = power.crew
	local spaceManager = Hyperspace.Global.GetInstance():GetCApp().world.space

	if crewmem.type == "aea_shleg_shell" then
		local currentManager = Hyperspace.ships(crewmem.currentShipId)
		for crewCurrent in vter(currentManager.vCrewList) do
			if crewCurrent.iRoomId == crewmem.iRoomId and crewCurrent.iShipId ~= crewmem.iShipId and crewCurrent.bMindControlled then
				crewCurrent.health.first = math.min(crewCurrent.health.first, math.max(10, crewCurrent.health.first - 75))
			end
		end
	elseif crewmem.type == "aea_shleg_sorrow" then
		local currentManager = Hyperspace.ships(crewmem.currentShipId)
		for crewCurrent in vter(currentManager.vCrewList) do
			if crewCurrent.iRoomId == crewmem.iRoomId and crewCurrent.iShipId ~= crewmem.iShipId and crewCurrent.bMindControlled then
				crewCurrent:Kill(false)
			end
		end
	elseif crewmem.type == "aea_shleg_slug" then
		if crewmem.currentShipId == 0 and crewmem.iShipId == 0 then
			playerRoomsSlugPlayer[crewmem.iRoomId] = 30
		elseif crewmem.currentShipId == 0 and crewmem.iShipId == 1 then
			playerRoomsSlugEnemy[crewmem.iRoomId] = 30
		elseif crewmem.currentShipId == 1 and crewmem.iShipId == 0 then
			enemyRoomsSlugPlayer[crewmem.iRoomId] = 30
		elseif crewmem.currentShipId == 1 and crewmem.iShipId == 1 then
			enemyRoomsSlugEnemy[crewmem.iRoomId] = 30
		end
	elseif crewmem.type == "aea_shleg_sickle" then
		--print("sickle")
		if crewmem.currentShipId == 0 and crewmem.iShipId == 0 then
			playerRoomsSlugPlayer[crewmem.iRoomId] = 60
		elseif crewmem.currentShipId == 0 and crewmem.iShipId == 1 then
			playerRoomsSlugEnemy[crewmem.iRoomId] = 60
		elseif crewmem.currentShipId == 1 and crewmem.iShipId == 0 then
			enemyRoomsSlugPlayer[crewmem.iRoomId] = 60
		elseif crewmem.currentShipId == 1 and crewmem.iShipId == 1 then
			enemyRoomsSlugEnemy[crewmem.iRoomId] = 60
		end
		if crewmem.currentShipId == 0 and crewmem.iShipId == 0 then
			playerRoomsSlugPlayerUnique[crewmem.iRoomId] = 60
		elseif crewmem.currentShipId == 0 and crewmem.iShipId == 1 then
			playerRoomsSlugEnemyUnique[crewmem.iRoomId] = 60
		elseif crewmem.currentShipId == 1 and crewmem.iShipId == 0 then
			enemyRoomsSlugPlayerUnique[crewmem.iRoomId] = 60
		elseif crewmem.currentShipId == 1 and crewmem.iShipId == 1 then
			enemyRoomsSlugEnemyUnique[crewmem.iRoomId] = 60
		end
	end
end)
mods.aea.gasWeapons = {}
local gasWeapons = mods.aea.gasWeapons
gasWeapons["AEA_SHLEG_BOMB"] = 30
gasWeapons["AEA_SHLEG_BOMB_FAKE"] = 90
gasWeapons["AEA_SHLEG_BOMB_FAKE_SHORT"] = 60
gasWeapons["AEA_SHLEG_MISSILES"] = 30
gasWeapons["AEA_SHLEG_MISSILES_LOOT"] = 60
gasWeapons["ARTILLERY_SHLEG_1"] = 20

script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA_HIT, function(shipManager, projectile, location, damage, shipFriendlyFire)
	if projectile and gasWeapons[projectile.extend.name] then
		local roomAtLoc = get_room_at_location(shipManager, location, true)
		if projectile.destinationSpace == 0 and projectile.ownerId == 0 then
			if not playerRoomsSlugPlayer[roomAtLoc] or playerRoomsSlugPlayer[roomAtLoc] < gasWeapons[projectile.extend.name] then
				playerRoomsSlugPlayer[roomAtLoc] = gasWeapons[projectile.extend.name]
			end
		elseif projectile.destinationSpace == 0 and projectile.ownerId == 1 then
			if not playerRoomsSlugEnemy[roomAtLoc] or playerRoomsSlugEnemy[roomAtLoc] < gasWeapons[projectile.extend.name] then
				playerRoomsSlugEnemy[roomAtLoc] = gasWeapons[projectile.extend.name]
			end
		elseif projectile.destinationSpace == 1 and projectile.ownerId == 0 then
			if not enemyRoomsSlugPlayer[roomAtLoc] or enemyRoomsSlugPlayer[roomAtLoc] < gasWeapons[projectile.extend.name] then
				enemyRoomsSlugPlayer[roomAtLoc] = gasWeapons[projectile.extend.name]
			end
		elseif projectile.destinationSpace == 1 and projectile.ownerId == 1 then
			if not enemyRoomsSlugEnemy[roomAtLoc] or enemyRoomsSlugEnemy[roomAtLoc] < gasWeapons[projectile.extend.name] then
				enemyRoomsSlugEnemy[roomAtLoc] = gasWeapons[projectile.extend.name]
			end
		end
	end
end)

script.on_internal_event(Defines.InternalEvents.DAMAGE_BEAM, function(shipManager, projectile, location, damage, realNewTile, beamHitType)
	if projectile and gasWeapons[projectile.extend.name] and beamHitType == Defines.BeamHit.NEW_ROOM then
		local roomAtLoc = get_room_at_location(shipManager, location, true)
		if projectile.destinationSpace == 0 and projectile.ownerId == 0 then
			if not playerRoomsSlugPlayer[roomAtLoc] or playerRoomsSlugPlayer[roomAtLoc] < gasWeapons[projectile.extend.name] then
				playerRoomsSlugPlayer[roomAtLoc] = gasWeapons[projectile.extend.name]
			end
		elseif projectile.destinationSpace == 0 and projectile.ownerId == 1 then
			if not playerRoomsSlugEnemy[roomAtLoc] or playerRoomsSlugEnemy[roomAtLoc] < gasWeapons[projectile.extend.name] then
				playerRoomsSlugEnemy[roomAtLoc] = gasWeapons[projectile.extend.name]
			end
		elseif projectile.destinationSpace == 1 and projectile.ownerId == 0 then
			if not enemyRoomsSlugPlayer[roomAtLoc] or enemyRoomsSlugPlayer[roomAtLoc] < gasWeapons[projectile.extend.name] then
				enemyRoomsSlugPlayer[roomAtLoc] = gasWeapons[projectile.extend.name]
			end
		elseif projectile.destinationSpace == 1 and projectile.ownerId == 1 then
			if not enemyRoomsSlugEnemy[roomAtLoc] or enemyRoomsSlugEnemy[roomAtLoc] < gasWeapons[projectile.extend.name] then
				enemyRoomsSlugEnemy[roomAtLoc] = gasWeapons[projectile.extend.name]
			end
		end
	end
	return Defines.Chain.CONTINUE, beamHitType
end)

local resists_mind_control = mods.multiverse.resists_mind_control
local can_be_mind_controlled = mods.multiverse.can_be_mind_controlled

local gasImmuneCrew = {}
for crew in vter(Hyperspace.Blueprints:GetBlueprintList("LIST_CREW_GAS")) do
	gasImmuneCrew[crew] = true
end

script.on_internal_event(Defines.InternalEvents.CREW_LOOP, function(crewmem)
	if gasImmuneCrew[crewmem.type] then return end
	local shipManager = Hyperspace.ships(crewmem.currentShipId)
	local shlegTable = userdata_table(crewmem, "mods.aea.shlegGas")
	local commandGui = Hyperspace.Global.GetInstance():GetCApp().gui
	if (commandGui.bPaused or commandGui.event_pause or commandGui.menu_pause or commandGui.bAutoPaused or commandGui.touch_pause) then return end
	if shlegTable.amount then
		if crewmem.bMindControlled then 
			shlegTable.amount = math.max(0, shlegTable.amount - (Hyperspace.FPS.SpeedFactor/16 * 7.5))
		elseif (crewmem.iShipId ~= crewmem.currentShipId and shipManager:HasAugmentation("LOCKED_AEA_SHLEG_MIND_GAS") > 0) or
				(crewmem.iShipId ~= crewmem.currentShipId and shipManager:HasAugmentation("LOCKED_AEA_SHLEG_MIND_GAS") > 0) or
				(crewmem.iShipId ~= crewmem.currentShipId and shipManager:HasAugmentation("LOCKED_AEA_SHLEG_MIND_GAS_PLUS") > 0) or
				(crewmem.currentShipId == 0 and crewmem.iShipId == 0 and playerRoomsSlugEnemy[crewmem.iRoomId]) or
				(crewmem.currentShipId == 0 and crewmem.iShipId == 1 and playerRoomsSlugPlayer[crewmem.iRoomId]) or
				(crewmem.currentShipId == 1 and crewmem.iShipId == 0 and enemyRoomsSlugEnemy[crewmem.iRoomId]) or
				(crewmem.currentShipId == 1 and crewmem.iShipId == 1 and enemyRoomsSlugPlayer[crewmem.iRoomId]) then
			if crewmem.health.first < 1 then return end
			shlegTable.amount = math.min(crewmem.health.first, shlegTable.amount + (Hyperspace.FPS.SpeedFactor/16 * 5))
			if (crewmem.iShipId ~= crewmem.currentShipId and shipManager:HasAugmentation("LOCKED_AEA_SHLEG_MIND_GAS_PLUS") > 0) or
				(crewmem.currentShipId == 0 and crewmem.iShipId == 0 and playerRoomsSlugEnemyUnique[crewmem.iRoomId]) or
				(crewmem.currentShipId == 0 and crewmem.iShipId == 1 and playerRoomsSlugPlayerUnique[crewmem.iRoomId]) or
				(crewmem.currentShipId == 1 and crewmem.iShipId == 0 and enemyRoomsSlugEnemyUnique[crewmem.iRoomId]) or
				(crewmem.currentShipId == 1 and crewmem.iShipId == 1 and enemyRoomsSlugPlayerUnique[crewmem.iRoomId]) then
				shlegTable.amount = math.min(crewmem.health.first, shlegTable.amount + (Hyperspace.FPS.SpeedFactor/16 * 5))
			end
			if shlegTable.amount >= crewmem.health.first then
				if can_be_mind_controlled(crewmem) then
					crewmem:SetMindControl(true)
					local mcTable = userdata_table(crewmem, "mods.mv.crewStuff")
					mcTable.mcTime = math.max((crewmem.health.first / 7.5), mcTable.mcTime or 0)
				elseif resists_mind_control(crewmem) then
					crewmem.bResisted = true
					shlegTable.amount = 0
				end
			end
		else 
			shlegTable.amount = math.max(0, shlegTable.amount - (Hyperspace.FPS.SpeedFactor/16 * 5))
		end
	else
		userdata_table(crewmem, "mods.aea.shlegGas").amount = 0
		--print("SET CREW MIND: "..crewmem.type)
	end
end)



local barBack1 = Hyperspace.Resources:CreateImagePrimitiveString("effects/aea_shleg_mind_bigred.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false)
local barBack2 = Hyperspace.Resources:CreateImagePrimitiveString("effects/aea_shleg_mind_bigblue.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false)
local barBack = Hyperspace.Resources:CreateImagePrimitiveString("effects/aea_shleg_mind.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false)
local mindBar = Hyperspace.Resources:CreateImagePrimitiveString("effects/aea_shleg_mindbar.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false)
script.on_render_event(Defines.RenderEvents.CREW_MEMBER_HEALTH, function(crewmem) end, function(crewmem)
	--print(crewmem.type)
	local shlegTable = userdata_table(crewmem, "mods.aea.shlegGas")
	if shlegTable.amount and shlegTable.amount > 0 then
		--print("CREW: "..crewmem.type.." #: "..tostring(shlegTable.amount))
		local position = crewmem:GetPosition()
		--[[Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(position.x - 11, position.y + 11, 0)
		Graphics.CSurface.GL_RenderPrimitive(barBack)
		Graphics.CSurface.GL_PopMatrix()]]

		local barScale = (shlegTable.amount / crewmem.health.second) * 25
		local offset = {x = -13, y = -11}
		if crewmem.iShipId == crewmem.currentShipId and not crewmem.bMindControlled and crewmem.bSharedSpot then
			offset.y = -15
		elseif crewmem.bSharedSpot then 
			offset.y = -4
			--print("SHARED") 
		end
		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(position.x + offset.x, position.y + offset.y, 0)
		Graphics.CSurface.GL_Scale(barScale,1,1)
		Graphics.CSurface.GL_RenderPrimitive(mindBar)
		Graphics.CSurface.GL_PopMatrix()
	end
end)



script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	local commandGui = Hyperspace.Global.GetInstance():GetCApp().gui
	if (commandGui.bPaused or commandGui.event_pause or commandGui.menu_pause or commandGui.bAutoPaused or commandGui.touch_pause) then return end
	for room in vter(shipManager.ship.vRoomList) do
		if shipManager.iShipId == 0 then
			if playerRoomsSlugPlayer[room.iRoomId] then
				playerRoomsSlugPlayer[room.iRoomId] = playerRoomsSlugPlayer[room.iRoomId] - Hyperspace.FPS.SpeedFactor/16
				if playerRoomsSlugPlayer[room.iRoomId] <= 0 then
					playerRoomsSlugPlayer[room.iRoomId] = nil
				end
			end
			if playerRoomsSlugEnemy[room.iRoomId] then
				playerRoomsSlugEnemy[room.iRoomId] = playerRoomsSlugEnemy[room.iRoomId] - Hyperspace.FPS.SpeedFactor/16
				if playerRoomsSlugEnemy[room.iRoomId] <= 0 then
					playerRoomsSlugEnemy[room.iRoomId] = nil
				end
			end
		else
			if enemyRoomsSlugPlayer[room.iRoomId] then
				enemyRoomsSlugPlayer[room.iRoomId] = enemyRoomsSlugPlayer[room.iRoomId] - Hyperspace.FPS.SpeedFactor/16
				if enemyRoomsSlugPlayer[room.iRoomId] <= 0 then
					enemyRoomsSlugPlayer[room.iRoomId] = nil
				end
			end
			if enemyRoomsSlugEnemy[room.iRoomId] then
				enemyRoomsSlugEnemy[room.iRoomId] = enemyRoomsSlugEnemy[room.iRoomId] - Hyperspace.FPS.SpeedFactor/16
				if enemyRoomsSlugEnemy[room.iRoomId] <= 0 then
					enemyRoomsSlugEnemy[room.iRoomId] = nil
				end
			end
		end
	end
end)


local function gasRooms(blueprintName)
	local shipManager = Hyperspace.ships.player
	local blueprint = Hyperspace.Blueprints:GetWeaponBlueprint(blueprintName)
	for room in vter(shipManager.ship.vRoomList) do
		local roomId = room.iRoomId
		local roomLoc = shipManager:GetRoomCenter(roomId)

		local spaceManager = Hyperspace.App.world.space
		spaceManager:CreateBomb(
			blueprint,
			1,
			roomLoc,
			0)
	end
end

script.on_game_event("AEA_SHLEG_GAS_TIMER_START_LONG", false, function()
	gasRooms("AEA_SHLEG_BOMB_FAKE")
end)
script.on_game_event("AEA_SHLEG_GAS_TIMER_START_SHORT", false, function()
	gasRooms("AEA_SHLEG_BOMB_FAKE_SHORT")
end)	
