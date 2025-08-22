-- this lua was done by Arc!! thank you Arc!!
-- some of it was tweaked by Silly as well!! thank you Silly!!

local function get_room_at_location(shipManager, location, includeWalls)
	return Hyperspace.ShipGraph.GetShipInfo(shipManager.iShipId):GetSelectedRoom(location.x, location.y, includeWalls)
end

local function vter(cvec)
	local i = -1
	local n = cvec:size()
	return function()
		i = i + 1
		if i < n then return cvec[i] end
	end
end

-- Get a table for a userdata value by name
local function userdata_table(userdata, tableName)
	if not userdata.table[tableName] then userdata.table[tableName] = {} end
	return userdata.table[tableName]
end

local systemIdName = "aea_freeze"
local freeze_durations = {5, 7, 9, 11}
freeze_durations[0] = 0

local function petrify_crew(crewmem, time, jumps)
	local crewTable = userdata_table(crewmem, "mods.aea.freeze")
	crewTable.petrified = {time = time, jumps = jumps}
	Hyperspace.playerVariables["aea_crew_petrified_"..tostring(crewmem.extend.selfId).."_time"] = crewTable.petrified.time * 1000
	Hyperspace.playerVariables["aea_crew_petrified_"..tostring(crewmem.extend.selfId).."_jumps"] = crewTable.petrified.jumps
end

local setCrew = false
script.on_init(function()
	setCrew = true
end)
script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
	if setCrew and Hyperspace.playerVariables.aea_test_variable == 1 then
		setCrew = false
		for crewmem in vter(Hyperspace.ships.player.vCrewList) do
			if Hyperspace.playerVariables["aea_crew_petrified_"..tostring(crewmem.extend.selfId).."_time"] > 0 then
				userdata_table(crewmem, "mods.aea.freeze").petrified = {time = Hyperspace.playerVariables["aea_crew_petrified_"..tostring(crewmem.extend.selfId).."_time"], jumps = Hyperspace.playerVariables["aea_crew_petrified_"..tostring(crewmem.extend.selfId).."_jumps"]}
			end
		end
		if Hyperspace.ships.enemy then
			for crewmem in vter(Hyperspace.ships.enemy.vCrewList) do
				if Hyperspace.playerVariables["aea_crew_petrified_"..tostring(crewmem.extend.selfId).."_time"] > 0 then
					userdata_table(crewmem, "mods.aea.freeze").petrified = {time = Hyperspace.playerVariables["aea_crew_petrified_"..tostring(crewmem.extend.selfId).."_time"], jumps = Hyperspace.playerVariables["aea_crew_petrified_"..tostring(crewmem.extend.selfId).."_jumps"]}
				end
			end
		end
	end
end)

local petrifyStats = {}
petrifyStats[Hyperspace.CrewStat.ALL_DAMAGE_TAKEN_MULTIPLIER] = {amount = 0}
petrifyStats[Hyperspace.CrewStat.CAN_FIGHT] = {value = false}
petrifyStats[Hyperspace.CrewStat.CAN_REPAIR] = {value = false}
petrifyStats[Hyperspace.CrewStat.CAN_SABOTAGE] = {value = false}
petrifyStats[Hyperspace.CrewStat.CAN_MAN] = {value = false}
petrifyStats[Hyperspace.CrewStat.CAN_TELEPORT] = {value = false}
petrifyStats[Hyperspace.CrewStat.CAN_SUFFOCATE] = {value = false}
petrifyStats[Hyperspace.CrewStat.CONTROLLABLE] = {value = false}
petrifyStats[Hyperspace.CrewStat.CAN_BURN] = {value = false}
petrifyStats[Hyperspace.CrewStat.CAN_MOVE] = {value = false}
petrifyStats[Hyperspace.CrewStat.VALID_TARGET] = {value = false}
petrifyStats[Hyperspace.CrewStat.SILENCED] = {value = true}

script.on_internal_event(Defines.InternalEvents.CALCULATE_STAT_POST, function(crewmem, stat, def, amount, value)
	local crewTable = userdata_table(crewmem, "mods.aea.freeze")
	if crewTable.petrified and petrifyStats[stat] then
		--print("SET STAT:"..tostring(stat).." crew"..crewmem.type)
		if petrifyStats[stat].amount then
			amount = petrifyStats[stat].amount
		elseif petrifyStats[stat].value == true or petrifyStats[stat].value == false then
			value = petrifyStats[stat].value
		end
	end
	if stat == Hyperspace.CrewStat.ACTIVE_HEAL_AMOUNT and Hyperspace.ships(crewmem.iShipId) and Hyperspace.ships(crewmem.iShipId):HasAugmentation("UPG_AEA_FREEZE_CREW") > 0 and not crewTable.petrified then
		for shipCrew in vter(Hyperspace.ships(crewmem.currentShipId).vCrewList) do
			if userdata_table(shipCrew, "mods.aea.freeze").petrified then
				amount = amount + 5
			end
		end
	end
	return Defines.Chain.CONTINUE, amount, value
end)

script.on_internal_event(Defines.InternalEvents.CREW_LOOP, function(crewmem)
	local crewTable = userdata_table(crewmem, "mods.aea.freeze")
	if crewTable.petrified then
		if crewTable.petrified.time and crewTable.petrified.time >= 0 then
			crewTable.petrified.time = crewTable.petrified.time - Hyperspace.FPS.SpeedFactor/16
			if crewTable.petrified.time <= 0 then
				crewTable.petrified = nil
				Hyperspace.playerVariables["aea_crew_petrified_"..tostring(crewmem.extend.selfId).."_time"] = 0
			else
				Hyperspace.playerVariables["aea_crew_petrified_"..tostring(crewmem.extend.selfId).."_time"] = crewTable.petrified.time * 1000
			end
		end
	end
end)

script.on_internal_event(Defines.InternalEvents.JUMP_LEAVE, function(shipManager)
	if shipManager.iShipId == 0 then
		for crewmem in vter(shipManager.vCrewList) do
			local crewTable = userdata_table(crewmem, "mods.aea.freeze")
			if crewTable.petrified then
				if crewTable.petrified.jumps and crewTable.petrified.jumps > 0 then
					crewTable.petrified.jumps = crewTable.petrified.jumps - 1
					if crewTable.petrified.jumps <= 0 then
						crewTable.petrified = nil
						Hyperspace.playerVariables["aea_crew_petrified_"..tostring(crewmem.extend.selfId).."_jumps"] = 0
					else
						Hyperspace.playerVariables["aea_crew_petrified_"..tostring(crewmem.extend.selfId).."_jumps"] = crewTable.petrified.jumps
					end
				end
			end
		end
	end
end)

petrifiedCrewIcon = Hyperspace.Resources:CreateImagePrimitiveString( "effects/aea_petrified_crew.png" , -17, -17, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
script.on_render_event(Defines.RenderEvents.CREW_MEMBER_HEALTH, function(crewmem)
	local crewTable = userdata_table(crewmem, "mods.aea.freeze")
	if crewTable.petrified then
		local position = crewmem:GetPosition()
		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(position.x, position.y, 0)
		Graphics.CSurface.GL_RenderPrimitive(petrifiedCrewIcon)
		Graphics.CSurface.GL_PopMatrix()
	end
end, function() end)

local roomIconImageString = "effects/aea_marble_ico"
local tileImageString = "effects/aea_marble_back"
local wallImageString = "effects/aea_marble_edge"
roomIconImage =  Hyperspace.Resources:CreateImagePrimitiveString( (roomIconImageString..".png") , 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
tileImage =  Hyperspace.Resources:CreateImagePrimitiveString( (tileImageString..".png") , 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
wallImage =  {
	up = Hyperspace.Resources:CreateImagePrimitiveString( (wallImageString.."_up.png") , 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	right = Hyperspace.Resources:CreateImagePrimitiveString( (wallImageString.."_right.png") , 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	down = Hyperspace.Resources:CreateImagePrimitiveString( (wallImageString.."_down.png") , 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	left = Hyperspace.Resources:CreateImagePrimitiveString( (wallImageString.."_left.png") , 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
}

--Handles tooltips and mousever descriptions per level
local function get_level_description_freeze(systemId, level, tooltip)
	if systemId == Hyperspace.ShipSystem.NameToSystemId(systemIdName) then
		return string.format("Freeze: %is enemy, %is self", freeze_durations[level], freeze_durations[level]-2)
	end
end

script.on_internal_event(Defines.InternalEvents.GET_LEVEL_DESCRIPTION, get_level_description_freeze)

--Utility function to check if the SystemBox instance is for our customs system
local function is_freeze(systemBox)
	local systemName = Hyperspace.ShipSystem.SystemIdToName(systemBox.pSystem.iSystemType)
	return systemName == systemIdName and systemBox.bPlayerUI
end

--Utility function to check if the SystemBox instance is for our customs system
local function is_freeze_enemy(systemBox)
	local systemName = Hyperspace.ShipSystem.SystemIdToName(systemBox.pSystem.iSystemType)
	return systemName == systemIdName and not systemBox.bPlayerUI
end
 
--Offsets of the button
local freezeButtonOffset_x = 37
local freezeButtonOffset_y = -50

--Handles initialization of custom system box
local function freeze_construct_system_box(systemBox)
	if is_freeze(systemBox) then
		systemBox.extend.xOffset = 54

		local activateButton1 = Hyperspace.Button()
		activateButton1:OnInit("systemUI/button_"..systemIdName.."1", Hyperspace.Point(freezeButtonOffset_x, freezeButtonOffset_y))
		activateButton1.hitbox.x = 10
		activateButton1.hitbox.y = 47
		activateButton1.hitbox.w = 20
		activateButton1.hitbox.h = 19
		systemBox.table.activateButton1 = activateButton1

		local activateButton2 = Hyperspace.Button()
		activateButton2:OnInit("systemUI/button_"..systemIdName.."2", Hyperspace.Point(freezeButtonOffset_x, freezeButtonOffset_y))
		activateButton2.hitbox.x = 10
		activateButton2.hitbox.y = 35
		activateButton2.hitbox.w = 20
		activateButton2.hitbox.h = 31
		systemBox.table.activateButton2 = activateButton2

		local activateButton3 = Hyperspace.Button()
		activateButton3:OnInit("systemUI/button_"..systemIdName.."3", Hyperspace.Point(freezeButtonOffset_x, freezeButtonOffset_y))
		activateButton3.hitbox.x = 10
		activateButton3.hitbox.y = 23
		activateButton3.hitbox.w = 20
		activateButton3.hitbox.h = 43
		systemBox.table.activateButton3 = activateButton3

		local activateButton4 = Hyperspace.Button()
		activateButton4:OnInit("systemUI/button_"..systemIdName.."4", Hyperspace.Point(freezeButtonOffset_x, freezeButtonOffset_y))
		activateButton4.hitbox.x = 10
		activateButton4.hitbox.y = 11
		activateButton4.hitbox.w = 20
		activateButton4.hitbox.h = 55
		systemBox.table.activateButton4 = activateButton4

		systemBox.pSystem.bBoostable = false -- make the system unmannable
	elseif is_freeze_enemy(systemBox) then
		systemBox.pSystem.bBoostable = false
	end
end

script.on_internal_event(Defines.InternalEvents.CONSTRUCT_SYSTEM_BOX, freeze_construct_system_box)

--Handles mouse movement
local function freeze_mouse_move(systemBox, x, y)
	if is_freeze(systemBox) then
		local activateButton1 = systemBox.table.activateButton1
		local activateButton2 = systemBox.table.activateButton2
		local activateButton3 = systemBox.table.activateButton3
		local activateButton4 = systemBox.table.activateButton4
		activateButton1:MouseMove(x - freezeButtonOffset_x, y - freezeButtonOffset_y, false)
		activateButton2:MouseMove(x - freezeButtonOffset_x, y - freezeButtonOffset_y, false)
		activateButton3:MouseMove(x - freezeButtonOffset_x, y - freezeButtonOffset_y, false)
		activateButton4:MouseMove(x - freezeButtonOffset_x, y - freezeButtonOffset_y, false)
	end
	return Defines.Chain.CONTINUE
end
script.on_internal_event(Defines.InternalEvents.SYSTEM_BOX_MOUSE_MOVE, freeze_mouse_move)

--Hyperspace.playerVariables.freeze_targetRoom
local freeze_targetting = false
local freeze_targetRoom = nil
local freeze_targetShip = nil
local need_set_freeze = false
script.on_init(function(newgame)
	if newgame then
		Hyperspace.playerVariables.freeze_targetRoom = -1
		Hyperspace.playerVariables.freeze_targetShip = -1
		Hyperspace.playerVariables.freeze_targetRoomEnemy = -1
	else
		need_set_freeze = true
	end
	freeze_targetting = false
	freeze_targetRoom = nil
	freeze_targetShip = nil
end)

local freezeDuration = 0
local freeze_targetRoomTemp = nil
local freeze_targetShipTemp = nil

local freezeTable = {}
freezeTable[0] = {systemResist = 0, hullResist = 0}
freezeTable[1] = {systemResist = 0, hullResist = 0}

local systemIds = {
	shields = 0,
	engines = 1,
	oxygen = 2,
	weapons = 3,
	drones = 4,
	medbay = 5,
	pilot = 6,
	sensors = 7,
	doors = 8,
	teleporter = 9,
	cloaking = 10,
	artillery = 11,
	battery = 12,
	clonebay = 13,
	mind = 14,
	hacking = 15,
	temporal = 20,
	aea_super_shields = Hyperspace.ShipSystem.NameToSystemId("aea_super_shields"),
	aea_freeze = Hyperspace.ShipSystem.NameToSystemId("aea_freeze")
}
mods.aea.systemFunctions = {}
local systemFunctions = mods.aea.systemFunctions
systemFunctions["shields"] = {
	start = function(system)
		local shipManager = Hyperspace.ships(system._shipObj.iShipId)
		userdata_table(system, "mods.aea.freeze").charger = shipManager.shieldSystem.shields.charger
	end,
	loop = function(system)
		local shipManager = Hyperspace.ships(system._shipObj.iShipId)
		shipManager.shieldSystem.shields.charger = userdata_table(system, "mods.aea.freeze").charger
	end,
	finish = function(system)
		local shipManager = Hyperspace.ships(system._shipObj.iShipId)
		userdata_table(system, "mods.aea.freeze").charger = nil
	end
}
systemFunctions["engines"] = {
	start = function(system)
		--local shipManager = Hyperspace.ships(system._shipObj.iShipId)
		--userdata_table(system, "mods.aea.freeze").jump_timer = shipManager.jump_timer.first
	end,
	loop = function(system)
		--local shipManager = Hyperspace.ships(system._shipObj.iShipId)
		--shipManager.jump_timer.first = userdata_table(system, "mods.aea.freeze").jump_timer
	end,
	finish = function(system)
		--userdata_table(system, "mods.aea.freeze").jump_timer = nil
	end
}
systemFunctions["oxygen"] = {
	start = function(system)
	end,
	loop = function(system)
		local shipManager = Hyperspace.ships(system._shipObj.iShipId)
		local refillSpeed = shipManager.oxygenSystem:GetRefillSpeed()
		for room in vter(shipManager.vRoomList) do
			shipManager.oxygenSystem:ModifyRoomOxygen(room.iRoomId, -1 * refillSpeed)
		end
	end,
	finish = function(system)
	end
}
systemFunctions["weapons"] = {
	start = function(system)
		local shipManager = Hyperspace.ships(system._shipObj.iShipId)
		for weapon in vter(shipManager.weaponSystem.weapons) do
			userdata_table(weapon, "mods.aea.freeze").cooldown = weapon.cooldown.first
		end
	end,
	loop = function(system)
		local shipManager = Hyperspace.ships(system._shipObj.iShipId)
		for weapon in vter(shipManager.weaponSystem.weapons) do
			weapon.cooldown.first = userdata_table(weapon, "mods.aea.freeze").cooldown
		end
	end,
	finish = function(system)
		local shipManager = Hyperspace.ships(system._shipObj.iShipId)
		for weapon in vter(shipManager.weaponSystem.weapons) do
			userdata_table(weapon, "mods.aea.freeze").cooldown = nil
		end
	end
}
systemFunctions["drones"] = {
	start = function(system)
		userdata_table(system, "mods.aea.freeze").dronesPowered = {}
		local shipManager = Hyperspace.ships(system._shipObj.iShipId)
		for drone in vter(shipManager.droneSystem.drones) do
			if drone.powered then
				userdata_table(system, "mods.aea.freeze").dronesPowered[drone.selfId] = true
				drone.powered = false
			end
		end
	end,
	loop = function(system)
	end,
	finish = function(system)
		local shipManager = Hyperspace.ships(system._shipObj.iShipId)
		for drone in vter(shipManager.droneSystem.drones) do
			if userdata_table(system, "mods.aea.freeze").dronesPowered[drone.selfId] then
				userdata_table(system, "mods.aea.freeze").dronesPowered[drone.selfId] = nil
				drone.powered = true
			end
		end
		userdata_table(system, "mods.aea.freeze").dronesPowered = nil
	end
}
systemFunctions["medbay"] = {
	start = function(system)
		userdata_table(system, "mods.aea.freeze").power = system:GetEffectivePower()
		system:SetPowerCap(0)
	end,
	loop = function(system)
	end,
	finish = function(system)
		system:SetPowerCap(100)
		system:IncreasePower(userdata_table(system, "mods.aea.freeze").power, false)
		userdata_table(system, "mods.aea.freeze").power = nil
	end
}
systemFunctions["pilot"] = {
	start = function(system)
		--local shipManager = Hyperspace.ships(system._shipObj.iShipId)
		--userdata_table(system, "mods.aea.freeze").jump_timer = shipManager.jump_timer
	end,
	loop = function(system)
		--local shipManager = Hyperspace.ships(system._shipObj.iShipId)
		--shipManager.jump_timer = userdata_table(system, "mods.aea.freeze").jump_timer
	end,
	finish = function(system)
		--userdata_table(system, "mods.aea.freeze").jump_timer = nil
	end
}
systemFunctions["sensors"] = {
	start = function(system)
	end,
	loop = function(system)
	end,
	finish = function(system)
	end
}
systemFunctions["doors"] = {
	start = function(system)
		local shipManager = Hyperspace.ships(system._shipObj.iShipId)
		userdata_table(system, "mods.aea.freeze").doors = {}
		for door in vter(shipManager.ship.vDoorList) do
			userdata_table(system, "mods.aea.freeze").doors[door.iRoom1.."_"..door.iRoom2] = door.bOpen
		end
	end,
	loop = function(system)
		local shipManager = Hyperspace.ships(system._shipObj.iShipId)
		for door in vter(shipManager.ship.vDoorList) do
			door.bOpen = userdata_table(system, "mods.aea.freeze").doors[door.iRoom1.."_"..door.iRoom2]
		end
	end,
	finish = function(system)
		userdata_table(system, "mods.aea.freeze").doors = nil
	end
}
systemFunctions["teleporter"] = {
	start = function(system)
	end,
	loop = function(system)
	end,
	finish = function(system)
	end
}
systemFunctions["cloaking"] = {
	start = function(system)
		local shipManager = Hyperspace.ships(system._shipObj.iShipId)
		userdata_table(system, "mods.aea.freeze").cloakTimer = shipManager.cloakSystem.timer.currTime
	end,
	loop = function(system)
		local shipManager = Hyperspace.ships(system._shipObj.iShipId)
		shipManager.cloakSystem.timer.currTime = userdata_table(system, "mods.aea.freeze").cloakTimer
	end,
	finish = function(system)
		userdata_table(system, "mods.aea.freeze").cloakTimer = nil
	end
}
systemFunctions["artillery"] = {
	start = function(system)
		local shipManager = Hyperspace.ships(system._shipObj.iShipId)
		for artillery in vter(shipManager.artillerySystems) do
			if artillery.iRoomId == system.iRoomId then
				local weapon = artillery.projectileFactory
				userdata_table(weapon, "mods.aea.freeze").cooldown = weapon.cooldown.first
			end
		end
	end,
	loop = function(system)
		local shipManager = Hyperspace.ships(system._shipObj.iShipId)
		for artillery in vter(shipManager.artillerySystems) do
			if artillery.iRoomId == system.iRoomId then
				local weapon = artillery.projectileFactory
				weapon.cooldown.first = userdata_table(weapon, "mods.aea.freeze").cooldown
			end
		end
	end,
	finish = function(system)
		local shipManager = Hyperspace.ships(system._shipObj.iShipId)
		for artillery in vter(shipManager.artillerySystems) do
			if artillery.iRoomId == system.iRoomId then
				local weapon = artillery.projectileFactory
				userdata_table(weapon, "mods.aea.freeze").cooldown = nil
			end
		end
	end
}
systemFunctions["battery"] = {
	start = function(system)
		local shipManager = Hyperspace.ships(system._shipObj.iShipId)
		userdata_table(system, "mods.aea.freeze").batteryTimer = shipManager.batterySystem.timer.currTime
	end,
	loop = function(system)
		local shipManager = Hyperspace.ships(system._shipObj.iShipId)
		shipManager.batterySystem.timer.currTime = userdata_table(system, "mods.aea.freeze").batteryTimer
	end,
	finish = function(system)
		local shipManager = Hyperspace.ships(system._shipObj.iShipId)
		userdata_table(system, "mods.aea.freeze").batteryTimer = nil
	end
}
systemFunctions["clonebay"] = {
	start = function(system)
		local shipManager = Hyperspace.ships(system._shipObj.iShipId)
		userdata_table(system, "mods.aea.freeze").cloneTimer = shipManager.cloneSystem.fTimeToClone
	end,
	loop = function(system)
		local shipManager = Hyperspace.ships(system._shipObj.iShipId)
		shipManager.cloneSystem.fTimeToClone = userdata_table(system, "mods.aea.freeze").cloneTimer
	end,
	finish = function(system)
		local shipManager = Hyperspace.ships(system._shipObj.iShipId)
		userdata_table(system, "mods.aea.freeze").cloneTimer = nil
	end
}
systemFunctions["mind"] = {
	start = function(system)
		local shipManager = Hyperspace.ships(system._shipObj.iShipId)
		userdata_table(system, "mods.aea.freeze").mindTimer = shipManager.mindSystem.controlTimer.first
	end,
	loop = function(system)
		local shipManager = Hyperspace.ships(system._shipObj.iShipId)
		shipManager.mindSystem.controlTimer.first = userdata_table(system, "mods.aea.freeze").mindTimer
	end,
	finish = function(system)
		local shipManager = Hyperspace.ships(system._shipObj.iShipId)
		userdata_table(system, "mods.aea.freeze").mindTimer = nil
	end
}
systemFunctions["hacking"] = {
	start = function(system)
		local shipManager = Hyperspace.ships(system._shipObj.iShipId)
		userdata_table(system, "mods.aea.freeze").hackTimer = shipManager.hackingSystem.effectTimer.first
	end,
	loop = function(system)
		local shipManager = Hyperspace.ships(system._shipObj.iShipId)
		shipManager.hackingSystem.effectTimer.first = userdata_table(system, "mods.aea.freeze").hackTimer
	end,
	finish = function(system)
		local shipManager = Hyperspace.ships(system._shipObj.iShipId)
		userdata_table(system, "mods.aea.freeze").hackTimer = nil
	end
}
systemFunctions["temporal"] = {
	start = function(system)
	end,
	loop = function(system)
	end,
	finish = function(system)
	end
}
systemFunctions["aea_super_shields"] = {
	start = function(system)
	end,
	loop = function(system)
	end,
	finish = function(system)
	end
}
systemFunctions["aea_clone_crime"] = {
	start = function(system)
	end,
	loop = function(system)
	end,
	finish = function(system)
	end
}
systemFunctions["aea_freeze"] = {
	start = function(system)
	end,
	loop = function(system)
	end,
	finish = function(system)
	end
}

local function freeze_apply(freezeSystem, roomId, shipId, duration)
	local originShip = Hyperspace.ships(freezeSystem._shipObj.iShipId)
	local targetShip = Hyperspace.ships(shipId)
	local targetRoom = nil
	for roomLoop in vter(targetShip.ship.vRoomList) do
		if roomLoop.iRoomId == roomId then
			targetRoom = roomLoop
		end
	end
	if targetRoom then
		freezeTable[targetShip.iShipId].hullResist = targetRoom.extend.hullDamageResistChance or 0
		freezeTable[targetShip.iShipId].systemResist = targetRoom.extend.sysDamageResistChance or 0

		targetRoom.extend.hullDamageResistChance = 100
		targetRoom.extend.sysDamageResistChance = 100
	else
		error("no room found")
	end
	for crewmem in vter(targetShip.vCrewList) do
		if crewmem.iRoomId == roomId and originShip:HasAugmentation("UPG_AEA_FREEZE_CREW") > 0 then
			petrify_crew(crewmem, 2*duration, 1)
		elseif crewmem.iRoomId == roomId then
			petrify_crew(crewmem, duration, 1)
		end
	end
	local targetSystem = targetShip:GetSystemInRoom(roomId)
	if targetSystem then
		userdata_table(targetSystem, "mods.aea.freeze").locked = targetSystem.iLockCount
		targetSystem:LockSystem(-1)
		if systemFunctions[Hyperspace.ShipSystem.SystemIdToName(targetSystem.iSystemType)] then
			systemFunctions[Hyperspace.ShipSystem.SystemIdToName(targetSystem.iSystemType)].start(targetSystem)
		end
	end
end
local function freeze_loop(freezeSystem, roomId, shipId)
	--log("freeze_loop start")
	local originShip = Hyperspace.ships(freezeSystem._shipObj.iShipId)
	local targetShip = Hyperspace.ships(shipId)
	
	local targetSystem = targetShip:GetSystemInRoom(roomId)
	if targetSystem and systemFunctions[Hyperspace.ShipSystem.SystemIdToName(targetSystem.iSystemType)] then
		if targetSystem.iLockCount >= 0 then
			--log("refresh lock")
			userdata_table(targetSystem, "mods.aea.freeze").locked = userdata_table(targetSystem, "mods.aea.freeze").locked + targetSystem.iLockCount
			targetSystem:LockSystem(-1)
		end
		--log("run loop func")
		systemFunctions[Hyperspace.ShipSystem.SystemIdToName(targetSystem.iSystemType)].loop(targetSystem)
	end
	--log("freeze_loop end")
end
local function freeze_end(freezeSystem, roomId, shipId)
	--log("freeze_end start")
	local originShip = Hyperspace.ships(freezeSystem._shipObj.iShipId)
	local targetShip = Hyperspace.ships(shipId)
	local targetRoom = nil
	for roomLoop in vter(targetShip.ship.vRoomList) do
		if roomLoop.iRoomId == roomId then
			targetRoom = roomLoop
			--log("found room")
		end
	end
	if targetRoom then
		--log("restore room values")
		targetRoom.extend.hullDamageResistChance = freezeTable[targetShip.iShipId].hullResist or 0
		targetRoom.extend.sysDamageResistChance = freezeTable[targetShip.iShipId].systemResist or 0
	else
		error("no room found")
	end

	local targetSystem = targetShip:GetSystemInRoom(roomId)
	if targetSystem then
		if userdata_table(targetSystem, "mods.aea.freeze").locked then
			--print("unlock")
			targetSystem:LockSystem(userdata_table(targetSystem, "mods.aea.freeze").locked)
		else
			error("failed")
		end
		if systemFunctions[Hyperspace.ShipSystem.SystemIdToName(targetSystem.iSystemType)] then
			--log("run finish func")
			systemFunctions[Hyperspace.ShipSystem.SystemIdToName(targetSystem.iSystemType)].finish(targetSystem)
		end
	end
	--log("freeze_end end")
end

---@param shipManager Hyperspace.ShipManager The ship to check for super shield.
---@return boolean hasSuperShield If the ship has any super shield layers up.
local function has_super_shield(shipManager)
   return shipManager.shieldSystem ~= nil and shipManager.shieldSystem.shields.power.super.first > 0
end

local cursorValid = Hyperspace.Resources:GetImageId("mouse/mouse_aea_freeze_valid.png")
local cursorValid2 = Hyperspace.Resources:GetImageId("mouse/mouse_aea_freeze_valid2.png")

local cursorDefault = Hyperspace.Resources:GetImageId("mouse/pointerValid.png")
local cursorDefault2 = Hyperspace.Resources:GetImageId("mouse/pointerInvalid.png")

--Handles click events 
local function freeze_click(systemBox, shift)
	if is_freeze(systemBox) then
		local combatControl = Hyperspace.App.gui.combatControl
		local activateButton1 = systemBox.table.activateButton1
		local activateButton2 = systemBox.table.activateButton2
		local activateButton3 = systemBox.table.activateButton3
		local activateButton4 = systemBox.table.activateButton4

		if (activateButton1.bHover and activateButton1.bActive) or
			(activateButton2.bHover and activateButton2.bActive) or
			(activateButton3.bHover and activateButton3.bActive) or
			(activateButton4.bHover and activateButton4.bActive) then
			freeze_targetting = true --Indicate that we are now targetting the system
			Hyperspace.Mouse.validPointer = cursorValid
			Hyperspace.Mouse.invalidPointer = cursorValid2
		elseif Hyperspace.Global.GetInstance():GetCApp().world.bStartedGame and freeze_targetting == true then 
			freeze_targetting = false 
			Hyperspace.Mouse.validPointer = cursorDefault
			Hyperspace.Mouse.invalidPointer = cursorDefault2
			if combatControl.selectedSelfRoom < 0 and combatControl.selectedRoom < 0 then return Defines.Chain.CONTINUE end
			if combatControl.selectedSelfRoom >= 0 then
				freeze_targetRoomTemp = combatControl.selectedSelfRoom
				freeze_targetShipTemp = 0
			elseif combatControl.selectedRoom >= 0 then
				if has_super_shield(Hyperspace.ships.enemy) then
					Hyperspace.Sounds:PlaySoundMix("powerUpFail", -1, false)
					return Defines.Chain.CONTINUE
				end
				freeze_targetRoomTemp = combatControl.selectedRoom
				freeze_targetShipTemp = 1
			end
		end
	end
	return Defines.Chain.CONTINUE
end
script.on_internal_event(Defines.InternalEvents.SYSTEM_BOX_MOUSE_CLICK, freeze_click)

local placedImage = Hyperspace.Resources:CreateImagePrimitiveString("icons/"..systemIdName.."_placed.png", -20, -20, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)

script.on_render_event(Defines.RenderEvents.SHIP_SPARKS, function(ship)
	local combatControl = Hyperspace.App.gui.combatControl
	if ship.iShipId == 0 and freeze_targetting then
		for room in vter(ship.vRoomList) do
			if room.iRoomId == combatControl.selectedSelfRoom then
				Graphics.CSurface.GL_RenderPrimitive(room.highlightPrimitive) -- highlight the room
				Graphics.CSurface.GL_RenderPrimitive(room.highlightPrimitive2)
			end
		end
	elseif ship.iShipId == 1 and freeze_targetting then
		for room in vter(ship.vRoomList) do
			if room.iRoomId == combatControl.selectedRoom then
				Graphics.CSurface.GL_RenderPrimitive(room.highlightPrimitive) -- highlight the room
				Graphics.CSurface.GL_RenderPrimitive(room.highlightPrimitive2)
			end
		end
	end
end, function() end)

script.on_render_event(Defines.RenderEvents.SHIP, function() end, function(ship)
	if freeze_targetRoomTemp and ship.iShipId == freeze_targetShipTemp then
		local location = ship:GetRoomCenter(freeze_targetRoomTemp)
		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(location.x, location.y, 0)
		Graphics.CSurface.GL_RenderPrimitive(placedImage)
		Graphics.CSurface.GL_PopMatrix()
	end
end)


--handle cancelling targetting by right clicking
script.on_internal_event(Defines.InternalEvents.ON_MOUSE_R_BUTTON_DOWN, function(x,y) 
	if freeze_targetting == true then
		freeze_targetting = false
		Hyperspace.Mouse.validPointer = cursorDefault
		Hyperspace.Mouse.invalidPointer = cursorDefault2
	end
	return Defines.Chain.CONTINUE
end)

--Utility function to see if the system is ready for use
local function freeze_ready(shipSystem)
   return not (shipSystem:GetLocked() and shipSystem.iLockCount ~= -1) and shipSystem:Functioning() and shipSystem.iHackEffect <= 1
end
--Utility function to see if the system is ready for use
local function freeze_ready_enemy(shipSystem)
   local shield_blocking = has_super_shield(Hyperspace.ships.player) and shipSystem._shipObj:HasAugmentation("ZOLTAN_BYPASS") <= 0
   return not (shipSystem:GetLocked() and shipSystem.iLockCount ~= -1) and shipSystem:Functioning() and shipSystem.iHackEffect <= 1 and Hyperspace.ships.enemy and Hyperspace.ships.enemy._targetable.hostile and not shield_blocking
end
--Initializes primitive for UI GetAllSegments()
local buttonBase = {}
local buttonCharging = {}
script.on_init(function()
	buttonBase[1] = Hyperspace.Resources:CreateImagePrimitiveString("systemUI/button_cloaking1_base.png", freezeButtonOffset_x, freezeButtonOffset_y, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false)
	buttonBase[2] = Hyperspace.Resources:CreateImagePrimitiveString("systemUI/button_cloaking2_base.png", freezeButtonOffset_x, freezeButtonOffset_y, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false)
	buttonBase[3] = Hyperspace.Resources:CreateImagePrimitiveString("systemUI/button_cloaking3_base.png", freezeButtonOffset_x, freezeButtonOffset_y, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false)
	buttonBase[4] = Hyperspace.Resources:CreateImagePrimitiveString("systemUI/button_cloaking4_base.png", freezeButtonOffset_x, freezeButtonOffset_y, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false)

	buttonCharging[1] = Hyperspace.Resources:CreateImagePrimitiveString("systemUI/button_cloaking1_charging_on.png", freezeButtonOffset_x, freezeButtonOffset_y, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false)
	buttonCharging[2] = Hyperspace.Resources:CreateImagePrimitiveString("systemUI/button_cloaking2_charging_on.png", freezeButtonOffset_x, freezeButtonOffset_y, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false)
	buttonCharging[3] = Hyperspace.Resources:CreateImagePrimitiveString("systemUI/button_cloaking3_charging_on.png", freezeButtonOffset_x, freezeButtonOffset_y, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false)
	buttonCharging[4] = Hyperspace.Resources:CreateImagePrimitiveString("systemUI/button_cloaking4_charging_on.png", freezeButtonOffset_x, freezeButtonOffset_y, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false)
end)

--Handles custom rendering
local function freeze_render(systemBox, ignoreStatus)
	if is_freeze(systemBox) then
		local activateButtonTable = {}
		activateButtonTable[1] = systemBox.table.activateButton1
		activateButtonTable[2] = systemBox.table.activateButton2
		activateButtonTable[3] = systemBox.table.activateButton3
		activateButtonTable[4] = systemBox.table.activateButton4
		activateButtonTable[1].bActive = false
		activateButtonTable[2].bActive = false
		activateButtonTable[3].bActive = false
		activateButtonTable[4].bActive = false
		local effectivePower = systemBox.pSystem:GetEffectivePower()
		if effectivePower == 0 then effectivePower = 1 end

		local activateButton = activateButtonTable[effectivePower]
		activateButton.bActive = freeze_ready(systemBox.pSystem) and not freeze_targetting and not freeze_targetRoom
		if activateButton.bHover then
			Hyperspace.Mouse.tooltip = "Freezes the target room, preventing it from functioning or taking damage.\nHotkey:N/A"
		end
		Graphics.CSurface.GL_RenderPrimitive(buttonBase[effectivePower])
		if freeze_targetRoom then
			local maxDuration = (freeze_targetShip == 0) and (freeze_durations[effectivePower] - 2) or freeze_durations[effectivePower]
			local height = math.ceil((freezeDuration/maxDuration) * (2 + 3 * effectivePower)) * 4
			Graphics.CSurface.GL_SetStencilMode(1,1,1)
			Graphics.CSurface.GL_DrawRect(freezeButtonOffset_x + 10, 
				freezeButtonOffset_y + (67 - (2 + 3 * effectivePower) * 4) + ((2 + 3 * effectivePower) * 4 - height), 
				20, 
				height, 
				Graphics.GL_Color(1, 1, 1, 1))
			Graphics.CSurface.GL_SetStencilMode(2,1,1)
			Graphics.CSurface.GL_RenderPrimitive(buttonCharging[effectivePower])
			Graphics.CSurface.GL_SetStencilMode(0,1,1)
		else
			activateButton:OnRender()
		end
	end
end
script.on_render_event(Defines.RenderEvents.SYSTEM_BOX, 
function(systemBox, ignoreStatus) 
	return Defines.Chain.CONTINUE
end, freeze_render)

local freeze_targetRoomEnemy = nil
local freezeDurationEnemy = 0

script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
	if freeze_targetRoomEnemy then
		if (not Hyperspace.ships.enemy) or Hyperspace.ships.enemy._targetable.hostile == false then
			print("RESET ENEMY DEAD")
			freeze_targetRoomEnemy = nil
		end
	end
end)
script.on_init(function()
	freeze_targetRoomEnemy = nil
end)

script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
	if Hyperspace.playerVariables.aea_test_variable == 1 and need_set_freeze and Hyperspace.ships.player then
		need_set_freeze = false
		if Hyperspace.playerVariables.freeze_targetRoom >= 0 then
			--print("load")
			freeze_targetRoomTemp = Hyperspace.playerVariables.freeze_targetRoom
			freeze_targetShipTemp = Hyperspace.playerVariables.freeze_targetShip
			local targetShip = Hyperspace.ships(freeze_targetShipTemp)
			local targetSystem = targetShip:GetSystemInRoom(freeze_targetRoomTemp)
			if targetShip.iShipId == 0 then
				targetSystem:LockSystem(4)
			else
				targetSystem:LockSystem(0)
			end
		end

		if Hyperspace.playerVariables.freeze_targetRoomEnemy >= 0 and Hyperspace.ships.enemy then
			--print("load enemy")
			local freezeSystem = nil
			for system in vter(Hyperspace.ships.enemy.vSystemList) do
				local systemName = Hyperspace.ShipSystem.SystemIdToName(system.iSystemType)
				if systemName == systemIdName then
					freezeSystem = system
				end
			end
			if freezeSystem then
				freezeSystem:LockSystem(-1)
				local effectivePower = freezeSystem:GetEffectivePower()
				freeze_targetRoomEnemy = Hyperspace.playerVariables.freeze_targetRoomEnemy
				freezeDurationEnemy = freeze_durations[effectivePower]
				local targetShip = Hyperspace.ships.player
				local targetSystem = targetShip:GetSystemInRoom(freeze_targetRoomEnemy)
				targetSystem:LockSystem(0)
				freeze_apply(freezeSystem, freeze_targetRoomEnemy, 0, freezeDurationEnemy)
			end
		end
	end
end)


---@param room Hyperspace.Room The room to get the time dilation factor for.
---@return number dilation multipier to the rate that time passes within the room.
local function get_time_dilation(room)
	return Hyperspace.TemporalSystemParser.GetDilationStrength(room.extend.timeDilation)
end

-- handle enemies using the system
local sysWeights = {}
sysWeights.weapons = 6
sysWeights.shields = 1
sysWeights.drones = 5
sysWeights.pilot = 3
sysWeights.engines = 3
sysWeights.teleporter = 2
sysWeights.hacking = 2
sysWeights.medbay = 2
sysWeights.clonebay = 2
sysWeights.artillery = 2
local function find_target_system(shipManager)

	local sysTargets = {}
	local weightSum = 0
	
	-- Collect all player systems and their weights
	for system in vter(shipManager.vSystemList) do
		local sysId = system:GetId()
		if shipManager:HasSystem(sysId) then
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
				return shipManager:GetSystemRoom(sysTargets[i].id)
			end
			rnd = rnd - sysTargets[i].weight
		end
		error("Weighted selection error - reached end of options without making a choice!")
	end
end

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	--player use
	if shipManager.iShipId == 0 then
		local freezeSystem = nil
		for system in vter(shipManager.vSystemList) do
			local systemName = Hyperspace.ShipSystem.SystemIdToName(system.iSystemType)
			if systemName == systemIdName then
				freezeSystem = system
			end
		end
		if not freezeSystem then return end

		if freeze_targetRoomTemp and freeze_ready(freezeSystem) then
			freezeSystem:LockSystem(-1)
			local effectivePower = freezeSystem:GetEffectivePower()
			freeze_targetRoom = freeze_targetRoomTemp
			freeze_targetShip = freeze_targetShipTemp
			Hyperspace.playerVariables.freeze_targetRoom = freeze_targetRoom
			Hyperspace.playerVariables.freeze_targetShip = freeze_targetShip
			freezeDuration = freeze_durations[effectivePower]
			if freeze_targetShip == 0 then freezeDuration = freezeDuration - 2 end
			freeze_apply(freezeSystem, freeze_targetRoom, freeze_targetShip, freezeDuration)
			freeze_targetRoomTemp = nil
			freeze_targetShipTemp = nil
		end

		if freeze_targetRoom and freeze_ready(freezeSystem) then
			freeze_loop(freezeSystem, freeze_targetRoom, freeze_targetShip)
			freezeDuration = freezeDuration - Hyperspace.FPS.SpeedFactor/16

			if freezeDuration <= 0 then
				freezeDuration = 0
				freeze_end(freezeSystem, freeze_targetRoom, freeze_targetShip)
				freeze_targetRoom = nil
				freeze_targetShip = nil
				Hyperspace.playerVariables.freeze_targetRoom = -1
				Hyperspace.playerVariables.freeze_targetShip = -1
				if shipManager:HasAugmentation("UPG_AEA_FREEZE_COOLDOWN") > 0 then
					freezeSystem:LockSystem(3)
				else
					freezeSystem:LockSystem(4)
				end
			end
		elseif freeze_targetRoom then 
			freeze_end(freezeSystem, freeze_targetRoom, freeze_targetShip)
			freeze_targetRoom = nil
			freeze_targetShip = nil
			Hyperspace.playerVariables.freeze_targetRoom = -1
			Hyperspace.playerVariables.freeze_targetShip = -1
			if shipManager:HasAugmentation("UPG_AEA_FREEZE_COOLDOWN") > 0 then
				freezeSystem:LockSystem(freezeSystem.iLockCount + 3)
			else
				freezeSystem:LockSystem(freezeSystem.iLockCount + 4)
			end
		end

		if freezeSystem.iLockCount == -1 and freeze_targetShip == 1 and Hyperspace.ships.enemy.bDestroyed then
			freezeDuration = 0
			freeze_end(freezeSystem, freeze_targetRoom, freeze_targetShip)
			freeze_targetRoom = nil
			freeze_targetShip = nil
			Hyperspace.playerVariables.freeze_targetRoom = -1
			Hyperspace.playerVariables.freeze_targetShip = -1
			if shipManager:HasAugmentation("UPG_AEA_FREEZE_COOLDOWN") > 0 then
				freezeSystem:LockSystem(3)
			else
				freezeSystem:LockSystem(4)
			end
		end
	else
		--log("enemy freeze sys")
		local freezeSystem = nil
		for system in vter(shipManager.vSystemList) do
			local systemName = Hyperspace.ShipSystem.SystemIdToName(system.iSystemType)
			if systemName == systemIdName then
				freezeSystem = system
				--log("found enemy freeze sys")
			end
		end
		if freezeSystem then
			if freeze_ready_enemy(freezeSystem) and not freeze_targetRoomEnemy then
				--log("start enemy freeze sys")
				freezeSystem:LockSystem(-1)
				local effectivePower = freezeSystem:GetEffectivePower()
				freeze_targetRoomEnemy = find_target_system(Hyperspace.ships.player)
				Hyperspace.playerVariables.freeze_targetRoomEnemy = freeze_targetRoomEnemy
				freezeDurationEnemy = freeze_durations[effectivePower]
				freeze_apply(freezeSystem, freeze_targetRoomEnemy, 0, freezeDurationEnemy)
			elseif freeze_ready_enemy(freezeSystem) and freeze_targetRoomEnemy then
				--log("loop enemy freeze sys")
				freezeDurationEnemy = freezeDurationEnemy - Hyperspace.FPS.SpeedFactor/16
				freeze_loop(freezeSystem, freeze_targetRoomEnemy, 0)

				if freezeDurationEnemy <= 0 then
					--log("finish enemy freeze sys")
					freezeDurationEnemy = 0
					freeze_end(freezeSystem, freeze_targetRoomEnemy, 0)
					freeze_targetRoomEnemy = nil
					Hyperspace.playerVariables.freeze_targetRoomEnemy = -1
					if shipManager:HasAugmentation("UPG_AEA_FREEZE_COOLDOWN") > 0 then
						freezeSystem:LockSystem(3)
					else
						freezeSystem:LockSystem(4)
					end
				end
			elseif freeze_targetRoomEnemy then
				--log("interrupt enemy freeze sys")
				freeze_end(freezeSystem, freeze_targetRoomEnemy, 0)
				freeze_targetRoomEnemy = nil
				Hyperspace.playerVariables.freeze_targetRoomEnemy = -1
				if shipManager:HasAugmentation("UPG_AEA_FREEZE_COOLDOWN") > 0 then
					freezeSystem:LockSystem(freezeSystem.iLockCount + 3)
				else
					freezeSystem:LockSystem(freezeSystem.iLockCount + 4)
				end
			end
		end
	end
end)

--Render floor
local function render_stone(room)
	local opacity = 0.5
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
		Graphics.CSurface.GL_RenderPrimitiveWithAlpha(tileImage, opacity)
		Graphics.CSurface.GL_PopMatrix()
	end
	opacity = 1
	-- top and bottom edge
	for i = 0, w - 1 do
		local xOff = x + i * 35
		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(xOff, y, 0)
		Graphics.CSurface.GL_RenderPrimitiveWithAlpha(wallImage.up, opacity)
		Graphics.CSurface.GL_PopMatrix()

		local yOff = y + (h-1) * 35
		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(xOff, yOff, 0)
		Graphics.CSurface.GL_RenderPrimitiveWithAlpha(wallImage.down, opacity)
		Graphics.CSurface.GL_PopMatrix()
	end
	-- left and right edge
	for i = 0, h - 1 do
		local yOff = y + i * 35
		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(x, yOff, 0)
		Graphics.CSurface.GL_RenderPrimitiveWithAlpha(wallImage.left, opacity)
		Graphics.CSurface.GL_PopMatrix()

		local xOff = x + (w-1) * 35
		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(xOff, yOff, 0)
		Graphics.CSurface.GL_RenderPrimitiveWithAlpha(wallImage.right, opacity)
		Graphics.CSurface.GL_PopMatrix()
	end
	Graphics.CSurface.GL_PushMatrix()
	Graphics.CSurface.GL_Translate(x, y, 0)
	Graphics.CSurface.GL_RenderPrimitive(roomIconImage)
	Graphics.CSurface.GL_PopMatrix()
end
script.on_render_event(Defines.RenderEvents.SHIP_BREACHES, function() end, function(ship) 
	local shipManager = Hyperspace.ships(ship.iShipId)
	if ship.iShipId == freeze_targetShip and freeze_targetRoom then
		for room in vter(shipManager.ship.vRoomList) do
	 		if room.iRoomId == freeze_targetRoom then
	 			render_stone(room)
	 		end
	 	end
	end
	if ship.iShipId == 0 and freeze_targetRoomEnemy then
		for room in vter(shipManager.ship.vRoomList) do
	 		if room.iRoomId == freeze_targetRoomEnemy then
	 			render_stone(room)
	 		end
	 	end
	end
end)

local stone_icon = Hyperspace.Resources:CreateImagePrimitiveString("icons/aea_stoned_icon.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false)
script.on_render_event(Defines.RenderEvents.SYSTEM_BOX, function(systemBox, ignoreStatus) end, function(systemBox, ignoreStatus) 
	--print("room:"..tostring(systemBox.pSystem.roomId).." ship:"..tostring(systemBox.pSystem.iShipId).." freezeRoom:"..tostring(freeze_targetRoom).." freezeShip:"..tostring(freeze_targetShip).." freezeRoomEnemy:"..tostring(freeze_targetRoomEnemy))
	if (systemBox.pSystem.roomId == freeze_targetRoom and (systemBox.bPlayerUI and 0 or 1) == freeze_targetShip) or (systemBox.pSystem.roomId == freeze_targetRoomEnemy and systemBox.bPlayerUI) then
		Graphics.CSurface.GL_RenderPrimitive(stone_icon)
	end
	return Defines.Chain.CONTINUE
end)

script.on_internal_event(Defines.InternalEvents.JUMP_LEAVE, function(shipManager)
	if shipManager.iShipId == 0 and shipManager:HasSystem(Hyperspace.ShipSystem.NameToSystemId(systemIdName)) then
		local system = shipManager:GetSystem(Hyperspace.ShipSystem.NameToSystemId(systemIdName))
		if system.iLockCount == -1 then
			system:LockSystem(0)
		end
		freezeDuration = 0
		freeze_targetRoom = nil
		freeze_targetShip = nil
	end
end)

mods.multiverse.systemIcons[Hyperspace.ShipSystem.NameToSystemId(systemIdName)] = Hyperspace.metaVariables.aea_gods_freeze_unlock == 1 and mods.multiverse.register_system_icon(systemIdName) or mods.multiverse.register_system_icon("aea_hidden")

local shipBuilderCheck = false
script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
	if not shipBuilderCheck and Hyperspace.App.menu.shipBuilder.bOpen then
		shipBuilderCheck = true
		mods.multiverse.systemIcons[Hyperspace.ShipSystem.NameToSystemId(systemIdName)] = Hyperspace.metaVariables.aea_gods_freeze_unlock == 1 and mods.multiverse.register_system_icon(systemIdName) or mods.multiverse.register_system_icon("aea_hidden")
	else
		shipBuilderCheck = false
	end
end)