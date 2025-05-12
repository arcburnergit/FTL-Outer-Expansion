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

local cursorValid = Hyperspace.Resources:GetImageId("mouse/mouse_aea_ritual_valid.png")
local cursorValid2 = Hyperspace.Resources:GetImageId("mouse/mouse_aea_ritual_valid2.png")
local cursorRed = Hyperspace.Resources:GetImageId("mouse/mouse_aea_ritual_red.png")

local cursorDefault = Hyperspace.Resources:GetImageId("mouse/pointerValid.png")
local cursorDefault2 = Hyperspace.Resources:GetImageId("mouse/pointerInvalid.png")

local weaknessBoost = Hyperspace.StatBoostDefinition()
weaknessBoost.stat = Hyperspace.CrewStat.MOVE_SPEED_MULTIPLIER
weaknessBoost.amount = 0.75
weaknessBoost.duration = -1
weaknessBoost.maxStacks = 99
weaknessBoost.jumpClear = true
weaknessBoost.cloneClear = false
weaknessBoost.boostAnim = "blood_effect"
weaknessBoost.boostType = Hyperspace.StatBoostDefinition.BoostType.MULT
weaknessBoost.boostSource = Hyperspace.StatBoostDefinition.BoostSource.AUGMENT
weaknessBoost.shipTarget = Hyperspace.StatBoostDefinition.ShipTarget.ALL
weaknessBoost.crewTarget = Hyperspace.StatBoostDefinition.CrewTarget.ALL
weaknessBoost:GiveId()
script.on_internal_event(Defines.InternalEvents.JUMP_ARRIVE, function(shipManager)
	if shipManager.iShipId == 0 then
		for crewmem in vter(shipManager.vCrewList) do
			local crewTable = userdata_table(crewmem, "mods.aea.dark_justicier")
			if crewTable.weakened then
				crewTable.weakened = crewTable.weakened - 1
				Hyperspace.playerVariables["aea_crew_weak_"..tostring(crewmem.extend.selfId)] = crewTable.weakened
				if crewTable.weakened <= 0 then
					crewTable.weakened = nil
				end
				Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(weaknessBoost), crewmem)
			end
		end
	end
end)

local function applyWeakened(crewmem)
	userdata_table(crewmem, "mods.aea.dark_justicier").weakened = 4
	Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(weaknessBoost), crewmem)
	Hyperspace.playerVariables["aea_crew_weak_"..tostring(crewmem.extend.selfId)] = 4
end
local function checkForValidCrew(crewmem)
	local crewTable = userdata_table(crewmem, "mods.aea.dark_justicier")
	if (crewmem.deathTimer and crewmem.deathTimer:Running()) or crewTable.weakened then
		return false
	end
	return true
end

--Stat boosts

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
healBoost:GiveId()
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
healShipBoost:GiveId()
local function healShip(shipManager, crewTarget)
	for crewmem in vter(shipManager.vCrewList) do
		if crewmem.iShipId == 0 then
			Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(healShipBoost), crewmem)
		end
	end
end
local buffDamageBoost = Hyperspace.StatBoostDefinition()
buffDamageBoost.stat = Hyperspace.CrewStat.DAMAGE_MULTIPLIER
buffDamageBoost.amount = 1.5
buffDamageBoost.duration = -1
buffDamageBoost.maxStacks = 1
buffDamageBoost.boostAnim = "unique_dessius_health"
buffDamageBoost.cloneClear = true
buffDamageBoost.jumpClear = true
buffDamageBoost.boostType = Hyperspace.StatBoostDefinition.BoostType.MULT
buffDamageBoost.boostSource = Hyperspace.StatBoostDefinition.BoostSource.AUGMENT
buffDamageBoost.shipTarget = Hyperspace.StatBoostDefinition.ShipTarget.ALL
buffDamageBoost.crewTarget = Hyperspace.StatBoostDefinition.CrewTarget.ALL
buffDamageBoost:GiveId()
local function buffDamage(shipManager, crewTarget)
	for crewmem in vter(shipManager.vCrewList) do
		if crewmem.iShipId == 0 then
			Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(buffDamageBoost), crewmem)
		end
	end
	if Hyperspace.ships(1 - shipManager.iShipId) then
		for crewmem in vter(Hyperspace.ships(1 - shipManager.iShipId).vCrewList) do
			if crewmem.iShipId == 0 then
				Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(buffDamageBoost), crewmem)
			end
		end
	end
end

local function buffCrewCond(shipManager, crewTarget)
	if checkForValidCrew(crewTarget) and Hyperspace.playerVariables["aea_crew_dark_buff_"..tostring(crewTarget.extend.selfId)] <= 0 then
		return true
	end
	return false
end

local crewPermaHealth = Hyperspace.StatBoostDefinition()
crewPermaHealth.stat = Hyperspace.CrewStat.MAX_HEALTH
crewPermaHealth.amount = 1.5
crewPermaHealth.duration = -1
crewPermaHealth.maxStacks = 1
crewPermaHealth.boostAnim = "aea_dark_buff_health"
crewPermaHealth.cloneClear = false
crewPermaHealth.jumpClear = false
crewPermaHealth.boostType = Hyperspace.StatBoostDefinition.BoostType.MULT
crewPermaHealth.boostSource = Hyperspace.StatBoostDefinition.BoostSource.AUGMENT
crewPermaHealth.shipTarget = Hyperspace.StatBoostDefinition.ShipTarget.ALL
crewPermaHealth.crewTarget = Hyperspace.StatBoostDefinition.CrewTarget.ALL
crewPermaHealth:GiveId()
local function buffCrewHealth(shipManager, crewTarget)
	Hyperspace.playerVariables["aea_crew_dark_buff_"..tostring(crewTarget.extend.selfId)] = 1
	Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(crewPermaHealth), crewTarget)
	applyWeakened(crewTarget)
end

local crewPermaFireRes = Hyperspace.StatBoostDefinition()
crewPermaFireRes.stat = Hyperspace.CrewStat.CAN_BURN
crewPermaFireRes.value = false
crewPermaFireRes.duration = -1
crewPermaFireRes.maxStacks = 1
crewPermaFireRes.boostAnim = "aea_dark_buff_res"
crewPermaFireRes.cloneClear = false
crewPermaFireRes.jumpClear = false
crewPermaFireRes.boostType = Hyperspace.StatBoostDefinition.BoostType.SET
crewPermaFireRes.boostSource = Hyperspace.StatBoostDefinition.BoostSource.AUGMENT
crewPermaFireRes.shipTarget = Hyperspace.StatBoostDefinition.ShipTarget.ALL
crewPermaFireRes.crewTarget = Hyperspace.StatBoostDefinition.CrewTarget.ALL
crewPermaFireRes:GiveId()
local crewPermaSuffRes = Hyperspace.StatBoostDefinition()
crewPermaSuffRes.stat = Hyperspace.CrewStat.CAN_SUFFOCATE
crewPermaSuffRes.value = false
crewPermaSuffRes.duration = -1
crewPermaSuffRes.maxStacks = 1
crewPermaSuffRes.cloneClear = false
crewPermaSuffRes.jumpClear = false
crewPermaSuffRes.boostType = Hyperspace.StatBoostDefinition.BoostType.SET
crewPermaSuffRes.boostSource = Hyperspace.StatBoostDefinition.BoostSource.AUGMENT
crewPermaSuffRes.shipTarget = Hyperspace.StatBoostDefinition.ShipTarget.ALL
crewPermaSuffRes.crewTarget = Hyperspace.StatBoostDefinition.CrewTarget.ALL
crewPermaSuffRes:GiveId()
local crewPermaHealRes = Hyperspace.StatBoostDefinition()
crewPermaHealRes.stat = Hyperspace.CrewStat.HEAL_SPEED_MULTIPLIER
crewPermaHealRes.amount = 2
crewPermaHealRes.duration = -1
crewPermaHealRes.maxStacks = 1
crewPermaHealRes.cloneClear = false
crewPermaHealRes.jumpClear = false
crewPermaHealRes.boostType = Hyperspace.StatBoostDefinition.BoostType.MULT
crewPermaHealRes.boostSource = Hyperspace.StatBoostDefinition.BoostSource.AUGMENT
crewPermaHealRes.shipTarget = Hyperspace.StatBoostDefinition.ShipTarget.ALL
crewPermaHealRes.crewTarget = Hyperspace.StatBoostDefinition.CrewTarget.ALL
crewPermaHealRes:GiveId()
local function buffCrewResistance(shipManager, crewTarget)
	Hyperspace.playerVariables["aea_crew_dark_buff_"..tostring(crewTarget.extend.selfId)] = 2
	Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(crewPermaFireRes), crewTarget)
	Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(crewPermaSuffRes), crewTarget)
	Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(crewPermaHealRes), crewTarget)
	applyWeakened(crewTarget)
end

local crewPermaDamage = Hyperspace.StatBoostDefinition()
crewPermaDamage.stat = Hyperspace.CrewStat.DAMAGE_MULTIPLIER
crewPermaDamage.amount = 1.5
crewPermaDamage.duration = -1
crewPermaDamage.maxStacks = 1
crewPermaDamage.boostAnim = "aea_dark_buff_action"
crewPermaDamage.cloneClear = false
crewPermaDamage.jumpClear = false
crewPermaDamage.boostType = Hyperspace.StatBoostDefinition.BoostType.MULT
crewPermaDamage.boostSource = Hyperspace.StatBoostDefinition.BoostSource.AUGMENT
crewPermaDamage.shipTarget = Hyperspace.StatBoostDefinition.ShipTarget.ALL
crewPermaDamage.crewTarget = Hyperspace.StatBoostDefinition.CrewTarget.ALL
crewPermaDamage:GiveId()
local crewPermaRepair = Hyperspace.StatBoostDefinition()
crewPermaRepair.stat = Hyperspace.CrewStat.REPAIR_SPEED_MULTIPLIER
crewPermaRepair.amount = 2
crewPermaRepair.duration = -1
crewPermaRepair.maxStacks = 1
crewPermaRepair.cloneClear = false
crewPermaRepair.jumpClear = false
crewPermaRepair.boostType = Hyperspace.StatBoostDefinition.BoostType.MULT
crewPermaRepair.boostSource = Hyperspace.StatBoostDefinition.BoostSource.AUGMENT
crewPermaRepair.shipTarget = Hyperspace.StatBoostDefinition.ShipTarget.ALL
crewPermaRepair.crewTarget = Hyperspace.StatBoostDefinition.CrewTarget.ALL
crewPermaRepair:GiveId()
local function buffCrewActions(shipManager, crewTarget)
	Hyperspace.playerVariables["aea_crew_dark_buff_"..tostring(crewTarget.extend.selfId)] = 3
	Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(crewPermaDamage), crewTarget)
	Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(crewPermaRepair), crewTarget)
	applyWeakened(crewTarget)
end

--Damage enemy

--Transform Race
local function transformStatBoost(eliteName)
	local transformRace = Hyperspace.StatBoostDefinition()
	transformRace.stat = Hyperspace.CrewStat.TRANSFORM_RACE
	transformRace.stringValue = eliteName
	transformRace.value = true
	transformRace.cloneClear = false
	transformRace.jumpClear = false
	transformRace.boostType = Hyperspace.StatBoostDefinition.BoostType.SET
	transformRace.boostSource = Hyperspace.StatBoostDefinition.BoostSource.AUGMENT
	transformRace.shipTarget = Hyperspace.StatBoostDefinition.ShipTarget.ALL
	transformRace.crewTarget = Hyperspace.StatBoostDefinition.CrewTarget.ALL
	transformRace:GiveId()
	return transformRace
end

mods.aea.crewToElite = {}
local crewToElite = mods.aea.crewToElite
crewToElite["human"] = transformStatBoost("human_soldier")
crewToElite["human_engineer"] = transformStatBoost("human_technician")
crewToElite["human_soldier"] = transformStatBoost("human_mfk")
crewToElite["human_mfk"] = transformStatBoost("human_legion")
crewToElite["engi"] = transformStatBoost("engi_defender")
crewToElite["zoltan"] = transformStatBoost("zoltan_peacekeeper")
crewToElite["zoltan_devotee"] = transformStatBoost("zoltan_martyr")
crewToElite["mantis"] = transformStatBoost("mantis_suzerain")
crewToElite["mantis_suzerain"] = transformStatBoost("mantis_bishop")
crewToElite["mantis_free"] = transformStatBoost("mantis_warlord")
crewToElite["rock"] = transformStatBoost("rock_crusader")
crewToElite["rock_crusader"] = transformStatBoost("rock_paladin")
crewToElite["crystal"] = transformStatBoost("crystal_sentinel")
crewToElite["orchid"] = transformStatBoost("orchid_praetor")
crewToElite["orchid_vampweed"] = transformStatBoost("orchid_cultivator")
crewToElite["shell"] = transformStatBoost("shell_radiant")
crewToElite["shell_guardian"] = transformStatBoost("shell_radiant")
crewToElite["leech"] = transformStatBoost("leech_ampere")
crewToElite["slug"] = transformStatBoost("slug_saboteur")
crewToElite["slug_saboteur"] = transformStatBoost("slug_knight")
crewToElite["slug_clansman"] = transformStatBoost("slug_ranger")
crewToElite["lanius"] = transformStatBoost("lanius_welder")
crewToElite["cognitive"] = transformStatBoost("cognitive_advanced")
crewToElite["cognitive_automated"] = transformStatBoost("cognitive_advanced_automated")
crewToElite["obelisk"] = transformStatBoost("obelisk_royal")
crewToElite["phantom"] = transformStatBoost("phantom_alpha")
crewToElite["phantom_goul"] = transformStatBoost("phantom_goul_alpha")
crewToElite["phantom_mare"] = transformStatBoost("phantom_mare_alpha")
crewToElite["phantom_wraith"] = transformStatBoost("phantom_wraith_alpha")
crewToElite["spider_hatch"] = transformStatBoost("spider")
crewToElite["spider"] = transformStatBoost("spider_weaver")
crewToElite["pony"] = transformStatBoost("ponyc")
crewToElite["pony_tamed"] = transformStatBoost("ponyc")
crewToElite["beans"] = transformStatBoost("sylvanrick")
crewToElite["siren"] = transformStatBoost("siren_harpy")
crewToElite["aea_acid_soldier"] = transformStatBoost("aea_acid_captain")
crewToElite["aea_necro_engi"] = transformStatBoost("aea_necro_lich")
crewToElite["aea_bird_avali"] = transformStatBoost("aea_bird_illuminant")
crewToElite["aea_cult_wizard"] = transformStatBoost("aea_cult_priest_off")
crewToElite["aea_cult_wizard_a01"] = transformStatBoost("aea_cult_priest_sup")
crewToElite["aea_cult_wizard_a02"] = transformStatBoost("aea_cult_priest_sup")
crewToElite["aea_cult_wizard_s03"] = transformStatBoost("aea_cult_priest_off")
crewToElite["aea_cult_wizard_s04"] = transformStatBoost("aea_cult_priest_off")
crewToElite["aea_cult_wizard_s05"] = transformStatBoost("aea_cult_priest_off")
crewToElite["aea_cult_wizard_s06"] = transformStatBoost("aea_cult_priest_off")
crewToElite["aea_cult_wizard_a07"] = transformStatBoost("aea_cult_priest_bor")
crewToElite["aea_cult_wizard_s08"] = transformStatBoost("aea_cult_priest_bor")
crewToElite["aea_cult_wizard_s09"] = transformStatBoost("aea_cult_priest_bor")
crewToElite["aea_cult_wizard_a10"] = transformStatBoost("aea_cult_priest_bor")
crewToElite["aea_cult_wizard_a11"] = transformStatBoost("aea_cult_priest_off")
crewToElite["aea_cult_wizard_s12"] = transformStatBoost("aea_cult_priest_sup")
crewToElite["aea_cult_wizard_s13"] = transformStatBoost("aea_cult_priest_off")
crewToElite["aea_cult_wizard_s14"] = transformStatBoost("aea_cult_priest_bor")
--[[function aeatest()
	for crewTarget in vter(Hyperspace.ships.player.vCrewList) do
		if crewToElite[crewTarget.type] then
			Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(crewToElite[crewTarget.type]), crewTarget)
		end
	end
end]]
local function promoteCrew(shipManager, crewTarget)
	Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(crewToElite[crewTarget.type]), crewTarget)
	applyWeakened(crewTarget)
end
local function promoteCond(shipManager, crewTarget)
	if crewToElite[crewTarget.type] and checkForValidCrew(crewTarget) then
		return true
	end
	return false
end

-- Give weapons
local function giveWeapon(weapon)
	local commandGui = Hyperspace.App.gui
	local equipment = commandGui.equipScreen
	local artyBlueprint = Hyperspace.Blueprints:GetWeaponBlueprint(weapon)
	equipment:AddWeapon(artyBlueprint, true, false)
end
local function constructCrewList(list)
	local tab = {}
	for blueprint in vter(Hyperspace.Blueprints:GetBlueprintList(list)) do
		tab[blueprint] = true
	end
	return tab
end
local function constructWeaponList(list)
	local tab = {}
	for blueprint in vter(Hyperspace.Blueprints:GetBlueprintList(list)) do
		table.insert(tab, blueprint)
	end
	return tab
end
local weaponTable = { 
	{crewList = constructCrewList("LIST_CREW_CRYSTAL_BASIC"), weaponList = constructWeaponList("GIFTLIST_CRYSTAL"), excludeList = {} },
	{crewList = constructCrewList("LIST_CREW_CRYSTAL"), weaponList = constructWeaponList("GIFTLIST_CRYSTAL_ELITE"), excludeList = constructCrewList("LIST_CREW_CRYSTAL_BASIC")},
	{crewList = constructCrewList("LIST_CREW_ROCK"), weaponList = constructWeaponList("GIFTLIST_MISSILES"), excludeList = {} },
	{crewList = constructCrewList("LIST_CREW_ORCHID"), weaponList = constructWeaponList("GIFTLIST_KERNEL"), excludeList = {} },
	{crewList = constructCrewList("LIST_CREW_VAMPWEED"), weaponList = constructWeaponList("GIFTLIST_SPORE"), excludeList = {} },
	{crewList = constructCrewList("LIST_CREW_GHOST"), weaponList = constructWeaponList("GIFTLIST_RUSTY"), excludeList = {} },
	{crewList = constructCrewList("LIST_CREW_LEECH"), weaponList = constructWeaponList("GIFTLIST_FLAK"), excludeList = {} },
	{crewList = constructCrewList("LIST_CREW_ANCIENT"), weaponList = constructWeaponList("GIFTLIST_ANCIENT"), excludeList = {} }
}
local function giveWeaponFunc(shipManager, crewTarget)
	for i, tab in ipairs(weaponTable) do
		--print("crew:"..crewTarget.type.." i:"..i.." list:"..tostring(tab.crewList[crewTarget.type]).." exclude:"..tostring(tab.excludeList[crewTarget.type]).." not exclude:"..tostring(not tab.excludeList[crewTarget.type]))
		if tab.crewList[crewTarget.type] and (not tab.excludeList[crewTarget.type]) then
			local randomSelect = math.random(1, #tab.weaponList)
			giveWeapon(tab.weaponList[randomSelect])
			applyWeakened(crewTarget)
			return
		end
	end
end
local function giveWeaponCond(shipManager, crewTarget)
	for _, tab in ipairs(weaponTable) do
		if tab.crewList[crewTarget.type] and (not tab.excludeList[crewTarget.type]) then
			return true
		end
	end
	return false
end

local function buyItemCond(shipManager, crewTarget)
	if Hyperspace.ships.player.currentScrap >= 10 then
		return true
	end
	return false
end
local function buyFuelFunc(shipManager, crewTarget)
	Hyperspace.ships.player.fuel_count = Hyperspace.ships.player.fuel_count + math.random(4, 5)
	Hyperspace.ships.player:ModifyScrapCount(-10, false)
	Hyperspace.Sounds:PlaySoundMix("buy", -1, false)
end
local function buyMissilesFunc(shipManager, crewTarget)
	Hyperspace.ships.player:ModifyMissileCount(3)
	Hyperspace.ships.player:ModifyScrapCount(-10, false)
	Hyperspace.Sounds:PlaySoundMix("buy", -1, false)
end
local function buyDronesFunc(shipManager, crewTarget)
	Hyperspace.ships.player:ModifyDroneCount(2)
	Hyperspace.ships.player:ModifyScrapCount(-10, false)
	Hyperspace.Sounds:PlaySoundMix("buy", -1, false)
end

local function fireBombFunc(shipManager, crewTarget)
	local worldManager = Hyperspace.App.world
	Hyperspace.CustomEventsParser.GetInstance():LoadEvent(worldManager,"AEA_SURGE_FIRE",false,-1)
	Hyperspace.ships.player:ModifyMissileCount(-3)
end
local function fireBombCond(shipManager, crewTarget)
	if Hyperspace.ships.player:GetMissileCount() >= 3 and Hyperspace.ships.enemy and Hyperspace.ships.enemy._targetable.hostile then
		return true
	end
	return false
end

local function spawnDroneFunc(shipManager, crewTarget)
	local worldManager = Hyperspace.App.world
	Hyperspace.CustomEventsParser.GetInstance():LoadEvent(worldManager,"AEA_SURGE_DRONE",false,-1)
	Hyperspace.ships.player:ModifyDroneCount(-3)
end
local function spawnDroneCond(shipManager, crewTarget)
	if Hyperspace.ships.player:GetDroneCount() >= 3 and Hyperspace.ships.enemy and Hyperspace.ships.enemy._targetable.hostile then
		return true
	end
	return false
end

local function lockdownFunc(shipManager, crewTarget)
	local worldManager = Hyperspace.App.world
	Hyperspace.CustomEventsParser.GetInstance():LoadEvent(worldManager,"AEA_SURGE_LOCKDOWN",false,-1)
end
local crystalLockdownList = constructCrewList("LIST_CREW_CRYSTAL")
local function lockdownCond(shipManager, crewTarget)
	if crystalLockdownList[crewTarget.type] and Hyperspace.ships.enemy and Hyperspace.ships.enemy._targetable.hostile then
		return true
	end
	return false
end

local function particleFunc(shipManager, crewTarget)
	local worldManager = Hyperspace.App.world
	Hyperspace.CustomEventsParser.GetInstance():LoadEvent(worldManager,"AEA_SURGE_PARTICLE",false,-1)
end
local function particleCond(shipManager, crewTarget)
	if Hyperspace.ships.enemy and Hyperspace.ships.enemy._targetable.hostile then
		return true
	end
	return false
end

local function boardingFunc(shipManager, crewTarget)
	local worldManager = Hyperspace.App.world
	Hyperspace.CustomEventsParser.GetInstance():LoadEvent(worldManager,"AEA_SURGE_BOARDING",false,-1)
	Hyperspace.ships.player:ModifyMissileCount(-1)
	Hyperspace.ships.player:ModifyDroneCount(-1)
end
local function boardingCond(shipManager, crewTarget)
	if Hyperspace.ships.player:GetMissileCount() >= 1 and Hyperspace.ships.player:GetDroneCount() >= 1 and Hyperspace.ships.enemy and Hyperspace.ships.enemy._targetable.hostile then
		return true
	end
	return false
end

-- repair spells
local function repairSystem(shipManager, crewTarget)
	for system in vter(shipManager.vSystemList) do
		if system.roomId == crewTarget.iRoomId then
			system:AddDamage(-4)
			Hyperspace.Sounds:PlaySoundMix("repairShip", -1, false)
		end
	end
end
local function repairSystemCond(shipManager, crewTarget)
	for system in vter(shipManager.vSystemList) do
		if system.roomId == crewTarget.iRoomId then
			return true
		end
	end
	return false
end
local function repairHull(shipManager, crewTarget)
	shipManager:DamageHull(-2, false)
	Hyperspace.Sounds:PlaySoundMix("repairShip", -1, false)
end

-- teleport spells
local function teleportOne(shipManager, crewTarget)
	local otherManager = Hyperspace.ships.enemy
	crewTarget.extend:InitiateTeleport(1, get_room_at_location(otherManager, otherManager:GetRandomRoomCenter(),false), 0)
end
local function teleportRoom(shipManager, crewTarget)
	local otherManager = Hyperspace.ships.enemy
	local roomTarget = get_room_at_location(otherManager, otherManager:GetRandomRoomCenter(),false)
	for crewmem in vter(shipManager.vCrewList) do
		if crewmem.iRoomId == crewTarget.iRoomId and crewmem ~= crewTarget then
			crewmem.extend:InitiateTeleport(1, roomTarget, 0)
		end
	end
	crewTarget.extend:InitiateTeleport(1, roomTarget, 0)
end
local function teleportCond(shipManager, crewTarget)
	if crewTarget.currentShipId == 0 and Hyperspace.ships.enemy then
		return true
	end
	return false
end
local function retrieveCrew(shipManager, crewTarget)
	local roomTarget = get_room_at_location(shipManager, shipManager:GetRandomRoomCenter(),false)
	for crewmem in vter(Hyperspace.ships.enemy.vCrewList) do
		if crewmem.iShipId == 0 and ((not crewmem.deathTimer) or (not crewmem.deathTimer:Running())) then
			crewmem.extend:InitiateTeleport(0, roomTarget, 0)
		end
	end
end
local function retrieveCond(shipManager, crewTarget)
	if crewTarget.currentShipId == 0 and Hyperspace.ships.enemy then
		for crewmem in vter(Hyperspace.ships.enemy.vCrewList) do
			if crewmem.iShipId == 0 and ((not crewmem.deathTimer) or (not crewmem.deathTimer:Running())) then
				return true
			end
		end
	end
	return false
end

local spellList = {
	heal_room = {func = healRoom, positionList = {} },
	heal_ship = {func = healShip, positionList = {{x = 0, y = 2}, {x = 1, y = -1}} },
	buff_damage = {func = buffDamage, positionList = {{x = 0, y = -2}, {x = -1, y = 1}} },

	buff_crew_health = {func = buffCrewHealth, excludeTarget = true, cond = buffCrewCond, condColour = 2, positionList = {{x = 0, y = -2}, {x = 1, y = 2}, {x = -1, y = 2}, {x = -1, y = -2}} },
	buff_crew_resistance = {func = buffCrewResistance, excludeTarget = true, cond = buffCrewCond, condColour = 2, positionList = {{x = 0, y = 2}, {x = 1, y = 1}, {x = 1, y = -1}, {x = 0, y = -2}} },
	buff_crew_actions = {func = buffCrewActions, excludeTarget = true, cond = buffCrewCond, condColour = 2, positionList = {{x = 0, y = 4}, {x = 1, y = 0}, {x = 0, y = -1}, {x = -2, y = 0}} },

	teleport_one = {func = teleportOne, excludeTarget = true, cond = teleportCond, condColour = 1, positionList = {{x = 3, y = 0}} },
	teleport_room = {func = teleportRoom, excludeTarget = true, cond = teleportCond, condColour = 1, positionList = {{x = 2, y = 0}, {x = 1, y = 0}} },
	retrieve_crew = {func = retrieveCrew, cond = retrieveCond, condColour = 5, positionList = {{x = -3, y = 0}} },

	buy_fuel = {func = buyFuelFunc, cond = buyItemCond, condColour = 4, positionList = {{x = 1, y = 0}} },
	buy_missile = {func = buyMissilesFunc, cond = buyItemCond, condColour = 4, positionList = {{x = 1, y = -1}} },
	buy_drone = {func = buyDronesFunc, cond = buyItemCond, condColour = 4, positionList = {{x = 1, y = 1}} },

	repair_system = {func = repairSystem, cond = repairSystemCond, condColour = 3, positionList = {{x = -1, y = 0}} },
	repair_hull = {func = repairHull, positionList = {{x = -2, y = 0}, {x = 0, y = 2}, {x = 1, y = -1}} },

	fire_bomb = {func = fireBombFunc, cond = fireBombCond, condColour = 4, positionList = {{x = -1, y = 1}, {x = 3, y = -1}, {x = -3, y = -1}} },
	spawn_drone = {func = spawnDroneFunc, cond = spawnDroneCond, condColour = 4, positionList = {{x = -1, y = -1}, {x = 3, y = 1}, {x = -3, y = 1}} },
	lockdown = {func = lockdownFunc, excludeTarget = true, cond = lockdownCond, condColour = 2, positionList = {{x = 3, y = 0}, {x = -1, y = 1}, {x = 0, y = -2}} },
	particle = {func = particleFunc, cond = particleCond, condColour = 1, positionList = {{x = 3, y = 0}, {x = -1, y = -1}, {x = 0, y = 2}} },
	boarding = {func = boardingFunc, cond = boardingCond, condColour = 4, positionList = {{x = 2, y = 0}, {x = 1, y = 1}, {x = 1, y = -1}} },

	promote = {func = promoteCrew, excludeTarget = true, cond = promoteCond, condColour = 2, positionList = {{x = 0, y = -2}, {x = 1, y = 4}, {x = -3, y = -3}, {x = 4, y = 0}, {x = -3, y = 3}} },
	give_weapon = {func = giveWeaponFunc, excludeTarget = true, cond = giveWeaponCond, condColour = 2, positionList = {{x = 1, y = 1}, {x = 0, y = 2}, {x = 3, y = 0}, {x = 0, y = -2}, {x = 1, y = -1}} }
}

local setCrew = false
script.on_init(function()
	setCrew = true
end)
script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
	if setCrew and Hyperspace.playerVariables.aea_test_variable == 1 then
		--print("VARIABLE SET")
		setCrew = false
		for crewmem in vter(Hyperspace.ships.player.vCrewList) do
			if Hyperspace.playerVariables["aea_crew_weak_"..tostring(crewmem.extend.selfId)] > 0 then
				userdata_table(crewmem, "mods.aea.dark_justicier").weakened = Hyperspace.playerVariables["aea_crew_weak_"..tostring(crewmem.extend.selfId)]
			end
		end
		if Hyperspace.ships.enemy then
			for crewmem in vter(Hyperspace.ships.enemy.vCrewList) do
				if Hyperspace.playerVariables["aea_crew_weak_"..tostring(crewmem.extend.selfId)] > 0 then
					userdata_table(crewmem, "mods.aea.dark_justicier").weakened = Hyperspace.playerVariables["aea_crew_weak_"..tostring(crewmem.extend.selfId)]
				end
			end
		end
	end
end)

local sacList = {}
local orderList = {}
local targetShip = 0
local activateCursor = false
local startAnimStarted = false

script.on_internal_event(Defines.InternalEvents.ACTIVATE_POWER, function(power, shipManager)
	local crewmem = power.crew
	if crewmem.type == "aea_dark_justicier" then
		startAnimStarted = false
		activateCursor = true
        Hyperspace.Mouse.validPointer = cursorValid
        Hyperspace.Mouse.invalidPointer = cursorValid2
        local commandGui = Hyperspace.App.gui
        local crewControl = commandGui.crewControl
        crewControl.selectedCrew:clear()
        crewControl.potentialSelectedCrew:clear()
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
        	if (crewmem.iShipId == 0 or crewmem.bMindControlled) and get_distance(mousePosRelative, location) <= 17 and crewmem:AtGoal() and not sacList[crewmem.extend.selfId] and checkForValidCrew(crewmem) then
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
        local commandGui = Hyperspace.App.gui
        local crewControl = commandGui.crewControl
        crewControl.selectedCrew:clear()
        crewControl.potentialSelectedCrew:clear()
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
script.on_init(function()
	bloodStainList = {[0] = {}, [1] = {}}
end)
script.on_render_event(Defines.RenderEvents.SHIP_FLOOR, function() end, function(shipManager)
	local list = bloodStainList[shipManager.iShipId]
	for i, bloodTable in ipairs(list) do
		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(bloodTable.x, bloodTable.y, 0)
		Graphics.CSurface.GL_RenderPrimitiveWithAlpha(bloodStain[bloodTable.state], 0.8)
		Graphics.CSurface.GL_PopMatrix()
	end
end)
script.on_internal_event(Defines.InternalEvents.JUMP_LEAVE, function(shipManager)
	if shipManager.iShipId == 0 then
		local list = bloodStainList[0]
		local newList = {}
		for i, bloodTable in ipairs(list) do
			bloodTable.jumps = bloodTable.jumps - 1
			if bloodTable.jumps > 0 then
				table.insert(newList, bloodTable)
			end
		end
		bloodStainList[0] = newList
		bloodStainList[1] = {}
	end
end)

local ritualStart = Hyperspace.Resources:CreateImagePrimitiveString("effects/aea_ritual_start.png", -17, -17, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false)
local ritualStartCond = Hyperspace.Resources:CreateImagePrimitiveString("effects/aea_ritual_start_crew.png", -17, -17, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false)
local ritual = Hyperspace.Resources:CreateImagePrimitiveString("effects/aea_ritual.png", -17, -17, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false)

local lastValid = false
local currentValidSpell = nil
local shapeRight = false
local crewCond = false
script.on_render_event(Defines.RenderEvents.SHIP, function() end, function(ship)
	local shipManager = Hyperspace.ships(ship.iShipId)
	if activateCursor and shipManager.iShipId == targetShip then
        local commandGui = Hyperspace.App.gui
        local crewControl = commandGui.crewControl
        crewControl.selectedCrew:clear()
        crewControl.potentialSelectedCrew:clear()
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
				local green = 0
				local blue = 0
				if lastValid then colour = 1 
				elseif shapeRight == 1 then 
					colour = 0.75 
					green = 0
					blue = 1
				elseif shapeRight == 2 then 
					colour = 0.75 
					green = 0.25
					blue = 0.75
				elseif shapeRight == 3 then 
					colour = 0.75 
					green = 0.5
					blue = 0.5
				elseif shapeRight == 4 then 
					colour = 0.75 
					green = 0.75
					blue = 0.25
				elseif shapeRight == 5 then 
					colour = 0.75 
					green = 1
					blue = 0
				elseif shapeRight == 6 then 
					colour = 0.75 
					green = 1
					blue = 0
				end
				if lastX and lastY then
	   				Graphics.CSurface.GL_DrawLine(lastX+1, lastY+1, location.x+1, location.y+1, 5, Graphics.GL_Color(colour, green, blue, 0.4))
	   				Graphics.CSurface.GL_DrawLine(lastX+1, lastY+1, location.x+1, location.y+1, 3, Graphics.GL_Color(colour, green, blue, 0.6))
	   				Graphics.CSurface.GL_PushMatrix()
					Graphics.CSurface.GL_Translate(location.x, location.y, 0)
					Graphics.CSurface.GL_RenderPrimitiveWithColor(ritual, Graphics.GL_Color(colour, green, blue, 0.8))
					Graphics.CSurface.GL_PopMatrix()
		   			if crewCount == 2 then
		   				Graphics.CSurface.GL_PushMatrix()
						Graphics.CSurface.GL_Translate(lastX, lastY, 0)
						if shapeRight and (not lastValid) and crewCond then 
							Graphics.CSurface.GL_RenderPrimitiveWithColor(ritualStartCond, Graphics.GL_Color(colour, green, blue, 0.8))
						else
							Graphics.CSurface.GL_RenderPrimitiveWithColor(ritualStart, Graphics.GL_Color(colour, green, blue, 0.8))
						end
						Graphics.CSurface.GL_PopMatrix()
		   			end
		   		elseif crewCount == 1 and #orderList == 1 then
	   				Graphics.CSurface.GL_PushMatrix()
					Graphics.CSurface.GL_Translate(location.x, location.y, 0)
					Graphics.CSurface.GL_RenderPrimitiveWithColor(ritualStart, Graphics.GL_Color(colour, green, blue, 0.8))
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
		crewCond = false
		shapeRight = false
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
							shapeRight = spellTable.condColour
							if spellTable.excludeTarget then
								crewCond = true
							end
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

local crewExplosions = {}

script.on_render_event(Defines.RenderEvents.SHIP, function() end, function(ship) 
	for i, expTable in ipairs(crewExplosions) do
		if expTable.ship == ship.iShipId then
	        expTable.anim:OnRender(1, Graphics.GL_Color(1, 1, 1, 1), false)
		end
	end
end)

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(ship)
	local removeId = nil
	for i, expTable in ipairs(crewExplosions) do
		if expTable.ship == ship.iShipId then
	        expTable.anim:Update()
	        if expTable.anim:Done() then
	            removeId = i
	        end
		end
	end
	if removeId then
		table.remove(crewExplosions, removeId)
	end
end)

local darkCrewImages = {
	base = Hyperspace.Resources:GetImageId("people/aea_dark_justicier_base.png"),
	colour = Hyperspace.Resources:GetImageId("people/aea_dark_justicier_color.png"),
	blank = Hyperspace.Resources:GetImageId("people/aea_dark_justicier_invisible.png"),
}
local startAnim = Hyperspace.Animations:GetAnimation("aea_dark_ritual_start")
startAnim.position.x = -startAnim.info.frameWidth/2
startAnim.position.y = -startAnim.info.frameHeight/2
startAnim.tracker.loop = false
local loopAnim = Hyperspace.Animations:GetAnimation("aea_dark_ritual_loop")
loopAnim.position.x = -loopAnim.info.frameWidth/2
loopAnim.position.y = -loopAnim.info.frameHeight/2
loopAnim.tracker.loop = true
local endAnim = Hyperspace.Animations:GetAnimation("aea_dark_ritual_end")
endAnim.position.x = -endAnim.info.frameWidth/2
endAnim.position.y = -endAnim.info.frameHeight/2
endAnim.tracker.loop = false

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(ship)
	if ship.iShipId == 0 then
	    endAnim:Update()
	    loopAnim:Update()
	    startAnim:Update()
	end
end)

script.on_render_event(Defines.RenderEvents.CREW_MEMBER_HEALTH, function(crewmem)
	if crewmem.type == "aea_dark_justicier" then
		local set = false
		for power in vter(crewmem.extend.crewPowers) do
			if power.temporaryPowerActive then
				crewmem.crewAnim.baseStrip = darkCrewImages.blank
				crewmem.crewAnim.colorStrip = darkCrewImages.blank
				set = true
			end
		end

		if set then
			local position = crewmem:GetPosition()
			Graphics.CSurface.GL_PushMatrix()
			Graphics.CSurface.GL_Translate(position.x, position.y, 0)
			if not activateCursor then
				if (not endAnim.tracker.running) or endAnim:Done() then
					endAnim:Start(true)
					loopAnim.tracker:Stop(true)
				end
	            endAnim:OnRender(1, Graphics.GL_Color(1, 1, 1, 1), false)
			elseif startAnim:Done() and startAnimStarted then
				if not loopAnim.tracker.running then
					loopAnim:Start(true)
				end
	            loopAnim:OnRender(1, Graphics.GL_Color(1, 1, 1, 1), false)
	        else
				if not startAnimStarted then
					startAnim:Start(true)
					startAnimStarted = true
				end
	            startAnim:OnRender(1, Graphics.GL_Color(1, 1, 1, 1), false)
			end
			Graphics.CSurface.GL_PopMatrix()
		else
			crewmem.crewAnim.baseStrip = darkCrewImages.base
			crewmem.crewAnim.colorStrip = darkCrewImages.colour
		end
	end
end, function() end)

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
					power.powerCooldown.first = power.powerCooldown.second - 0.01
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
	    	--print("ATTEMPTING SPELL:"..currentValidSpell)
	    	spellList[currentValidSpell].func(Hyperspace.ships(targetShip), orderList[1])
	    	for i, crewmem in ipairs(orderList) do
	    		if not spellList[currentValidSpell].excludeTarget or i > 1 then
	    			local x = crewmem.currentSlot.worldLocation.x + math.random(-17, 6)
	    			local y = crewmem.currentSlot.worldLocation.y + math.random(-17, 6)
	    			local random = math.random(1,4)
	    			table.insert(bloodStainList[targetShip], {x = x, y = y, state = random, jumps = 6})
	    			x = crewmem.currentSlot.worldLocation.x + math.random(-17, 6)
	    			y = crewmem.currentSlot.worldLocation.y + math.random(-17, 6)
	    			random = math.random(1,4)
	    			table.insert(bloodStainList[targetShip], {x = x, y = y, state = random, jumps = 10})
	    			local newAnim = Hyperspace.Animations:GetAnimation("aea_dark_explosion")
					newAnim.position.x = crewmem.currentSlot.worldLocation.x - math.floor(newAnim.info.frameWidth/2)
					newAnim.position.y = crewmem.currentSlot.worldLocation.y - math.floor(newAnim.info.frameHeight/2)
					newAnim.tracker.loop = false
					newAnim:Start(true)
	    			table.insert(crewExplosions, {ship = targetShip, anim = newAnim})
	    			crewmem:Kill(false)
	    			if crewmem then
	    				applyWeakened(crewmem)
	    			end
					Hyperspace.Sounds:PlaySoundMix("shell_death", -1, false)
					
	    		end
	    	end
	    	Hyperspace.metaVariables["aea_dark_spell_"..currentValidSpell] = Hyperspace.metaVariables["aea_dark_spell_"..currentValidSpell] + 1
			local varValue = Hyperspace.metaVariables["aea_dark_spell_"..currentValidSpell]
			if varValue == 1 or varValue == 3 or varValue == 5 then
				Hyperspace.metaVariables["aea_dark_spell_seen_"..currentValidSpell] = 1
			end
			Hyperspace.metaVariables["aea_dark_spell_all"] = Hyperspace.metaVariables["aea_dark_spell_all"] + 1
	    else
	    	for crewmem in vter(Hyperspace.ships.player.vCrewList) do
				if crewmem.type == "aea_dark_justicier" then
					for power in vter(crewmem.extend.crewPowers) do
						power:CancelPower(true)
						power.powerCooldown.first = power.powerCooldown.second - 0.01
					end
				end
			end
	    end
	    sacList = {}
	    orderList = {}
	end
end)

local spellListPage1 = {}
spellListPage1[1] = {id = "heal_room", name="Prope Sana", hint_amount = 0, description="Sacrifice an offering of blood to restore those around.", condition="None.", stat="50hp of healing over 5 seconds to allies in the same room."}
spellListPage1[2] = {id = "heal_ship", name="Sana Navis", hint_amount = 1, description="Sacrifice a large offering to restore those on the vessel.", condition="None.", stat="150hp of healing over 10 seconds to allies on the same ship."}
spellListPage1[3] = {id = "buff_damage", name="Damnum", hint_amount = 3, description="Grant allies a boon of damage, dispelled after leaving the location.", condition="None.", stat="1.5x combat damage until death or jump to all allies on either ship."}

spellListPage1[4] = {id = "buff_crew_health", name="Salus", hint_amount = 12, description="Permanently grant the chosen a boon of health.", condition="Cannot target temporary, weakened or crew already buffed similarly.", stat="1.5x Max Health permanently to target crew."}
spellListPage1[5] = {id = "buff_crew_resistance", name="Resistentia", hint_amount = 12, description="Permanently grant the chosen a boon of resistance to the void and flame.", condition="Cannot target temporary, weakened or crew already buffed similarly.", stat="Suffocation and Fire immunity and 2x heal speed to target crew."}
spellListPage1[6] = {id = "buff_crew_actions", name="Actio", hint_amount = 12, description="Permanently grant the chosen a boon of destruction and restoration.", condition="Cannot target temporary, weakened or crew already buffed similarly.", stat="1.5x Combat damage and 2x Repair speed permanently to target crew."}

spellListPage1[7] = {id = "teleport_one", name="Ianuae", hint_amount = 8, description="Translocate the chosen to a far away destination.", condition="Must be performed on player ship.", stat="Target is teleported onto enemy ship."}
spellListPage1[8] = {id = "teleport_room", name="Ianuae Prope", hint_amount = 8, description="Translocate the chosen and their allies to a far away destination", condition="Must be performed on player ship.", stat="Target and allies in the same room are teleported onto enemy ship."}
spellListPage1[9] = {id = "retrieve_crew", name="Recuperare", hint_amount = 8, description="Retrieve allies from far away.", condition="Must have crew onboard the enemy ship.", stat="All crew onboard the enemy ship are teleported back."}

local spellListPage2 = {}
spellListPage2[1] = {id = "buy_fuel", name="Navis Cibum", hint_amount = 4, description="Sacrifice blood and riches to recieve a boon of travel.", condition="Requires 10 scrap.", stat="Takes 10 scrap and returns 4-5 fuel."}
spellListPage2[2] = {id = "buy_missile", name="Tela", hint_amount = 4, description="Sacrifice blood and riches to recieve a boon of ammunition.", condition="Requires 10 scrap.", stat="Takes 10 scrap and returns 2-3 missiles."}
spellListPage2[3] = {id = "buy_drone", name="Partes", hint_amount = 4, description="Sacrifice blood and riches to recieve a boon of components.", condition="Requires 10 scrap.", stat="Takes 10 scrap and returns 2 drone parts."}

spellListPage2[4] = {id = "repair_system", name="Reparare Ratio", hint_amount = 6, description="Restore broken components with a blood sacrifice.", condition="Target must be inside of a system room.", stat="Repairs 4 system damage."}
spellListPage2[5] = {id = "repair_hull", name="Reparare Navis", hint_amount = 6, description="Restore the vessel with a blood sacrifice.", condition="None.", stat="Repairs 2 hull damage."}

spellListPage2[6] = {id = "promote", name="Promovere", hint_amount = 20, description="Permanently empower the chosen.", condition="Cannot target temporary, weakened or crew without promotion pathway.", stat="Upgrades crew, for example; Human -> Human Soldier."}
spellListPage2[7] = {id = "give_weapon", name="Vocate Telum", hint_amount = 20, description="Draw upon the technology of the chosen and recieve a weapon.", condition="Target must be: Crystal, Rock, Orchid, Vampweed, Ghost, Leech or Obelisk.", stat="Grants a weapon corresponding to the target crew."}

local spellListPage3 = {}
spellListPage3[1] = {id = "fire_bomb", name="Ignis", hint_amount = 18, description="Sacrifice an offering of blood to rain fire upon one's foe.", condition="Requires 3 missiles and an enemy ship.", stat="Launches 3 fire bombs at the enemy ship."}
spellListPage3[2] = {id = "spawn_drone", name="Fucus", hint_amount = 16, description="Sacrifice an offering of blood to launch a mechanical assault on one's foe.", condition="Requires 3 drone parts and an enemy ship.", stat="Summons 3 beam drones around the enemy ship."}
spellListPage3[3] = {id = "lockdown", name="Cincinno", hint_amount = 22, description="Sacrifice an offering of blood and channel the power of a chosen to freeze one's foe.", condition="Target must be a crystal crew, Target cannot be weakened by a ritual.", stat="Launches 3 crystal shards that damage and lockdown rooms at the enemy ship."}
spellListPage3[4] = {id = "particle", name="Particula", hint_amount = 10, description="Sacrifice an offering of blood to bring destruction to one's foe.", condition="Requires an enemy ship.", stat="Fires 3 particle lasers at the enemy ship."}
spellListPage3[5] = {id = "boarding", name="Conscensis", hint_amount = 16, description="Sacrifice an offering of blood to summon mechanical warriors against one's foe.", condition="Requires 1 drone part and 1 missile and an enemy ship.", stat="Launches 3 boarding drones at the enemy ship."}

local emptyReq = Hyperspace.ChoiceReq()
local blueReq = Hyperspace.ChoiceReq()
blueReq.object = "pilot"
blueReq.blue = true
blueReq.max_level = mods.multiverse.INT_MAX
blueReq.max_group = -1

local function createPage(id, name, description, hintAmount, event, condition, outcome, eventFix)
	local eventManager = Hyperspace.Event
	if Hyperspace.metaVariables["aea_dark_spell_"..id] > 0 then
		local pageEvent = eventManager:CreateEvent("AEA_JUSTICIER_BOOK_TEMPLATE"..eventFix, 0, false)
		pageEvent.eventName = "AEA_JUSTICIER_BOOK_PAGE_"..id
		local eventString = description.."\n\n\n\n\n\n\n\n\n"
		if Hyperspace.metaVariables["aea_dark_spell_"..id] > 2 or Hyperspace.metaVariables["aea_dark_spell_all"] >= hintAmount + 5 then 
			eventString = eventString.."\nRitual Requirement: "..condition
		else
			eventString = eventString.."\nThe Glyphs here are still too hard to make out, perhaps further experimentation could reveal them."
		end
		if Hyperspace.metaVariables["aea_dark_spell_"..id] > 4 then 
			eventString = eventString.."\nRitual Outcome: "..outcome
		else
			eventString = eventString.."\nThe Glyphs here are still too hard to make out, perhaps further experimentation could reveal them."
		end
		pageEvent.text.data = eventString
		pageEvent.text.isLiteral = true
		if Hyperspace.metaVariables["aea_dark_spell_seen_"..id] == 1 then
			event:AddChoice(pageEvent, name, blueReq, true)
		else
			event:AddChoice(pageEvent, name, emptyReq, true)
		end
	elseif Hyperspace.metaVariables["aea_dark_spell_all"] >= hintAmount then
		local pageEvent = eventManager:CreateEvent("AEA_JUSTICIER_BOOK_TEMPLATE"..eventFix, 0, false)
		pageEvent.eventName = "AEA_JUSTICIER_BOOK_PAGE_"..id
		local eventString = "The glyphs on the page are indecipherable to you, however you are able to make out some faint ritual markings.\n\n\n\n\n\n\n\n\n"
		if Hyperspace.metaVariables["aea_dark_spell_all"] >= hintAmount + 5 then 
			eventString = eventString.."\nRitual Requirement: "..condition
		else
			eventString = eventString.."\n"
		end
		pageEvent.text.data = eventString
		pageEvent.text.isLiteral = true
		event:AddChoice(pageEvent, "A page with faint ritual markings.", blueReq, true)
	else
		local invalidEvent = eventManager:CreateEvent("OPTION_INVALID", 0, false)
		event:AddChoice(invalidEvent, "The glyphs are indecipherable. Perhaps more use of the rituals will teach you more.", emptyReq, true)
	end
end

script.on_internal_event(Defines.InternalEvents.PRE_CREATE_CHOICEBOX, function(event)
	local eventManager = Hyperspace.Event
	if event.eventName == "AEA_JUSTICIER_BOOK_CREW" then
		for _, spellTable in ipairs(spellListPage1) do
			createPage(spellTable.id, spellTable.name, spellTable.description, spellTable.hint_amount, event, spellTable.condition, spellTable.stat, "_CREW")
		end
		local closeEvent = eventManager:CreateEvent("AEA_JUSTICIER_EMPTY", 0, false)
		event:AddChoice(closeEvent, "Close the book.", emptyReq, true)
	elseif event.eventName == "AEA_JUSTICIER_BOOK_TRADE" then
		for _, spellTable in ipairs(spellListPage2) do
			createPage(spellTable.id, spellTable.name, spellTable.description, spellTable.hint_amount, event, spellTable.condition, spellTable.stat, "_TRADE")
		end
		local closeEvent = eventManager:CreateEvent("AEA_JUSTICIER_EMPTY", 0, false)
		event:AddChoice(closeEvent, "Close the book.", emptyReq, true)
	elseif event.eventName == "AEA_JUSTICIER_BOOK_ATTACK" then
		for _, spellTable in ipairs(spellListPage3) do
			createPage(spellTable.id, spellTable.name, spellTable.description, spellTable.hint_amount, event, spellTable.condition, spellTable.stat, "_ATTACK")
		end
		local closeEvent = eventManager:CreateEvent("AEA_JUSTICIER_EMPTY", 0, false)
		event:AddChoice(closeEvent, "Close the book.", emptyReq, true)
	end
end)

local renderSpell = nil
local renderRules = false
script.on_internal_event(Defines.InternalEvents.POST_CREATE_CHOICEBOX, function(choiceBox, event)
	--print(string.sub(event.eventName, 25, string.len(event.eventName)))
	if spellList[string.sub(event.eventName, 25, string.len(event.eventName))] then
		renderSpell = string.sub(event.eventName, 25, string.len(event.eventName))
		Hyperspace.metaVariables["aea_dark_spell_seen_"..renderSpell] = 0
		renderRules = false
	elseif event.eventName == "AEA_JUSTICIER_BOOK_RULES" then
		renderRules = true
		renderSpell = nil
	else
		renderRules = false
		renderSpell = nil
	end
	--local isSpellPage = false
	--[[for id, spellTable in pairs(spellList) do --26+
		if event.eventName == "AEA_JUSTICIER_BOOK_PAGE_"..id then
			renderSpell = id
			isSpellPage = true
		end
	end
	if not isSpellPage then
		renderSpell = nil
	end]]
end)

local ritualPage = Hyperspace.Resources:CreateImagePrimitiveString("effects/aea_ritual_book.png", -17, -17, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false)
local ritualGrid = Hyperspace.Resources:CreateImagePrimitiveString("effects/aea_ritual_page_grid.png", -99, -77, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false)
script.on_render_event(Defines.RenderEvents.CHOICE_BOX, function() end, function()
	local commandGui = Hyperspace.App.gui
	--print("pause:"..tostring(commandGui.bPaused).." autoPaused:"..tostring(commandGui.bAutoPaused).." menu:"..tostring(commandGui.menu_pause).." event:"..tostring(commandGui.event_pause).." touch:"..tostring(commandGui.touch_pause))
	if commandGui.event_pause and renderSpell then
		local spellTable = spellList[renderSpell]
		local x = 635
		local y = 288
		local moveDistance = 22
		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(x, y, 0)
		Graphics.CSurface.GL_RenderPrimitive(ritualGrid)
		Graphics.CSurface.GL_RenderPrimitiveWithColor(ritual, Graphics.GL_Color(1, 0, 0, 1))
		Graphics.CSurface.GL_PopMatrix()
		for _, position in ipairs(spellTable.positionList) do
			local newX = x + position.x * moveDistance
			local newY = y + position.y * moveDistance
			Graphics.CSurface.GL_DrawLine(x+1, y+1, newX+1, newY+1, 3, Graphics.GL_Color(1, 0, 0, 0.8))
			Graphics.CSurface.GL_PushMatrix()
			Graphics.CSurface.GL_Translate(newX, newY, 0)
			Graphics.CSurface.GL_RenderPrimitiveWithColor(ritualPage, Graphics.GL_Color(1, 0, 0, 1))
			Graphics.CSurface.GL_PopMatrix()
			x = newX
			y = newY
		end
	elseif commandGui.event_pause and renderRules then
		local x = 635-274
		local y = 288-70
		local moveDistance = 26
		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(x, y, 0)

		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(0, moveDistance, 0)
		Graphics.CSurface.GL_RenderPrimitiveWithColor(ritual, Graphics.GL_Color(1, 0, 0, 1))
		Graphics.freetype.easy_print(1, 11, -6, "Valid Ritual.")
		Graphics.CSurface.GL_PopMatrix()

		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(0, moveDistance*2, 0)
		Graphics.CSurface.GL_RenderPrimitiveWithColor(ritual, Graphics.GL_Color(0.5, 0, 0, 1))
		Graphics.freetype.easy_print(1, 11, -6, "Invalid Ritual.")
		Graphics.CSurface.GL_PopMatrix()

		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(0, moveDistance*3, 0)
		Graphics.CSurface.GL_RenderPrimitiveWithColor(ritual, Graphics.GL_Color(0.75, 0, 1, 1))
		Graphics.freetype.easy_print(1, 11, -6, "Ritual requires an enemy ship present.")
		Graphics.CSurface.GL_PopMatrix()

		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(0, moveDistance*4, 0)
		Graphics.CSurface.GL_RenderPrimitiveWithColor(ritual, Graphics.GL_Color(0.75, 0.25, 0.75, 1))
		Graphics.freetype.easy_print(1, 11, -6, "Ritual requires a specific/different target crew type.")
		Graphics.CSurface.GL_PopMatrix()

		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(0, moveDistance*5, 0)
		Graphics.CSurface.GL_RenderPrimitiveWithColor(ritual, Graphics.GL_Color(0.75, 0.5, 0.5, 1))
		Graphics.freetype.easy_print(1, 11, -6, "Ritual requires a specific target room type.")
		Graphics.CSurface.GL_PopMatrix()

		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(0, moveDistance*6, 0)
		Graphics.CSurface.GL_RenderPrimitiveWithColor(ritual, Graphics.GL_Color(0.75, 0.75, 0.25, 1))
		Graphics.freetype.easy_print(1, 11, -6, "Ritual requires a specific resource.")
		Graphics.CSurface.GL_PopMatrix()

		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(0, moveDistance*7, 0)
		Graphics.CSurface.GL_RenderPrimitiveWithColor(ritual, Graphics.GL_Color(0.75, 1, 0, 1))
		Graphics.freetype.easy_print(1, 11, -6, "Ritual must be done while you have crew on the enemy ship.")
		Graphics.CSurface.GL_PopMatrix()

		Graphics.CSurface.GL_PopMatrix()
	end
end)


---------------------------------------------------------
---------------------------------------------------------
---------------------- ENEMY STUFF ----------------------
---------------------------------------------------------
---------------------------------------------------------local healBoost = Hyperspace.StatBoostDefinition()
local function healShipEnemy(shipManager, crewTarget)
	for crewmem in vter(shipManager.vCrewList) do
		if crewmem.iShipId == 1 then
			Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(healShipBoost), crewmem)
		end
	end
end
local function buffDamageEnemy(shipManager, crewTarget)
	for crewmem in vter(shipManager.vCrewList) do
		if crewmem.iShipId == 1 then
			Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(buffDamageBoost), crewmem)
		end
	end
	if Hyperspace.ships(1 - shipManager.iShipId) then
		for crewmem in vter(Hyperspace.ships(1 - shipManager.iShipId).vCrewList) do
			if crewmem.iShipId == 1 then
				Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(buffDamageBoost), crewmem)
			end
		end
	end
end

-- repair spells
local function repairSystemEnemy(shipManager, crewTarget)
	local system = shipManager:GetSystemInRoom(crewTarget.iRoomId)
	system:AddDamage(-4)
	Hyperspace.Sounds:PlaySoundMix("repairShip", -1, false)
end
local function repairHullEnemy(shipManager, crewTarget)
	shipManager:DamageHull(-4, false)
	Hyperspace.Sounds:PlaySoundMix("repairShip", -1, false)
end

local function fireBombFuncEnemy(shipManager, crewTarget)
	local worldManager = Hyperspace.App.world
	Hyperspace.CustomEventsParser.GetInstance():LoadEvent(worldManager,"AEA_SURGE_FIRE_ENEMY",false,-1)
end

local function spawnDroneFuncEnemy(shipManager, crewTarget)
	local worldManager = Hyperspace.App.world
	Hyperspace.CustomEventsParser.GetInstance():LoadEvent(worldManager,"AEA_SURGE_DRONE_ENEMY",false,-1)
end

local function lockdownFuncEnemy(shipManager, crewTarget)
	local worldManager = Hyperspace.App.world
	Hyperspace.CustomEventsParser.GetInstance():LoadEvent(worldManager,"AEA_SURGE_LOCKDOWN_ENEMY",false,-1)
end

local function particleFuncEnemy(shipManager, crewTarget)
	local worldManager = Hyperspace.App.world
	Hyperspace.CustomEventsParser.GetInstance():LoadEvent(worldManager,"AEA_SURGE_PARTICLE_ENEMY",false,-1)
end

local function boardingFuncEnemy(shipManager, crewTarget)
	local worldManager = Hyperspace.App.world
	Hyperspace.CustomEventsParser.GetInstance():LoadEvent(worldManager,"AEA_SURGE_BOARDING_ENEMY",false,-1)
end

local spellListEnemy = {
	healShipEnemy,
	buffDamageEnemy,

	repairSystemEnemy,
	repairHullEnemy,

	fireBombFuncEnemy,
	spawnDroneFuncEnemy,
	lockdownFuncEnemy,
	particleFuncEnemy,
	boardingFuncEnemy
}

local startedPowerEnemy = false
script.on_internal_event(Defines.InternalEvents.ACTIVATE_POWER, function(power, shipManager)
	local crewmem = power.crew
	if crewmem.type == "aea_dark_justicier_enemy" then
		startedPowerEnemy = true
	end
	return Defines.Chain.CONTINUE
end)
script.on_internal_event(Defines.InternalEvents.POWER_ON_UPDATE, function(power)
	if power.temporaryPowerActive then
		local crewmem = power.crew
		if crewmem.type == "aea_dark_justicier_enemy" and power.temporaryPowerDuration.first <= 3.2 and startedPowerEnemy then
			startedPowerEnemy = false
			local targetCrewList = {}
			if Hyperspace.ships.enemy then
				for crew in vter(Hyperspace.ships.enemy.vCrewList) do
					if crew.iShipId == 1 and crew.type ~= "aea_dark_justicier_enemy" then
						table.insert(targetCrewList, crew)
					end
				end
			end
			if #targetCrewList > 0 then
				local targetCrew = targetCrewList[math.random( #targetCrewList)]
				local randomSelect = math.random(1, #spellListEnemy)
				spellListEnemy[randomSelect](Hyperspace.ships.enemy, targetCrew)
				local x = targetCrew.currentSlot.worldLocation.x + math.random(-17, 6)
    			local y = targetCrew.currentSlot.worldLocation.y + math.random(-17, 6)
    			local random = math.random(1,4)
    			table.insert(bloodStainList[1], {x = x, y = y, state = random})
    			x = targetCrew.currentSlot.worldLocation.x + math.random(-17, 6)
    			y = targetCrew.currentSlot.worldLocation.y + math.random(-17, 6)
    			random = math.random(1,4)
    			table.insert(bloodStainList[1], {x = x, y = y, state = random})
    			local newAnim = Hyperspace.Animations:GetAnimation("aea_dark_explosion")
				newAnim.position.x = targetCrew.currentSlot.worldLocation.x - math.floor(newAnim.info.frameWidth/2)
				newAnim.position.y = targetCrew.currentSlot.worldLocation.y - math.floor(newAnim.info.frameHeight/2)
				newAnim.tracker.loop = false
				newAnim:Start(true)
    			table.insert(crewExplosions, {ship = 1, anim = newAnim})
    			targetCrew:Kill(false)
				Hyperspace.Sounds:PlaySoundMix("shell_death", -1, false)
			else
				Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(healBoost), crewmem)
				Hyperspace.Sounds:PlaySoundMix("shell_death", -1, false)
			end
		end
	end
	return Defines.Chain.CONTINUE
end)

local startAnimEnemy = Hyperspace.Animations:GetAnimation("aea_dark_ritual_start_enemy")
startAnimEnemy.position.x = -startAnimEnemy.info.frameWidth/2
startAnimEnemy.position.y = -startAnimEnemy.info.frameHeight/2
startAnimEnemy.tracker.loop = false
local loopAnimEnemy = Hyperspace.Animations:GetAnimation("aea_dark_ritual_loop_enemy")
loopAnimEnemy.position.x = -loopAnimEnemy.info.frameWidth/2
loopAnimEnemy.position.y = -loopAnimEnemy.info.frameHeight/2
loopAnimEnemy.tracker.loop = true
local endAnimEnemy = Hyperspace.Animations:GetAnimation("aea_dark_ritual_end_enemy")
endAnimEnemy.position.x = -endAnimEnemy.info.frameWidth/2
endAnimEnemy.position.y = -endAnimEnemy.info.frameHeight/2
endAnimEnemy.tracker.loop = false

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(ship)
	if ship.iShipId == 0 then
	    endAnimEnemy:Update()
	    loopAnimEnemy:Update()
	    startAnimEnemy:Update()
	end
end)

script.on_render_event(Defines.RenderEvents.CREW_MEMBER_HEALTH, function(crewmem)
	if crewmem.type == "aea_dark_justicier_enemy" then
		local set = false
		local powerState = nil
		for power in vter(crewmem.extend.crewPowers) do
			if power.temporaryPowerActive then
				powerState = power.temporaryPowerDuration.first
				crewmem.crewAnim.baseStrip = darkCrewImages.blank
				crewmem.crewAnim.colorStrip = darkCrewImages.blank
				set = true
			end
		end

		if set then
			local position = crewmem:GetPosition()
			Graphics.CSurface.GL_PushMatrix()
			Graphics.CSurface.GL_Translate(position.x, position.y, 0)
			if powerState >= 3.2 then
				if (not startAnimEnemy.tracker.running) or startAnimEnemy:Done() then
					startAnimEnemy:Start(true)
				end
	            startAnimEnemy:OnRender(1, Graphics.GL_Color(1, 1, 1, 1), false)
			elseif powerState >= 0.8 then
				if not loopAnimEnemy.tracker.running then
					loopAnimEnemy:Start(true)
				end
	            loopAnimEnemy:OnRender(1, Graphics.GL_Color(1, 1, 1, 1), false)
	        else
				if (not endAnimEnemy.tracker.running) or endAnimEnemy:Done() then
					endAnimEnemy:Start(true)
					loopAnimEnemy.tracker:Stop(true)
				end
	            endAnimEnemy:OnRender(1, Graphics.GL_Color(1, 1, 1, 1), false)
			end
			Graphics.CSurface.GL_PopMatrix()
		else
			crewmem.crewAnim.baseStrip = darkCrewImages.base
			crewmem.crewAnim.colorStrip = darkCrewImages.colour
		end
	end
end, function() end)

local lastBeacon = -1

script.on_internal_event(Defines.InternalEvents.JUMP_LEAVE, function(shipManager)
	local map = Hyperspace.App.world.starMap
	if shipManager.iShipId == 0 and map.worldLevel == 3 and Hyperspace.playerVariables.aea_justice_battleship_found == 0 and Hyperspace.ships.player:HasAugmentation("SHIP_AEA_JUSTICE")== 0 then
		local fightEvent = "AEA_JUSTICIER_FIGHT_ONE"
		
		if Hyperspace.playerVariables.aea_justice_battleship_location == -1 then
			local furthest_right = nil
			local i = 0
			for location in vter(map.locations) do
				if (location.dangerZone or location.fleetChanging) and ((not furthest_right) or location.loc.x > furthest_right.loc.x) then
					furthest_right = location
				end
				i = i + 1
			end
			if furthest_right then
				Hyperspace.playerVariables.aea_justice_battleship_location = i
				location.event = Hyperspace.Event:CreateEvent(fightEvent, 0, false)
				location.known = false
				Hyperspace.playerVariables.aea_justice_battleship_jumping = -1
			end
		end

		if Hyperspace.playerVariables.aea_justice_battleship_jumping >= 0 then
			for location in vter(map.locations) do
				if location.event.eventName == fightEvent then
					location.event = Hyperspace.Event:CreateEvent("AEA_FLEET_WRECK_ELITE", 0, false)
				end
			end
			local i = 0
			for location in vter(map.locations) do
				if i == Hyperspace.playerVariables.aea_justice_battleship_jumping then
					Hyperspace.playerVariables.aea_justice_battleship_location = i
					location.event = Hyperspace.Event:CreateEvent(fightEvent, 0, false)
					location.known = false
					Hyperspace.playerVariables.aea_justice_battleship_jumping = -1
				end
				i = i + 1
			end
		else
			local jumpLocation = nil
			local i = 0
			for location in vter(map.locations) do
				if Hyperspace.playerVariables.aea_justice_battleship_location == i then
					local furthest_right = nil
					local jumpFound = false
					for near in vter(location.connectedLocations) do
						if (near.dangerZone or near.fleetChanging) and ((not furthest_right) or near.loc.x > furthest_right.loc.x) then
							furthest_right = near
							jumpFound = true
						end
					end
					if jumpFound then
						jumpLocation = furthest_right
					end
					break
				end
				i = i + 1
			end
			if jumpLocation then
				local i = 0
				for location in vter(map.locations) do
					if location.loc.x == jumpLocation.loc.x and location.loc.y == jumpLocation.loc.y then
						Hyperspace.playerVariables.aea_justice_battleship_jumping = i
						break					
					end
					i = i + 1
				end
			end
		end
	elseif shipManager.iShipId == 0 and map.worldLevel == 5 and Hyperspace.playerVariables.aea_justice_battleship == 1 and Hyperspace.playerVariables.aea_justice_cruiser_found == 0 and Hyperspace.ships.player:HasAugmentation("SHIP_AEA_JUSTICE") == 0 then
		local fightEvent = "AEA_JUSTICIER_FIGHT_TWO"
		
		if Hyperspace.playerVariables.aea_justice_cruiser_jumping >= 0 then
			for location in vter(map.locations) do
				if location.event.eventName == fightEvent then
					location.event = Hyperspace.Event:CreateEvent("AEA_FLEET_WRECK_ELITE", 0, false)
				end
			end
			local i = 0
			for location in vter(map.locations) do
				if i == Hyperspace.playerVariables.aea_justice_cruiser_jumping then
					Hyperspace.playerVariables.aea_justice_cruiser_location = i
					location.event = Hyperspace.Event:CreateEvent(fightEvent, 0, false)
					location.known = false
					Hyperspace.playerVariables.aea_justice_cruiser_jumping = -1
				end
				i = i + 1
			end
		else
			local jumpLocation = nil
			local i = 0
			for location in vter(map.locations) do
				if Hyperspace.playerVariables.aea_justice_cruiser_location == i then
					local furthest_right = nil
					local jumpFound = false
					for near in vter(location.connectedLocations) do
						if (near.dangerZone or near.fleetChanging) and ((not furthest_right) or near.loc.x > furthest_right.loc.x) then
							furthest_right = near
							jumpFound = true
						end
					end
					if jumpFound then
						jumpLocation = furthest_right
					end
					break
				end
				i = i + 1
			end
			if jumpLocation then
				local i = 0
				for location in vter(map.locations) do
					if location.loc.x == jumpLocation.loc.x and location.loc.y == jumpLocation.loc.y then
						Hyperspace.playerVariables.aea_justice_cruiser_jumping = i
						break					
					end
					i = i + 1
				end
			end
		end
	end
end)

local needSetBeacon = false
script.on_init(function()
	needSetBeacon = true
end)

script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
	local map = Hyperspace.App.world.starMap
	if map and map.locations and needSetBeacon and Hyperspace.playerVariables.aea_justice_test == 1 then
		needSetBeacon = false
		if map.worldLevel == 3 and Hyperspace.playerVariables.aea_justice_battleship_location >= 0 and Hyperspace.playerVariables.aea_justice_battleship_found == 0 and Hyperspace.ships.player:HasAugmentation("SHIP_AEA_JUSTICE") == 0 then
			local i = 0
			for location in vter(map.locations) do
				if  Hyperspace.playerVariables.aea_justice_battleship_location == i then
					location.event = Hyperspace.Event:CreateEvent("AEA_JUSTICIER_FIGHT_ONE", 0, false)
					location.known = false
				end
				i = i + 1
			end
		elseif map.worldLevel == 5 and Hyperspace.playerVariables.aea_justice_battleship == 1 and Hyperspace.playerVariables.aea_justice_cruiser_location >= 0 and Hyperspace.playerVariables.aea_justice_cruiser_found == 0 and Hyperspace.ships.player:HasAugmentation("SHIP_AEA_JUSTICE") == 0 then
			local i = 0
			for location in vter(map.locations) do
				if  Hyperspace.playerVariables.aea_justice_cruiser_location == i then
					location.event = Hyperspace.Event:CreateEvent("AEA_JUSTICIER_FIGHT_TWO", 0, false)
					location.known = false
				end
				i = i + 1
			end
		end
	end
end)

local shipImage = {AEA_JUSTICIER_FIGHT_ONE = Hyperspace.Resources:CreateImagePrimitiveString("map/map_icon_aea_justice_battleship.png", -10, -32, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false),
	AEA_JUSTICIER_FIGHT_TWO = Hyperspace.Resources:CreateImagePrimitiveString("map/map_icon_aea_justice_cruiser.png", -10, -32, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false)
}
local shipImageMoving = {AEA_JUSTICIER_FIGHT_ONE = Hyperspace.Resources:CreateImagePrimitiveString("map/map_icon_aea_justice_battleship.png", -32, -32, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false),
	AEA_JUSTICIER_FIGHT_TWO = Hyperspace.Resources:CreateImagePrimitiveString("map/map_icon_aea_justice_cruiser.png", -32, -32, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false)
}
shipImage["AEA_JUSTICIER_FIGHT_ONE"].textureAntialias = true
shipImage["AEA_JUSTICIER_FIGHT_TWO"].textureAntialias = true
shipImageMoving["AEA_JUSTICIER_FIGHT_ONE"].textureAntialias = true
shipImageMoving["AEA_JUSTICIER_FIGHT_TWO"].textureAntialias = true

local angle = 0
script.on_render_event(Defines.RenderEvents.GUI_CONTAINER, function() end, function()
	local map = Hyperspace.App.world.starMap
	if map.bOpen and not map.bChoosingNewSector then
		local destinationLoc = nil
		local i = 0
		for location in vter(map.locations) do
			if (i == Hyperspace.playerVariables.aea_justice_battleship_jumping and map.worldLevel == 3) or (i == Hyperspace.playerVariables.aea_justice_cruiser_jumping and map.worldLevel == 5) then
				destinationLoc = location
				break
			end
			i = i + 1
		end

		for location in vter(map.locations) do
			if (location.event.eventName == "AEA_JUSTICIER_FIGHT_ONE" and Hyperspace.playerVariables.aea_justice_battleship_found == 1) or (location.event.eventName == "AEA_JUSTICIER_FIGHT_TWO" and Hyperspace.playerVariables.aea_justice_cruiser_found == 1) then return end
			if (location.event.eventName == "AEA_JUSTICIER_FIGHT_ONE" or location.event.eventName == "AEA_JUSTICIER_FIGHT_TWO") and destinationLoc then
				angle = angle + Hyperspace.FPS.SpeedFactor/16 * 40
				local distance = get_distance(location.loc, destinationLoc.loc)
				if angle > 100 then angle = angle - 100 end
				local point = get_point_local_offset(location.loc, destinationLoc.loc, (angle/100)*(distance - 10), 0)
				local alpha = math.atan((location.loc.y-destinationLoc.loc.y), (location.loc.x-destinationLoc.loc.x))
				local pointAngle = math.deg(alpha) + 90
				Graphics.CSurface.GL_PushMatrix()
				Graphics.CSurface.GL_Translate(point.x + 385,point.y + 122,0)
				Graphics.CSurface.GL_Rotate(pointAngle, 0, 0, 1)
				Graphics.CSurface.GL_RenderPrimitive(shipImageMoving[location.event.eventName])
				Graphics.CSurface.GL_PopMatrix()
			elseif location.event.eventName == "AEA_JUSTICIER_FIGHT_ONE" or location.event.eventName == "AEA_JUSTICIER_FIGHT_TWO" then
				angle = angle + Hyperspace.FPS.SpeedFactor/16 * 18
				if angle > 360 then angle = angle - 360 end
				Graphics.CSurface.GL_PushMatrix()
				Graphics.CSurface.GL_Translate(location.loc.x + 385,location.loc.y + 122,0)
				Graphics.CSurface.GL_Rotate(angle, 0, 0, 1)
				Graphics.CSurface.GL_RenderPrimitive(shipImage[location.event.eventName])
				Graphics.CSurface.GL_PopMatrix()
			end
		end
	end
end)