local function vter(cvec)
	local i = -1
	local n = cvec:size()
	return function()
		i = i + 1
		if i < n then return cvec[i] end
	end
end

local function get_room_at_location(shipManager, location, includeWalls)
	return Hyperspace.ShipGraph.GetShipInfo(shipManager.iShipId):GetSelectedRoom(location.x, location.y, includeWalls)
end

local function get_distance(point1, point2)
	return math.sqrt(((point2.x - point1.x)^ 2)+((point2.y - point1.y) ^ 2))
end

local function get_point_local_offset(original, target, offsetForwards, offsetRight)
	local alpha = math.atan((original.y-target.y), (original.x-target.x))
	local newX = original.x - (offsetForwards * math.cos(alpha)) - (offsetRight * math.cos(alpha+math.rad(90)))
	local newY = original.y - (offsetForwards * math.sin(alpha)) - (offsetRight * math.sin(alpha+math.rad(90)))
	return Hyperspace.Pointf(newX, newY)
end

local function worldToPlayerLocation(location)
	local cApp = Hyperspace.App
	local combatControl = cApp.gui.combatControl
	local playerPosition = combatControl.playerShipPosition
	return Hyperspace.Point(location.x - playerPosition.x, location.y - playerPosition.y)
end
local function worldToEnemyLocation(location)
	local cApp = Hyperspace.App
	local combatControl = cApp.gui.combatControl
	local position = combatControl.position
	local targetPosition = combatControl.targetPosition
	local enemyShipOriginX = position.x + targetPosition.x
	local enemyShipOriginY = position.y + targetPosition.y
	return Hyperspace.Point(location.x - enemyShipOriginX, location.y - enemyShipOriginY)
end

-- Get a table for a userdata value by name
local function userdata_table(userdata, tableName)
	if not userdata.table[tableName] then userdata.table[tableName] = {} end
	return userdata.table[tableName]
end

local targets_enum = {player = 1, exit = 2, random = 3}

local roamers = {}
roamers["AEA_JUSTICIER_FIGHT_ONE"] = {
	image = Hyperspace.Resources:CreateImagePrimitiveString("map/map_icon_aea_justice_battleship.png", -32, -32, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false),
	fleet = true,
	angle = 0,
	target = targets_enum.player,
	sector_count = 3,
	rotation = 0,
	beacon = nil,
	beacon_var = "aea_justicier_roamer_one_beacon",
	jumping = 0,
	jumping_var = "aea_justicier_roamer_one_jumping",
	jumping_cooldown = 0,
	killed_var = "aea_justicier_roamer_one_killed",
	start_left = true,
	next = nil
}
roamers["AEA_JUSTICIER_FIGHT_ONE"].image.textureAntialias = true

roamers["AEA_JUSTICIER_FIGHT_TWO"] = {
	image = Hyperspace.Resources:CreateImagePrimitiveString("map/map_icon_aea_justice_cruiser.png", -32, -32, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false),
	fleet = true,
	spawn_var = "aea_justicier_roamer_one_killed",
	angle = 0,
	target = targets_enum.player,
	sector_count = 5,
	rotation = 0,
	beacon = nil,
	beacon_var = "aea_justicier_roamer_two_beacon",
	jumping = 0,
	jumping_var = "aea_justicier_roamer_two_jumping",
	jumping_cooldown = 0,
	killed_var = "aea_justicier_roamer_two_killed",
	start_left = true,
	next = nil
}
roamers["AEA_JUSTICIER_FIGHT_TWO"].image.textureAntialias = true

roamers["AEA_ENEMY_BROADSIDE_EVENT"] = {
	image = Hyperspace.Resources:CreateImagePrimitiveString("map/map_icon_aea_broadside.png", -32, -32, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false),
	fleet = true,
	angle = 0,
	target = targets_enum.player,
	sector_count = 6,
	rotation = 0,
	beacon = nil,
	beacon_var = "aea_broadside_roamer_beacon",
	jumping = 0,
	jumping_var = "aea_broadside_roamer_jumping",
	jumping_cooldown = 0,
	killed_var = "aea_broadside_roamer_killed",
	start_left = true,
	next = nil
}
roamers["AEA_ENEMY_BROADSIDE_EVENT"].image.textureAntialias = true

roamers["AEA_OLD_SHOWDOWN_CASUAL"] = {
	image = Hyperspace.Resources:CreateImagePrimitiveString("map/map_icon_aea_old_showdown.png", -32, -32, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false),
	spawn_meta_var = "challenge_level",
	spawn_meta_lvl = 0,
	skip_exit = true,
	angle = 0,
	target = targets_enum.player,
	sector_count = -1,
	sector = "SECRET_AEA_OLD_3",
	rotation = 0,
	beacon = nil,
	beacon_var = "aea_old_showdown_roamer_beacon",
	jumping = 0,
	jumping_var = "aea_old_showdown_roamer_jumping",
	jumping_cooldown = 1,
	killed_var = "aea_old_showdown_roamer_killed",
	stages = 3,
	start_left = false,
	next = nil
}
roamers["AEA_OLD_SHOWDOWN_NORMAL"] = {
	image = Hyperspace.Resources:CreateImagePrimitiveString("map/map_icon_aea_old_showdown.png", -32, -32, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false),
	spawn_var = "challenge_level",
	spawn_lvl = 1,
	skip_exit = true,
	angle = 0,
	target = targets_enum.player,
	sector_count = -1,
	sector = "SECRET_AEA_OLD_3",
	rotation = 0,
	beacon = nil,
	beacon_var = "aea_old_showdown_roamer_beacon",
	jumping = 0,
	jumping_var = "aea_old_showdown_roamer_jumping",
	jumping_cooldown = 1,
	killed_var = "aea_old_showdown_roamer_killed",
	stages = 3,
	start_left = false,
	next = nil
}
roamers["AEA_OLD_SHOWDOWN_CHALLENGE"] = {
	image = Hyperspace.Resources:CreateImagePrimitiveString("map/map_icon_aea_old_showdown.png", -32, -32, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false),
	spawn_var = "challenge_level",
	spawn_lvl = 2,
	skip_exit = true,
	angle = 0,
	target = targets_enum.player,
	sector_count = -1,
	sector = "SECRET_AEA_OLD_3",
	rotation = 0,
	beacon = nil,
	beacon_var = "aea_old_showdown_roamer_beacon",
	jumping = 0,
	jumping_var = "aea_old_showdown_roamer_jumping",
	jumping_cooldown = 1,
	killed_var = "aea_old_showdown_roamer_killed",
	stages = 3,
	start_left = false,
	next = nil
}
roamers["AEA_OLD_SHOWDOWN_EXTREME"] = {
	image = Hyperspace.Resources:CreateImagePrimitiveString("map/map_icon_aea_old_showdown.png", -32, -32, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false),
	spawn_var = "challenge_level",
	spawn_lvl = 3,
	skip_exit = true,
	angle = 0,
	target = targets_enum.player,
	sector_count = -1,
	sector = "SECRET_AEA_OLD_3",
	rotation = 0,
	beacon = nil,
	beacon_var = "aea_old_showdown_roamer_beacon",
	jumping = 0,
	jumping_var = "aea_old_showdown_roamer_jumping",
	jumping_cooldown = 1,
	killed_var = "aea_old_showdown_roamer_killed",
	stages = 3,
	start_left = false,
	next = nil
}
roamers["AEA_OLD_SHOWDOWN_CASUAL"].image.textureAntialias = true
roamers["AEA_OLD_SHOWDOWN_NORMAL"].image.textureAntialias = true
roamers["AEA_OLD_SHOWDOWN_CHALLENGE"].image.textureAntialias = true
roamers["AEA_OLD_SHOWDOWN_EXTREME"].image.textureAntialias = true


roamers["AEA_GODS_BOSS_LIGHT"] = {
	image = Hyperspace.Resources:CreateImagePrimitiveString("map/map_icon_aea_old_showdown.png", -32, -32, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false),
	spawn_var = "AEA_GODS_BOSS_SPAWN_LIGHT",
	angle = 0,
	target = targets_enum.player,
	sector_count = -1,
	sector = "SECRET_AEA_GODS",
	rotation = 0,
	beacon = nil,
	beacon_var = "aea_gods_roamer_beacon",
	jumping = 0,
	jumping_var = "aea_gods_roamer_jumping",
	jumping_cooldown = 0,
	killed_var = "aea_gods_roamer_killed",
	start_left = true,
	next = nil
}
roamers["AEA_GODS_BOSS_DARK"] = {
	image = Hyperspace.Resources:CreateImagePrimitiveString("map/map_icon_aea_old_showdown.png", -32, -32, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false),
	spawn_var = "AEA_GODS_BOSS_SPAWN_DARK",
	angle = 0,
	target = targets_enum.player,
	sector_count = -1,
	sector = "SECRET_AEA_GODS",
	rotation = 0,
	beacon = nil,
	beacon_var = "aea_gods_roamer_beacon",
	jumping = 0,
	jumping_var = "aea_gods_roamer_jumping",
	jumping_cooldown = 0,
	killed_var = "aea_gods_roamer_killed",
	start_left = true,
	next = nil
}
roamers["AEA_GODS_BOSS_LIGHT"].image.textureAntialias = true
roamers["AEA_GODS_BOSS_DARK"].image.textureAntialias = true

local function findClosestBeacon(x, y)
	if not (x or y) then return nil end
	local map = Hyperspace.App.world.starMap
	closestLoc = nil
	for location in vter(map.locations) do
		local distance = get_distance(location.loc, {x=x, y=y})
		if not closestLoc or distance < closestLoc.distance then
			closestLoc = {loc = location, distance = distance}
		end
	end
	if closestLoc then
		return closestLoc.loc
	end
	return nil
end

local function dijkstra(map, source, finish)
	local info = {}
	--print("source:"..tostring(source).." finish:"..tostring(finish))

	for loc in vter(map.locations) do
		local dis = math.huge
		if loc == source then
			dis = 0
		end
		table.insert(info, {beacon = loc, unVisited = true, distance = dis})
	end
	repeat
		local cur = nil
		for i, locTable in ipairs(info) do
			if locTable.unVisited and locTable.distance ~= math.huge and ((not cur) or locTable.distance < cur.distance) then
				cur = locTable
			end
		end
		if cur and tostring(cur.beacon) == tostring(finish) then
			local path = {cur.beacon}
			local last = cur.last
			while last and last.beacon ~= source do
				--print("path:"..tostring(last.beacon))
				table.insert(path, last.beacon)
				last = last.last
			end
			return path
		end
		if cur then
			for loc in vter(cur.beacon.connectedLocations) do
				local locTable = nil
				for i, findTable in ipairs(info) do
					if tostring(findTable.beacon) == tostring(loc) then
						locTable = findTable
					end
				end
				if locTable and locTable.unVisited then
					local dis = cur.distance + 1
					if dis < locTable.distance then
						locTable.distance = dis
						locTable.last = cur
					end
				end
			end
			cur.unVisited = false
		end
	until not cur
	print("failed")
	return nil
end


local function roamer_should_spawn_print(event, roamer, map, newSector)
	local killed = Hyperspace.playerVariables[roamer.killed_var] < (roamer.stages or 1)
	local sector = (newSector and 1 or 0) + Hyperspace.playerVariables.loc_sector_count == roamer.sector_count or map.currentSector.description.type == roamer.sector
	--local var = not roamer.spawn_var or Hyperspace.playerVariables[roamer.spawn_var] == (roamer.spawn_lvl or 1)
	--local metaVar = not roamer.spawn_meta_var or Hyperspace.metaVariables[roamer.spawn_meta_var] == (roamer.spawn_meta_lvl or math.max(1, Hyperspace.metaVariables[roamer.spawn_meta_var]))
	--print(event.." k:"..tostring(killed).." s:"..tostring(sector).." v:"..tostring(var).." m:"..tostring(metaVar))
	local equip = not roamer.spawn_var or Hyperspace.ships.player:HasEquipment(roamer.spawn_var) == (roamer.spawn_lvl or math.max(1, Hyperspace.ships.player:HasEquipment(roamer.spawn_var)))
	print(event.." k:"..tostring(killed).." s:"..tostring(sector).." e:"..tostring(equip))
end

local function roamer_should_spawn(roamer, map, newSector)
	local killed = Hyperspace.playerVariables[roamer.killed_var] < (roamer.stages or 1)
	local sector = (newSector and 1 or 0) + Hyperspace.playerVariables.loc_sector_count == roamer.sector_count or map.currentSector.description.type == roamer.sector
	--local var = not roamer.spawn_var or Hyperspace.playerVariables[roamer.spawn_var] == (roamer.spawn_lvl or 1)
	--local metaVar = not roamer.spawn_meta_var or Hyperspace.metaVariables[roamer.spawn_meta_var] == (roamer.spawn_meta_lvl or math.max(1, Hyperspace.metaVariables[roamer.spawn_meta_var]))
	local equip = not roamer.spawn_var or Hyperspace.ships.player:HasEquipment(roamer.spawn_var) == (roamer.spawn_lvl or math.max(1, Hyperspace.ships.player:HasEquipment(roamer.spawn_var)))
	return killed and sector and equip --var and metaVar
end

local function roamer_find_target(roamer, map)
	if roamer.target == targets_enum.player then
		return map.potentialLoc or map.currentLoc
	elseif roamer.target == targets_enum.exit then
		for location in vter(map.locations) do
			if location.beacon then
				return location
			end
		end
	elseif roamer.target == targets_enum.random then
		if roamer.target_random and not roamer.target_random == roamer.beacon.loc then
			return roamer.target_random
		else
			local random = math.random(0, map.locations:size() - 1)
			roamer.target_random = map.locations[random]
			return roamer.target_random
		end
	end
end

local restoreBeacon = nil
local last_current_loc = nil
local last_choose_new_sector = false
local function roamer_update(shipManager)
	local map = Hyperspace.App.world.starMap
	local commandGui = Hyperspace.App.gui
	local eventManager = Hyperspace.Event
	if restoreBeacon then
		restoreBeacon.location.event = eventManager:CreateEvent(restoreBeacon.event, 0, false)
		restoreBeacon = nil
	end

	for event, roamer in pairs(roamers) do
		--roamer_should_spawn_print(event, roamer, map, last_choose_new_sector)
		if roamer_should_spawn(roamer, map, last_choose_new_sector) then
			--roamer_should_spawn_print(event, roamer, map, last_choose_new_sector)
			--print(tostring(map.currentLoc).." last:"..tostring(last_current_loc))
			--print("JUMP LEAVE ROAMER SHOULD SPAWN:"..event)
			if not (roamer.beacon and roamer.beacon.loc) then
				roamer.beacon = nil
				local selectBeacon = nil
				for location in vter(map.locations) do
					if (location.fleetChanging or location.dangerZone or not roamer.fleet) and location ~= map.currentLoc then
						if not selectBeacon or (location.loc.x < selectBeacon.loc.x and roamer.start_left) or (location.loc.x > selectBeacon.loc.x and not roamer.start_left) then
							selectBeacon = location
						end
					end 
				end
				if selectBeacon then
					roamer.beacon = {x = selectBeacon.loc.x, y = selectBeacon.loc.y, loc = selectBeacon}
					Hyperspace.playerVariables[roamer.beacon_var.."_x"] = selectBeacon.loc.x
					Hyperspace.playerVariables[roamer.beacon_var.."_y"] = selectBeacon.loc.y
				end
			end
			if roamer.beacon and tostring(roamer.beacon.loc) == tostring(last_current_loc) and roamer.beacon.loc.connectedLocations:size() > 0 then
				--print("RUNNING AWAY")
				local next = roamer.beacon.loc.connectedLocations[0]
				roamer.beacon = {x = next.loc.x, y = next.loc.y, loc = next}
				Hyperspace.playerVariables[roamer.beacon_var.."_x"] = next.loc.x
				Hyperspace.playerVariables[roamer.beacon_var.."_y"] = next.loc.y

				roamer.jumping = roamer.jumping_cooldown
				Hyperspace.playerVariables[roamer.jumping_var] = roamer.jumping

			elseif roamer.beacon and roamer.jumping == 0 then
				--print("MOVING TO TARGET")
				local nextTable = dijkstra(map, roamer.beacon.loc, target)
				if nextTable == nil then
					roamer.beacon = nil
				else
					local target = roamer_find_target(roamer, map)
					local next = table.remove(nextTable)
					--print("n"..tostring(next).." b:"..tostring(roamer.beacon.loc).." a:"..tostring(tostring(next)==tostring(roamer.beacon.loc)).."1:"..tostring(not (next == roamer.beacon.loc)).." 2:"..tostring(next.fleetChanging or next.dangerZone or not roamer.fleet))
					if not (tostring(next) == tostring(roamer.beacon.loc)) and (next.fleetChanging or next.dangerZone or not roamer.fleet) then
						--print("VALID MOVE")
						if not (next.beacon and roamer.skip_exit) then
							if tostring(roamer.beacon.loc) == tostring(map.currentLoc) then
								restoreBeacon = {location = map.currentLoc, event = map.currentLoc.event.eventName}
							end

							if tostring(next) == tostring(map.currentLoc) and ((not roamer.stages) or Hyperspace.playerVariables[roamer.killed_var] == 0) then
								next.event = eventManager:CreateEvent(event, 0, false)
							elseif tostring(next) == tostring(map.currentLoc) and Hyperspace.playerVariables[roamer.killed_var] == 1 then
								next.event = eventManager:CreateEvent(event.."_TWO", 0, false)
							elseif tostring(next) == tostring(map.currentLoc) and Hyperspace.playerVariables[roamer.killed_var] == 2 then
								next.event = eventManager:CreateEvent(event.."_THREE", 0, false)
							end
						end
						roamer.beacon = {x = next.loc.x, y = next.loc.y, loc = next}
						Hyperspace.playerVariables[roamer.beacon_var.."_x"] = next.loc.x
						Hyperspace.playerVariables[roamer.beacon_var.."_y"] = next.loc.y

						roamer.jumping = roamer.jumping_cooldown
						Hyperspace.playerVariables[roamer.jumping_var] = roamer.jumping
					end
				end
			elseif roamer.beacon then
				--print("STAYING STILL")
				if not (roamer.beacon.loc.beacon and roamer.skip_exit) then
					if tostring(roamer.beacon.loc) == tostring(map.currentLoc) then
						restoreBeacon = {location = map.currentLoc, event = map.currentLoc.event.eventName}
					end

					if tostring(roamer.beacon.loc) == tostring(map.currentLoc) and (not roamer.stages or Hyperspace.playerVariables[roamer.killed_var] == 0) then
						roamer.beacon.loc.event = eventManager:CreateEvent(event, 0, false)
					elseif tostring(roamer.beacon.loc) == tostring(map.currentLoc) and (not roamer.stages or Hyperspace.playerVariables[roamer.killed_var] == 1) then
						roamer.beacon.loc.event = eventManager:CreateEvent(event.."_TWO", 0, false)
					elseif tostring(roamer.beacon.loc) == tostring(map.currentLoc) and (not roamer.stages or Hyperspace.playerVariables[roamer.killed_var] == 2) then
						roamer.beacon.loc.event = eventManager:CreateEvent(event.."_THREE", 0, false)
					end
				end
				roamer.jumping = roamer.jumping - 1
				Hyperspace.playerVariables[roamer.jumping_var] = roamer.jumping
			end

		end
	end
end

script.on_internal_event(Defines.InternalEvents.JUMP_LEAVE, roamer_update)
script.on_internal_event(Defines.InternalEvents.ON_WAIT, roamer_update)

script.on_internal_event(Defines.InternalEvents.ON_MOUSE_R_BUTTON_DOWN, function(x,y)
	local map = Hyperspace.App.world.starMap
	if map.bOpen then
		local h = map.hoverLoc
		--print("bChoosingNewSector:"..tostring(map.bChoosingNewSector).." beacon:"..tostring(h.beacon).." known:"..tostring(h.known).." visited:"..tostring(h.visited).." dangerZone:"..tostring(h.dangerZone).." newSector:"..tostring(h.newSector).." nebula:"..tostring(h.nebula).." boss:"..tostring(h.boss).." eventName:"..tostring(h.event.eventName).." questLoc:"..tostring(h.questLoc).." fleetChanging:"..tostring(h.fleetChanging))
	end
	return Defines.Chain.CONTINUE
end)

local loadRoamers = false
script.on_init(function(newGame)
	if not newGame then
		loadRoamers = true
	end
end)

script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
	local map = Hyperspace.App.world.starMap
	local commandGui = Hyperspace.App.gui
	if loadRoamers and Hyperspace.playerVariables.aea_test_variable == 1 then
		--print("loading roamers")
		loadRoamers = false
		for event, roamer in pairs(roamers) do
			if roamer_should_spawn(roamer, map, false) then
				print(event.." roamer loading")
				roamer.jumping = Hyperspace.playerVariables[roamer.jumping_var]
				local closestLoc = findClosestBeacon(Hyperspace.playerVariables[roamer.beacon_var.."_x"], Hyperspace.playerVariables[roamer.beacon_var.."_y"])

				if closestLoc then 
					if (closestLoc.fleetChanging or closestLoc.dangerZone or not roamer.fleet) and closestLoc ~= map.currentLoc then
						roamer.beacon = {x = closestLoc.loc.x, y = closestLoc.loc.y, loc = closestLoc}
						Hyperspace.playerVariables[roamer.beacon_var.."_x"] = closestLoc.loc.x
						Hyperspace.playerVariables[roamer.beacon_var.."_y"] = closestLoc.loc.y
					end 
				end
			end
		end
	end
	last_choose_new_sector = false
	if map.bOpen and map.bChoosingNewSector then last_choose_new_sector = true end
	last_current_loc = map.currentLoc
end)

local waitPrimitive = Hyperspace.Resources:CreateImagePrimitiveString("map/map_icon_aea_old_gate.png", 350, 230, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)

--Impossible to reconstruct beacon rendering ignore this
--[[local diamond = {
	blue = Hyperspace.Resources:CreateImagePrimitiveString("map/map_icon_diamond_blue.png", -16, -16, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	orange = Hyperspace.Resources:CreateImagePrimitiveString("map/map_icon_diamond_yellow.png", -16, -16, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	shadow = Hyperspace.Resources:CreateImagePrimitiveString("map/map_icon_diamond_shadow.png", -16, -16, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	warning = Hyperspace.Resources:CreateImagePrimitiveString("map/map_icon_warning.png", -16, -16, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
}

local triangle = {
	blue = Hyperspace.Resources:CreateImagePrimitiveString("map/map_icon_triangle_blue.png", -16, -16, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	orange = Hyperspace.Resources:CreateImagePrimitiveString("map/map_icon_triangle_yellow.png", -16, -16, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	shadow = Hyperspace.Resources:CreateImagePrimitiveString("map/map_icon_triangle_shadow.png", -16, -16, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	warning = Hyperspace.Resources:CreateImagePrimitiveString("map/map_icon_triangle_red.png", -16, -16, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
}

local hazard = Hyperspace.Resources:CreateImagePrimitiveString("map/map_icon_hazard.png", -22, -22, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
local corner = Hyperspace.Resources:CreateImagePrimitiveString("map/map_icon_triangle_red.png", -16, -16, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
]]

local timer = 0
local check_time = 0.1
script.on_render_event(Defines.RenderEvents.GUI_CONTAINER, function() end, function()
	local map = Hyperspace.App.world.starMap
	if map.bOpen and not map.bChoosingNewSector then
		--print("current:"..tostring(map.currentLoc).." potentialLoc:"..tostring(map.potentialLoc).." hoverLoc:"..tostring(map.hoverLoc))
		timer = timer + Hyperspace.FPS.SpeedFactor/16
		local isRoamer = false
		for event, roamer in pairs(roamers) do
			if roamer_should_spawn(roamer, map, false) then
				if roamer.beacon then
					isRoamer = true
					if roamer.beacon and tostring(roamer.beacon.loc) == tostring(map.currentLoc) and roamer.beacon.loc.connectedLocations:size() > 0 then
						--print("RUNNING AWAY")
						local next = roamer.beacon.loc.connectedLocations[0]
						roamer.next = {x = next.loc.x, y = next.loc.y, loc = next}
					elseif timer > check_time then
						local nextTable = dijkstra(map, roamer.beacon.loc, target)
						if nextTable == nil then
							roamer.beacon = nil
						else
							local target = roamer_find_target(roamer, map)
							local next = table.remove(nextTable)
							if not (tostring(next) == tostring(roamer.beacon.loc)) and (next.fleetChanging or next.dangerZone or not roamer.fleet) then
								roamer.next = {x = next.loc.x, y = next.loc.y, loc = next}
							end
						end
					end

					if roamer.jumping == 0 and roamer.next then
						roamer.angle = roamer.angle + Hyperspace.FPS.SpeedFactor/16 * 15
						local distance = get_distance(roamer.beacon, roamer.next)
						if roamer.angle > 30 then roamer.angle = roamer.angle - 30 end

						local point = get_point_local_offset(roamer.beacon, roamer.next, roamer.angle + 10, 0)

						local alpha = math.atan((roamer.beacon.y-roamer.next.y), (roamer.beacon.x-roamer.next.x))

						local pointAngle = math.deg(alpha) - 90

						local fade = math.min(1, (30 - roamer.angle)/10, roamer.angle)

						Graphics.CSurface.GL_DrawLine(roamer.beacon.x + 385, roamer.beacon.y + 123, roamer.next.x + 385, roamer.next.y + 123, 9, Graphics.GL_Color(0.88, 0.4, 0.4, 0.5))

						Graphics.CSurface.GL_PushMatrix()
						Graphics.CSurface.GL_Translate(point.x + 385,point.y + 123,0)
						Graphics.CSurface.GL_Rotate(pointAngle, 0, 0, 1)
						Graphics.CSurface.GL_RenderPrimitiveWithAlpha(roamer.image, fade)
						Graphics.CSurface.GL_PopMatrix()

					else
						roamer.angle = roamer.angle + Hyperspace.FPS.SpeedFactor/16 * 18
						if roamer.angle > 360 then roamer.angle = roamer.angle - 360 end
						Graphics.CSurface.GL_PushMatrix()
						Graphics.CSurface.GL_Translate(roamer.beacon.x + 385, roamer.beacon.y + 123, 0)
						Graphics.CSurface.GL_Rotate(360-roamer.angle, 0, 0, 1)
						Graphics.CSurface.GL_Translate(22, 0, 0)
						Graphics.CSurface.GL_RenderPrimitive(roamer.image)
						Graphics.CSurface.GL_PopMatrix()
					end
				end
			end
		end
		if isRoamer then
			map:ForceWaitMessage()
		end
		if timer > check_time then
			timer = 0
		end
	end
end)

local shouldUpdate = false
script.on_internal_event(Defines.InternalEvents.JUMP_ARRIVE, function(shipManager)
	shouldUpdate = true
end)

local function roamer_update_spawns()
	local map = Hyperspace.App.world.starMap
	local commandGui = Hyperspace.App.gui
	local eventManager = Hyperspace.Event
	for event, roamer in pairs(roamers) do
		if roamer_should_spawn(roamer, map, false) then
			if not (roamer.beacon and roamer.beacon.loc) then
				roamer.beacon = nil
				local selectBeacon = nil
				for location in vter(map.locations) do
					if (location.fleetChanging or location.dangerZone or not roamer.fleet) and location ~= map.currentLoc then
						if not selectBeacon or (location.loc.x < selectBeacon.loc.x and roamer.start_left) or (location.loc.x > selectBeacon.loc.x and not roamer.start_left) then
							selectBeacon = location
						end
					end 
				end
				if selectBeacon then
					roamer.beacon = {x = selectBeacon.loc.x, y = selectBeacon.loc.y, loc = selectBeacon}
					Hyperspace.playerVariables[roamer.beacon_var.."_x"] = selectBeacon.loc.x
					Hyperspace.playerVariables[roamer.beacon_var.."_y"] = selectBeacon.loc.y
				end
			end
		end
	end
end

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	if shouldUpdate then
		shouldUpdate = false
		roamer_update_spawns()
	end
end)
