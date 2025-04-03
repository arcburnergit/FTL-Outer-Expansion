local function vter(cvec)
	local i = -1
	local n = cvec:size()
	return function()
		i = i + 1
		if i < n then return cvec[i] end
	end
end

local function get_distance(point1, point2)
	return math.sqrt(((point2.x - point1.x)^ 2)+((point2.y - point1.y) ^ 2))
end

local function worldToPlayerLocation(location)
	local cApp = Hyperspace.Global.GetInstance():GetCApp()
	local combatControl = cApp.gui.combatControl
	local playerPosition = combatControl.playerShipPosition
	return Hyperspace.Point(location.x - playerPosition.x, location.y - playerPosition.y)
end

local cursorValid = Hyperspace.Resources:GetImageId("mouse/mouse_aea_ritual_valid.png")
local cursorValid2 = Hyperspace.Resources:GetImageId("mouse/mouse_aea_ritual_valid2.png")
local cursorRed = Hyperspace.Resources:GetImageId("mouse/mouse_aea_ritual_red.png")

local cursorDefault = Hyperspace.Resources:GetImageId("mouse/pointerValid.png")
local cursorDefault2 = Hyperspace.Resources:GetImageId("mouse/pointerInvalid.png")

local function test1()
	print("TEST 1")
end
local function test2()
	print("TEST 2")
end

local spellList = {
	test1 = {func = test1, positionList = {{x = 0, y = 1}} },
	test2 = {func = test2, positionList = {{x = 0, y = 1}, {x = 1, y = 1}} }
}


local sacList = {}
local orderList = {}
local activateCursor = false

script.on_internal_event(Defines.InternalEvents.ACTIVATE_POWER, function(power, shipManager)
	local crewmem = power.crew
	if crewmem.type == "aea_dark_justicier" then
		activateCursor = true
        Hyperspace.Mouse.validPointer = cursorValid
        Hyperspace.Mouse.invalidPointer = cursorValid2
	end
	return Defines.Chain.CONTINUE
end)

script.on_internal_event(Defines.InternalEvents.ON_MOUSE_L_BUTTON_DOWN, function(x,y)
	if activateCursor and Hyperspace.ships.player then
		local combatControl = Hyperspace.App.gui.combatControl
		local shipManager = Hyperspace.ships.player
        for crewmem in vter(shipManager.vCrewList) do
        	local location = crewmem:GetLocation()
        	local mousePos = Hyperspace.Mouse.position
        	local mousePosRelative = worldToPlayerLocation(mousePos)
        	if get_distance(mousePosRelative, location) <= 17 and crewmem:AtGoal() and not sacList[crewmem.extend.selfId] then
        		local slotX = math.floor((crewmem.currentSlot.worldLocation.x - 17)/35)
        		local slotY = math.floor((crewmem.currentSlot.worldLocation.y - 17)/35)
        		sacList[crewmem.extend.selfId] = {room = crewmem.iRoomId, slot = crewmem.currentSlot.slotId, x = slotX, y = slotY}
        		table.insert(orderList, crewmem)
        		break
        	elseif get_distance(mousePosRelative, location) <= 17 and sacList[crewmem.extend.selfId] then
        		sacList[crewmem.extend.selfId] = nil
        		break
        	end
        end
	end 
end)

local ritualStart = Hyperspace.Resources:CreateImagePrimitiveString("effects/aea_ritual_start.png", -17, -17, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false)
local ritual = Hyperspace.Resources:CreateImagePrimitiveString("effects/aea_ritual.png", -17, -17, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false)

local lastValid = false
local currentValidSpell = nil
script.on_render_event(Defines.RenderEvents.SHIP, function() end, function()
	if activateCursor then
		local lastX = nil
		local lastY = nil
		local lastRoomX = nil
		local lastRoomY = nil
		local removeI = nil
		local validSpells = {}
		for spell, pos in pairs(spellList) do
			validSpells[spell] = true
		end
		local crewCount = 0
		for i, crewmem in ipairs(orderList) do
			if sacList[crewmem.extend.selfId] then
				crewCount = crewCount + 1
				local location = crewmem:GetLocation()
				local colour = 0.5
				if lastValid then colour = 1 end
				if lastX and lastY then
	   				Graphics.CSurface.GL_DrawLine(lastX+1, lastY+1, location.x+1, location.y+1, 5, Graphics.GL_Color(colour, 0, 0, 0.4))
	   				Graphics.CSurface.GL_DrawLine(lastX+1, lastY+1, location.x+1, location.y+1, 3, Graphics.GL_Color(colour, 0, 0, 0.6))
	   				Graphics.CSurface.GL_PushMatrix()
					Graphics.CSurface.GL_Translate(location.x, location.y, 0)
					Graphics.CSurface.GL_RenderPrimitiveWithColor(ritual, Graphics.GL_Color(colour, 0, 0, 0.8))
					Graphics.CSurface.GL_PopMatrix()
	   			else
	   				Graphics.CSurface.GL_PushMatrix()
					Graphics.CSurface.GL_Translate(location.x, location.y, 0)
					Graphics.CSurface.GL_RenderPrimitiveWithColor(ritualStart, Graphics.GL_Color(colour, 0, 0, 0.8))
					Graphics.CSurface.GL_PopMatrix()
	   			end
	   			lastX = location.x
	   			lastY = location.y
	   			local sacTable = sacList[crewmem.extend.selfId] 
	   			local roomX = sacTable.x
	   			local roomY = sacTable.y
	   			if lastRoomX and lastRoomY then
		   			for spell, spellTable in pairs(spellList) do
		   				local positionOffset = spellTable.positionList[crewCount - 1]
		   				if validSpells[spell] and positionOffset then
			   				if roomX - lastRoomX ~= positionOffset.x or roomY - lastRoomY ~= positionOffset.y then
			   					validSpells[spell] = nil
			   				end
			   			elseif validSpells[spell] then
			   				validSpells[spell] = nil
			   			end
		   			end
		   		end
	   			lastRoomX = roomX
	   			lastRoomY = roomY
	   		else
	   			removeI = i
			end
		end
		if removeI then
			table.remove(orderList, removeI)
		end

		local validSpell = nil
		if crewCount > 0 then
			for spell, spellTable in pairs(spellList) do
				--local positionOffset = spellTable.positionList[crewCount]
				if validSpells[spell] and spellTable.positionList[crewCount] then
					validSpells[spell] = nil
				elseif validSpells[spell] then
					validSpell = spell
				end
			end
		end
		local nowValid = false
		if validSpell then
			nowValid = true
			currentValidSpell = validSpell
		else
			currentValidSpell = nil
		end

		if nowValid ~= lastValid and nowValid == true then
        	Hyperspace.Mouse.validPointer = cursorRed
        	Hyperspace.Mouse.invalidPointer = cursorRed
		elseif nowValid ~= lastValid then
        	Hyperspace.Mouse.validPointer = cursorValid
        	Hyperspace.Mouse.invalidPointer = cursorValid2
		end

		lastValid = nowValid
	end
end)

script.on_internal_event(Defines.InternalEvents.CREW_LOOP, function(crewmem)
	if activateCursor and sacList[crewmem.extend.selfId] then
		local crewTable = sacList[crewmem.extend.selfId]
		crewmem:SetRoomPath(crewTable.slot, crewTable.room)
	elseif activateCursor and crewmem.type == "aea_dark_justicier" then
		--[[for power in vter(crewmem.extend.crewPowers) do
			power.temporaryPowerDuration.first = power.temporaryPowerDuration.second
		end]]
	end
end)

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	if activateCursor then
		for crewmem in vter(shipManager.vCrewList) do
			if crewmem.type == "aea_dark_justicier" then
				for power in vter(crewmem.extend.crewPowers) do
					power.temporaryPowerDuration.first = power.temporaryPowerDuration.second
				end
			end
		end
	end
end)

script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
	local commandGui = Hyperspace.App.gui
	if activateCursor and (commandGui.event_pause or commandGui.menu_pause) then
		activateCursor = false
	    Hyperspace.Mouse.validPointer = cursorDefault
	    Hyperspace.Mouse.invalidPointer = cursorDefault2
	    sacList = {}
	    for crewmem in vter(Hyperspace.ships.player.vCrewList) do
			if crewmem.type == "aea_dark_justicier" then
				for power in vter(crewmem.extend.crewPowers) do
					power:CancelPower(true)
					power.powerCooldown.first = power.powerCooldown.second - 0.1
				end
			end
		end
	end
end)

script.on_internal_event(Defines.InternalEvents.ON_MOUSE_R_BUTTON_DOWN, function(x,y) 
	if activateCursor then
		activateCursor = false
	    Hyperspace.Mouse.validPointer = cursorDefault
	    Hyperspace.Mouse.invalidPointer = cursorDefault2
	    sacList = {}
	    if currentValidSpell then
	    	spellList[currentValidSpell].func()
	    end
	end
end)

--[[local vter = mods.multiverse.vter

local huskList = {}
huskList["ddsoulplague_husk_human"] = true
huskList["ddsoulplague_husk_crystal"] = true
huskList["ddsoulplague_husk_engi"] = true
huskList["ddsoulplague_husk_zoltan"] = true
huskList["ddsoulplague_husk_orchid"] = true
huskList["ddsoulplague_husk_mantis"] = true
huskList["ddsoulplague_husk_rockman"] = true
huskList["ddsoulplague_husk_slug"] = true
huskList["ddsoulplague_husk_shell"] = true
huskList["ddsoulplague_husk_lanius"] = true
huskList["ddsoulplague_husk_deepone"] = true
huskList["ddsoulplague_husk_ghost"] = true
huskList["ddsoulplague_husk_leech"] = true
huskList["ddsoulplague_husk_obelisk"] = true

script.on_internal_event(Defines.InternalEvents.HAS_EQUIPMENT, function(shipManager, equipment, value)
	if huskList[equipment] and shipManager.iShipId == 0 then
		local count = 0
		for crewmem in vter(Hyperspace.ships.player) do
			if crewmem.type == equipment then
				count = count + 1
			end
		end
		return Defines.Chain.CONTINUE, count
	end
	return Defines.Chain.CONTINUE, value
end)]]