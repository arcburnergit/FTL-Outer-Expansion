local vter = mods.multiverse.vter

local function is_weapons(systemBox)
	local systemName = Hyperspace.ShipSystem.SystemIdToName(systemBox.pSystem.iSystemType)
	return systemName == "weapons" and systemBox.bPlayerUI
end
local function is_drones(systemBox)
	local systemName = Hyperspace.ShipSystem.SystemIdToName(systemBox.pSystem.iSystemType)
	return systemName == "drones" and systemBox.bPlayerUI
end

local toggleWeapons = {}
toggleWeapons["SHOTGUN_TOGGLE_FIRE"] = { {id = "SHOTGUN_TOGGLE_FIRE", toggle = true, inactive = true}, {id = "SHOTGUN_TOGGLE_ION", toggle = true}, {id = "SHOTGUN_TOGGLE_TOXIC", toggle = true} }
toggleWeapons["SHOTGUN_TOGGLE_ION"] = { {id = "SHOTGUN_TOGGLE_FIRE", toggle = true}, {id = "SHOTGUN_TOGGLE_ION", toggle = true, inactive = true}, {id = "SHOTGUN_TOGGLE_TOXIC", toggle = true} }
toggleWeapons["SHOTGUN_TOGGLE_TOXIC"] = { {id = "SHOTGUN_TOGGLE_FIRE", toggle = true}, {id = "SHOTGUN_TOGGLE_ION", toggle = true}, {id = "SHOTGUN_TOGGLE_TOXIC", toggle = true, inactive = true} }

local toggleDrones = {}
toggleDrones["GUARDIAN_1_MISSILE"] = { {id = "GUARDIAN_1_DRONE", toggle = true} }
toggleDrones["GUARDIAN_1_DRONE"] = { {id = "GUARDIAN_1_MISSILE", toggle = true} }
toggleDrones["GUARDIAN_2_MISSILE"] = { {id = "GUARDIAN_2_DRONE", toggle = true} }
toggleDrones["GUARDIAN_2_DRONE"] = { {id = "GUARDIAN_2_MISSILE", toggle = true} }

toggleDrones["HELLRAISER_HULL_PLAYER"] = { {id = "HELLRAISER_FIRE_PLAYER", toggle = true} }
toggleDrones["HELLRAISER_FIRE_PLAYER"] = { {id = "HELLRAISER_HULL_PLAYER", toggle = true} }

local toggleButtonOffset_x = 24
local toggleButtonOffset_y = 20

local toggleButtonButtonOffset = 17
local toggleButtonWeaponOffset = 8

local toggleButtonPadding = 1

local toggleButton = {
	on = Hyperspace.Resources:CreateImagePrimitiveString("systemUI/button_equipment_toggle_on.png", toggleButtonOffset_x, toggleButtonOffset_y, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false),
	off = Hyperspace.Resources:CreateImagePrimitiveString("systemUI/button_equipment_toggle_off.png", toggleButtonOffset_x, toggleButtonOffset_y, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false),
	select = Hyperspace.Resources:CreateImagePrimitiveString("systemUI/button_equipment_toggle_select.png", toggleButtonOffset_x, toggleButtonOffset_y, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false)
}
local toggleButtonHitbox = {w = 16, h = 15}
--script.on_render_event(Defines.RenderEvents.FTL_BUTTON, function() print("TEST") end, function() end)

local function withinHitbox(target, position, hitbox, padding)
	if target.x > position.x - padding and
		target.x < position.x + hitbox.w + padding and
		target.y > position.y - padding and
		target.y < position.y + hitbox.h + padding then
		return true
	end
	return false
end

local toggleButtonHover = nil

script.on_render_event(Defines.RenderEvents.SHIP_STATUS, function() end, function()
	--if ship.iShipId == 1 then return Defines.Chain.CONTINUE end
	toggleButtonHover = nil
	local shipManager = Hyperspace.ships.player
	local mousePos = Hyperspace.Mouse.position 
	if shipManager:HasSystem(3) then
		local system = shipManager.weaponSystem
		local weaponControl = Hyperspace.App.gui.combatControl.weapControl
		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(weaponControl.location.x, weaponControl.location.y, 0)


		local i = -1
		for weaponBox in vter(weaponControl.boxes) do
			i = i + 1
			local weapon = system.weapons[i]
			if toggleWeapons[weapon.blueprint.name] then
				Graphics.CSurface.GL_PushMatrix()
				Graphics.CSurface.GL_Translate(weaponBox.location.x + weaponBox.lastIconPos.x + toggleButtonWeaponOffset, weaponBox.location.y + weaponBox.lastIconPos.y, 0)
				for n = 1, #toggleWeapons[weapon.blueprint.name] do
					local pos = {
						x = weaponControl.location.x + weaponBox.location.x + toggleButtonWeaponOffset + toggleButtonOffset_x + (n - 1) * toggleButtonButtonOffset, 
						y = weaponControl.location.y + weaponBox.location.y + toggleButtonOffset_y
					}
					
					Graphics.CSurface.GL_PushMatrix()
					Graphics.CSurface.GL_Translate((n - 1) * toggleButtonButtonOffset, 0, 0)
					if toggleWeapons[weapon.blueprint.name][n].inactive then
						Graphics.CSurface.GL_RenderPrimitive(toggleButton.off)
					elseif withinHitbox(mousePos, pos, toggleButtonHitbox, toggleButtonPadding) then
						Graphics.CSurface.GL_RenderPrimitive(toggleButton.select)
						toggleButtonHover = {weapon = true, slot = i, blueprint = weapon.blueprint.name, button = n}
					else
						Graphics.CSurface.GL_RenderPrimitive(toggleButton.on)
					end
					Graphics.CSurface.GL_PopMatrix()
				end
				Graphics.CSurface.GL_PopMatrix()
			end
		end
		Graphics.CSurface.GL_PopMatrix()

	end
	if shipManager:HasSystem(4) then
		local system = shipManager.droneSystem
		local droneControl = Hyperspace.App.gui.combatControl.droneControl
		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(droneControl.location.x, droneControl.location.y, 0)


		local i = -1
		for droneBox in vter(droneControl.boxes) do
			i = i + 1
			local drone = system.drones[i]
			if toggleDrones[drone.blueprint.name] then
				Graphics.CSurface.GL_PushMatrix()
				Graphics.CSurface.GL_Translate(weaponBox.location.x, weaponBox.location.y, 0)
				for n = 1, #toggleDrones[drone.blueprint.name] do
					local pos = {
						x = droneControl.location.x + weaponBox.location.x + toggleButtonOffset_x + (n - 1) * toggleButtonButtonOffset, 
						y = droneControl.location.y + weaponBox.location.y + toggleButtonOffset_y
					}
					
					Graphics.CSurface.GL_PushMatrix()
					Graphics.CSurface.GL_Translate((n - 1) * toggleButtonButtonOffset, 0, 0)
					if toggleDrones[drone.blueprint.name][n].inactive then
						Graphics.CSurface.GL_RenderPrimitive(toggleButton.off)
					elseif withinHitbox(mousePos, pos, toggleButtonHitbox, toggleButtonPadding) then
						Graphics.CSurface.GL_RenderPrimitive(toggleButton.select)
						toggleButtonHover = {weapon = false, slot = i, blueprint = drone.blueprint.name, button = n}
					else
						Graphics.CSurface.GL_RenderPrimitive(toggleButton.on)
					end
					Graphics.CSurface.GL_PopMatrix()
				end
				Graphics.CSurface.GL_PopMatrix()
			end
		end
		Graphics.CSurface.GL_PopMatrix()
	end
	return Defines.Chain.CONTINUE
end)

script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
	if toggleButtonHover and toggleButtonHover.weapon then
		local togTable = toggleWeapons[toggleButtonHover.blueprint][toggleButtonHover.button]
		Hyperspace.Mouse.tooltip = tostring(toggleButtonHover.blueprint).." "..tostring(toggleButtonHover.button)
	elseif toggleButtonHover and not toggleButtonHover.weapon then
		local togTable = toggleDrones[toggleButtonHover.blueprint][toggleButtonHover.button]
		Hyperspace.Mouse.tooltip = tostring(toggleButtonHover.blueprint).." "..tostring(toggleButtonHover.button)
	end
end)

script.on_internal_event(Defines.InternalEvents.ON_MOUSE_L_BUTTON_DOWN, function(x,y) 
	local shipManager = Hyperspace.ships.player
    if toggleButtonHover and toggleButtonHover.weapon then
		local togTable = toggleWeapons[toggleButtonHover.blueprint][toggleButtonHover.button]
		local system = shipManager.weaponSystem
		--system:RemoveWeapon(toggleButtonHover.slot)
		local blueprint = Hyperspace.Blueprints:GetWeaponBlueprint(togTable.id)
		shipManager:AddWeapon(blueprint, toggleButtonHover.slot)
	elseif toggleButtonHover and not toggleButtonHover.weapon then
		local togTable = toggleDrones[toggleButtonHover.blueprint][toggleButtonHover.button]
		local system = shipManager.droneSystem
		--system:RemoveDrone(toggleButtonHover.slot)
		local blueprint = Hyperspace.Blueprints:GetDroneBlueprint(togTable.id)
		shipManager:AddDrone(blueprint, toggleButtonHover.slot)
	end
    return Defines.Chain.CONTINUE
end)