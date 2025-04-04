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

local cursorValid = Hyperspace.Resources:GetImageId("mouse/mouse_aea_ritual_valid.png")
local cursorValid2 = Hyperspace.Resources:GetImageId("mouse/mouse_aea_ritual_valid2.png")
local cursorRed = Hyperspace.Resources:GetImageId("mouse/mouse_aea_ritual_red.png")

local cursorDefault = Hyperspace.Resources:GetImageId("mouse/pointerValid.png")
local cursorDefault2 = Hyperspace.Resources:GetImageId("mouse/pointerInvalid.png")


local healBoost = Hyperspace.StatBoostDefinition()
healBoost.stat = Hyperspace.CrewStat.ACTIVE_HEAL_AMOUNT
healBoost.amount = 10
healBoost.duration = 5
healBoost.maxStacks = 1
healBoost.cloneClear = true
healBoost.boostType = Hyperspace.StatBoostDefinition.BoostType.FLAT
healBoost.boostSource = Hyperspace.StatBoostDefinition.BoostSource.AUGMENT
healBoost.shipTarget = Hyperspace.StatBoostDefinition.ShipTarget.ALL
healBoost.crewTarget = Hyperspace.StatBoostDefinition.CrewTarget.ALL
local function healRoom(shipManager, crewTarget)
	for crewmem in vter(shipManager.vCrewList) do
		if crewmem.iRoomId == crewTarget.iRoomId and crewmem.iShipId == 0 then
			Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(healBoost), crewmem)
		end
	end
end
local healShipBoost = Hyperspace.StatBoostDefinition()
healShipBoost.stat = Hyperspace.CrewStat.ACTIVE_HEAL_AMOUNT
healShipBoost.amount = 15
healShipBoost.duration = 10
healShipBoost.maxStacks = 1
healShipBoost.cloneClear = true
healShipBoost.boostType = Hyperspace.StatBoostDefinition.BoostType.FLAT
healShipBoost.boostSource = Hyperspace.StatBoostDefinition.BoostSource.AUGMENT
healShipBoost.shipTarget = Hyperspace.StatBoostDefinition.ShipTarget.ALL
healShipBoost.crewTarget = Hyperspace.StatBoostDefinition.CrewTarget.ALL
local function healShip(shipManager, crewTarget)
	for crewmem in vter(shipManager.vCrewList) do
		if crewmem.iShipId == 0 then
			Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(healShipBoost), crewmem)
		end
	end
end

mods.aea.crewToElite = {}
local crewToElite = mods.aea.crewToElite
crewToElite["human"] = "human_soldier"
crewToElite["human_engineer"] = "human_technician"
crewToElite["human_soldier"] = "human_mfk"
crewToElite["human_mfk"] = "human_legion"
crewToElite["engi"] = "engi_defender"
crewToElite["zoltan"] = "zoltan_peacekeeper"
crewToElite["zoltan_devotee"] = "zoltan_martyr"
crewToElite["mantis"] = "mantis_suzerain"
crewToElite["mantis_suzerain"] = "mantis_bishop"
crewToElite["mantis_free"] = "mantis_warlord"
crewToElite["rock"] = "rock_crusader"
crewToElite["rock_crusader"] = "rock_paladin"
crewToElite["crystal"] = "crystal_sentinel"
crewToElite["orchid"] = "orchid_praetor"
crewToElite["orchid_vampweed"] = "orchid_cultivator"
crewToElite["shell"] = "shell_radiant"
crewToElite["shell_guardian"] = "shell_radiant"
crewToElite["leech"] = "leech_ampere"
crewToElite["slug"] = "slug_saboteur"
crewToElite["slug_saboteur"] = "slug_knight"
crewToElite["slug_clansman"] = "slug_ranger"
crewToElite["lanius"] = "lanius_welder"
crewToElite["cognitive"] = "cognitive_advanced"
crewToElite["cognitive_automated"] = "cognitive_advanced_automated"
crewToElite["obelisk"] = "obelisk_royal"
crewToElite["phantom"] = "phantom_alpha"
crewToElite["phantom_goul"] = "phantom_goul_alpha"
crewToElite["phantom_mare"] = "phantom_mare_alpha"
crewToElite["phantom_wraith"] = "phantom_wraith_alpha"
crewToElite["spider_hatch"] = "spider"
crewToElite["spider"] = "spider_weaver"
crewToElite["pony"] = "ponyc"
crewToElite["pony_tamed"] = "ponyc"
crewToElite["beans"] = "sylvanrick"
crewToElite["siren"] = "siren_harpy"
crewToElite["aea_acid_soldier"] = "aea_acid_captain"
crewToElite["aea_necro_engi"] = "aea_necro_lich"
crewToElite["aea_bird_avali"] = "aea_bird_illuminant"
crewToElite["aea_cult_wizard"] = "aea_cult_priest_off"
crewToElite["aea_cult_wizard_a01"] = "aea_cult_priest_sup"
crewToElite["aea_cult_wizard_a02"] = "aea_cult_priest_sup"
crewToElite["aea_cult_wizard_s03"] = "aea_cult_priest_off"
crewToElite["aea_cult_wizard_s04"] = "aea_cult_priest_off"
crewToElite["aea_cult_wizard_s05"] = "aea_cult_priest_off"
crewToElite["aea_cult_wizard_s06"] = "aea_cult_priest_off"
crewToElite["aea_cult_wizard_a07"] = "aea_cult_priest_bor"
crewToElite["aea_cult_wizard_s08"] = "aea_cult_priest_bor"
crewToElite["aea_cult_wizard_s09"] = "aea_cult_priest_bor"
crewToElite["aea_cult_wizard_a10"] = "aea_cult_priest_bor"
crewToElite["aea_cult_wizard_a11"] = "aea_cult_priest_off"
crewToElite["aea_cult_wizard_s12"] = "aea_cult_priest_sup"
crewToElite["aea_cult_wizard_s13"] = "aea_cult_priest_off"
crewToElite["aea_cult_wizard_s14"] = "aea_cult_priest_bor"
function aeatest()
	for crewTarget in vter(Hyperspace.ships.player.vCrewList) do
		if crewToElite[crewTarget.type] then
			local transformRace = Hyperspace.StatBoostDefinition()
			transformRace.stat = Hyperspace.CrewStat.TRANSFORM_RACE
			transformRace.stringValue = crewToElite[crewTarget.type]
			transformRace.value = true
			transformRace.cloneClear = false
			transformRace.jumpClear = false
			transformRace.boostType = Hyperspace.StatBoostDefinition.BoostType.SET
			transformRace.boostSource = Hyperspace.StatBoostDefinition.BoostSource.AUGMENT
			transformRace.shipTarget = Hyperspace.StatBoostDefinition.ShipTarget.ALL
			transformRace.crewTarget = Hyperspace.StatBoostDefinition.CrewTarget.ALL
			Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(transformRace), crewTarget)
		end
	end
end
local function promoteCrew(shipManager, crewTarget)
	local transformRace = Hyperspace.StatBoostDefinition()
	transformRace.stat = Hyperspace.CrewStat.TRANSFORM_RACE
	transformRace.stringValue = crewToElite[crewTarget.type]
	transformRace.value = true
	transformRace.cloneClear = false
	transformRace.jumpClear = false
	transformRace.boostType = Hyperspace.StatBoostDefinition.BoostType.SET
	transformRace.boostSource = Hyperspace.StatBoostDefinition.BoostSource.AUGMENT
	transformRace.shipTarget = Hyperspace.StatBoostDefinition.ShipTarget.ALL
	transformRace.crewTarget = Hyperspace.StatBoostDefinition.CrewTarget.ALL
	Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(transformRace), crewTarget)
end
local function promoteCond(shipManager, crewTarget)
	if crewToElite[crewTarget.type] and ((not crewTarget.extend.deathTimer) or not crewTarget.extend.deathTimer:Running()) then
		return true
	end
	return false
end
local function test1(shipManager, crewmem)
	print("TEST 1")
end
local function test2(shipManager, crewmem)
	print("TEST 2")
end

local spellList = {
	heal_room = {func = healRoom, positionList = {} },
	heal_ship = {func = healShip, positionList = {{x = 0, y = 2}, {x = 1, y = -1}} },
	promote = {func = promoteCrew, excludeTarget = true, cond = promoteCond, positionList = {{x = 0, y = -2}, {x = 1, y = 4}, {x = -3, y = -3}, {x = 4, y = 0}, {x = -3, y = 3}} }
}


local sacList = {}
local orderList = {}
local targetShip = 0
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
		if #orderList <= 0 then
			if combatControl.selectedSelfRoom < 0 and combatControl.selectedRoom < 0 then return Defines.Chain.CONTINUE end
	        if combatControl.selectedSelfRoom >= 0 then
	        	shipManager = Hyperspace.ships.player
	            targetShip = 0
	            --print("ship player")
	        elseif combatControl.selectedRoom >= 0 then
	        	shipManager = Hyperspace.ships.enemy
	            targetShip = 1
	            --print("ship enemy")
	        end
	    else
	    	shipManager = Hyperspace.ships(targetShip)
	    end
        for crewmem in vter(shipManager.vCrewList) do
        	local location = crewmem:GetLocation()
        	local mousePos = Hyperspace.Mouse.position
        	local mousePosRelative = worldToPlayerLocation(mousePos)
        	if targetShip == 1 then
        		mousePosRelative = worldToEnemyLocation(mousePos)
        	end
        	--print("mouse x:"..mousePosRelative.x.." y:"..mousePosRelative.y.." crew "..crewmem.type.." x:"..location.x.." y:"..location.y)
        	if crewmem.iShipId == 0 and get_distance(mousePosRelative, location) <= 17 and crewmem:AtGoal() and not sacList[crewmem.extend.selfId] then
        		local slotX = math.floor((crewmem.currentSlot.worldLocation.x - 17)/35)
        		local slotY = math.floor((crewmem.currentSlot.worldLocation.y - 17)/35)
	            --print("slot x:"..slotX.." y:"..slotY)
        		sacList[crewmem.extend.selfId] = {room = crewmem.iRoomId, slot = crewmem.currentSlot.slotId, x = slotX, y = slotY}
        		table.insert(orderList, crewmem)
        		break
        	elseif get_distance(mousePosRelative, location) <= 17 and sacList[crewmem.extend.selfId] then
        		sacList[crewmem.extend.selfId] = nil
        		break
        	end
        end
	end 
	return Defines.Chain.CONTINUE
end)

local bloodStain = {
	Hyperspace.Resources:CreateImagePrimitiveString("effects/aea_blood_stain_1.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false),
	Hyperspace.Resources:CreateImagePrimitiveString("effects/aea_blood_stain_2.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false),
	Hyperspace.Resources:CreateImagePrimitiveString("effects/aea_blood_stain_3.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false),
	Hyperspace.Resources:CreateImagePrimitiveString("effects/aea_blood_stain_4.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false)
}
local bloodStainList = {[0] = {}, [1] = {}}
script.on_render_event(Defines.RenderEvents.SHIP_FLOOR, function() end, function(shipManager)
	local list = bloodStainList[shipManager.iShipId]
	for i, bloodTable in ipairs(list) do
		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(bloodTable.x, bloodTable.y, 0)
		Graphics.CSurface.GL_RenderPrimitive(bloodStain[bloodTable.state])
		Graphics.CSurface.GL_PopMatrix()
	end
end)

local ritualStart = Hyperspace.Resources:CreateImagePrimitiveString("effects/aea_ritual_start.png", -17, -17, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false)
local ritual = Hyperspace.Resources:CreateImagePrimitiveString("effects/aea_ritual.png", -17, -17, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false)

local lastValid = false
local currentValidSpell = nil
script.on_render_event(Defines.RenderEvents.SHIP, function() end, function(shipManager)
	if activateCursor and shipManager.iShipId == targetShip then
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
		local crewTarget = nil
		for i, crewmem in ipairs(orderList) do
			if sacList[crewmem.extend.selfId] then
				if crewCount == 0 then
					crewTarget = crewmem
				end
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
			   					--print("spell fail pos:"..spell.." count:"..crewCount)
			   				end
			   			elseif validSpells[spell] then
			   				validSpells[spell] = nil
		   					--print("spell fail count:"..spell.." count:"..crewCount)
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
   					--print("spell fail low count:"..spell.." count:"..crewCount)
					validSpells[spell] = nil
				elseif validSpells[spell] then
					if spellTable.cond then
						if spellTable.cond(shipManager, crewTarget) then
							validSpell = spell
						else
							--print("cond fail")
							validSpells[spell] = nil
						end
					else
						validSpell = spell
					end
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
	    orderList = {}
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
	    if currentValidSpell and orderList[1] then
	    	spellList[currentValidSpell].func(Hyperspace.ships(targetShip), orderList[1])
	    	for i, crewmem in ipairs(orderList) do
	    		if not spellList[currentValidSpell].excludeTarget or i > 1 then
	    			crewmem:DirectModifyHealth(-150)
	    			local x = crewmem.currentSlot.worldLocation.x + math.random(-17, 6)
	    			local y = crewmem.currentSlot.worldLocation.y + math.random(-17, 6)
	    			local random = math.random(1,4)
	    			table.insert(bloodStainList[targetShip], {x = x, y = y, state = random})
	    		end
	    	end
	    else
	    	for crewmem in vter(Hyperspace.ships.player.vCrewList) do
				if crewmem.type == "aea_dark_justicier" then
					for power in vter(crewmem.extend.crewPowers) do
						power:CancelPower(true)
						power.powerCooldown.first = power.powerCooldown.second - 0.1
					end
				end
			end
	    end
	    sacList = {}
	    orderList = {}
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