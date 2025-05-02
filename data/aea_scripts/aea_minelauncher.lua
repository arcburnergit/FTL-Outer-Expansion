
local function get_random_point_in_radius(center, radius)
	r = radius * math.sqrt(math.random())
	theta = math.random() * 2 * math.pi
	return Hyperspace.Pointf(center.x + r * math.cos(theta), center.y + r * math.sin(theta))
end

local function get_point_local_offset(original, target, offsetForwards, offsetRight)
	local alpha = math.atan((original.y-target.y), (original.x-target.x))
	local newX = original.x - (offsetForwards * math.cos(alpha)) - (offsetRight * math.cos(alpha+math.rad(90)))
	local newY = original.y - (offsetForwards * math.sin(alpha)) - (offsetRight * math.sin(alpha+math.rad(90)))
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

mods.aea.mine_launchers = {}
local mine_launchers = mods.aea.mine_launchers
mine_launchers["AEA_MINE_1"] = {blueprint = Hyperspace.Blueprints:GetWeaponBlueprint("AEA_MINE_PROJ_BASE"), spread = 100, radius = 45, shape = { {front=-1,side=0}, {front=0,side=0}, {front=1,side=0} } }
mine_launchers["AEA_MINE_2"] = {blueprint = Hyperspace.Blueprints:GetWeaponBlueprint("AEA_MINE_PROJ_BASE"), spread = 50, radius = 45, shape = { {front=-2,side=-1}, {front=0,side=1}, {front=2,side=-1}, {front=4,side=1} } }

script.on_internal_event(Defines.InternalEvents.PROJECTILE_FIRE, function(projectile, weapon)
    if projectile and mine_launchers[projectile.extend.name] then
    	local tab = mine_launchers[projectile.extend.name]
        local spaceManager = Hyperspace.Global.GetInstance():GetCApp().world.space
        local target1 = projectile.target1
        local target2 = projectile.target2
    	for i, positionOffset in ipairs(tab.shape) do
            local newTarget = get_random_point_in_radius( get_point_local_offset(target1, target2, positionOffset.front * tab.spread, positionOffset.side * tab.spread), tab.radius )
            local newProjectile = spaceManager:CreateMissile(
            	tab.blueprint,
            	projectile.position,
            	projectile.currentSpace,
            	projectile.ownerId,
            	newTarget,
            	projectile.destinationSpace,
            	projectile.heading)
            newProjectile.bBroadcastTarget = true
            newProjectile.entryAngle = projectile.entryAngle
    	end
    	projectile:Kill()
    end
end)

script.on_render_event(Defines.RenderEvents.SHIP, function() end, function(ship)
    if ship.iShipId == 0 then return end
    local shipManager = Hyperspace.ships(1-ship.iShipId)
    local cApp = Hyperspace.Global.GetInstance():GetCApp()
    local combatControl = cApp.gui.combatControl
    local weaponControl = combatControl.weapControl
    if weaponControl.armedWeapon and mine_launchers[weaponControl.armedWeapon.blueprint.name] then
    	local tab = mine_launchers[weaponControl.armedWeapon.blueprint.name]
        local target1 = nil
        for point in vter(combatControl.aimingPoints) do
        	target1 = point
        	break
        end
        if target1 then
	        local target2 = combatControl.potentialAiming
	    	for i, positionOffset in ipairs(tab.shape) do
	            local newTarget = get_random_point_in_radius( get_point_local_offset(target1, target2, positionOffset.front * tab.spread, positionOffset.side * tab.spread), tab.radius )
	            Graphics.CSurface.GL_DrawCircle(newTarget.x, newTarget.y, 45, Graphics.GL_Color(1, 0, 0, 0.5))
	    	end
	    end
    end
end)