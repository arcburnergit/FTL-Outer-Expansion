local function get_room_at_location(shipManager, location, includeWalls)
	return Hyperspace.ShipGraph.GetShipInfo(shipManager.iShipId):GetSelectedRoom(location.x, location.y, includeWalls)
end
local get_adjacent_rooms = mods.multiverse.get_adjacent_rooms

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

local systemIdName = "aea_grease"
local systemChargesVariable = "aea_grease_charges"
local systemFillingAmount = {[0] = 0, [1] = 0}
local systemTypeVariable = "aea_grease_type"

local greaseEffects = {
	{name = "Fire", type = 1, colour = Graphics.GL_Color(253/255, 84/255, 70/255, 1), fill_rate = 0.05, desc = "Causes the last projectile in the volley to start a fire on hit."},
	{name = "Frost", type = 1, colour = Graphics.GL_Color(171/255, 201/255, 202/255, 1), fill_rate = 0.033, desc = "Causes the last projectile in the volley to create a short lockdown on hit."},
	{name = "Breach", type = 1, colour = Graphics.GL_Color(138/255, 150/255, 125/255, 1), fill_rate = 0.05, desc = "Causes the last projectile in the volley to open a breach on hit."},
	{name = "Shock", req="AEA_GREASE_EFFECT_SHOCK", type = 1, colour = Graphics.GL_Color(95/255, 205/255, 228/255, 1), fill_rate = 0.125, desc = "Causes the last projectile in the volley to break and stun all doors in the room."},
	{name = "Shatter", req="AEA_GREASE_EFFECT_SHATTER", type = 1, colour = Graphics.GL_Color(126/255, 174/255, 173/255, 1), fill_rate = 0.05, desc = "Causes the last projectile in the volley to create an extremely weak lockdown, the next hit to this room while the lockdown is active will do 2x damage."},
	{name = "Acidic", req="AEA_GREASE_EFFECT_ACID", type = 1, colour = Graphics.GL_Color(111/255, 236/255, 95/255, 1), fill_rate = 0.05, desc = "Causes the last projectile in the volley to create acidic that erodes the system on hit."},
	{name = "Inculcation", req="AEA_GREASE_EFFECT_SHLEG", type = 1, colour = Graphics.GL_Color(159/255, 228/255, 204/255, 1), fill_rate = 0.025, desc = "Causes the last projectile in the volley to create inculcation gas on hit."},
	{name = "Marked", req="AEA_GREASE_EFFECT_BIRD", type = 1, colour = Graphics.GL_Color(211/255, 133/255, 255/255, 1), fill_rate = 0.025, desc = "Causes the last projectile in the volley to target all friendly drones on hit."},
	{name = "Resurrection", req="AEA_GREASE_EFFECT_NECRO", type = 2, colour = Graphics.GL_Color(255/255, 201/255, 63/255, 1), fill_rate = 0.025, desc = "When a projectile kills a crewmember, temporarily resurrect that crewmember on your side."},
	{name = "Cascade", req="AEA_GREASE_EFFECT_CASCADE", type = 2, colour = Graphics.GL_Color(182/255, 182/255, 182/255, 1), fill_rate = 0.075, desc = "When a projectile full breaks a system, deal system damage to an adjacent room."},
}
greaseEffects[0] = {name = "PLACEHOLDER", type = 1, colour = Graphics.GL_Color(255/255, 255/255, 255/255, 1), fill_rate = 0.1, desc = "PLACEHOLDER"}

effectImages = {}
effectImages["PLACEHOLDER"] = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/aea_grease_icon_fire.png" , 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
effectImages["Fire"] = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/aea_grease_icon_fire.png" , 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
effectImages["Frost"] = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/aea_grease_icon_frost.png" , 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
effectImages["Breach"] = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/aea_grease_icon_breach.png" , 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
effectImages["Shock"] = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/aea_grease_icon_shock.png" , 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
effectImages["Shatter"] = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/aea_grease_icon_lockdown.png" , 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
effectImages["Acidic"] = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/aea_grease_icon_acid.png" , 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
effectImages["Inculcation"] = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/aea_grease_icon_inculcation.png" , 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
effectImages["Marked"] = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/aea_grease_icon_marked.png" , 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
effectImages["Resurrection"] = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/aea_grease_icon_resurrect.png" , 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
effectImages["Cascade"] = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/aea_grease_icon_cascade.png" , 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)

--Handles tooltips and mousever descriptions per level
local function get_level_description_grease(systemId, level, tooltip)
	if systemId == Hyperspace.ShipSystem.NameToSystemId(systemIdName) then
		return string.format("%i charges", level)
	end
end

script.on_internal_event(Defines.InternalEvents.GET_LEVEL_DESCRIPTION, get_level_description_grease)

--Utility function to check if the SystemBox instance is for our customs system
local function is_grease(systemBox)
	local systemName = Hyperspace.ShipSystem.SystemIdToName(systemBox.pSystem.iSystemType)
	return systemName == systemIdName and systemBox.bPlayerUI
end

--Utility function to check if the SystemBox instance is for our customs system
local function is_grease_enemy(systemBox)
	local systemName = Hyperspace.ShipSystem.SystemIdToName(systemBox.pSystem.iSystemType)
	return systemName == systemIdName and not systemBox.bPlayerUI
end
 
--Offsets of the button
local greaseButtonOffset_x = 37
local greaseButtonOffset_y = -50

--Handles initialization of custom system box
local function grease_construct_system_box(systemBox)
	if is_grease(systemBox) then
		systemBox.extend.xOffset = 54

		local greaseButton = Hyperspace.Button()
		greaseButton:OnInit("systemUI/button_aea_grease", Hyperspace.Point(greaseButtonOffset_x, greaseButtonOffset_y))
		greaseButton.hitbox.x = 10
		greaseButton.hitbox.y = 47
		greaseButton.hitbox.w = 20
		greaseButton.hitbox.h = 19
		systemBox.table.greaseButton = greaseButton

		local effectButtonTable = {}
		for i = 1, #greaseEffects do
			local effectButton = Hyperspace.Button()
			effectButton:OnInit("systemUI/aea_grease_box_button_blank", Hyperspace.Point(0, 0))
			effectButton.hitbox.x = 0
			effectButton.hitbox.y = 0
			effectButton.hitbox.w = 22
			effectButton.hitbox.h = 22
			table.insert(effectButtonTable, {b = effectButton, position = {x = 0, y = 0}})
		end
		systemBox.table.effectButtonTable = effectButtonTable

		systemBox.pSystem.bNeedsPower = false
		systemBox.pSystem.bBoostable = false -- make the system unmannable
	elseif is_grease_enemy(systemBox) then
		systemBox.pSystem.bNeedsPower = false
		systemBox.pSystem.bBoostable = false
	end
end

script.on_internal_event(Defines.InternalEvents.CONSTRUCT_SYSTEM_BOX, grease_construct_system_box)

--Handles mouse movement
local function grease_mouse_move(systemBox, x, y)
	if is_grease(systemBox) then
		local greaseButton = systemBox.table.greaseButton
		greaseButton:MouseMove(x - greaseButtonOffset_x, y - greaseButtonOffset_y, false)
		local effectButtonTable = systemBox.table.effectButtonTable
		for _, effectButton in ipairs(effectButtonTable) do
			effectButton.b:MouseMove(x - effectButton.position.x, y - effectButton.position.y, false)
		end
	end
	return Defines.Chain.CONTINUE
end
script.on_internal_event(Defines.InternalEvents.SYSTEM_BOX_MOUSE_MOVE, grease_mouse_move)

---@param shipManager Hyperspace.ShipManager The ship to check for super shield.
---@return boolean hasSuperShield If the ship has any super shield layers up.
local function has_super_shield(shipManager)
   return shipManager.shieldSystem ~= nil and shipManager.shieldSystem.shields.power.super.first > 0
end

local displayGreaseOptions = false
--Handles click events 
local function grease_click(systemBox, shift)
	if is_grease(systemBox) then
		local greaseButton = systemBox.table.greaseButton
		if greaseButton.bHover and greaseButton.bActive then
			displayGreaseOptions = not displayGreaseOptions
		end
		local effectButtonTable = systemBox.table.effectButtonTable
		for i, effectButton in ipairs(effectButtonTable) do
			if effectButton.b.bHover and effectButton.b.bActive then
				print("set type:"..i)
				Hyperspace.playerVariables[systemTypeVariable] = i
				Hyperspace.playerVariables[systemChargesVariable] = 0
				systemFillingAmount[0] = 0
			end
		end
	end
	return Defines.Chain.CONTINUE
end
script.on_internal_event(Defines.InternalEvents.SYSTEM_BOX_MOUSE_CLICK, grease_click)

local greaseImages = {
	[1] = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/aea_grease_1_base.png" , 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	[2] = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/aea_grease_2_base.png" , 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	[3] = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/aea_grease_3_base.png" , 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	gauge_outline = {
		on = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/aea_grease_gauge_outer_on.png" , 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
		off = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/aea_grease_gauge_outer_off.png" , 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
		full = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/aea_grease_gauge_outer_full.png" , 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
	},
	gauge = {
		filling = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/aea_grease_gauge_filling.png" , 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
		full = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/aea_grease_gauge_full.png" , 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	}

}

local boxImages = {
	arrow = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/aea_grease_box_arrow.png" , -7, 3, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	top = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/aea_grease_box_top.png" , 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	bottom = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/aea_grease_box_bottom.png" , 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	left = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/aea_grease_box_left.png" , 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	right = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/aea_grease_box_right.png" , 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	top_left = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/aea_grease_box_top_left.png" , 4, 4, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	top_right = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/aea_grease_box_top_right.png" , 0, 4, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	bottom_left = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/aea_grease_box_bottom_left.png" , 4, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	bottom_right = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/aea_grease_box_bottom_right.png" , 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	middle = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/aea_grease_box_middle.png" , 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
}

local tempBoxImage = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/aea_grease_box_button_blank_off.png" , 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)

local maxButtonWidth = 4
local boxButton_w = 22
local boxButton_h = 22
local function renderGreaseOptions(originPos_x, originPos_y, effectButtonTable)
	Graphics.CSurface.GL_PushMatrix()
	Graphics.CSurface.GL_Translate(originPos_x, originPos_y, 0)

	local activeEffectButtons = {}
	for i, effectButton in ipairs(effectButtonTable) do
		local currentEffect = greaseEffects[i]
		if (currentEffect.req and Hyperspace.ships.player:HasEquipment(currentEffect.req) > 0) or not currentEffect.req then
			table.insert(activeEffectButtons, effectButton)
			effectButton.b.bActive = true
		else
			effectButton.b.bActive = false
		end
	end
	local boxNumber = #activeEffectButtons

	local boxWidthNumber = math.min(maxButtonWidth, boxNumber)
	local boxHeightNumber = math.ceil(boxNumber/maxButtonWidth)
	local boxWidth = boxButton_w * boxWidthNumber
	local boxHeight = boxButton_h * boxHeightNumber
	Graphics.CSurface.GL_PushMatrix()
	Graphics.CSurface.GL_Translate(-0.5 * boxWidth, -1 * boxHeight, 0)

	--Render Corners
	Graphics.CSurface.GL_PushMatrix()
	Graphics.CSurface.GL_Translate(-(boxButton_w/2), -(boxButton_h/2), 0)
	Graphics.CSurface.GL_RenderPrimitive(boxImages.top_left)
	Graphics.CSurface.GL_PopMatrix()
	Graphics.CSurface.GL_PushMatrix()
	Graphics.CSurface.GL_Translate(boxWidth-(boxButton_w/2), -(boxButton_h/2), 0)
	Graphics.CSurface.GL_RenderPrimitive(boxImages.top_right)
	Graphics.CSurface.GL_PopMatrix()
	Graphics.CSurface.GL_PushMatrix()
	Graphics.CSurface.GL_Translate(-(boxButton_w/2), boxHeight-(boxButton_h/2), 0)
	Graphics.CSurface.GL_RenderPrimitive(boxImages.bottom_left)
	Graphics.CSurface.GL_PopMatrix()
	Graphics.CSurface.GL_PushMatrix()
	Graphics.CSurface.GL_Translate(boxWidth-(boxButton_w/2), boxHeight-(boxButton_h/2), 0)
	Graphics.CSurface.GL_RenderPrimitive(boxImages.bottom_right)
	Graphics.CSurface.GL_PopMatrix()

	if boxWidthNumber > 1 then
		for n = 1, boxWidthNumber - 1 do
			Graphics.CSurface.GL_PushMatrix()
			Graphics.CSurface.GL_Translate(-(boxButton_w/2)+boxButton_w*n, -(boxButton_h/2), 0)
			Graphics.CSurface.GL_RenderPrimitive(boxImages.top)
			Graphics.CSurface.GL_PopMatrix()
			Graphics.CSurface.GL_PushMatrix()
			Graphics.CSurface.GL_Translate(-(boxButton_w/2)+boxButton_w*n, boxHeight-(boxButton_h/2), 0)
			Graphics.CSurface.GL_RenderPrimitive(boxImages.bottom)
			Graphics.CSurface.GL_PopMatrix()
			if boxHeightNumber > 1 then
				for m = 1, boxHeightNumber - 1 do
					Graphics.CSurface.GL_PushMatrix()
					Graphics.CSurface.GL_Translate(-(boxButton_w/2)+boxButton_w*n, -(boxButton_h/2)+boxButton_h*m, 0)
					Graphics.CSurface.GL_RenderPrimitive(boxImages.middle)
					Graphics.CSurface.GL_PopMatrix()
				end
			end
		end
	end
	if boxHeightNumber > 1 then
		for m = 1, boxHeightNumber - 1 do
			Graphics.CSurface.GL_PushMatrix()
			Graphics.CSurface.GL_Translate(-(boxButton_w/2), -(boxButton_h/2)+boxButton_h*m, 0)
			Graphics.CSurface.GL_RenderPrimitive(boxImages.left)
			Graphics.CSurface.GL_PopMatrix()
			Graphics.CSurface.GL_PushMatrix()
			Graphics.CSurface.GL_Translate(boxWidth-(boxButton_w/2), -(boxButton_h/2)+boxButton_h*m, 0)
			Graphics.CSurface.GL_RenderPrimitive(boxImages.right)
			Graphics.CSurface.GL_PopMatrix()
		end
	end

	Graphics.CSurface.GL_PopMatrix()
	Graphics.CSurface.GL_RenderPrimitive(boxImages.arrow)
	Graphics.CSurface.GL_PopMatrix()
	for i = 1, boxNumber do
		if activeEffectButtons[i] then
			effectButton = activeEffectButtons[i]
			local buttonX = originPos_x - 0.5 * boxWidth + ((i - 1) % maxButtonWidth) * boxButton_w
			local buttonY = originPos_y - 1 * boxHeight + math.floor((i - 1) / maxButtonWidth) * boxButton_h
			effectButton.position = {x = buttonX, y = buttonY}
			Graphics.CSurface.GL_PushMatrix()
			Graphics.CSurface.GL_Translate(effectButton.position.x, effectButton.position.y, 0)
			effectButton.b:OnRender()
			local effect = greaseEffects[i]
			local effectImage = effectImages[effect.name]
			Graphics.CSurface.GL_RenderPrimitive(effectImage)
			Graphics.CSurface.GL_PopMatrix()
			if effectButton.b.bHover then
				Hyperspace.Mouse.tooltip = effect.name.." ("..math.floor(1/effect.fill_rate).."s): "..effect.desc
			end
		end
	end
end

--Utility function to see if the system is ready for use
local function grease_ready(shipSystem)
   return not (shipSystem:GetLocked() and shipSystem.iLockCount ~= -1) and shipSystem:Functioning() and shipSystem.iHackEffect <= 1
end
--Utility function to see if the system is ready for use
local function grease_ready_enemy(shipSystem)
   local shield_blocking = has_super_shield(Hyperspace.ships.player) and shipSystem._shipObj:HasAugmentation("ZOLTAN_BYPASS") <= 0
   return not (shipSystem:GetLocked() and shipSystem.iLockCount ~= -1) and shipSystem:Functioning() and shipSystem.iHackEffect <= 1 and Hyperspace.ships.enemy and Hyperspace.ships.enemy._targetable.hostile and not shield_blocking
end

local yOffset = 13
--Handles custom rendering
local function grease_render(systemBox, ignoreStatus)
	if is_grease(systemBox) then
		local system = systemBox.pSystem
		local effectivePower = system:GetEffectivePower()
		local maxPower = system:GetMaxPower()
		local mousePos = Hyperspace.Mouse.position
		local effect = greaseEffects[Hyperspace.playerVariables[systemTypeVariable]]

		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(greaseButtonOffset_x, greaseButtonOffset_y, 0)
		Graphics.CSurface.GL_RenderPrimitive(greaseImages[maxPower])

		local systemReady = grease_ready(system)
		local x = 10
		local y = 55 - 21
		for i = 1, maxPower do
			Graphics.CSurface.GL_PushMatrix()
			Graphics.CSurface.GL_Translate(x, y - yOffset * (i - 1), 0)
			if i <= effectivePower and i <= Hyperspace.playerVariables[systemChargesVariable] then
				Graphics.CSurface.GL_RenderPrimitiveWithColor(greaseImages.gauge.full, effect.colour)
				Graphics.CSurface.GL_RenderPrimitive(greaseImages.gauge_outline.full)
			elseif i <= effectivePower then
				if i == Hyperspace.playerVariables[systemChargesVariable] + 1 then
					local fill = systemFillingAmount[0]
					Graphics.CSurface.GL_PushStencilMode()
					Graphics.CSurface.GL_SetStencilMode(1,1,1)
					Graphics.CSurface.GL_DrawRect(
						1 + math.ceil(18 * (1 - fill)), 
						0, 
						math.ceil(18*fill), 
						11, 
						Graphics.GL_Color(1, 1, 1, 1)
					)
					Graphics.CSurface.GL_SetStencilMode(2,1,1)
					Graphics.CSurface.GL_RenderPrimitiveWithColor(greaseImages.gauge.filling, effect.colour)
					Graphics.CSurface.GL_SetStencilMode(0,1,1)
					Graphics.CSurface.GL_PopStencilMode()
				end
				Graphics.CSurface.GL_RenderPrimitive(greaseImages.gauge_outline.on)
			else
				Graphics.CSurface.GL_RenderPrimitive(greaseImages.gauge_outline.off)
			end
			Graphics.CSurface.GL_PopMatrix()
		end

		Graphics.CSurface.GL_PopMatrix()

		local greaseButton = systemBox.table.greaseButton
		greaseButton:OnRender()
		if greaseButton.bHover then
			Hyperspace.Mouse.tooltip = "Current Enhancement: "..effect.name
		end
		local effectButtonTable = systemBox.table.effectButtonTable
		if displayGreaseOptions then
			renderGreaseOptions(greaseButtonOffset_x + 20, greaseButtonOffset_y + 7 + (2 - maxPower) * yOffset, effectButtonTable)
		end
	end
end
script.on_render_event(Defines.RenderEvents.SYSTEM_BOX, 
function(systemBox, ignoreStatus) 
	return Defines.Chain.CONTINUE
end, grease_render)

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	if shipManager:HasSystem(Hyperspace.ShipSystem.NameToSystemId(systemIdName)) then
		local system = shipManager:GetSystem(Hyperspace.ShipSystem.NameToSystemId(systemIdName))
		local chargeVar = (shipManager.iShipId == 0 and systemChargesVariable) or (systemChargesVariable.."_enemy")
		local typeVar = (shipManager.iShipId == 0 and systemTypeVariable) or (systemTypeVariable.."_enemy")
		if Hyperspace.playerVariables[typeVar] == 0 then Hyperspace.playerVariables[typeVar] = 1 end

		local effectivePower = system:GetEffectivePower()
		local maxPower = system:GetMaxPower()

		local currentType = greaseEffects[Hyperspace.playerVariables[typeVar]]

		local rateMult = currentType.fill_rate
		local decayRate = 1
		if Hyperspace.playerVariables[chargeVar] < effectivePower then
			systemFillingAmount[shipManager.iShipId] = systemFillingAmount[shipManager.iShipId] + rateMult * Hyperspace.FPS.SpeedFactor/16
			if systemFillingAmount[shipManager.iShipId] >= 1 then
				systemFillingAmount[shipManager.iShipId] = 0
				Hyperspace.playerVariables[chargeVar] = Hyperspace.playerVariables[chargeVar] + 1
			end
		elseif Hyperspace.playerVariables[chargeVar] > effectivePower or (Hyperspace.playerVariables[chargeVar] == effectivePower and systemFillingAmount[shipManager.iShipId] > 0) then
			systemFillingAmount[shipManager.iShipId] = systemFillingAmount[shipManager.iShipId] - decayRate *  Hyperspace.FPS.SpeedFactor/16
			if systemFillingAmount[shipManager.iShipId] <= 0 and Hyperspace.playerVariables[chargeVar] > 0 then
				systemFillingAmount[shipManager.iShipId] = 1
				Hyperspace.playerVariables[chargeVar] = Hyperspace.playerVariables[chargeVar] - 1
			elseif systemFillingAmount[shipManager.iShipId] <= 0 then
				systemFillingAmount[shipManager.iShipId] = 0
			end
		else
			systemFillingAmount[shipManager.iShipId] = 0
		end
	end
end)

local function spawn_fire(shipManager, projectile, location, damage, shipFriendlyFire)
	local room = get_room_at_location(shipManager, location, true)
	print("start fire")
	shipManager:StartFire(room)
end

local function spawn_lockdown(shipManager, projectile, location, damage, shipFriendlyFire)
	local room = get_room_at_location(shipManager, location, true)
	shipManager.ship:LockdownRoom(room, location)
end

local function spawn_breach(shipManager, projectile, location, damage, shipFriendlyFire)
	local room = get_room_at_location(shipManager, location, true)
	shipManager.ship:BreachRandomHull(room)
end

local smashedRooms = mods.aea.smashedRooms
local function spawn_shock(shipManager, projectile, location, damage, shipFriendlyFire)
	local roomId = get_room_at_location(shipManager, location, false)
	smashedRooms[shipManager.iShipId][roomId] = {time = 7}
	local animationsTable = {}
	for door in vter(shipManager.ship.vDoorList) do
		if door.iRoom1 == roomId or door.iRoom2 == roomId then
			door.forcedOpen:Start(0)

			local name = "aea_door_sparks_hor"
			if door.bVertical then name = "aea_door_sparks_ver" end

			local anim = Hyperspace.Animations:GetAnimation(name)
			anim.position.x = door.x - anim.info.frameWidth/2
			anim.position.y = door.y - anim.info.frameHeight/2
			anim.tracker.loop = true
			anim:Start(true)
			local randomFrame = math.random(15)
			anim:SetCurrentFrame(randomFrame)
			table.insert(animationsTable, anim)
		end
	end
	smashedRooms[shipManager.iShipId][roomId].animations = animationsTable
end

local function spawn_shatter(shipManager, projectile, location, damage, shipFriendlyFire)
	local room = get_room_at_location(shipManager, location, true)
	shipManager.ship:LockdownRoom(room, location)
end

local startAcid = mods.aea.startAcid
local function spawn_acid(shipManager, projectile, location, damage, shipFriendlyFire)
	local room = get_room_at_location(shipManager, location, true)
	startAcid(shipManager.iShipId, room, acidWeapons[projectile.extend.name])
end

local createGasInRoom = mods.aea.createGasInRoom
local function spawn_inculcation(shipManager, projectile, location, damage, shipFriendlyFire)
	createGasInRoom(shipManager, projectile, location, damage, 30)
end

local function spawn_marked(shipManager, projectile, location, damage, shipFriendlyFire)
	local spaceManager = Hyperspace.App.world.space
	for drone in vter(spaceManager.drones) do
		if drone.currentSpace == shipManager.iShipId and drone.iShipId ~= shipManager.iShipId then
			drone.targetLocation = location
		end
	end
end

local resurrectCrew = mods.aea.resurrectCrew
local function spawn_resurrection(shipManager, projectile, location, damage, shipFriendlyFire)
	local room = get_room_at_location(shipManager, location, true)
	local chargeVar = (originShip == 0 and systemChargesVariable) or (systemChargesVariable.."_enemy")
	local charges = Hyperspace.playerVariables[chargeVar]
	for crewmem in vter(shipManager.vCrewList) do
		if crewmem.iRoomId == room and crewmem:IsDead() and charges > 0 and not crewmem:IsDrone() then
			resurrectCrew(crewmem)
			Hyperspace.playerVariables[chargeVar] = Hyperspace.playerVariables[chargeVar] - 1
		end
	end
end

local function spawn_lightning(shipManager, projectile, location, damage, shipFriendlyFire)
	local room = get_room_at_location(shipManager, location, true)
	local sys = shipManager:GetSystemInRoom(room)
	local originShip = projectile.ownerId
	local chargeVar = (originShip == 0 and systemChargesVariable) or (systemChargesVariable.."_enemy")
	local charges = Hyperspace.playerVariables[chargeVar]

	if sys and sys.healthState.first == 0 and charges > 0 then
		print("LIGHTNING!!")
		local adjacentSystems = {}
		for roomId, roomPos in pairs(get_adjacent_rooms(shipManager.iShipId, get_room_at_location(shipManager, location, false), false)) do
			if shipManager:GetSystemInRoom(roomId) then
				table.insert(adjacentSystems, shipManager:GetSystemInRoom(roomId))
			end
		end
		if #adjacentSystems > 0 then
			local r = math.random(#adjacentSystems)
			local damageSys = adjacentSystems[r]
			damageSys:AddDamage(charges)
			Hyperspace.playerVariables[chargeVar] = 0
		end
	end
end

local spawn_effect = {}
spawn_effect["PLACEHOLDER"] = spawn_fire
spawn_effect["Fire"] = spawn_fire
spawn_effect["Frost"] = spawn_lockdown
spawn_effect["Breach"] = spawn_breach
spawn_effect["Shock"] = spawn_shock
spawn_effect["Shatter"] = spawn_shatter
spawn_effect["Acidic"] = spawn_acid
spawn_effect["Inculcation"] = spawn_inculcation
spawn_effect["Marked"] = spawn_marked
spawn_effect["Resurrection"] = spawn_resurrection
spawn_effect["Cascade"] = spawn_lightning

script.on_internal_event(Defines.InternalEvents.PROJECTILE_FIRE, function(projectile, weapon)
	local shipManager = Hyperspace.ships(weapon.iShipId)
	if shipManager:HasSystem(Hyperspace.ShipSystem.NameToSystemId(systemIdName)) then
		local chargeVar = (shipManager.iShipId == 0 and systemChargesVariable) or (systemChargesVariable.."_enemy")
		local typeVar = (shipManager.iShipId == 0 and systemTypeVariable) or (systemTypeVariable.."_enemy")

		local currentTypeIndex = Hyperspace.playerVariables[typeVar]
		local currentEffect = greaseEffects[currentTypeIndex]

		if currentEffect.type == 1 and weapon.queuedProjectiles:empty() and Hyperspace.playerVariables[chargeVar] > 0  then
			userdata_table(projectile, "mods.aea.aea_grease").greased = currentTypeIndex
			Hyperspace.playerVariables[chargeVar] = Hyperspace.playerVariables[chargeVar] - 1
		elseif currentEffect.type == 2 and Hyperspace.playerVariables[chargeVar] > 0 then
			userdata_table(projectile, "mods.aea.aea_grease").greased = currentTypeIndex
		end
	end
end)

script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA_HIT, function(shipManager, projectile, location, damage, shipFriendlyFire)
	if projectile and userdata_table(projectile, "mods.aea.aea_grease").greased then
		local effect = greaseEffects[userdata_table(projectile, "mods.aea.aea_grease").greased]
		if spawn_effect[effect.name] then
			spawn_effect[effect.name](shipManager, projectile, location, damage, shipFriendlyFire)
		end
		userdata_table(projectile, "mods.aea.aea_grease").greased = nil
	end
end)

script.on_internal_event(Defines.InternalEvents.DAMAGE_BEAM, function(shipManager, projectile, location, damage, realNewTile, beamHitType)
	if projectile and userdata_table(projectile, "mods.aea.aea_grease").greased and beamHitType == Defines.BeamHit.NEW_ROOM then
		local effect = greaseEffects[userdata_table(projectile, "mods.aea.aea_grease").greased]
		if spawn_effect[effect.name] then
			spawn_effect[effect.name](shipManager, projectile, location, damage, false)
		end
		userdata_table(projectile, "mods.aea.aea_grease").greased = nil
	end
end)

script.on_render_event(Defines.RenderEvents.SHIP, function(ship) end, function(ship)
	local spaceManager = Hyperspace.App.world.space
	for projectile in vter(spaceManager.projectiles) do
		greaseTable = userdata_table(projectile, "mods.aea.aea_grease")
		if projectile.currentSpace == ship.iShipId and greaseTable.greased then
			local effect = greaseEffects[greaseTable.greased]
			Graphics.CSurface.GL_PushStencilMode()
			Graphics.CSurface.GL_SetStencilMode(1,1,1)
			projectile.flight_animation:OnRender(1, Graphics.GL_Color(1, 1, 1, 1), false)
			Graphics.CSurface.GL_SetStencilMode(2,1,1)
			Graphics.CSurface.GL_DrawRect(
				projectile.position.x - 25, 
				projectile.position.y - 25, 
				50, 
				50, 
				effect.colour
			)
			Graphics.CSurface.GL_SetStencilMode(0,1,1)
			Graphics.CSurface.GL_PopStencilMode()

			
		end
	end
end)

---@param room Hyperspace.Room The room to get the time dilation factor for.
---@return number dilation multipier to the rate that time passes within the room.
local function get_time_dilation(room)
	return Hyperspace.TemporalSystemParser.GetDilationStrength(room.extend.timeDilation)
end

script.on_internal_event(Defines.InternalEvents.JUMP_ARRIVE, function(shipManager)
	if shipManager.iShipId == 0 and shipManager:HasSystem(Hyperspace.ShipSystem.NameToSystemId(systemIdName)) then
		Hyperspace.playerVariables[systemChargesVariable] = 0
		systemFillingAmount[0] = 0

		Hyperspace.playerVariables[systemChargesVariable.."_enemy"] = 0
		systemFillingAmount[1] = 0
	end
end)

mods.multiverse.systemIcons[Hyperspace.ShipSystem.NameToSystemId(systemIdName)] = mods.multiverse.register_system_icon(systemIdName)
