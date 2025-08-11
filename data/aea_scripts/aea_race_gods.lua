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

local is_first_shot = mods.multiverse.is_first_shot

local beacon = {
	bright = Hyperspace.Resources:CreateImagePrimitiveString("stars_old/planet_aea_star.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	dark = Hyperspace.Resources:CreateImagePrimitiveString("stars_old/planet_aea_hole.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	select1 = Hyperspace.Resources:CreateImagePrimitiveString("stars_old/planet_aea_beacon_select1.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	select2 = Hyperspace.Resources:CreateImagePrimitiveString("stars_old/planet_aea_beacon_select2.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	select3 = Hyperspace.Resources:CreateImagePrimitiveString("stars_old/planet_aea_beacon_select3.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
}

brightEvents = {}
brightEvents["ENTER_AEA_GODS"] = "aea_gods_beacon_bright_0_consumed"
brightEvents["AEA_GODS_BEACON_BRIGHT_1"] = "aea_gods_beacon_bright_1_consumed"
brightEvents["AEA_GODS_BEACON_BRIGHT_2"] = "aea_gods_beacon_bright_2_consumed"
brightEvents["AEA_GODS_BEACON_BRIGHT_3"] = "aea_gods_beacon_bright_3_consumed"
brightEvents["AEA_GODS_BEACON_BRIGHT_4"] = "aea_gods_beacon_bright_4_consumed"
brightEvents["AEA_GODS_BEACON_BRIGHT_5"] = "aea_gods_beacon_bright_5_consumed"
brightEvents["AEA_GODS_BEACON_BRIGHT_6"] = "aea_gods_beacon_bright_6_consumed"
brightEvents["AEA_GODS_BEACON_BRIGHT_7"] = "aea_gods_beacon_bright_7_consumed"

darkEvents = {}
darkEvents["AEA_GODS_BEACON_DARK_1"] = "aea_gods_beacon_dark_1_consumed"
darkEvents["AEA_GODS_BEACON_DARK_2"] = "aea_gods_beacon_dark_2_consumed"
darkEvents["AEA_GODS_BEACON_DARK_3"] = "aea_gods_beacon_dark_3_consumed"
darkEvents["AEA_GODS_BEACON_DARK_4"] = "aea_gods_beacon_dark_4_consumed"
darkEvents["AEA_GODS_BEACON_DARK_5"] = "aea_gods_beacon_dark_5_consumed"
darkEvents["AEA_GODS_BEACON_DARK_6"] = "aea_gods_beacon_dark_6_consumed"
darkEvents["AEA_GODS_BEACON_DARK_7"] = "aea_gods_beacon_dark_7_consumed"

grayEvents = {}
grayEvents["AEA_GODS_BEACON_SECRET"] = "aea_gods_beacon_secret_consumed"

local randomPos = {x = 0, y = 0}
local padding = -100
local secretFade = 0
local hoverBeacon = false
local jumping = false
script.on_render_event(Defines.RenderEvents.LAYER_FOREGROUND, function()
	local map = Hyperspace.App.world.starMap
	local commandGui = Hyperspace.App.gui
	hoverBeacon = false
	if Hyperspace.playerVariables.aea_gods_light_active <= 1 and not jumping then
		if brightEvents[map.currentLoc.event.eventName] then
			Graphics.CSurface.GL_PushMatrix()
			Graphics.CSurface.GL_Translate(randomPos.x,randomPos.y, 0)
			Graphics.CSurface.GL_RenderPrimitive(beacon.bright)
	    	local mousePos = Hyperspace.Mouse.position
			if mousePos.x >= randomPos.x - padding and mousePos.x <= randomPos.x + 414 + padding and mousePos.y >= randomPos.y - padding and mousePos.y <= randomPos.y + 690 + padding then
				if Hyperspace.playerVariables.aea_gods_light_active == 1 and not commandGui.event_pause then
					Graphics.CSurface.GL_RenderPrimitive(beacon.select2)
					hoverBeacon = 1
				elseif not commandGui.event_pause then
					Graphics.CSurface.GL_RenderPrimitive(beacon.select1)
					Hyperspace.Mouse.tooltip = "You cannot get close enough."
				end
			end
			Graphics.CSurface.GL_PopMatrix()
		elseif darkEvents[map.currentLoc.event.eventName] then
			Graphics.CSurface.GL_PushMatrix()
			Graphics.CSurface.GL_Translate(randomPos.x,randomPos.y, 0)
			Graphics.CSurface.GL_RenderPrimitive(beacon.dark)
	    	local mousePos = Hyperspace.Mouse.position
			if mousePos.x >= randomPos.x - padding and mousePos.x <= randomPos.x + 414 + padding and mousePos.y >= randomPos.y - padding and mousePos.y <= randomPos.y + 690 + padding then
				if Hyperspace.playerVariables.aea_gods_light_active == 1 and not commandGui.event_pause then
					Graphics.CSurface.GL_RenderPrimitive(beacon.select2)
					hoverBeacon = 2
				elseif not commandGui.event_pause then
					Graphics.CSurface.GL_RenderPrimitive(beacon.select1)
					Hyperspace.Mouse.tooltip = "You cannot get close enough."
				end
			end
			Graphics.CSurface.GL_PopMatrix()
		elseif grayEvents[map.currentLoc.event.eventName] then
			randomPos = {x = 950, y = -250}
			Graphics.CSurface.GL_PushMatrix()
			Graphics.CSurface.GL_Translate(randomPos.x,randomPos.y, 0)
	    	local mousePos = Hyperspace.Mouse.position
			if mousePos.x >= randomPos.x - padding and mousePos.x <= randomPos.x + 414 + padding and mousePos.y >= randomPos.y - padding and mousePos.y <= randomPos.y + 690 + padding then
				fade = math.max(1, fade + Hyperspace.FPS.SpeedFactor/128)
				Graphics.CSurface.GL_RenderPrimitiveWithAlpha(beacon.select3, fade)
				if fade == 1 then
					Hyperspace.Mouse.tooltip = "Coming soon..."
					--hoverBeacon = 3
				end
			else
				fade = math.max(0, fade - Hyperspace.FPS.SpeedFactor/16)
				if fade > 0 then
					Graphics.CSurface.GL_RenderPrimitiveWithAlpha(beacon.select3, fade)
				end
			end
			Graphics.CSurface.GL_PopMatrix()
		end
	end
end, function() end)

local cleanseEvents = {"AEA_GODS_BRIGHT_CLEANSE", "AEA_GODS_DARK_CLEANSE", "AEA_GODS_GRAY_CLEANSE"}
script.on_internal_event(Defines.InternalEvents.ON_MOUSE_L_BUTTON_DOWN, function(x,y)
	if hoverBeacon then
		local worldManager = Hyperspace.App.world
		Hyperspace.CustomEventsParser.GetInstance():LoadEvent(worldManager, cleanseEvents[hoverBeacon], false, -1)
	end
	return Defines.Chain.CONTINUE
end)

local function set_root_var()
	local map = Hyperspace.App.world.starMap
	local var = brightEvents[map.currentLoc.event.eventName] or darkEvents[map.currentLoc.event.eventName] or grayEvents[map.currentLoc.event.eventName]
	if var then
		Hyperspace.playerVariables[var] = 1
	end
end


script.on_game_event("AEA_GODS_CLEAR_1", false, set_root_var)
script.on_game_event("AEA_GODS_CLEAR_2", false, set_root_var)

script.on_internal_event(Defines.InternalEvents.JUMP_LEAVE, function()
	jumping = true
end)
script.on_internal_event(Defines.InternalEvents.JUMP_ARRIVE, function()
	jumping = false
	randomPos = {x = math.random(550, 1000), y = math.random(-250, 250)}
end)

script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
	local map = Hyperspace.App.world.starMap
	if map.bOpen and map.currentSector.description.type == "SECRET_AEA_GODS" then
		for loc in vter(map.locations) do
			if loc.visited > 0 then
				--loc.visited = 0
			end
			if loc.known then
				loc.known = false
			end
		end
	end
end)
local diamond = {
	white = Hyperspace.Resources:CreateImagePrimitiveString("map/map_icon_diamond_aea_white.png", -16, -16, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	gray = Hyperspace.Resources:CreateImagePrimitiveString("map/map_icon_diamond_aea_gray.png", -16, -16, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	black = Hyperspace.Resources:CreateImagePrimitiveString("map/map_icon_diamond_aea_black.png", -16, -16, 0, Graphics.GL_Color(0.75, 0.75, 0.75, 1), 1.0, false)
}
local backImage = Hyperspace.Resources:CreateImagePrimitiveString("map/map_aea_back.png", 344, 87, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
local backImageTop = Hyperspace.Resources:CreateImagePrimitiveString("map/map_aea_back_top.png", 344, 87, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
local corner = Hyperspace.Resources:CreateImagePrimitiveString("map/map_targetbox.png", -16, -16, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)

local ruinEvents = {}
ruinEvents["AEA_GODS_RUINS"] = true

local shipEvents = {}

local angle = 0
script.on_render_event(Defines.RenderEvents.GUI_CONTAINER, function() end, function()
	local map = Hyperspace.App.world.starMap
	if map.bOpen and map.currentSector.description.type == "SECRET_AEA_GODS" then
		--potential means can jump to it, hover is just whatever you're hovering over.
		--print("current:"..tostring(map.currentLoc).." potentialLoc:"..tostring(map.potentialLoc).." hoverLoc:"..tostring(map.hoverLoc))
		Graphics.CSurface.GL_RenderPrimitive(backImage)
		Graphics.CSurface.GL_RenderPrimitive(backImageTop)
		for loc in vter(map.locations) do
			local pos = loc.loc
			Graphics.CSurface.GL_PushMatrix()
			Graphics.CSurface.GL_Translate(385, 123, 0)
			for conLoc in vter(loc.connectedLocations) do
				Graphics.CSurface.GL_DrawLine(pos.x, pos.y, conLoc.loc.x, conLoc.loc.y, 3, Graphics.GL_Color(0.5, 0.5, 0.5, 1))
			end
			Graphics.CSurface.GL_PopMatrix()
		end
		for loc in vter(map.locations) do
			Graphics.CSurface.GL_PopMatrix()
			--print(loc.event.eventName)
			local pos = loc.loc
			Graphics.CSurface.GL_PushMatrix()
			Graphics.CSurface.GL_Translate(pos.x + 385,pos.y + 123, 0)
			if brightEvents[loc.event.eventName] then
				Graphics.CSurface.GL_RenderPrimitive(diamond.white)
			elseif darkEvents[loc.event.eventName] then
				Graphics.CSurface.GL_RenderPrimitive(diamond.black)
			elseif shipEvents[loc.event.eventName] then
			else
				Graphics.CSurface.GL_RenderPrimitive(diamond.gray)
				if ruinEvents[loc.event.eventName] then
					local hitbox = Graphics.freetype.easy_measurePrintLines(51, 0, 0, 400, "RUIN")
					Graphics.CSurface.GL_DrawRect(-1 - (hitbox.x/2), -16-1, (hitbox.x+5), (hitbox.y+2), Graphics.GL_Color(1, 1, 1, 1))
					Graphics.CSurface.GL_DrawRect(0 - (hitbox.x/2), -16, (hitbox.x+3), (hitbox.y), Graphics.GL_Color(0, 0, 0, 1))
		    		Graphics.freetype.easy_printNewlinesCentered(51, 1, -16, 400, "RUIN")
				end
			end
			Graphics.CSurface.GL_PopMatrix()
		end
		local sbPos = map.currentLoc.loc
		local shipPrim = map.ship
		angle = (angle + (Hyperspace.FPS.SpeedFactor/16) * 18)%360
		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(sbPos.x + 385, sbPos.y + 123, 0)
		Graphics.CSurface.GL_Rotate(360-angle, 0, 0, 1)
		--Graphics.CSurface.GL_Translate(0, 0, 0)
		Graphics.CSurface.GL_RenderPrimitive(shipPrim)
		Graphics.CSurface.GL_PopMatrix()

		if map.potentialLoc then
			local potPos = map.potentialLoc.loc
			local offset = ((angle/18) * 22) % 22
			if offset > 10 then offset = 21 - offset end
			Graphics.CSurface.GL_PushMatrix()
			Graphics.CSurface.GL_Translate(potPos.x + 385, potPos.y + 123, 0)

			Graphics.CSurface.GL_PushMatrix()
			Graphics.CSurface.GL_Translate(-1 * offset, -1 * offset, 0)
			Graphics.CSurface.GL_RenderPrimitive(corner)
			Graphics.CSurface.GL_PopMatrix()

			Graphics.CSurface.GL_PushMatrix()
			Graphics.CSurface.GL_Rotate(90, 0, 0, 1)
			Graphics.CSurface.GL_Translate(-1 * offset, -1 * offset, 0)
			Graphics.CSurface.GL_RenderPrimitive(corner)
			Graphics.CSurface.GL_PopMatrix()

			Graphics.CSurface.GL_PushMatrix()
			Graphics.CSurface.GL_Rotate(180, 0, 0, 1)
			Graphics.CSurface.GL_Translate(-1 * offset, -1 * offset, 0)
			Graphics.CSurface.GL_RenderPrimitive(corner)
			Graphics.CSurface.GL_PopMatrix()

			Graphics.CSurface.GL_PushMatrix()
			Graphics.CSurface.GL_Rotate(270, 0, 0, 1)
			Graphics.CSurface.GL_Translate(-1 * offset, -1 * offset, 0)
			Graphics.CSurface.GL_RenderPrimitive(corner)
			Graphics.CSurface.GL_PopMatrix()

			Graphics.CSurface.GL_PopMatrix()
		end
	end
end)

script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA_HIT, function(shipManager, projectile, location, damage, shipFriendlyFire)
    if projectile and shipManager:GetAugmentationValue("AEA_GODS_HEAL") > 0 and damage.iDamage > 0 then
    	if not userdata_table(shipManager, "mods.aea.godHeal").healTable then
    		userdata_table(shipManager, "mods.aea.godHeal").healTable = {}
    	end
    	local healTable = userdata_table(shipManager, "mods.aea.godHeal").healTable
    	local tempTimer = shipManager:GetAugmentationValue("AEA_GODS_HEAL") + #healTable
    	local room = -1
    	if location then
    		room = get_room_at_location(shipManager, location, true)
    	end
    	print("create heal timer:"..tostring(tempTimer).." damage:"..tostring(damage.iDamage).." sysDamage:"..tostring(damage.iDamage + damage.iSystemDamage).." room:"..tostring(room))
    	table.insert(healTable, {timer = tempTimer, damage = damage.iDamage, sysDamage = damage.iDamage + damage.iSystemDamage, room = room})
    end
end)
script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	if shipManager:GetAugmentationValue("AEA_GODS_HEAL") > 0 and userdata_table(shipManager, "mods.aea.godHeal").healTable then
    	local healTable = userdata_table(shipManager, "mods.aea.godHeal").healTable
    	local removeI = nil
    	for i, item in ipairs(healTable) do
    		item.timer = item.timer - Hyperspace.FPS.SpeedFactor/16
    		if item.timer <= 0 then
    			removeI = i
    		end
    	end
    	if removeI then
    		Hyperspace.Sounds:PlaySoundMix("repairShip", -1, false)
    		local item = healTable[removeI]
    		print("finish heal timer:"..tostring(item.timer).." damage:"..tostring(item.damage).." sysDamage:"..tostring(item.sysDamage).." room:"..tostring(item.room))
			shipManager:DamageHull(-1 * item.damage, false)
    		local sys = shipManager:GetSystemInRoom(item.room)
    		if sys then
    			sys:AddDamage(-1 * item.sysDamage)
    		end
    		table.remove(healTable, removeI)
    	end
	end
end)

local cycleWeapons = {}
cycleWeapons["ARTILLERY_AEA_GODS_CYCLE"] = {
	{print = "ARTILLERY_REBEL_MISSILE", type = "missile", image = Hyperspace.Resources:CreateImagePrimitiveString("weapons_aea/aea_gods_boss_artillery_missile.png", 0, -20, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)}, 
	{print = "ARTILLERY_REBEL_LASER", type = "laser", image = Hyperspace.Resources:CreateImagePrimitiveString("weapons_aea/aea_gods_boss_artillery_laser.png", 0, -20, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)}, 
	{print = "ARTILLERY_REBEL_ION", type = "laser", image = Hyperspace.Resources:CreateImagePrimitiveString("weapons_aea/aea_gods_boss_artillery_ion.png", 0, -20, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)}
}

local offset = true
script.on_internal_event(Defines.InternalEvents.JUMP_ARRIVE, function(ship)
	if ship.iShipId == 0 then
		offset = true
	end
end)

script.on_internal_event(Defines.InternalEvents.PROJECTILE_FIRE, function(projectile, weapon)
	local cycleData = cycleWeapons[weapon.blueprint.name]
	if cycleData then
		local weaponTable = userdata_table(weapon, "mods.aea.cycleWeapons")
		if weaponTable.cycle then
			if is_first_shot(weapon, true) then
				weaponTable.cycle = (weaponTable.cycle + 1)%(#cycleData)
				if cycleData[weaponTable.cycle+1].type == "laser" then
					weapon.cooldown.first = weapon.cooldown.first + 5
				end
			end
			--print("print:"..tostring(cycleData[weaponTable.cycle+1].print).." type:"..tostring(cycleData[weaponTable.cycle+1].type))
        	local spaceManager = Hyperspace.Global.GetInstance():GetCApp().world.space
        	--print("cycle:"..tostring(weaponTable.cycle))
			local blueprint = Hyperspace.Blueprints:GetWeaponBlueprint(cycleData[weaponTable.cycle+1].print)
			if cycleData[weaponTable.cycle+1].type == "missile" then
				--print("fire missile:"..blueprint.name)
				local missile = spaceManager:CreateMissile(
	            	blueprint,
	            	projectile.position,
	            	projectile.currentSpace,
	            	projectile.ownerId,
					projectile.target,
	            	projectile.destinationSpace,
	            	projectile.heading)
            	missile.bBroadcastTarget = true
				missile.entryAngle = projectile.entryAngle
			elseif cycleData[weaponTable.cycle+1].type == "laser" then
				--print("fire laser:"..blueprint.name)
				local laser = spaceManager:CreateLaserBlast(
					blueprint,
					projectile.position,
					projectile.currentSpace,
					projectile.ownerId,
					projectile.target,
					projectile.destinationSpace,
					projectile.heading)
            	laser.bBroadcastTarget = true
				laser.entryAngle = projectile.entryAngle
			end
			projectile:Kill()
		else
			if offset then
				userdata_table(weapon, "mods.aea.cycleWeapons").cycle = 1
				offset = false
			else
				userdata_table(weapon, "mods.aea.cycleWeapons").cycle = 0
			end
		end
	end
end)

script.on_render_event(Defines.RenderEvents.SHIP, function(ship) end, function(ship) 
	local shipManager = Hyperspace.ships(ship.iShipId)
	local shipGraph = Hyperspace.ShipGraph.GetShipInfo(shipManager.iShipId)
	local shipCorner = {x = shipManager.ship.shipImage.x + shipGraph.shipBox.x, y = shipManager.ship.shipImage.y + shipGraph.shipBox.y}
	if shipManager and shipManager:HasSystem(11) then
		for artillery in vter(shipManager.artillerySystems) do
			local weapon = artillery.projectileFactory
			local cycleData = cycleWeapons[weapon.blueprint.name]
			if cycleData then
				local weaponTable = userdata_table(weapon, "mods.aea.cycleWeapons")
				if weaponTable.cycle then
					local imageCycle = ((weaponTable.cycle + 1)%(#cycleData)) + 1
					local image = cycleData[imageCycle].image
					local x = (weapon.mount.mirror and -(weapon.weaponVisual.anim.info.frameWidth - weapon.weaponVisual.mountPoint.x)) or -weapon.weaponVisual.mountPoint.x
					local y = -weapon.weaponVisual.mountPoint.y
					Graphics.CSurface.GL_PushMatrix()
      				Graphics.CSurface.GL_Translate(weapon.weaponVisual.renderPoint.x + shipCorner.x + x, weapon.weaponVisual.renderPoint.y + shipCorner.y + y)
					Graphics.CSurface.GL_RenderPrimitive(image)
					Graphics.CSurface.GL_PopMatrix()
				else
					if offset then
						userdata_table(weapon, "mods.aea.cycleWeapons").cycle = 1
						offset = false
					else
						userdata_table(weapon, "mods.aea.cycleWeapons").cycle = 0
					end
				end
			end
		end
	end
end)

script.on_internal_event(Defines.InternalEvents.POST_CREATE_CHOICEBOX, function(choiceBox, event)
	if event.store then
		Hyperspace.playerVariables.aea_store_active = 1
	end
end)

script.on_internal_event(Defines.InternalEvents.JUMP_LEAVE, function(ship)
	if ship.iShipId == 0 then
		Hyperspace.playerVariables.aea_store_active = 0
	end
end)

local petrifyStats = {}
petrifyStats[Hyperspace.CrewStat.MAX_HEALTH] = {amount = 1000}
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

local blankCrewImage = Hyperspace.Resources:GetImageId("people/aea_invisible.png")
mods.aea.statueCrewImage = {}
local statueCrewImage = mods.aea.statueCrewImage
statueCrewImage["human"] = {base = Hyperspace.Resources:GetImageId("people/blobhuman_base.png"), colour = Hyperspace.Resources:GetImageId("people/blobhuman_color.png")}
statueCrewImage["engi"] = {base = Hyperspace.Resources:GetImageId("people/blobengi_base.png"), colour = Hyperspace.Resources:GetImageId("people/blobengi_color.png")}
statueCrewImage["zoltan"] = {base = Hyperspace.Resources:GetImageId("people/blobzoltan_base.png"), colour = Hyperspace.Resources:GetImageId("people/blobzoltan_color.png")}
statueCrewImage["orchid"] = {base = Hyperspace.Resources:GetImageId("people/bloborchid_base.png"), colour = Hyperspace.Resources:GetImageId("people/bloborchid_color.png")}
statueCrewImage["vampweed"] = {base = Hyperspace.Resources:GetImageId("people/blobvampweed_base.png"), colour = Hyperspace.Resources:GetImageId("people/blobvampweed_color.png")}
statueCrewImage["shell"] = {base = Hyperspace.Resources:GetImageId("people/blobshell_base.png"), colour = Hyperspace.Resources:GetImageId("people/blobshell_color.png")}
statueCrewImage["mantis"] = {base = Hyperspace.Resources:GetImageId("people/blobmantis_base.png"), colour = Hyperspace.Resources:GetImageId("people/blobmantis_color.png")}
statueCrewImage["freemantis"] = {base = Hyperspace.Resources:GetImageId("people/blobfreemantis_base.png"), colour = Hyperspace.Resources:GetImageId("people/blobfreemantis_color.png")}
statueCrewImage["rock"] = {base = Hyperspace.Resources:GetImageId("people/blobrock_base.png"), colour = Hyperspace.Resources:GetImageId("people/blobrock_color.png")}
statueCrewImage["crystal"] = {base = Hyperspace.Resources:GetImageId("people/blobcrystal_base.png"), colour = Hyperspace.Resources:GetImageId("people/blobcrystal_color.png")}
statueCrewImage["slug"] = {base = Hyperspace.Resources:GetImageId("people/blobslug_base.png"), colour = Hyperspace.Resources:GetImageId("people/blobslug_color.png")}
statueCrewImage["leech"] = {base = Hyperspace.Resources:GetImageId("people/blobleech_base.png"), colour = Hyperspace.Resources:GetImageId("people/blobleech_color.png")}
statueCrewImage["lanius"] = {base = Hyperspace.Resources:GetImageId("people/lanius_base.png"), colour = Hyperspace.Resources:GetImageId("people/lanius_color.png")}
statueCrewImage["spider"] = {base = Hyperspace.Resources:GetImageId("people/blobspider_base.png"), colour = Hyperspace.Resources:GetImageId("people/blobspider_color.png")}
statueCrewImage["pony"] = {base = Hyperspace.Resources:GetImageId("people/blobpony_base.png"), colour = Hyperspace.Resources:GetImageId("people/blobpony_color.png")}
statueCrewImage["lizard"] = {base = Hyperspace.Resources:GetImageId("people/bloblizard_base.png"), colour = Hyperspace.Resources:GetImageId("people/bloblizard_color.png")}
statueCrewImage["cognitive"] = {base = Hyperspace.Resources:GetImageId("people/aea_statue_cognitive_base.png"), colour = Hyperspace.Resources:GetImageId("people/cognitive_color.png")}
statueCrewImage["obelisk"] = {base = Hyperspace.Resources:GetImageId("people/aea_statue_obelisk_base.png"), colour = Hyperspace.Resources:GetImageId("people/obelisk_color.png")}

mods.aea.crewToStatue = {}
local crewToStatue = mods.aea.crewToStatue
crewToStatue["human"] = statueCrewImage["human"]
crewToStatue["human_medic"] = statueCrewImage.human
crewToStatue["human_engineer"] = statueCrewImage.human
crewToStatue["human_rebel"] = statueCrewImage.human
crewToStatue["human_rebel_medic"] = statueCrewImage.human
crewToStatue["human_soldier"] = statueCrewImage.human
crewToStatue["human_mfk"] = statueCrewImage.human
crewToStatue["human_legion"] = statueCrewImage.human
crewToStatue["human_legion_pyro"] = statueCrewImage.human
crewToStatue["human_technician"] = statueCrewImage.human
crewToStatue["human_angel"] = statueCrewImage.human
crewToStatue["unique_haynes"] = statueCrewImage.human
crewToStatue["unique_tully"] = statueCrewImage.human
crewToStatue["unique_ellie_lvl1"] = statueCrewImage.human
crewToStatue["unique_ellie_lvl2"] = statueCrewImage.human
crewToStatue["unique_ellie_lvl3"] = statueCrewImage.human
crewToStatue["unique_ellie_lvl4"] = statueCrewImage.human
crewToStatue["unique_ellie_lvl5"] = statueCrewImage.human
crewToStatue["unique_ellie_lvl6"] = statueCrewImage.human
crewToStatue["unique_ellie_stephan"] = statueCrewImage.human
crewToStatue["unique_jerry"] = statueCrewImage.human
crewToStatue["unique_jerry_gun"] = statueCrewImage.human
crewToStatue["unique_jerry_pony"] = statueCrewImage.human
crewToStatue["unique_jerry_pony_crystal"] = statueCrewImage.human

crewToStatue["engi"] = statueCrewImage.engi
crewToStatue["engi_separatist"] = statueCrewImage.engi
crewToStatue["engi_separatist_nano"] = statueCrewImage.engi
crewToStatue["engi_defender"] = statueCrewImage.engi
crewToStatue["unique_turzil"] = statueCrewImage.engi

crewToStatue["zoltan"] = statueCrewImage.human
crewToStatue["zoltan_monk"] = statueCrewImage.human
crewToStatue["zoltan_devotee"] = statueCrewImage.human
crewToStatue["zoltan_osmian"] = statueCrewImage.zoltan
crewToStatue["zoltan_osmian_enemy"] = statueCrewImage.zoltan
crewToStatue["zoltan_osmian_hologram "] = statueCrewImage.zoltan
crewToStatue["zoltan_peacekeeper"] = statueCrewImage.human
crewToStatue["zoltan_martyr"] = statueCrewImage.human
crewToStatue["zoltan_infernum"] = statueCrewImage.human
crewToStatue["zoltan_infernum_defector"] = statueCrewImage.human
crewToStatue["unique_anurak"] = statueCrewImage.human
crewToStatue["unique_devorak"] = statueCrewImage.human
crewToStatue["unique_mafan"] = statueCrewImage.human

crewToStatue["orchid"] = statueCrewImage.orchid
crewToStatue["orchid_caretaker"] = statueCrewImage.orchid
crewToStatue["orchid_praetor"] = statueCrewImage.orchid
crewToStatue["unique_mayeb"] = statueCrewImage.orchid
crewToStatue["unique_tyerel"] = statueCrewImage.orchid
crewToStatue["unique_ivar"] = statueCrewImage.orchid

crewToStatue["orchid_vampweed"] = statueCrewImage.vampweed
crewToStatue["orchid_cultivator"] = statueCrewImage.vampweed

crewToStatue["shell"] = statueCrewImage.shell
crewToStatue["shell_scientist"] = statueCrewImage.shell
crewToStatue["shell_mechanic"] = statueCrewImage.shell
crewToStatue["shell_guardian"] = statueCrewImage.shell
crewToStatue["shell_radiant"] = statueCrewImage.shell
crewToStatue["unique_alkali"] = statueCrewImage.shell

crewToStatue["mantis"] = statueCrewImage.mantis
crewToStatue["mantis_suzerain"] = statueCrewImage.mantis
crewToStatue["mantis_bishop"] = statueCrewImage.mantis
crewToStatue["unique_kaz"] = statueCrewImage.mantis
crewToStatue["unique_freddy"] = statueCrewImage.mantis
crewToStatue["unique_freddy_sombrero"] = statueCrewImage.mantis
crewToStatue["unique_freddy_jester"] = statueCrewImage.mantis
crewToStatue["unique_freddy_fedora"] = statueCrewImage.mantis
crewToStatue["unique_freddy_twohats"] = statueCrewImage.mantis

crewToStatue["mantis_free"] = statueCrewImage.freemantis
crewToStatue["mantis_warlord"] = statueCrewImage.freemantis

crewToStatue["rock"] = statueCrewImage.rock
crewToStatue["rock_outcast"] = statueCrewImage.rock
crewToStatue["rock_commando"] = statueCrewImage.rock
crewToStatue["rock_cultist"] = statueCrewImage.rock
crewToStatue["rock_crusader"] = statueCrewImage.rock
crewToStatue["rock_paladin"] = statueCrewImage.rock
crewToStatue["unique_ariadne"] = statueCrewImage.rock
crewToStatue["unique_tuco"] = statueCrewImage.rock
crewToStatue["unique_vortigon"] = statueCrewImage.rock
crewToStatue["unique_symbiote"] = statueCrewImage.rock
crewToStatue["rock_elder"] = statueCrewImage.rock
crewToStatue["unique_obyn"] = statueCrewImage.rock

crewToStatue["crystal"] = statueCrewImage.crystal
crewToStatue["crystal_liberator"] = statueCrewImage.crystal_liberator
crewToStatue["crystal_sentinel"] = statueCrewImage.crystal
crewToStatue["unique_ruwen"] = statueCrewImage.crystal
crewToStatue["unique_dianesh"] = statueCrewImage.crystal

crewToStatue["slug"] = statueCrewImage.slug
crewToStatue["slug_hektar"] = statueCrewImage.slug
crewToStatue["slug_clansman"] = statueCrewImage.slug
crewToStatue["slug_saboteur"] = statueCrewImage.slug
crewToStatue["slug_knight"] = statueCrewImage.slug
crewToStatue["slug_ranger"] = statueCrewImage.slug
crewToStatue["unique_nights"] = statueCrewImage.slug
crewToStatue["unique_slocknog"] = statueCrewImage.slug
crewToStatue["unique_sylvan"] = statueCrewImage.slug
crewToStatue["unique_irwin"] = statueCrewImage.slug
crewToStatue["unique_irwin_demon"] = statueCrewImage.slug
crewToStatue["unique_billy"] = statueCrewImage.slug

crewToStatue["leech"] = statueCrewImage.leech
crewToStatue["leech_ampere"] = statueCrewImage.leech
crewToStatue["unique_tyrdeo"] = statueCrewImage.leech
crewToStatue["unique_alkram"] = statueCrewImage.leech
crewToStatue["unique_tonysr"] = statueCrewImage.leech

crewToStatue["phantom"] = statueCrewImage.human
crewToStatue["phantom_goul"] = statueCrewImage.human
crewToStatue["phantom_mare"] = statueCrewImage.human
crewToStatue["phantom_wraith"] = statueCrewImage.human
crewToStatue["phantom_alpha"] = statueCrewImage.human
crewToStatue["phantom_goul_alpha"] = statueCrewImage.human
crewToStatue["phantom_mare_alpha"] = statueCrewImage.human
crewToStatue["phantom_wraith_alpha"] = statueCrewImage.human
crewToStatue["unique_dessius"] = statueCrewImage.human

crewToStatue["lanius"] = statueCrewImage.lanius
crewToStatue["lanius_augmented"] = statueCrewImage.lanius
crewToStatue["lanius_welder"] = statueCrewImage.lanius
crewToStatue["unique_eater"] = statueCrewImage.lanius
crewToStatue["unique_anointed"] = statueCrewImage.lanius

crewToStatue["spider"] = statueCrewImage.spider
crewToStatue["spider_weaver"] = statueCrewImage.spider
crewToStatue["spider_hatch"] = statueCrewImage.spider
crewToStatue["unique_queen"] = statueCrewImage.spider

crewToStatue["pony"] = statueCrewImage.pony
crewToStatue["pony_tamed"] = statueCrewImage.pony
crewToStatue["ponyc"] = statueCrewImage.pony
crewToStatue["pony_engi"] = statueCrewImage.pony
crewToStatue["pony_engi_nano"] = statueCrewImage.pony
crewToStatue["pony_engi_chaos"] = statueCrewImage.pony
crewToStatue["pony_engi_nano_chaos"] = statueCrewImage.pony

crewToStatue["lizard"] = statueCrewImage.lizard
crewToStatue["unique_guntput"] = statueCrewImage.lizard
crewToStatue["unique_metyunt"] = statueCrewImage.lizard

crewToStatue["cognitive"] = statueCrewImage.cognitive
crewToStatue["cognitive_automated"] = statueCrewImage.cognitive
crewToStatue["cognitive_advanced"] = statueCrewImage.cognitive
crewToStatue["cognitive_advanced_automated"] = statueCrewImage.cognitive

crewToStatue["obelisk"] = statueCrewImage.obelisk
crewToStatue["obelisk_royal"] = statueCrewImage.obelisk
crewToStatue["unique_wither"] = statueCrewImage.obelisk

local function statue_apply_crew(crewmem)
	userdata_table(crewmem, "mods.aea.statueCrew").statue = {base = crewmem.crewAnim.baseStrip, colour = crewmem.crewAnim.colorStrip, layers = {}}
	local i = 0
	for layer in vter(crewmem.crewAnim.layerStrips) do
		table.insert(userdata_table(crewmem, "mods.aea.statueCrew").statue.layers, layer)
		crewmem.crewAnim.layerStrips[i] = blankCrewImage
		i = i + 1
	end
	Hyperspace.playerVariables["aea_crew_statue_"..tostring(crewmem.extend.selfId)] = 1
	crewmem.crewAnim.baseStrip = crewToStatue[crewmem.type].base or statueCrewImage.human.base
	crewmem.crewAnim.colorStrip = crewToStatue[crewmem.type].colour or statueCrewImage.human.colour
end

script.on_internal_event(Defines.InternalEvents.CALCULATE_STAT_POST, function(crewmem, stat, def, amount, value)
	local crewTable = userdata_table(crewmem, "mods.aea.statueCrew")
	if crewTable.statue and petrifyStats[stat] then
		if petrifyStats[stat].amount then
			amount = petrifyStats[stat].amount
		elseif petrifyStats[stat].value == true or petrifyStats[stat].value == false then
			value = petrifyStats[stat].value
		end
	end
	return Defines.Chain.CONTINUE, amount, value
end)

local function statue_remove_crew(crewmem)
	--print("un-statue:"..crewmem.type)
	if userdata_table(crewmem, "mods.aea.statueCrew").statue then
		Hyperspace.playerVariables["aea_crew_statue_"..tostring(crewmem.extend.selfId)] = 0
		crewmem.crewAnim.baseStrip = userdata_table(crewmem, "mods.aea.statueCrew").statue.base
		crewmem.crewAnim.colorStrip = userdata_table(crewmem, "mods.aea.statueCrew").statue.colour
		for i, layer in ipairs(userdata_table(crewmem, "mods.aea.statueCrew").statue.layers) do
			crewmem.crewAnim.layerStrips[i-1] = layer
		end
		userdata_table(crewmem, "mods.aea.statueCrew").statue = nil
	end
end

local setCrew = false
script.on_init(function()
	setCrew = true
end)
script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
	if setCrew and Hyperspace.playerVariables.aea_test_variable == 1 then
		setCrew = false
		for crewmem in vter(Hyperspace.ships.player.vCrewList) do
			if Hyperspace.playerVariables["aea_crew_statue_"..tostring(crewmem.extend.selfId)] > 0 then
				statue_apply_crew(crewmem)
			end
		end
		if Hyperspace.ships.enemy then
			for crewmem in vter(Hyperspace.ships.enemy.vCrewList) do
				if Hyperspace.playerVariables["aea_crew_statue_"..tostring(crewmem.extend.selfId)] > 0 then
					statue_apply_crew(crewmem)
				end
			end
		end
	end
end)

script.on_game_event("ENTER_AEA_GODS", false, function()
	for crewmem in vter(Hyperspace.ships.player.vCrewList) do
		statue_apply_crew(crewmem)
	end
end)

script.on_game_event("AEA_GODS_CLEAR_1", false, function()
	local statueCrew = {}
	for crewmem in vter(Hyperspace.ships.player.vCrewList) do
		if userdata_table(crewmem, "mods.aea.statueCrew").statue then
			table.insert(statueCrew, crewmem)
		end
	end
	if #statueCrew > 0 then
		local random = math.random(#statueCrew)
		print("random:"..tostring(random))
		statue_remove_crew(statueCrew[random])
	end
end)
script.on_game_event("AEA_GODS_CLEAR_2", false, function()
	local statueCrew = {}
	for crewmem in vter(Hyperspace.ships.player.vCrewList) do
		if userdata_table(crewmem, "mods.aea.statueCrew").statue then
			table.insert(statueCrew, crewmem)
		end
	end
	if #statueCrew > 0 then
		local random = math.random(#statueCrew)
		print("random:"..tostring(random))
		statue_remove_crew(statueCrew[random])
	end
end)
script.on_game_event("AEA_GODS_CLEAR_3", false, function()
	for crewmem in vter(Hyperspace.ships.player.vCrewList) do
		statue_remove_crew(crewmem)
	end
end)