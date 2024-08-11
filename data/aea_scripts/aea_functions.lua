mods.aea = {}

-----------------------
-- UTILITY FUNCTIONS --
-----------------------

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
    local position = 0--combatControl.position -- not exposed yet
    local targetPosition = combatControl.targetPosition
    local enemyShipOriginX = position.x + targetPosition.x
    local enemyShipOriginY = position.y + targetPosition.y
    return Hyperspace.Point(mousePosition.x - enemyShipOriginX, mousePosition.y - enemyShipOriginY)
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
        check_for_room(roomShape.x - 17,               roomShape.y + offset + 17)
        check_for_room(roomShape.x + roomShape.w + 17, roomShape.y + offset + 17)
    end
    if diagonals then
        check_for_room(roomShape.x - 17,               roomShape.y - 17)
        check_for_room(roomShape.x + roomShape.w + 17, roomShape.y - 17)
        check_for_room(roomShape.x + roomShape.w + 17, roomShape.y + roomShape.h + 17)
        check_for_room(roomShape.x - 17,               roomShape.y + roomShape.h + 17)
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

function round(num, numDecimalPlaces)
  local mult = 10^(numDecimalPlaces or 0)
  return math.floor(num * mult + 0.5) / mult
end
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
	if weapon.blueprint then
	    if weapon.blueprint.name == "AEA_LASER_ACID_SUPER" or weapon.blueprint.name == "AEA_LASER_ACID_SUPER_ENEMY" then
	    	local shipManager = Hyperspace.ships(1-projectile.ownerId)
	        for system in vter(shipManager.vSystemList) do
	            local roomId = system.roomId
	            local roomLoc = shipManager:GetRoomCenter(roomId)

	        	local spaceManager = Hyperspace.Global.GetInstance():GetCApp().world.space
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
    --print(string.sub(event.eventName, 0, 13))
    if string.sub(event.eventName, 0, string.len(eventString)) == eventString and Hyperspace.playerVariables[playerVar] == 0 then
        Hyperspace.playerVariables[playerVar] = 1
		initialPosX = (math.random() * 131072) % 131 - 65
		initialPosY = (math.random() * 131072) % 81 - 40
    end
end)

script.on_internal_event(Defines.InternalEvents.JUMP_ARRIVE, function(shipManager)
    Hyperspace.playerVariables[playerVar] = 0
end)

--[[script.on_init(function()
	if Hyperspace.playerVariables[playerVar] == 1 then
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
	if Hyperspace.Global.GetInstance():GetCApp().world.bStartedGame and Hyperspace.playerVariables[playerVar] == 1 and Hyperspace.Settings.lowend == false then
		--log("startLoop")
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

		        --[[if (commandGui.bPaused or commandGui.event_pause) then
		        	Graphics.CSurface.GL_SetColor(Graphics.GL_Color(0.5, 0.5, 0.5, 1))
		        end]]

		        Graphics.CSurface.GL_RenderPrimitive(cloudImageTemp)
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


--[[script.on_render_event(Defines.RenderEvents.LAYER_BACKGROUND, function()
    if Hyperspace.Global.GetInstance():GetCApp().world.bStartedGame then
    	if true then
            Graphics.CSurface.GL_PushMatrix()
            Graphics.CSurface.GL_SetColorTint(Graphics.GL_Color(1, 0, 0, 1))
        end
    end
end, function()
    if Hyperspace.Global.GetInstance():GetCApp().world.bStartedGame then
    	if true then
            Graphics.CSurface.GL_PopMatrix()
        end
    end
end)]]


--[[script.on_render_event(Defines.RenderEvents.LAYER_FOREGROUND, function()
    if Hyperspace.Global.GetInstance():GetCApp().world.bStartedGame then
    	if true then
            Graphics.CSurface.GL_PushMatrix()
            Graphics.CSurface.GL_SetColorTint(Graphics.GL_Color(0, 0, 1, 1))
        end
    end
end, function()
    if Hyperspace.Global.GetInstance():GetCApp().world.bStartedGame then
    	if true then
            Graphics.CSurface.GL_PopMatrix()
        end
    end
end)]]
