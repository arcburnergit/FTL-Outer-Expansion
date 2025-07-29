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
	image = Hyperspace.Resources:CreateImagePrimitiveString("map/map_icon_aeap_broadside_enemy.png", -32, -32, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false),
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

local function findClosestBeacon(x, y)
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
		if cur.beacon == finish then
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
					if findTable.beacon == loc then
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

local function roamer_should_spawn(roamer, map, newSector)
	local killed = Hyperspace.playerVariables[roamer.killed_var] == 0
	local sector = (newSector and 1 or 0) + Hyperspace.playerVariables.loc_sector_count == roamer.sector_count or map.currentSector.description.type == roamer.sector
	local var = not roamer.spawn_var or Hyperspace.playerVariables[roamer.spawn_var] >= 1
	return killed and sector and var
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

local last_choose_new_sector = false
script.on_internal_event(Defines.InternalEvents.JUMP_LEAVE, function(shipManager)
	local map = Hyperspace.App.world.starMap
	local commandGui = Hyperspace.App.gui
	local eventManager = Hyperspace.Event
	for event, roamer in pairs(roamers) do
		if roamer_should_spawn(roamer, map, last_choose_new_sector) then
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
			if roamer.beacon and roamer.jumping == 0 then
				local target = roamer_find_target(roamer, map)
				local next = table.remove(dijkstra(map, roamer.beacon.loc, target))

				if (not next == target) and (next.fleetChanging or next.dangerZone or not roamer.fleet) then
					if next == map.currentLoc then
						next.event = eventManager:CreateEvent(event, 0, false)
					end
					roamer.beacon = {x = next.loc.x, y = next.loc.y, loc = next}
					Hyperspace.playerVariables[roamer.beacon_var.."_x"] = next.loc.x
					Hyperspace.playerVariables[roamer.beacon_var.."_y"] = next.loc.y

					roamer.jumping = roamer.jumping_cooldown
					Hyperspace.playerVariables[roamer.jumping_var] = roamer.jumping
				end
			elseif roamer.beacon then
				if roamer.beacon.loc == map.currentLoc then
					roamer.beacon.loc.event = eventManager:CreateEvent(event, 0, false)
				end
				roamer.jumping = roamer.jumping - 1
				Hyperspace.playerVariables[roamer.jumping_var] = roamer.jumping
			end

		end
	end
end)

script.on_internal_event(Defines.InternalEvents.ON_MOUSE_R_BUTTON_DOWN, function(x,y)
	local map = Hyperspace.App.world.starMap
	if map.bOpen then
		local h = map.hoverLoc
		print("bChoosingNewSector:"..tostring(map.bChoosingNewSector).." beacon:"..tostring(h.beacon).." known:"..tostring(h.known).." visited:"..tostring(h.visited).." dangerZone:"..tostring(h.dangerZone).." newSector:"..tostring(h.newSector).." nebula:"..tostring(h.nebula).." boss:"..tostring(h.boss).." eventName:"..tostring(h.event.eventName).." questLoc:"..tostring(h.questLoc).." fleetChanging:"..tostring(h.fleetChanging))
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
		loadRoamers = false
		for event, roamer in pairs(roamers) do
			if roamer_should_spawn(roamer, map, false) then
				roamer.jumping = Hyperspace.playerVariables[roamer.jumping_var]
				local closestLoc = findClosestBeacon(Hyperspace.playerVariables[roamer.beacon_var.."_x"], Hyperspace.playerVariables[roamer.beacon_var.."_y"])
				if closestLoc then 
					roamer.beacon = {x = closestLoc.loc.x, y = closestLoc.loc.y, loc = closestLoc}
					Hyperspace.playerVariables[roamer.beacon_var.."_x"] = closestLoc.loc.x
					Hyperspace.playerVariables[roamer.beacon_var.."_y"] = closestLoc.loc.y
				end
			end
		end
	end
	last_choose_new_sector = false
	if map.bOpen and map.bChoosingNewSector then last_choose_new_sector = true end
end)

local timer = 0
local check_time = 0.1
script.on_render_event(Defines.RenderEvents.GUI_CONTAINER, function() end, function()
	local map = Hyperspace.App.world.starMap
	if map.bOpen and not map.bChoosingNewSector then
		timer = timer + Hyperspace.FPS.SpeedFactor/16
		for event, roamer in pairs(roamers) do
			if roamer_should_spawn(roamer, map, false) then

				if roamer.beacon then
					if timer > check_time then
						local target = roamer_find_target(roamer, map)
						local next = table.remove(dijkstra(map, roamer.beacon.loc, target))
						if (not next == target) and (next.fleetChanging or next.dangerZone or not roamer.fleet) then
							roamer.next = {x = next.loc.x, y = next.loc.y, loc = next}
						end
					end

					if roamer.jumping == 0 and roamer.next then
						roamer.angle = roamer.angle + Hyperspace.FPS.SpeedFactor/16 * 15
						local distance = get_distance(roamer.beacon, roamer.next)
						if roamer.angle > 30 then roamer.angle = roamer.angle - 30 end

						local point = get_point_local_offset(roamer.beacon, roamer.next, roamer.angle + 10, 0)

						local alpha = math.atan((roamer.beacon.y-roamer.next.y), (roamer.beacon.x-roamer.next.x))

						local pointAngle = math.deg(alpha) + 90

						local fade = math.min(1, (30 - roamer.angle)/10)
						Graphics.CSurface.GL_PushMatrix()
						Graphics.CSurface.GL_Translate(point.x + 385,point.y + 122,0)
						Graphics.CSurface.GL_Rotate(pointAngle, 0, 0, 1)
						Graphics.CSurface.GL_RenderPrimitiveWithAlpha(roamer.image, fade)
						Graphics.CSurface.GL_PopMatrix()

					else
						roamer.angle = roamer.angle + Hyperspace.FPS.SpeedFactor/16 * 18
						if roamer.angle > 360 then roamer.angle = roamer.angle - 360 end
						Graphics.CSurface.GL_PushMatrix()
						Graphics.CSurface.GL_Translate(roamer.beacon.x + 385, roamer.beacon.y + 122, 0)
						Graphics.CSurface.GL_Rotate(roamer.angle, 0, 0, 1)
						Graphics.CSurface.GL_Translate(22, 0, 0)
						Graphics.CSurface.GL_RenderPrimitive(roamer.image)
						Graphics.CSurface.GL_PopMatrix()
					end
				end
			end
		end
		if timer > check_time then
			timer = 0
		end
	end
end)