mods.aea = {}

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
	if log_events then
		log("PROJECTILE_FIRE 1")
	end
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

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	if log_events then
		--log("SHIP_LOOP 1")
	end
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
	if log_events then
		--log("ON_TICK 1")
	end
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
	if log_events then
		log("PRE_CREATE_CHOICEBOX 1")
	end
	--print(string.sub(event.eventName, 0, 13))
	if string.sub(event.eventName, 0, string.len(eventString)) == eventString and Hyperspace.playerVariables[playerVar] == 0 then
		Hyperspace.playerVariables[playerVar] = 1
		initialPosX = (math.random() * 131072) % 131 - 65
		initialPosY = (math.random() * 131072) % 81 - 40
	end
end)

script.on_internal_event(Defines.InternalEvents.JUMP_ARRIVE, function(shipManager)
	if log_events then
		log("JUMP_ARRIVE 1")
	end
	Hyperspace.playerVariables[playerVar] = 0
end)

--[[script.on_init(function()
	if Hyperspace.playerVariables[playerVar] == 1 then
		if log_events then
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
	if log_events then
		--log("LAYER_FOREGROUND 1")
	end
	if Hyperspace.Global.GetInstance():GetCApp().world.bStartedGame and Hyperspace.playerVariables[playerVar] == 1 and Hyperspace.Settings.lowend == false then
		--if log_events then
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
	if log_events then
		--log("MOUSE_CONTROL 1")
	end
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

script.on_internal_event(Defines.InternalEvents.ACTIVATE_POWER,  function(power, shipManager)
	if log_events then
		log("ACTIVATE_POWER 1")
	end
	local crewmem = power.crew
	if crewmem.type == "aea_acid_bill" and (not crewmem.bMindControlled) then
		if Hyperspace.ships.player then
			for crewp in vter(Hyperspace.ships.player.vCrewList) do
				if (not crewp.iShipId == crewmem.iShipId) and crewp.health.first < 35 then
					crewp:Kill(false)
				end
			end
		end
		if Hyperspace.ships.enemy then
			for crewe in vter(Hyperspace.ships.enemy.vCrewList) do
				if (not crewe.iShipId == crewmem.iShipId) and crewe.health.first < 35 then
					crewe:Kill(false)
				end
			end
		end
	end
end)

-----------------------------------------
-----------------------------------------
--------------END OF ACIDIC--------------
-----------------------------------------
-----------------------------------------

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
				if enemyCrew.iShipId ~= crewmem.iShipId and enemyCrew.iRoomId == crewmem.iRoomId and (not zombieTable[enemyCrew.extend.selfId]) and (not crewmem:IsDrone()) then
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
		if not crewTable then return end
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

-----------------------------------------
-----------------------------------------
-------------END OF HERETICS-------------
-----------------------------------------
-----------------------------------------


script.on_render_event(Defines.RenderEvents.MOUSE_CONTROL, function() end, function() end)

script.on_internal_event(Defines.InternalEvents.PROJECTILE_INITIALIZE, function(projectile, weaponBlueprint) 
	if log_events then
		log("PROJECTILE_INITIALIZE 1")
	end
	if Hyperspace.ships(projectile.destinationSpace):HasAugmentation("AEA_OLD_EVASION_ENEMY") > 0 and projectile.destinationSpace ~= projectile.currentSpace then
		local dodgeFactor = Hyperspace.ships.enemy:GetDodgeFactor()
		--print("ORGINAL: "..tostring(projectile.entryAngle))
		if dodgeFactor >= 5 then
			projectile.entryAngle = (projectile.entryAngle / 6) + 270 - 30
			--print(tostring((360/6) + 270 - 30).." TO "..tostring(270 - 30))
		end
		--print(projectile.entryAngle)
	end
	if Hyperspace.ships(projectile.destinationSpace):HasAugmentation("AEA_OLD_EVASION_ENEMY_WEAK") > 0 and projectile.destinationSpace ~= projectile.currentSpace then
		local dodgeFactor = Hyperspace.ships.enemy:GetDodgeFactor()
		if dodgeFactor >= 10 then
			projectile.entryAngle = (projectile.entryAngle / 4) + 270 - 45
			--print(tostring((360/4) + 270 - 45).." TO "..tostring(270 - 45))
		end
		--print(projectile.entryAngle)
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
	if log_events then
		--log("SHIP_LOOP 4")
	end
	if shipManager.iShipId == 0 then
		--print("ADD PLAYER ROOMS")
		playerRooms = armouredShips[shipManager.myBlueprint.blueprintName]
	elseif shipManager.iShipId == 1 then
		enemyRooms = armouredShips[shipManager.myBlueprint.blueprintName]
	end
end)

local reducedProjectiles = {}


script.on_internal_event(Defines.InternalEvents.PROJECTILE_PRE, function(projectile) 
	if log_events then
		--log("PROJECTILE_PRE 1")
	end
	--print("PROJECTILE_PRE")
	if projectile.currentSpace == projectile.destinationSpace and projectile.ownerId ~= projectile.currentSpace then
		local shipManager = Hyperspace.ships(projectile.currentSpace)
		if not shipManager then return end
		local roomAtProjectile = get_room_at_location(shipManager, projectile.position, false)
		local roomAtTarget = get_room_at_location(shipManager, projectile.position, false)
		if shipManager.iShipId == 0 and playerRooms then
			--print("ROOM: ".."r"..tostring(math.floor(roomAtProjectile)))
			local isRoom = playerRooms["r"..tostring(math.floor(roomAtProjectile))]
			--print(isRoom)
			if isRoom and (not reducedProjectiles[projectile.selfId]) then 
				--print("IS ROOM")
				if projectile.damage.iDamage <= 1 then
					--print("DELETE PROJ")
					projectile.target = projectile.position
					--projectile:ComputeHeading()
				else
					--print("REDUCE DAMAGE")
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
					--print("DELETE PROJ")
					projectile.target = projectile.position
					--projectile:ComputeHeading()
				else
					--print("REDUCE DAMAGE")
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
	if log_events then
		log("JUMP_ARRIVE 4")
	end
	reducedProjectiles = {}
end)

script.on_internal_event(Defines.InternalEvents.PROJECTILE_UPDATE_PRE, function(projectile) 
	if log_events then
		--log("PROJECTILE_UPDATE_PRE 1")
	end
	--print("PROJECTILE_UPDATE_PRE")
end)
script.on_internal_event(Defines.InternalEvents.PROJECTILE_UPDATE_POST, function(projectile, preempted)  
	if log_events then
		--log("PROJECTILE_UPDATE_POST 1")
	end
	--print("PROJECTILE_UPDATE_POST")
end)
script.on_internal_event(Defines.InternalEvents.PROJECTILE_POST, function(projectile, preempted) 
	if log_events then
		--log("PROJECTILE_POST 1")
	end
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
	if log_events then
		--log("GET_DODGE_FACTOR 1")
	end
	if shipManager:HasSystem(1) then
		local engine = shipManager:GetSystem(1)
		if engine.powerState.first + engine.iBonusPower >= 9 then
			local powerExtra = engine.powerState.first + engine.iBonusPower + engine.iBatteryPower - 8
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
	if log_events then
		--log("SHIP_LOOP 5")
	end
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
	if log_events then
		log("ACTIVATE_POWER 3")
	end
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
script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA_HIT, function(shipManager, projectile, location, damage, shipFriendlyFire)
	if log_events then
		log("DAMAGE_AREA_HIT 1")
	end
	if projectile then
		if projectile.extend.name == "ARTILLERY_AEA_GRAPPLE" then
			attachedTimer = 25
		end
	end
end)

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	if log_events then
		--log("SHIP_LOOP 6")
	end
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
	if log_events then
		--log("ON_TICK 3")
	end
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

script.on_internal_event(Defines.InternalEvents.JUMP_ARRIVE, function(shipManager)
	if log_events then
		log("JUMP_ARRIVE 5")
	end
	--[[local map = Hyperspace.App.world.starMap
	local sourceLoc = nil
	--print("CHECK FOR BEACON")
	for loc in vter(map.locations) do
		if loc.event.eventName == "AEA_OLD_1_BARON" then
			--print("FOUND EXIT BEACON")
			sourceLoc = loc
		end
	end
	if sourceLoc then
		if sourceLoc.visited > 0 then return end
		local numberOfConnections = sourceLoc.connectedLocations:size()
		local random = math.random(0, numberOfConnections - 1)
		--print("random:"..tostring(random).." number of connections:"..tostring(numberOfConnections))
		local targetLoc = sourceLoc.connectedLocations[random]

		local sourceConnections = {}
		table.insert(sourceConnections, sourceLoc)
		--print("ADD SOURCE LOCATION:"..tostring(sourceLoc))

		for loc in vter(sourceLoc.connectedLocations) do
			if loc ~= targetLoc then
				--print("ADD SOURCE LOCATION:"..tostring(loc))
				table.insert(sourceConnections, loc)
			end
		end
		local sourcePoint = Hyperspace.Pointf(sourceLoc.loc.x,sourceLoc.loc.y) 

		local targetConnections = {}
		table.insert(targetConnections, targetLoc)
		--print("ADD TARGET LOCATION:"..tostring(targetLoc))

		for loc in vter(targetLoc.connectedLocations) do
			if loc ~= sourceLoc then
				--print("ADD TARGET LOCATION:"..tostring(loc))
				table.insert(targetConnections, loc)
			end
		end
		local targetPoint = Hyperspace.Pointf(targetLoc.loc.x,targetLoc.loc.y)

		--print("GOT ALL VALUES")


		targetLoc.connectedLocations:clear()
		sourceLoc.connectedLocations:clear()

		--[[
		print("SOURCE CONNECTIONS")
		for k,v in pairs(sourceConnections) do
			print("key:"..tostring(k).." value:"..tostring(v))
		end
		print("SOURCE POINT: x:"..tostring(sourcePoint.x).." y:"..tostring(sourcePoint.y))

		print("TARGET CONNECTIONS")
		for k,v in pairs(targetConnections) do
			print("key:"..tostring(k).." value:"..tostring(v))
		end
		print("SOURCE POINT: x:"..tostring(targetPoint.x).." y:"..tostring(targetPoint.y))
		]]
		--[[for k,loc in pairs(sourceConnections) do
			targetLoc.connectedLocations:push_back(loc)

			local adjacentConnections = {}
			table.insert(adjacentConnections, targetLoc)
			for loc2 in vter(loc.connectedLocations) do
				if loc2 ~= sourceLoc then
					table.insert(adjacentConnections, loc2)
				end
			end
			loc.connectedLocations:clear()
			for k, loc2 in pairs(adjacentConnections) do
				loc.connectedLocations:push_back(loc2)
			end
		end
		targetLoc.loc = sourcePoint

		for k,loc in pairs(targetConnections) do
			sourceLoc.connectedLocations:push_back(loc)

			local adjacentConnections = {}
			table.insert(adjacentConnections, sourceLoc)
			for loc2 in vter(loc.connectedLocations) do
				if loc2 ~= targetLoc then
					table.insert(adjacentConnections, loc2)
				end
			end
			loc.connectedLocations:clear()
			for k, loc2 in pairs(adjacentConnections) do
				loc.connectedLocations:push_back(loc2)
			end
		end
		sourceLoc.loc = targetPoint
	end]]
end)


-----------------------------------------
-----------------------------------------
--------------END OF LYLMIK--------------
-----------------------------------------
-----------------------------------------

mods.aea.burstDrones = {}
local burstDrones = mods.aea.burstDrones
burstDrones["AEA_BEAM_BIRD_BURST_1"] = 2
burstDrones["AEA_BEAM_BIRD_BURST_2"] = 3
burstDrones["AEA_BEAM_BIRD_BURST_3"] = 4


script.on_internal_event(Defines.InternalEvents.DRONE_FIRE, function(projectile, drone)
	if log_events then
		log("DRONE_FIRE 1")
	end
	local burstAmount = burstDrones[projectile.extend.name]
	if burstAmount then
		--print("DRONE FIRE")
		userdata_table(drone, "mods.aea.burstDrones").table = {0.0, burstAmount, projectile.position.x, projectile.position.y, projectile.currentSpace, projectile.target1, projectile.destinationSpace, projectile.heading, projectile.entryAngle}
		projectile:Kill()
	end
	return Defines.Chain.CONTINUE
end)

local burstLaserBlueprint = Hyperspace.Blueprints:GetWeaponBlueprint("DRONE_LASER_COMBAT")
burstSounds = RandomList:New {"lightLaser1", "lightLaser2", "lightLaser3"}

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	if log_events then
		--log("SHIP_LOOP 7")
	end
	for drone in vter(shipManager.spaceDrones) do
		--print("DRONE LOOP")
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
	if log_events then
		log("DRONE_FIRE 1")
	end
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
			local random = math.random(1, crewListSize)
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
	if log_events then
		log("DRONE_FIRE 1")
	end
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
	if log_events then
		--log("ON_TICK 4")
	end
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
	if log_events then
		log("DRONE_FIRE 1")
	end
	if (projectile.extend.name == "AEA_BEAM_BIRD_SWEEP_DELETE") then
		projectile:Kill()
	end
	return Defines.Chain.CONTINUE
end)

--[[script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA, function(shipManager, projectile, location, damage, evasion, friendlyfire) 
	if shipManager:HasAugmentation("AEA_OLD_ARMOUR_ALLOY") > 0 then
		if projectile.damage.iDamage > 0 then
			print("REDUCE")
			local damageNew = projectile.damage
			damageNew.iDamage = damageNew.iDamage - 1
			damage = damageNew
			projectile:SetDamage(damageNew)
		end
	end
end)]]


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
	if log_events then
		log("SHIELD_COLLISION 2525")
	end
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

-----------------------------------------
-----------------------------------------
---------------END OF BIRD---------------
-----------------------------------------
-----------------------------------------
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

script.on_render_event(Defines.RenderEvents.SHIP_SPARKS, function() end, function(shipManager)
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
	if weapon then
		local shipManager = Hyperspace.ships(weapon.iShipId)
		if shipManager:HasAugmentation("AEA_BARRIER_RELAY") > 0 then
			local room = get_room_at_location(shipManager, shipManager:GetRandomRoomCenter(), false)
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
	local room = get_room_at_location(shipManager, projectile.target, true)
	if projectile.ownerId ~= shipManager.iShipId then
		for crewmem in vter(shipManager.vCrewList) do
			if allMagicCrew[crewmem.type] and crewmem.iShipId == shipManager.iShipId and crewmem.iRoomId == room then
				projectile.bBroadcastTarget = true
			end
		end
	end
end)






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
		print("sickle")
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
				(crewmem.currentShipId == 0 and crewmem.iShipId == 0 and playerRoomsSlugEnemy[crewmem.iRoomId]) or
				(crewmem.currentShipId == 0 and crewmem.iShipId == 1 and playerRoomsSlugPlayer[crewmem.iRoomId]) or
				(crewmem.currentShipId == 1 and crewmem.iShipId == 0 and enemyRoomsSlugEnemy[crewmem.iRoomId]) or
				(crewmem.currentShipId == 1 and crewmem.iShipId == 1 and enemyRoomsSlugPlayer[crewmem.iRoomId]) then
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

--local selectedArtillery1 = 1
--local selectedArtillery1 = 2
--local selectedArtillery1 = 3
local nextWeapon = {}
nextWeapon["ARTILLERY_REBEL_LASER"] = "ARTILLERY_REBEL_BEAM"
nextWeapon["ARTILLERY_REBEL_BEAM"] = "ARTILLERY_REBEL_MISSILE"
nextWeapon["ARTILLERY_REBEL_MISSILE"] = "ARTILLERY_REBEL_LASER"

--[[script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	if Hyperspace.App.menu.shipBuilder.bOpen then
		print("IN HANGER")
		return
		--[[for artillery in vter(shipManager.artillerySystems) do
			local artyBlueprint = Hyperspace.Blueprints:GetWeaponBlueprint("ARTILLERY_REBEL_BEAM")
			artillery.projectileFactory = Hyperspace.ProjectileFactory(artyBlueprint, 0)
		end
		--local artilleryCount = 0

		--[[for system in vter(shipManager.vSystemList) do
			print("SYSTEM: "..system.iSystemType.." IMAGE: "..system.interiorImageName)

			if system.iSystemType == 11 then
				artilleryCount = artilleryCount + 1
				print("ARTILLERY: "..artilleryCount)

				if artilleryCount == selectedArtillery1 then
					print("SELECTED")
				elseif artilleryCount - 3 == selectedArtillery2 then
					print("SELECTED")
				elseif artilleryCount - 6 == selectedArtillery2 then
					print("SELECTED")
				else
					print("NOT SELECTED")
				end
			end
		end]]
	--[[end
	print("\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n")
	for artillery in vter(shipManager.artillerySystems) do
		local commandGui = Hyperspace.App.gui
		local equipment = commandGui.equipScreen
		local artyBlueprint = Hyperspace.Blueprints:GetWeaponBlueprint(nextWeapon[artillery.projectileFactory.blueprint.name])
		equipment:AddWeapon(artyBlueprint, true, false)
		local artilleryWeapon = shipManager.weaponSystem.weapons[0]
		--print(artilleryWeapon.blueprint.name)
		artillery.projectileFactory = artilleryWeapon
		shipManager.weaponSystem:RemoveWeapon(0)
		--print("REPLACED ARTY")
	end
	--[[local commandGui = Hyperspace.App.gui
	local equipment = commandGui.equipScreen
	--local artyBlueprint = Hyperspace.Blueprints:GetWeaponBlueprint("ARTILLERY_REBEL_MISSILE")
	local artyBlueprint = Hyperspace.Blueprints:GetWeaponBlueprint(nextWeapon[shipManager.artillerySystems[0].projectileFactory.blueprint.name])
	local shipManager = Hyperspace.ships.player
	equipment:AddWeapon(artyBlueprint, true, false)
	local artilleryWeapon = shipManager.weaponSystem.weapons[0]
	print(artilleryWeapon.blueprint.name)
	shipManager.artillerySystems[0].projectileFactory = artilleryWeapon
	shipManager.weaponSystem:RemoveWeapon(0)]]--
--end)]]


--[[script.on_game_event("START_BEACON_REAL", false, function()

	local commandGui = Hyperspace.App.gui
	local equipment = commandGui.equipScreen
	--local artyBlueprint = Hyperspace.Blueprints:GetWeaponBlueprint("ARTILLERY_REBEL_MISSILE")
	local artyBlueprint = Hyperspace.Blueprints:GetWeaponBlueprint(nextWeapon[shipManager.artillerySystems[0].projectileFactory.blueprint.name])
	local shipManager = Hyperspace.ships.player
	equipment:AddWeapon(artyBlueprint, true, false)
	local artilleryWeapon = shipManager.weaponSystem.weapons[0]
	print(artilleryWeapon.blueprint.name)
	shipManager.artillerySystems[0].projectileFactory = artilleryWeapon
	shipManager.weaponSystem:RemoveWeapon(0)
	--shipManager.weaponSystem.weapons[0] = nil
end)]]
local function setArtySlot(blueprintName, slot)
	--print("FUNCTION SLOT:"..slot.." BLUEPRINT:"..blueprintName)
	if Hyperspace.ships.player.artillerySystems[slot].projectileFactory.blueprint.name == blueprintName then return end
	--print("ACTUALLY SETTING")
	local commandGui = Hyperspace.App.gui
	local equipment = commandGui.equipScreen
	local artyBlueprint = Hyperspace.Blueprints:GetWeaponBlueprint(blueprintName)
	local shipManager = Hyperspace.ships.player
	equipment:AddWeapon(artyBlueprint, true, false)
	local artilleryWeapon = shipManager.weaponSystem.weapons[0]
	shipManager.artillerySystems[slot].projectileFactory = artilleryWeapon
	shipManager.weaponSystem:RemoveWeapon(0)
end

script.on_game_event("AEA_BROADSIDE_CHOOSE_LASER_1", false, function()
	setArtySlot("ARTILLERY_BROADSIDE_PIERCE", 0)
end)
script.on_game_event("AEA_BROADSIDE_CHOOSE_BEAM_1", false, function()
	setArtySlot("ARTILLERY_BROADSIDE_FOCUS", 0)
end)
script.on_game_event("AEA_BROADSIDE_CHOOSE_MISSILE_1", false, function()
	setArtySlot("ARTILLERY_BROADSIDE_MISSILE", 0)
end)
script.on_game_event("AEA_BROADSIDE_CHOOSE_ION_1", false, function()
	setArtySlot("ARTILLERY_BROADSIDE_MINE", 0)
end)


script.on_game_event("AEA_BROADSIDE_CHOOSE_LASER_1", false, function()
	setArtySlot("ARTILLERY_BROADSIDE_PIERCE", 1)
end)
script.on_game_event("AEA_BROADSIDE_CHOOSE_BEAM_2", false, function()
	setArtySlot("ARTILLERY_BROADSIDE_FOCUS", 1)
end)
script.on_game_event("AEA_BROADSIDE_CHOOSE_MISSILE_2", false, function()
	setArtySlot("ARTILLERY_BROADSIDE_MISSILE", 1)
end)
script.on_game_event("AEA_BROADSIDE_CHOOSE_ION_2", false, function()
	setArtySlot("ARTILLERY_BROADSIDE_MINE", 1)
end)


script.on_game_event("AEA_BROADSIDE_CHOOSE_LASER_1", false, function()
	setArtySlot("ARTILLERY_BROADSIDE_PIERCE", 2)
end)
script.on_game_event("AEA_BROADSIDE_CHOOSE_BEAM_3", false, function()
	setArtySlot("ARTILLERY_BROADSIDE_FOCUS", 2)
end)
script.on_game_event("AEA_BROADSIDE_CHOOSE_MISSILE_3", false, function()
	setArtySlot("ARTILLERY_BROADSIDE_MISSILE", 2)
end)
script.on_game_event("AEA_BROADSIDE_CHOOSE_ION_3", false, function()
	setArtySlot("ARTILLERY_BROADSIDE_MINE", 2)
end)



script.on_game_event("AEA_BROADSIDE2_CHOOSE_LASER_1", false, function()
	setArtySlot("ARTILLERY_BROADSIDE2_LASER", 0)
end)
script.on_game_event("AEA_BROADSIDE2_CHOOSE_BEAM_1", false, function()
	setArtySlot("ARTILLERY_BROADSIDE2_BEAM", 0)
end)
script.on_game_event("AEA_BROADSIDE2_CHOOSE_MISSILE_1", false, function()
	setArtySlot("ARTILLERY_BROADSIDE2_MISSILE", 0)
end)
script.on_game_event("AEA_BROADSIDE2_CHOOSE_ION_1", false, function()
	setArtySlot("ARTILLERY_BROADSIDE2_ION", 0)
end)


script.on_game_event("AEA_BROADSIDE2_CHOOSE_LASER_1", false, function()
	setArtySlot("ARTILLERY_BROADSIDE2_LASER", 1)
end)
script.on_game_event("AEA_BROADSIDE2_CHOOSE_BEAM_2", false, function()
	setArtySlot("ARTILLERY_BROADSIDE2_BEAM", 1)
end)
script.on_game_event("AEA_BROADSIDE2_CHOOSE_MISSILE_2", false, function()
	setArtySlot("ARTILLERY_BROADSIDE2_MISSILE", 1)
end)
script.on_game_event("AEA_BROADSIDE2_CHOOSE_ION_2", false, function()
	setArtySlot("ARTILLERY_BROADSIDE2_ION", 1)
end)


script.on_game_event("AEA_BROADSIDE2_CHOOSE_LASER_1", false, function()
	setArtySlot("ARTILLERY_BROADSIDE2_LASER", 2)
end)
script.on_game_event("AEA_BROADSIDE2_CHOOSE_BEAM_3", false, function()
	setArtySlot("ARTILLERY_BROADSIDE2_BEAM", 2)
end)
script.on_game_event("AEA_BROADSIDE2_CHOOSE_MISSILE_3", false, function()
	setArtySlot("ARTILLERY_BROADSIDE2_MISSILE", 2)
end)
script.on_game_event("AEA_BROADSIDE2_CHOOSE_ION_3", false, function()
	setArtySlot("ARTILLERY_BROADSIDE2_ION", 2)
end)

local needSetArty = false
--Run on game load
script.on_init(function()
	needSetArty = true
end)

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	if Hyperspace.ships.player and needSetArty and shipManager:HasAugmentation("SHIP_AEA_BROADSIDE") > 0 and Hyperspace.playerVariables.aea_broadside_slot1 > 0 then
		--print("SET slot1:"..Hyperspace.playerVariables.aea_broadside_slot1.. " slot2:"..Hyperspace.playerVariables.aea_broadside_slot2.." slot3:"..Hyperspace.playerVariables.aea_broadside_slot3)
		needSetArty = flase
		if Hyperspace.playerVariables.aea_broadside_slot1 == 1 then
			setArtySlot("ARTILLERY_BROADSIDE_PIERCE", 0)
		elseif Hyperspace.playerVariables.aea_broadside_slot1 == 2 then
			setArtySlot("ARTILLERY_BROADSIDE_FOCUS", 0)
		elseif Hyperspace.playerVariables.aea_broadside_slot1 == 3 then
			setArtySlot("ARTILLERY_BROADSIDE_MISSILE", 0)
		elseif Hyperspace.playerVariables.aea_broadside_slot1 == 4 then
			setArtySlot("ARTILLERY_BROADSIDE_MINE", 0)
		end
		if Hyperspace.playerVariables.aea_broadside_slot2 == 1 then
			setArtySlot("ARTILLERY_BROADSIDE_PIERCE", 1)
		elseif Hyperspace.playerVariables.aea_broadside_slot2 == 2 then
			setArtySlot("ARTILLERY_BROADSIDE_FOCUS", 1)
		elseif Hyperspace.playerVariables.aea_broadside_slot2 == 3 then
			setArtySlot("ARTILLERY_BROADSIDE_MISSILE", 1)
		elseif Hyperspace.playerVariables.aea_broadside_slot2 == 4 then
			setArtySlot("ARTILLERY_BROADSIDE_MINE", 1)
		end
		if Hyperspace.playerVariables.aea_broadside_slot3 == 1 then
			setArtySlot("ARTILLERY_BROADSIDE_PIERCE", 2)
		elseif Hyperspace.playerVariables.aea_broadside_slot3 == 2 then
			setArtySlot("ARTILLERY_BROADSIDE_FOCUS", 2)
		elseif Hyperspace.playerVariables.aea_broadside_slot3 == 3 then
			setArtySlot("ARTILLERY_BROADSIDE_MISSILE", 2)
		elseif Hyperspace.playerVariables.aea_broadside_slot3 == 4 then
			setArtySlot("ARTILLERY_BROADSIDE_MINE", 2)
		end
	elseif Hyperspace.ships.player and needSetArty and shipManager:HasAugmentation("SHIP_AEA_BROADSIDE2") > 0 and Hyperspace.playerVariables.aea_broadside_slot1 > 0 then
		--print("SET slot1:"..Hyperspace.playerVariables.aea_broadside_slot1.. " slot2:"..Hyperspace.playerVariables.aea_broadside_slot2.." slot3:"..Hyperspace.playerVariables.aea_broadside_slot3)
		needSetArty = flase
		if Hyperspace.playerVariables.aea_broadside_slot1 == 1 then
			setArtySlot("ARTILLERY_BROADSIDE2_LASER", 0)
		elseif Hyperspace.playerVariables.aea_broadside_slot1 == 2 then
			setArtySlot("ARTILLERY_BROADSIDE2_BEAM", 0)
		elseif Hyperspace.playerVariables.aea_broadside_slot1 == 3 then
			setArtySlot("ARTILLERY_BROADSIDE2_MISSILE", 0)
		elseif Hyperspace.playerVariables.aea_broadside_slot1 == 4 then
			setArtySlot("ARTILLERY_BROADSIDE2_ION", 0)
		end
		if Hyperspace.playerVariables.aea_broadside_slot2 == 1 then
			setArtySlot("ARTILLERY_BROADSIDE2_LASER", 1)
		elseif Hyperspace.playerVariables.aea_broadside_slot2 == 2 then
			setArtySlot("ARTILLERY_BROADSIDE2_BEAM", 1)
		elseif Hyperspace.playerVariables.aea_broadside_slot2 == 3 then
			setArtySlot("ARTILLERY_BROADSIDE2_MISSILE", 1)
		elseif Hyperspace.playerVariables.aea_broadside_slot2 == 4 then
			setArtySlot("ARTILLERY_BROADSIDE2_ION", 1)
		end
		if Hyperspace.playerVariables.aea_broadside_slot3 == 1 then
			setArtySlot("ARTILLERY_BROADSIDE2_LASER", 2)
		elseif Hyperspace.playerVariables.aea_broadside_slot3 == 2 then
			setArtySlot("ARTILLERY_BROADSIDE2_BEAM", 2)
		elseif Hyperspace.playerVariables.aea_broadside_slot3 == 3 then
			setArtySlot("ARTILLERY_BROADSIDE2_MISSILE", 2)
		elseif Hyperspace.playerVariables.aea_broadside_slot3 == 4 then
			setArtySlot("ARTILLERY_BROADSIDE2_ION", 2)
		end
	elseif Hyperspace.ships.player and needSetArty and shipManager.iShipId == 0 and Hyperspace.playerVariables.aea_broadside_slot1 > 0 then
		--print("FAIL")
		needSetArty = false
	end
end)

local missileToggle = false
local broadSideFocusBlueprint = Hyperspace.Blueprints:GetWeaponBlueprint("AEA_BROADSIDE_FOCUS_BEAM")
script.on_internal_event(Defines.InternalEvents.PROJECTILE_FIRE, function(projectile, weapon)
	if projectile.extend.name == "ARTILLERY_BROADSIDE_PIERCE" then
		projectile.heading = -90
		local spaceManager = Hyperspace.App.world.space
		local laser = spaceManager:CreateLaserBlast(
			weapon.blueprint,
			Hyperspace.Pointf(projectile.position.x + 7, projectile.position.y),
			projectile.currentSpace,
			projectile.ownerId,
			Hyperspace.Pointf(projectile.target.x + 7, projectile.target.y),
			projectile.destinationSpace,
			projectile.heading)
		laser.entryAngle = projectile.entryAngle

		projectile.position = Hyperspace.Pointf(projectile.position.x - 7, projectile.position.y)
		projectile.target = Hyperspace.Pointf(projectile.target.x - 7, projectile.target.y)		
	elseif projectile.extend.name == "ARTILLERY_BROADSIDE_MISSILE" then
		projectile.heading = -90
		if missileToggle then
			projectile.position = Hyperspace.Pointf(projectile.position.x - 7 - 16, projectile.position.y)
		else
			projectile.position = Hyperspace.Pointf(projectile.position.x + 7 - 17, projectile.position.y)
		end
		missileToggle = not missileToggle
	elseif projectile.extend.name == "ARTILLERY_BROADSIDE_MINE" then
		projectile.heading = -90
	elseif projectile.extend.name == "ARTILLERY_BROADSIDE_FOCUS" then
		local spaceManager = Hyperspace.App.world.space
		local beam1 = spaceManager:CreateBeam(
			broadSideFocusBlueprint, 
			projectile.position, 
			projectile.currentSpace, 
			projectile.ownerId, 
			projectile.target, 
			Hyperspace.Pointf(projectile.target.x, projectile.target.y + 1), 
			projectile.destinationSpace, 
			1, 
			-0.1)
		beam1.sub_end = Hyperspace.Pointf(projectile.position.x, projectile.position.y - 300)
		projectile:Kill()
	elseif projectile.extend.name == "ARTILLERY_BROADSIDE_PIERCE_ENEMY" or projectile.extend.name == "ARTILLERY_BROADSIDE_PIERCE_ENEMY_OFFSET" then
		projectile.heading = -180
		local spaceManager = Hyperspace.App.world.space
		local laser = spaceManager:CreateLaserBlast(
			weapon.blueprint,
			Hyperspace.Pointf(projectile.position.x, projectile.position.y + 7),
			projectile.currentSpace,
			projectile.ownerId,
			Hyperspace.Pointf(projectile.target.x, projectile.target.y + 7),
			projectile.destinationSpace,
			projectile.heading)
		laser.entryAngle = projectile.entryAngle

		projectile.position = Hyperspace.Pointf(projectile.position.x, projectile.position.y - 7)
		projectile.target = Hyperspace.Pointf(projectile.target.x, projectile.target.y - 7)	
	elseif projectile.extend.name == "ARTILLERY_BROADSIDE2_LASER" or projectile.extend.name == "ARTILLERY_BROADSIDE2_ION" then
		projectile.heading = -90
	elseif projectile.extend.name == "ARTILLERY_BROADSIDE2_MISSILE" then
		projectile.heading = -90
		projectile.position = Hyperspace.Pointf(projectile.position.x - 8, projectile.position.y)
	elseif projectile.extend.name == "ARTILLERY_BROADSIDE2_BEAM" then
		projectile.sub_end = Hyperspace.Pointf(projectile.position.x, projectile.position.y - 300)
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