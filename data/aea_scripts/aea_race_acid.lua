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


script.on_internal_event(Defines.InternalEvents.PROJECTILE_FIRE, function(projectile, weapon)
	if weapon.blueprint then
		if weapon.blueprint.name == "AEA_LASER_ACID_SUPER" or weapon.blueprint.name == "AEA_LASER_ACID_SUPER_ENEMY" then
			local shipManager = Hyperspace.ships(1-projectile.ownerId)
			for system in vter(shipManager.vSystemList) do
				local roomId = system.roomId
				local roomLoc = shipManager:GetRoomCenter(roomId)

				local spaceManager = Hyperspace.App.world.space
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

script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA_HIT, function(shipManager, projectile, location, damage, shipFriendlyFire)
  if projectile and projectile.extend.name == "AEA_LASER_ACID_BOSS" or projectile.extend.name == "AEA_LASER_ACID_BOSS_CHAOS" then
		local blueprint = Hyperspace.Blueprints:GetWeaponBlueprint(projectile.extend.name.."_PROJ")
    for roomId, roomPos in pairs(get_adjacent_rooms(shipManager.iShipId, get_room_at_location(shipManager, location, false), false)) do
      local spaceManager = Hyperspace.App.world.space
			local laser = spaceManager:CreateLaserBlast(
				blueprint,
				projectile.position,
				projectile.currentSpace,
				projectile.ownerId,
				roomPos,
				projectile.destinationSpace,
				projectile.heading)
    end
  end
end)


script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	if shipManager:HasAugmentation("AEA_ACID_O2SYS") > 0 and shipManager:HasSystem(2) and not Hyperspace.App.menu.shipBuilder.bOpen then
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
	elseif shipManager:HasAugmentation("AEA_ACID_O2SYS_ENEMY") > 0 and shipManager:HasSystem(2) and not Hyperspace.App.menu.shipBuilder.bOpen then
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

script.on_internal_event(Defines.InternalEvents.PRE_CREATE_CHOICEBOX, function(event)
	if string.sub(event.eventName, 0, string.len(eventString)) == eventString and Hyperspace.playerVariables[playerVar] == 0 then
		Hyperspace.playerVariables[playerVar] = 1
		initialPosX = (math.random() * 131072) % 131 - 65
		initialPosY = (math.random() * 131072) % 81 - 40
	end
end)

script.on_internal_event(Defines.InternalEvents.JUMP_ARRIVE, function(shipManager)
	Hyperspace.playerVariables[playerVar] = 0
end)

script.on_render_event(Defines.RenderEvents.LAYER_FOREGROUND, function() 
	if Hyperspace.Global.GetInstance():GetCApp().world.bStartedGame and Hyperspace.playerVariables[playerVar] == 1 and Hyperspace.Settings.lowend == false then
		for k, cloud in ipairs(nebulaClouds) do
			if cloud.exists == 1 then
				local commandGui = Hyperspace.Global.GetInstance():GetCApp().gui
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
					cloud.timerScale = cloud.timerScale + (Hyperspace.FPS.SpeedFactor/16)
					cloud.scale = cloud.scale + ((scaleIncrease/lifeTime) * (Hyperspace.FPS.SpeedFactor/16))
					if cloud.timerScale >= lifeTime then
						cloud.exists = 0
					end

					if cloud.timerScale >= (lifeTime - fadeOutTime) then
						cloud.opacity = math.max(cloud.opacity - (0.95 * (Hyperspace.FPS.SpeedFactor/16)), 0.05)
						if cloud.fade == 0 then
							cloud.fade = 1
							for k2, cloudNew in ipairs(nebulaClouds) do
								if cloudNew.exists == 0 then
									nebulaClouds[k2] = createCloud(cloud.x, cloud.y)
									break
								end
							end
						end
					elseif cloud.timerScale < fadeInTime then
						cloud.opacity = math.min(cloud.opacity + (0.95 * (Hyperspace.FPS.SpeedFactor/16)), 1)

					elseif cloud.revOp == 0 then
						cloud.opacity = math.min(cloud.opacity + (0.1 * (Hyperspace.FPS.SpeedFactor/16)), 1)
						if cloud.opacity >= 1 then
							cloud.revOp = 1
						end
					else
						cloud.opacity = cloud.opacity - (0.1 * (Hyperspace.FPS.SpeedFactor/16))
						if cloud.opacity <= 0.9 then
							cloud.revOp = 0
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
		if mousePos.x >= warningX and mousePos.x < (warningX + warningSizeX) and mousePos.y >= warningY and mousePos.y < (warningY + warningSizeY) then
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

script.on_internal_event(Defines.InternalEvents.ACTIVATE_POWER,  function(power, shipManager)
	local crewmem = power.crew
	if crewmem.type == "aea_acid_bill" and (not crewmem.bMindControlled) then
		if Hyperspace.ships.player then
			for crewp in vter(Hyperspace.ships.player.vCrewList) do
				if crewp.iShipId ~= crewmem.iShipId and crewp.health.first < 35 then
					crewp:Kill(false)
				end
			end
		end
		if Hyperspace.ships.enemy then
			for crewe in vter(Hyperspace.ships.enemy.vCrewList) do
				if crewe.iShipId ~= crewmem.iShipId and crewe.health.first < 35 then
					crewe:Kill(false)
				end
			end
		end
	end
end)

local acidBombPrint = Hyperspace.Blueprints:GetWeaponBlueprint("AEA_BOMB_INVIS_ACID_1")
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
				shipManager:GetRoomCenter(empty_rooms[math.random(empty_rooms_size)]),
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

local acidTimer = 1
script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
	local commandGui = Hyperspace.Global.GetInstance():GetCApp().gui
	if Hyperspace.playerVariables[playerVar] == 1 and not (commandGui.bPaused or commandGui.event_pause or commandGui.menu_pause or commandGui.bAutoPaused or commandGui.touch_pause) then
		acidTimer = acidTimer - (Hyperspace.FPS.SpeedFactor/16)
		if acidTimer <= 0 then
			acidTimer = (math.random() * 3) + 4
			acidTrigger()
		end
	end
end)

--[[local playerAcidTable = {}
local enemyAcidTable = {}
local acidTable = {[0] = playerAcidTable, [1] = enemyAcidTable}
local breachSpeed = 25
local airlockSpeed = 25
local breachDrainSpeed = 25
local airlockDrainSpeed = 25
local passiveDrain = 10
local maxDiffSpeed = 25

local needsSetRooms = {[0] = false, [1] = false}
script.on_internal_event(Defines.InternalEvents.CONSTRUCT_SHIP_MANAGER, function(shipManager)
	needsSetRooms[shipManager.iShipId] = true
end)

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	local acidRoomTable = acidTable[shipManager.iShipId]
	if needsSetRooms[shipManager.iShipId] then
		print("SET SHIP ACID ROOMS"..shipManager.iShipId)
		for room in vter(shipManager.ship.vRoomList) do
			local level = Hyperspace.playerVariables["aea_acid_ship"..shipManager.iShipId.."_room"..room.iRoomId]
			acidRoomTable[room.iRoomId] = {gasLevel = level}
			print("set room:"..room.iRoomId.." to level:"..level.." ship:"..shipManager.iShipId)
		end
		needsSetRooms[shipManager.iShipId] = false
	end
	for door in vter(shipManager.ship.vDoorList) do
		if door.bOpen then
			if door.iRoom1 < 0 then
				if Hyperspace.playerVariables[playerVar] == 1 then
					print("TRANSFERING FROM airlock to room:"..door.iRoom2)
					acidRoomTable[door.iRoom2].gasLevel = math.min(100, acidRoomTable[door.iRoom2].gasLevel + airlockSpeed * Hyperspace.FPS.SpeedFactor/16)
				else
					print("TRANSFERING FROM room:"..door.iRoom2.." to airlock")
					acidRoomTable[door.iRoom1].gasLevel = math.max(0, acidRoomTable[door.iRoom1].gasLevel - airlockDrainSpeed * Hyperspace.FPS.SpeedFactor/16)
				end
			elseif door.iRoom2 < 0 then
				if Hyperspace.playerVariables[playerVar] == 1 then
					print("TRANSFERING FROM airlock to room:"..door.iRoom1)
					acidRoomTable[door.iRoom1].gasLevel = math.min(100, acidRoomTable[door.iRoom1].gasLevel + airlockSpeed * Hyperspace.FPS.SpeedFactor/16)
				else
					print("TRANSFERING FROM room:"..door.iRoom1.." to airlock")
					acidRoomTable[door.iRoom1].gasLevel = math.max(0, acidRoomTable[door.iRoom1].gasLevel - airlockDrainSpeed * Hyperspace.FPS.SpeedFactor/16)
				end
			else
				local diff = acidRoomTable[door.iRoom1].gasLevel - acidRoomTable[door.iRoom2].gasLevel
				if diff > 0.1 then
					print("TRANSFERING FROM room:"..door.iRoom1.." to room:"..door.iRoom2)
					acidRoomTable[door.iRoom1].gasLevel = math.max(0, math.min(100, acidRoomTable[door.iRoom1].gasLevel + -1 * math.min(diff, maxDiffSpeed) * Hyperspace.FPS.SpeedFactor/16))
					acidRoomTable[door.iRoom2].gasLevel = math.max(0, math.min(100, acidRoomTable[door.iRoom2].gasLevel + math.min(diff, maxDiffSpeed) * Hyperspace.FPS.SpeedFactor/16))
				end
			end
		end
	end
	if Hyperspace.playerVariables[playerVar] == 1 then
		for breach in vter(shipManager.ship:GetHullBreaches(true)) do
			--print("found Breach:"..breach.name.." room:"..breach.roomId.." fDamage:"..breach.fDamage.." fMaxDamage:"..breach.fMaxDamage.." iRepairCount:"..breach.iRepairCount)
				print("TRANSFERING FROM breach to room:"..breach.roomId)
			acidRoomTable[breach.roomId].gasLevel = math.min(100, acidRoomTable[breach.roomId].gasLevel + breachSpeed * Hyperspace.FPS.SpeedFactor/16)
		end
	else
		for breach in vter(shipManager.ship:GetHullBreaches(true)) do
			--print("found Breach:"..breach.name.." room:"..breach.roomId.." fDamage:"..breach.fDamage.." fMaxDamage:"..breach.fMaxDamage.." iRepairCount:"..breach.iRepairCount)
			print("TRANSFERING FROM room:"..breach.roomId.." to breach")
			acidRoomTable[breach.roomId].gasLevel = math.max(0, acidRoomTable[breach.roomId].gasLevel - breachDrainSpeed * Hyperspace.FPS.SpeedFactor/16)
		end
	end
	for room in vter(shipManager.ship.vRoomList) do
		acidRoomTable[room.iRoomId].gasLevel = math.max(0, acidRoomTable[room.iRoomId].gasLevel - passiveDrain * Hyperspace.FPS.SpeedFactor/16)
		Hyperspace.playerVariables["aea_acid_ship"..shipManager.iShipId.."_room"..room.iRoomId] = acidRoomTable[room.iRoomId].gasLevel
	end
end)

-- Add oxygen instead of removing
script.on_internal_event(Defines.InternalEvents.CALCULATE_LEAK_MODIFIER, function(ship, mod)
    if Hyperspace.playerVariables[playerVar] == 1 then
        return Defines.Chain.CONTINUE, -mod
    end
end)

local roomAcidGasImage = Hyperspace.Resources:CreateImagePrimitiveString("effects/acid_effect_tile.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false)
script.on_render_event(Defines.RenderEvents.SHIP_FLOOR, function() end, function(ship)
  local shipManager = Hyperspace.ships(ship.iShipId)
 	for room in vter(shipManager.ship.vRoomList) do
 		local gasLevel = Hyperspace.playerVariables["aea_acid_ship"..shipManager.iShipId.."_room"..room.iRoomId]
 		
 		if gasLevel > 0 then
 			local opacity = gasLevel/100
 			local x = room.rect.x
 			local y = room.rect.y
 			local w = math.floor(room.rect.w/35)
 			local h = math.floor(room.rect.h/35)
 			local size = w * h
 			--print("room:"..room.iRoomId.." gasLevel:"..gasLevel.." w:"..w.." h:"..h.." size:"..size)
 			for i = 0, size - 1 do
 				local xOff = x + (i%w) * 35
 				local yOff = y + math.floor(i/w) * 35
				Graphics.CSurface.GL_PushMatrix()
				Graphics.CSurface.GL_Translate(xOff, yOff, 0)
				Graphics.CSurface.GL_RenderPrimitiveWithAlpha(roomAcidGasImage, opacity)
				Graphics.CSurface.GL_PopMatrix()
 			end
 		end
 	end
end)]]


--[[local gases = {}
local updateInterval = 0.25
local function initializeGas(name, breachLevels, airlockLevels, fire, passive, doorLevels, fakeOpen, variable)
	gases[name] = {[0] = {}, [1] = {}, breachSpeedLevels = breachLevels, airlockSpeedLevels = airlockLevels, fireSpeed = fire, passiveSpeed = passive, doorSpeedLevels = doorLevels, transferBetweenFakeOpen = transferBetweenFakeOpen, activeVar = variable}
end

script.on_internal_event(Defines.InternalEvents.CALCULATE_LEAK_MODIFIER, function(ship, mod)
    return Defines.Chain.CONTINUE, -mod
end)

-- -1 = open doors
-- 0 = lvl 0 doors
-- 1 = lvl 1 doors
-- 2 = lvl 2 doors
-- 3 = lvl 3 doors
-- 4 = lvl 4 doors
-- 5 = lockedDown doors
local function connectivityRecursion(shipGraph, connectTable, roomId, lowestDoor, currentRecursion)
	--print("RECURSE:"..roomId)
	for door in vter(shipGraph:GetDoors(roomId)) do
		local currentDoorLevel = door.doorLevel
		if door.bOpen then
			currentDoorLevel = -1
		end
		local targetRoom = door.iRoom1
		if targetRoom == roomId then
			targetRoom = door.iRoom2
		end
		if connectTable[targetRoom] then
			if connectTable[targetRoom].doorLevel > math.max(lowestDoor, currentDoorLevel) or (connectTable[targetRoom].doorLevel == math.max(lowestDoor, currentDoorLevel) and connectTable[targetRoom].connection > currentRecursion) then
				connectTable[targetRoom] = {connection = currentRecursion, doorLevel = math.max(lowestDoor, currentDoorLevel)}
				--print("  UPDATING TARGET ROOM:"..targetRoom.." connection:"..currentRecursion.." level:"..math.max(lowestDoor, currentDoorLevel)..", RECURSING FROM "..roomId)
				connectivityRecursion(shipGraph, connectTable, targetRoom, math.max(lowestDoor, currentDoorLevel), currentRecursion + 1)
			end
		else
			connectTable[targetRoom] = {connection = currentRecursion, doorLevel = math.max(lowestDoor, currentDoorLevel)}
			--print("CREATING TARGET ROOM:"..targetRoom.." connection:"..currentRecursion.." level:"..math.max(lowestDoor, currentDoorLevel)..", RECURSING FROM "..roomId.." TO "..targetRoom)
			connectivityRecursion(shipGraph, connectTable, targetRoom, math.max(lowestDoor, currentDoorLevel), currentRecursion + 1)
		end
	end
end
local function getConnectivityTable(shipManager, shipGraph, roomId)
	local tab = {}
	tab[roomId] = {connection = 0, doorLevel = -1}
	connectivityRecursion(shipGraph, tab, roomId, -1, 1)
	for room in vter(shipManager.ship.vRoomList) do
		if not tab[room.iRoomId] then
			tab[room.iRoomId] = {connection = -1, doorLevel = -1}
		end
	end
	return tab
end

local function getRoomChunks(shipManager, threshold)
	local roomChunks = {}
	local shipGraph = Hyperspace.ShipGraph.GetShipInfo(shipManager.iShipId)
	for room in vter(shipManager.ship.vRoomList) do
		local fitsInRoomGroup = false
		local connectivityTable = getConnectivityTable(shipManager, shipGraph, room.iRoomId)
		for i, chunk in ipairs(roomChunks) do
			if connectivityTable[chunk[1]]--[[.connection >= 0 and connectivityTable[chunk[1]]--[[.doorLevel <= threshold and not fitsInRoomGroup then
				fitsInRoomGroup = true
				table.insert(chunk, room.iRoomId)
			end
		end
		if not fitsInRoomGroup then
			table.insert(roomChunks, {room.iRoomId})
		end
	end
	--print("FOUND "..#roomChunks.." ROOM GROUPS")
	return roomChunks
end

local function getGasInRoom(shipManager, data, roomId)
	return data[shipManager.iShipId][roomId]
end
local function updateGasInRoom(shipManager, name, data, roomId, average, level)
	local diff = average - data[shipManager.iShipId][roomId]
	data[shipManager.iShipId][roomId] = math.min(100, data[shipManager.iShipId][roomId] + data.doorSpeedLevels[level] * (diff/100) * updateInterval)
	Hyperspace.playerVariables["gas"..name.."_ship"..shipManager.iShipId.."_room"..roomId] = data[shipManager.iShipId][roomId]
end

local function redistributeGases(shipManager)
	for i = -1, 4 do
		local roomChunks = getRoomChunks(shipManager, i)
		for _, chunk in ipairs(roomChunks) do
			local averageSum = {}
			for name, data in pairs(gases) do
				averageSum[name] = 0
			end
			-- sum gases
			for _, roomId in ipairs(chunk) do
				for name, data in pairs(gases) do
					averageSum[name] = averageSum[name] + getGasInRoom(shipManager, data, roomId)
				end
			end
			-- compute averages
			local average = {}
			for name, data in pairs(gases) do
				average[name] = averageSum[name] / #chunk
			end
			-- Update rooms
			for _, roomId in ipairs(chunk) do
				for name, data in pairs(gases) do
					updateGasInRoom(shipManager, name, data, roomId, average[name], i)
				end
			end
		end
	end
end

local function computerAirLoss(shipManager, name, data, loss, connection, roomId)
	local invert = 1
	if Hyperspace.playerVariables[data.activeVar] >= 1 then invert = -1 end
	data[shipManager.iShipId][roomId] = math.min(100, math.max(0, data[shipManager.iShipId][roomId] - loss * updateInterval * (0.75 ^ connection) * invert))
	Hyperspace.playerVariables["gas"..name.."_ship"..shipManager.iShipId.."_room"..roomId] = data[shipManager.iShipId][roomId]
end

local function computeBreaches(shipManager)
	local shipGraph = Hyperspace.ShipGraph.GetShipInfo(shipManager.iShipId)
	for breach in vter(shipManager.ship:GetHullBreaches(true)) do
		print("BREACH DRAINING ROOM:"..breach.roomId)
		local connectivityTable = getConnectivityTable(shipManager, shipGraph, breach.roomId)
		for room in vter(shipManager.ship.vRoomList) do
			for i = -1, 4 do
				if connectivityTable[room.iRoomId].doorLevel <= i and connectivityTable[room.iRoomId].connection >= 0 then
					for name, data in pairs(gases) do
						computerAirLoss(shipManager, name, data, data.breachSpeedLevels[i], connectivityTable[room.iRoomId].connection, room.iRoomId)
					end
				end
			end
		end
	end
end

local function computeAirlocks(shipManager)
	local shipGraph = Hyperspace.ShipGraph.GetShipInfo(shipManager.iShipId)
	for door in vter(shipManager.ship.vOuterAirlocks) do
		if door.bOpen then
			print("DOOR OPEN 1:"..tostring(door.iRoom1).." 2:"..tostring(door.iRoom2))
			local targetRoom = nil
			if door.iRoom1 < 0 then
				targetRoom = door.iRoom2
			elseif door.iRoom2 < 0 then
				targetRoom = door.iRoom1
			end
			if targetRoom then
				print("AIRLOCK DRAINING ROOM:"..targetRoom)
				local connectivityTable = getConnectivityTable(shipManager, shipGraph, targetRoom)
				for room in vter(shipManager.ship.vRoomList) do
					for i = -1, 4 do
						if connectivityTable[room.iRoomId].doorLevel <= i and connectivityTable[room.iRoomId].connection >= 0 then
							for name, data in pairs(gases) do
								computerAirLoss(shipManager, name, data, data.breachSpeedLevels[i], connectivityTable[room.iRoomId].connection, room.iRoomId)
							end
						end
					end
				end
			end
		end
	end
end

local function directModifyGas(shipManager, name, data, loss, roomId)
	data[shipManager.iShipId][roomId] =  math.min(100, math.max(0, data[shipManager.iShipId][roomId] - loss * updateInterval * (0.75 ^ connection)))
	Hyperspace.playerVariables["gas"..name.."_ship"..shipManager.iShipId.."_room"..roomId] = data[shipManager.iShipId][roomId]
end

initializeGas("AEA_ACID", 
	{[-1] = 6.4, [0] = 0, [1] = 1, [2] = 0.4, [3] = 0.2, [4] = 0, lockedDown = 0}, 
	{[-1] = 12.8, [0] = 0, [1] = 2, [2] = 0.8, [3] = 0.4, [4] = 0, lockedDown = 0}, 
	0.96, 
	1.2, 
	{[-1] = 6.4, [0] = 0, [1] = 1, [2] = 0.4, [3] = 0.2, [4] = 0, lockedDown = 0}, 
	true,
	playerVar)

function testGas1()
	gases["AEA_ACID"][0][0] = 100
end

function d()
	local shipManager = Hyperspace.ships.player
	local shipGraph = Hyperspace.ShipGraph.GetShipInfo(shipManager.iShipId)
	local tabCon = getConnectivityTable(shipManager, shipGraph, 0)
	for roomId, data in pairs(tabCon) do
		gases["AEA_ACID"][0][roomId] = data.connection
		print("FROM room 0 to room "..roomId.." connection:"..data.connection.." level:"..data.doorLevel)
	end
end

local timer = 0
script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	timer = timer + Hyperspace.FPS.SpeedFactor/16
	if timer > updateInterval then 
		timer = timer - updateInterval
		computeBreaches(shipManager)
		computeAirlocks(shipManager)
		redistributeGases(shipManager)
		for room in vter(shipManager.ship.vRoomList) do
			for name, data in pairs(gases) do
				local modifier = data.passiveSpeed + data.fireSpeed * shipManager:GetFireCount(room.iRoomId)
				directModifyGas(shipManager, name, data, modifier, room.iRoomId)
			end
		end
	end
end)

script.on_render_event(Defines.RenderEvents.SHIP, function() end, function(ship)
  local shipManager = Hyperspace.ships(ship.iShipId)
 	for room in vter(shipManager.ship.vRoomList) do
 		for name, data in pairs(gases) do
			Graphics.CSurface.GL_SetColor(Graphics.GL_Color(1, 0, 0, 1))
 			Graphics.freetype.easy_print(1, room.rect.x+3, room.rect.y+3, math.floor(getGasInRoom(shipManager, data, room.iRoomId)) )
			Graphics.CSurface.GL_SetColor(Graphics.GL_Color(1, 1, 1, 1))
 		end
 	end
end)

local needsSetRooms = {[0] = false, [1] = false}
script.on_internal_event(Defines.InternalEvents.CONSTRUCT_SHIP_MANAGER, function(shipManager)
	needsSetRooms[shipManager.iShipId] = true
end)

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	if needsSetRooms[shipManager.iShipId] and Hyperspace.playerVariables.aea_test_variable == 1 then
		for room in vter(shipManager.ship.vRoomList) do
			for name, data in pairs(gases) do
				local level = Hyperspace.playerVariables["gas"..name.."_ship"..shipManager.iShipId.."_room"..room.iRoomId]
				data[shipManager.iShipId][room.iRoomId] = level
			end
		end
		needsSetRooms[shipManager.iShipId] = false
	end
end)]]