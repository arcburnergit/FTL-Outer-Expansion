mods.mvtest = {}
mods.mvtest.customWeaponAnims = {}
local customWeaponAnims = mods.mvtest.customWeaponAnims

local userdata_table = mods.multiverse.userdata_table
local vter = mods.multiverse.vter
local node_child_iter = mods.multiverse.node_child_iter
local parse_xml_bool = mods.multiverse.parse_xml_bool

-- Iterator for children of an xml node
do
    local function nodeIter(parent, child)
        if child == "Start" then return parent:first_attribute() end
        return child:next_attribute()
    end
    mods.mvtest.node_attribute_iter = function(parent)
        if not parent then error("Invalid node to node_attribute_iter iterator!", 2) end
        return nodeIter, parent, "Start"
    end
end
local node_attribute_iter = mods.mvtest.node_attribute_iter

script.on_load(function()
    for _, file in ipairs(mods.multiverse.blueprintFiles) do
		local doc = RapidXML.xml_document(file)
		for node in node_child_iter(doc:first_node("FTL") or doc) do
			if node:name() == "weaponBlueprint" then
				for weaponNode in node_child_iter(node) do
					if weaponNode:name() == "mv-customAnimations" then
						customWeaponAnims[node:first_attribute("name"):value()] = {}
						local customTable = customWeaponAnims[node:first_attribute("name"):value()]
						for animNode in node_child_iter(weaponNode) do
							local animation = {}
							animation.name = animNode:name()

							for attribute in node_attribute_iter(animNode) do
								animation[attribute:name()] = parse_xml_bool(attribute:value())
							end
							table.insert(customTable, animation)
						end
					end
				end
			end
		end
		doc:clear()
	end
	--[[for weapon, weaponTable in pairs(customWeaponAnims) do
		for _, animTable in ipairs(weaponTable) do
			local str = tostring(weapon)
			for key, value in pairs(animTable) do
				str = str .." "..tostring(key)..":"..tostring(value)
			end
			print(str)
		end
	end]]
end)


script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(ship)
	local shipManager = Hyperspace.ships(ship.iShipId)
	if shipManager and shipManager:HasSystem(3) then
		for weapon in vter(shipManager.weaponSystem.weapons) do
			if customWeaponAnims[weapon.blueprint.name] then
				local tab = userdata_table(weapon, "mods.mvtest.customWeaponAnimations")
				for _, animTable in ipairs(customWeaponAnims[weapon.blueprint.name]) do
					if tab[animTable.name] then
						tab[animTable.name]:Update()
					end
				end
			end
		end
	end
end)

script.on_render_event(Defines.RenderEvents.SHIP_HULL, function(ship) 
	local shipManager = Hyperspace.ships(ship.iShipId)
	local shipGraph = Hyperspace.ShipGraph.GetShipInfo(shipManager.iShipId)
	local shipCorner = {x = shipManager.ship.shipImage.x + shipGraph.shipBox.x, y = shipManager.ship.shipImage.y + shipGraph.shipBox.y}
	if shipManager and shipManager:HasSystem(3) then
		for weapon in vter(shipManager.weaponSystem.weapons) do
			if customWeaponAnims[weapon.blueprint.name] then
				local tab = userdata_table(weapon, "mods.mvtest.customWeaponAnimations")
				for _, animTable in ipairs(customWeaponAnims[weapon.blueprint.name]) do
					local name = animTable.name
					local depoweredMet = animTable.depowered and not weapon.weaponVisual.bPowered
					local chargingMet = animTable.charging and weapon.weaponVisual.bPowered and not (weapon:IsChargedGoal() or weapon.weaponVisual.bFiring)
					local chargedMet = animTable.charged and weapon:IsChargedGoal()
					local firingMet = animTable.firing and weapon.weaponVisual.bFiring
					if depoweredMet or chargingMet or chargedMet or firingMet then
						if not tab[name] then
							tab[name] = Hyperspace.Animations:GetAnimation(name)
							tab[name].position.x = (weapon.mount.mirror and - weapon.weaponVisual.anim.info.frameWidth + weapon.weaponVisual.mountPoint.x) or -weapon.weaponVisual.mountPoint.x
							tab[name].position.y = -weapon.weaponVisual.mountPoint.y
							tab[name].tracker.loop = (animTable.looping == nil and true) or animTable.looping
							tab[name]:Start(true)
						elseif tab[name].tracker.running then
							tab[name].position.x = (weapon.mount.mirror and -(weapon.weaponVisual.anim.info.frameWidth - weapon.weaponVisual.mountPoint.x)) or -weapon.weaponVisual.mountPoint.x
							tab[name].position.y = -weapon.weaponVisual.mountPoint.y
							local slideOffset = weapon.weaponVisual:GetSlide()
							Graphics.CSurface.GL_PushMatrix()
		      				Graphics.CSurface.GL_Translate(weapon.weaponVisual.renderPoint.x + shipCorner.x + slideOffset.x, weapon.weaponVisual.renderPoint.y + shipCorner.y + slideOffset.y)
							if weapon.mount.rotate then
								Graphics.CSurface.GL_Rotate(90, 0, 0, 1)
							end
							tab[name]:OnRender(1, Graphics.GL_Color(1, 1, 1, 1), weapon.mount.mirror)
							Graphics.CSurface.GL_PopMatrix()
						else
							tab[name]:Start(true)
						end
					elseif tab[name] and tab[name].tracker.running then
						tab[name].tracker:Stop(true)
					end
				end
			end
		end
	end
end, function(ship) end)