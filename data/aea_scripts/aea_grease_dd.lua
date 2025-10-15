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


local soulplagueName = "AEA_GREASE_EFFECT_BOMB_DD_SOULPLAGUE"
local soulplagueBlueprint = Hyperspace.Blueprints:GetWeaponBlueprint(soulplagueName)

function mods.aea.spawn_soulplague(shipManager, projectile, location, damage, shipFriendlyFire)
	--print("spawn_soulplague")
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
local spawn_soulplague = mods.aea.spawn_soulplague

local randomDarknessCrew = {}
for crew in vter(Hyperspace.Blueprints:GetBlueprintList("LIST_DDDARK_OBELISK_ENTITIES")) do
    table.insert(randomDarknessCrew, crew)
end

function mods.aea.spawn_darkness(shipManager, projectile, location, damage, shipFriendlyFire)
	--print("spawn_darkness")
	local random = math.random(6)
	if random <= 1 then
		mods.aea.spawn_fire(shipManager, projectile, location, damage, shipFriendlyFire)
	elseif random <= 2 then
		mods.aea.spawn_breach(shipManager, projectile, location, damage, shipFriendlyFire)
	else
		local crewId = randomDarknessCrew[math.random(#randomDarknessCrew)]
		local intruder = not (shipManager.iShipId == projectile.ownerId)
		local room = get_room_at_location(shipManager, location, true)
		local crew = shipManager:AddCrewMemberFromString("Voidborn", crewId, intruder, room, true, true)
		crew.extend.deathTimer = Hyperspace.TimerHelper(false)
    	crew.extend.deathTimer:Start(15)
	end
end
local spawn_darkness = mods.aea.spawn_darkness

local shadowName = "AEA_GREASE_EFFECT_BOMB_DD_SHADOW"
local shadowBlueprint = Hyperspace.Blueprints:GetWeaponBlueprint(shadowName)

function mods.aea.spawn_shadow(shipManager, projectile, location, damage, shipFriendlyFire)
	--print("spawn_shadow")
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
local spawn_shadow = mods.aea.spawn_shadow

local radiantName = "AEA_GREASE_EFFECT_BOMB_DD_SHADOW"
local radiantBlueprint = Hyperspace.Blueprints:GetWeaponBlueprint(shadowName)

function mods.aea.spawn_radiant(shipManager, projectile, location, damage, shipFriendlyFire)
	--print("spawn_radiant")
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
local spawn_radiant = mods.aea.spawn_radiant