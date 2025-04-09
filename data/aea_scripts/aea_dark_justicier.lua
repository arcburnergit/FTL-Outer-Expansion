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
weaknessBoost.stat = Hyperspace.CrewStat.MAX_HEALTH
weaknessBoost.amount = 0.5
weaknessBoost.duration = -1
weaknessBoost.maxStacks = 99
weaknessBoost.jumpClear = true
weaknessBoost.cloneClear = false
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
crewPermaHealth.amount = 1.25
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
crewPermaFireRes.stat = Hyperspace.CrewStat.FIRE_DAMAGE_MULTIPLIER
crewPermaFireRes.amount = 0.5
crewPermaFireRes.duration = -1
crewPermaFireRes.maxStacks = 1
crewPermaFireRes.boostAnim = "aea_dark_buff_res"
crewPermaFireRes.cloneClear = false
crewPermaFireRes.jumpClear = false
crewPermaFireRes.boostType = Hyperspace.StatBoostDefinition.BoostType.MULT
crewPermaFireRes.boostSource = Hyperspace.StatBoostDefinition.BoostSource.AUGMENT
crewPermaFireRes.shipTarget = Hyperspace.StatBoostDefinition.ShipTarget.ALL
crewPermaFireRes.crewTarget = Hyperspace.StatBoostDefinition.CrewTarget.ALL
crewPermaFireRes:GiveId()
local crewPermaSuffRes = Hyperspace.StatBoostDefinition()
crewPermaSuffRes.stat = Hyperspace.CrewStat.SUFFOCATION_MODIFIER
crewPermaSuffRes.amount = 0.5
crewPermaSuffRes.duration = -1
crewPermaSuffRes.maxStacks = 1
crewPermaSuffRes.cloneClear = false
crewPermaSuffRes.jumpClear = false
crewPermaSuffRes.boostType = Hyperspace.StatBoostDefinition.BoostType.MULT
crewPermaSuffRes.boostSource = Hyperspace.StatBoostDefinition.BoostSource.AUGMENT
crewPermaSuffRes.shipTarget = Hyperspace.StatBoostDefinition.ShipTarget.ALL
crewPermaSuffRes.crewTarget = Hyperspace.StatBoostDefinition.CrewTarget.ALL
crewPermaSuffRes:GiveId()
local crewPermaHealRes = Hyperspace.StatBoostDefinition()
crewPermaHealRes.stat = Hyperspace.CrewStat.HEAL_SPEED_MULTIPLIER
crewPermaHealRes.amount = 1.25
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
crewPermaDamage.amount = 1.25
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
crewPermaRepair.amount = 1.4
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
	Hyperspace.ships.player:ModifyMissileCount(math.random(2,3))
	Hyperspace.ships.player:ModifyScrapCount(-10, false)
	Hyperspace.Sounds:PlaySoundMix("buy", -1, false)
end
local function buyDronesFunc(shipManager, crewTarget)
	Hyperspace.ships.player:ModifyMissileCount(2)
	Hyperspace.ships.player:ModifyScrapCount(-10, false)
	Hyperspace.Sounds:PlaySoundMix("buy", -1, false)
end

local function fireBombFunc(shipManager, crewTarget)
	local worldManager = Hyperspace.App.world
	Hyperspace.CustomEventsParser.GetInstance():LoadEvent(worldManager,"AEA_SURGE_FIRE",false,-1)
	Hyperspace.ships.player:ModifyMissileCount(-3)
end
local function fireBombCond(shipManager, crewTarget)
	if Hyperspace.ships.player.tempMissileCount >= 3 and Hyperspace.ships.enemy and Hyperspace.ships.enemy._targetable.hostile then
		return true
	end
	print("missiles:"..Hyperspace.ships.player.tempMissileCount)
	return false
end

local function spawnDroneFunc(shipManager, crewTarget)
	local worldManager = Hyperspace.App.world
	Hyperspace.CustomEventsParser.GetInstance():LoadEvent(worldManager,"AEA_SURGE_DRONE",false,-1)
	Hyperspace.ships.player:ModifyDroneCount(-3)
end
local function spawnDroneCond(shipManager, crewTarget)
	if Hyperspace.ships.player.tempDroneCount >= 3 and Hyperspace.ships.enemy and Hyperspace.ships.enemy._targetable.hostile then
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
	if Hyperspace.ships.player.tempMissileCount >= 1 and Hyperspace.ships.player.tempDroneCount >= 1 and Hyperspace.ships.enemy and Hyperspace.ships.enemy._targetable.hostile then
		return true
	end
	return false
end

-- repair spells
local function repairSystem(shipManager, crewTarget)
	local system = shipManager:GetSystemInRoom(crewTarget.iRoomId)
	system:AddDamage(-4)
	Hyperspace.Sounds:PlaySoundMix("repairShip", -1, false)
end
local function repairSystemCond(shipManager, crewTarget)
	if shipManager:GetSystemInRoom(crewTarget.iRoomId) == 0 then
		return false
	end
	return true
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
	if crewTarget.currentShipId == 0 then
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
	if crewTarget.currentShipId == 0 then
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

	buff_crew_health = {func = buffCrewHealth, excludeTarget = true, cond = buffCrewCond, positionList = {{x = 0, y = -2}, {x = 1, y = 2}, {x = -1, y = 2}, {x = -1, y = -2}} },
	buff_crew_resistance = {func = buffCrewResistance, excludeTarget = true, cond = buffCrewCond, positionList = {{x = 0, y = 2}, {x = 1, y = 1}, {x = 1, y = -1}, {x = 0, y = -2}} },
	buff_crew_actions = {func = buffCrewActions, excludeTarget = true, cond = buffCrewCond, positionList = {{x = 0, y = 4}, {x = 1, y = 0}, {x = 0, y = -1}, {x = -2, y = 0}} },

	teleport_one = {func = teleportOne, excludeTarget = true, cond = teleportCond, positionList = {{x = 3, y = 0}} },
	teleport_room = {func = teleportRoom, excludeTarget = true, cond = teleportCond, positionList = {{x = 2, y = 0}, {x = 1, y = 0}} },
	retrieve_crew = {func = retrieveCrew, cond = retrieveCond, positionList = {{x = -3, y = 0}} },

	buy_fuel = {func = buyFuelFunc, cond = buyItemCond, positionList = {{x = 1, y = 0}} },
	buy_missile = {func = buyMissilesFunc, cond = buyItemCond, positionList = {{x = 1, y = -1}} },
	buy_drone = {func = buyDronesFunc, cond = buyItemCond, positionList = {{x = 1, y = 1}} },

	repair_system = {func = repairSystem, cond = repairSystemCond, positionList = {{x = -1, y = 0}} },
	repair_hull = {func = repairHull, positionList = {{x = -2, y = 0}, {x = 0, y = 2}, {x = 1, y = -1}} },

	fire_bomb = {func = fireBombFunc, cond = fireBombCond, positionList = {{x = -1, y = 1}, {x = 3, y = -1}, {x = -3, y = -1}} },
	spawn_drone = {func = spawnDroneFunc, cond = spawnDroneCond, positionList = {{x = -1, y = -1}, {x = 3, y = 1}, {x = -3, y = 1}} },
	lockdown = {func = lockdownFunc, excludeTarget = true, cond = lockdownCond, positionList = {{x = 3, y = 0}, {x = -1, y = 1}, {x = 0, y = -2}} },
	particle = {func = particleFunc, cond = particleCond, positionList = {{x = 3, y = 0}, {x = -1, y = -1}, {x = 0, y = 2}} },
	boarding = {func = boardingFunc, cond = boardingCond, positionList = {{x = 2, y = 0}, {x = 1, y = 1}, {x = 1, y = -1}} },

	promote = {func = promoteCrew, excludeTarget = true, cond = promoteCond, positionList = {{x = 0, y = -2}, {x = 1, y = 4}, {x = -3, y = -3}, {x = 4, y = 0}, {x = -3, y = 3}} },
	give_weapon = {func = giveWeaponFunc, excludeTarget = true, cond = giveWeaponCond, positionList = {{x = 1, y = 1}, {x = 0, y = 2}, {x = 3, y = 0}, {x = 0, y = -2}, {x = 1, y = -1}} }
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
        local commandGui = Hyperspace.App.gui
        local crewControl = commandGui.crewControl
        pcall(function() 
	        crewControl.selectedCrew:clear()
	        crewControl.potentialSelectedCrew:clear()
    	end)
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
local ritualStartCond = Hyperspace.Resources:CreateImagePrimitiveString("effects/aea_ritual_start_crew.png", -17, -17, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false)
local ritual = Hyperspace.Resources:CreateImagePrimitiveString("effects/aea_ritual.png", -17, -17, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false)

local lastValid = false
local currentValidSpell = nil
local shapeRight = false
local crewCond = false
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
				local blue = 0
				if lastValid then colour = 1 
				elseif shapeRight then 
					colour = 0.75 
					blue = 1
				end
				if lastX and lastY then
	   				Graphics.CSurface.GL_DrawLine(lastX+1, lastY+1, location.x+1, location.y+1, 5, Graphics.GL_Color(colour, 0, blue, 0.4))
	   				Graphics.CSurface.GL_DrawLine(lastX+1, lastY+1, location.x+1, location.y+1, 3, Graphics.GL_Color(colour, 0, blue, 0.6))
	   				Graphics.CSurface.GL_PushMatrix()
					Graphics.CSurface.GL_Translate(location.x, location.y, 0)
					Graphics.CSurface.GL_RenderPrimitiveWithColor(ritual, Graphics.GL_Color(colour, 0, blue, 0.8))
					Graphics.CSurface.GL_PopMatrix()
		   			if crewCount == 2 then
		   				Graphics.CSurface.GL_PushMatrix()
						Graphics.CSurface.GL_Translate(lastX, lastY, 0)
						if shapeRight and (not lastValid) and crewCond then 
							Graphics.CSurface.GL_RenderPrimitiveWithColor(ritualStartCond, Graphics.GL_Color(colour, 0, blue, 0.8))
						else
							Graphics.CSurface.GL_RenderPrimitiveWithColor(ritualStart, Graphics.GL_Color(colour, 0, blue, 0.8))
						end
						Graphics.CSurface.GL_PopMatrix()
		   			end
		   		elseif crewCount == 1 and #orderList == 1 then
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
							shapeRight = true
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
	    			table.insert(bloodStainList[targetShip], {x = x, y = y, state = random})
	    			x = crewmem.currentSlot.worldLocation.x + math.random(-17, 6)
	    			y = crewmem.currentSlot.worldLocation.y + math.random(-17, 6)
	    			random = math.random(1,4)
	    			table.insert(bloodStainList[targetShip], {x = x, y = y, state = random})
	    			crewmem:Kill(false)
	    			if crewmem then
	    				applyWeakened(crewmem)
	    			end
					Hyperspace.Sounds:PlaySoundMix("mantisSlash", -1, false)
					Hyperspace.metaVariables["aea_dark_spell_"..currentValidSpell] = Hyperspace.metaVariables["aea_dark_spell_"..currentValidSpell] + 1
					local varValue = Hyperspace.metaVariables["aea_dark_spell_"..currentValidSpell]
					if varValue == 1 or varValue == 3 or varValue == 5 then
						Hyperspace.metaVariables["aea_dark_spell_seen_"..id] = 1
					end
					Hyperspace.metaVariables["aea_dark_spell_all"] = Hyperspace.metaVariables["aea_dark_spell_all"] + 1
	    		end
	    	end
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
spellListPage1[1] = {id = "heal_room", name="prope sana", hint_amount = 0, description="Sacrifice an offering of blood to restore those around.", condition="None.", stat="50hp of healing over 5 seconds to allies in the same room."}
spellListPage1[2] = {id = "heal_ship", name="sana Navis", hint_amount = 1, description="Sacrifice a large offering to restore those on the vessel.", condition="None.", stat="150hp of healing over 10 seconds to allies on the same ship."}
spellListPage1[3] = {id = "buff_damage", name="Damnum", hint_amount = 3, description="Grant allies a boon of damage, dispelled after leaving the location.", condition="None.", stat="1.5x combat damage until death or jump to all allies on either ship."}

spellListPage1[4] = {id = "buff_crew_health", name="Salus", hint_amount = 12, description="Permanently grant the chosen a boon of health.", condition="Cannot target temporary, weakened or crew already buffed similarly.", stat="1.25x Health permanently to target crew."}
spellListPage1[5] = {id = "buff_crew_resistance", name="Resistentia", hint_amount = 12, description="Permanently grant the chosen a boon of resistance to the void and flame.", condition="Cannot target temporary, weakened or crew already buffed similarly.", stat="0.5x Suffocation and Fire Damage permanently to target crew."}
spellListPage1[6] = {id = "buff_crew_actions", name="Actio", hint_amount = 12, description="Permanently grant the chosen a boon of destruction and restoration.", condition="Cannot target temporary, weakened or crew already buffed similarly.", stat="1.25x Combat damage and 1.4x Repair speed permanently to target crew."}

spellListPage1[7] = {id = "teleport_one", name="Ianuae", hint_amount = 8, description="Translocate the chosen to a far away destination.", condition="Must be performed on player ship.", stat="Target is teleported onto enemy ship."}
spellListPage1[8] = {id = "teleport_room", name="Ianuae prope", hint_amount = 8, description="Translocate the chosen and their allies to a far away destination", condition="Must be performed on player ship.", stat="Target and allies in the same room are teleported onto enemy ship."}
spellListPage1[9] = {id = "retrieve_crew", name="Recuperare", hint_amount = 8, description="Retrieve allies from far away.", condition="Must have crew onboard the enemy ship.", stat="All crew onboard the enemy ship are teleported back."}

local spellListPage2 = {}
spellListPage2[1] = {id = "buy_fuel", name="Navis cibum", hint_amount = 4, description="Sacrifice blood and riches to recieve a boon of travel.", condition="Requires 10 scrap.", stat="Takes 10 scrap and returns 4-5 fuel."}
spellListPage2[2] = {id = "buy_missile", name="Tela", hint_amount = 4, description="Sacrifice blood and riches to recieve a boon of ammunition.", condition="Requires 10 scrap.", stat="Takes 10 scrap and returns 2-3 missiles."}
spellListPage2[3] = {id = "buy_drone", name="Partes", hint_amount = 4, description="Sacrifice blood and riches to recieve a boon of components.", condition="Requires 10 scrap.", stat="Takes 10 scrap and returns 2 drone parts."}

spellListPage2[4] = {id = "repair_system", name="Reparare Ratio", hint_amount = 6, description="Restore broken components with a blood sacrifice.", condition="Target must be inside of a system room.", stat="Repairs 4 system damage."}
spellListPage2[5] = {id = "repair_hull", name="Reparare Navis", hint_amount = 6, description="Restore the vessel with a blood sacrifice.", condition="None.", stat="Repairs 2 hull damage."}

spellListPage2[6] = {id = "promote", name="Promovere", hint_amount = 20, description="Permanently empower the chosen.", condition="Cannot target temporary, weakened or crew without promotion pathway.", stat="Upgrades crew, for example; Human -> Human Soldier."}
spellListPage2[7] = {id = "give_weapon", name="Vocate telum", hint_amount = 20, description="Draw upon the technology of the chosen and recieve a weapon.", condition="Target must be: Crystal, Rock, Orchid, Vampweed, Ghost, Leech or Obelisk.", stat="Grants a weapon corresponding to the target crew."}

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
		if Hyperspace.metaVariables["aea_dark_spell_"..id] > 2 then 
			eventString = eventString.."\nRitual Requirement:"..condition
		else
			eventString = eventString.."\nThe Glyphs here are still too hard to make out, perhaps further experimentation could reveal them."
		end
		if Hyperspace.metaVariables["aea_dark_spell_"..id] > 4 then 
			eventString = eventString.."\nRitual Outcome:"..outcome
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
		local eventString = "The glyphs on the page are indecipherable to you, however you are able to make out some faint ritual markings.\n\n\n\n\n\n\n\n\n\n"
		pageEvent.text.data = eventString
		pageEvent.text.isLiteral = true
		event:AddChoice(pageEvent, "A page with faint ritual markings.", blueReq, true)
	else
		local invalidEvent = eventManager:CreateEvent("OPTION_INVALID", 0, false)
		event:AddChoice(invalidEvent, "The glyphs are indecipherable. Perhaps more use of the rituals will teach you more.", emptyReq, true)
	end
end

script.on_internal_event(Defines.InternalEvents.PRE_CREATE_CHOICEBOX, function(event)
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
script.on_internal_event(Defines.InternalEvents.POST_CREATE_CHOICEBOX, function(choiceBox, event)
	--print(string.sub(event.eventName, 25, string.len(event.eventName)))
	if spellList[string.sub(event.eventName, 25, string.len(event.eventName))] then
		renderSpell = string.sub(event.eventName, 25, string.len(event.eventName))
		Hyperspace.metaVariables["aea_dark_spell_seen_"..renderSpell] = 0
	else
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
	end
end)