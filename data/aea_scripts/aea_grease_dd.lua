local function get_room_at_location(shipManager, location, includeWalls)
	return Hyperspace.ShipGraph.GetShipInfo(shipManager.iShipId):GetSelectedRoom(location.x, location.y, includeWalls)
end

local soulplagueName = "AEA_GREASE_EFFECT_BOMB_DD_SOULPLAGUE"
local soulplagueBlueprint = Hyperspace.Blueprints:GetWeaponBlueprint(soulplagueName)

local function spawn_soulplague(shipManager, projectile, location, damage, shipFriendlyFire)
	if mods.dd then
		local spaceManager = Hyperspace.App.world.space
		spaceManager:CreateLaserBlast(
			soulplagueBlueprint,
			location,
			projectile.currentSpace,
			projectile.ownerId,
			location,
			projectile.destinationSpace,
			projectile.heading)
	end
end
local spawn_soulplague = mods.aea.spawn_soulplague

local randomDarknessCrew = {}
for crew in vter(Hyperspace.Blueprints:GetBlueprintList("LIST_DDDARK_OBELISK_ENTITIES")) do
    table.insert(randomDarknessCrew, crew)
end

local spawn_fire = mods.aea.spawn_fire
local spawn_breach = mods.aea.spawn_breach
local function spawn_darkness(shipManager, projectile, location, damage, shipFriendlyFire)
	if mods.dd then
		local random = math.random(6)
		if random <= 1 then
			spawn_fire(shipManager, projectile, location, damage, shipFriendlyFire)
		elseif random <= 2 then
			spawn_breach(shipManager, projectile, location, damage, shipFriendlyFire)
		else
			local crewId = randomDarknessCrew[math.random(#randomDarknessCrew)]
			local intruder = not (shipManager.iShipId == projectile.ownerId)
			local room = get_room_at_location(shipManager, location, true)
			local crew = shipManager:AddCrewMemberFromString("Voidborn", crewId, intruder, room, true, true)
		end
	end
end
local spawn_darkness = mods.aea.spawn_darkness

local shadowName = "AEA_GREASE_EFFECT_BOMB_DD_SHADOW"
local shadowBlueprint = Hyperspace.Blueprints:GetWeaponBlueprint(shadowName)

local function spawn_shadow(shipManager, projectile, location, damage, shipFriendlyFire)
	if mods.dd then
		local spaceManager = Hyperspace.App.world.space
		spaceManager:CreateLaserBlast(
			shadowBlueprint,
			location,
			projectile.currentSpace,
			projectile.ownerId,
			location,
			projectile.destinationSpace,
			projectile.heading)
	end
end
local spawn_shadow = mods.aea.spawn_shadow

local radiantName = "AEA_GREASE_EFFECT_BOMB_DD_SHADOW"
local radiantBlueprint = Hyperspace.Blueprints:GetWeaponBlueprint(shadowName)

local function spawn_radiant(shipManager, projectile, location, damage, shipFriendlyFire)
	if mods.dd then
		local spaceManager = Hyperspace.App.world.space
		spaceManager:CreateLaserBlast(
			shadowBlueprint,
			location,
			projectile.currentSpace,
			projectile.ownerId,
			location,
			projectile.destinationSpace,
			projectile.heading)
	end
end
local spawn_radiant = mods.aea.spawn_radiant