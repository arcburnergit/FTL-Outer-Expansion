local version = {major = 1, minor = 19}
if not (Hyperspace.version and Hyperspace.version.major == version.major and Hyperspace.version.minor >= version.minor) then
	error("Incorrect Hyperspace version detected! The Outer Expansion requires Hyperspace "..version.major.."."..version.minor.."+")
end

mods.aea = {}

-----------------------
-- UTILITY FUNCTIONS --
-----------------------

local log_events = false
function AEAlogEvents()
	log_events = not log_events
end

-- Get a table for a userdata value by name
local function userdata_table(userdata, tableName)
	if not userdata.table[tableName] then userdata.table[tableName] = {} end
	return userdata.table[tableName]
end

local function get_random_point_in_radius(center, radius)
	r = radius * math.sqrt(math.random())
	theta = math.random() * 2 * math.pi
	return Hyperspace.Pointf(center.x + r * math.cos(theta), center.y + r * math.sin(theta))
end

local function get_distance(point1, point2)
	return math.sqrt(((point2.x - point1.x)^ 2)+((point2.y - point1.y) ^ 2))
end

-- Check if a weapon's current shot is its first
local function is_first_shot(weapon, afterFirstShot)
	local shots = weapon.numShots
	if weapon.weaponVisual.iChargeLevels > 0 then shots = shots*(weapon.weaponVisual.boostLevel + 1) end
	if weapon.blueprint.miniProjectiles:size() > 0 then shots = shots*weapon.blueprint.miniProjectiles:size() end
	if afterFirstShot then shots = shots - 1 end
	return shots == weapon.queuedProjectiles:size()
end

local function get_point_local_offset(original, target, offsetForwards, offsetRight)
	local alpha = math.atan((original.y-target.y), (original.x-target.x))
	--print(alpha)
	local newX = original.x - (offsetForwards * math.cos(alpha)) - (offsetRight * math.cos(alpha+math.rad(90)))
	--print(newX)
	local newY = original.y - (offsetForwards * math.sin(alpha)) - (offsetRight * math.sin(alpha+math.rad(90)))
	--print(newY)
	return Hyperspace.Pointf(newX, newY)
end

local function offset_point_direction(oldX, oldY, angle, distance)
	local newX = oldX + (distance * math.cos(math.rad(angle)))
	local newY = oldY + (distance * math.sin(math.rad(angle)))
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

-- Find ID of a room at the given location
local function get_room_at_location(shipManager, location, includeWalls)
	return Hyperspace.ShipGraph.GetShipInfo(shipManager.iShipId):GetSelectedRoom(location.x, location.y, includeWalls)
end

-- Returns a table of all crew belonging to the given ship on the room tile at the given point
local function get_ship_crew_point(shipManager, x, y, maxCount)
	res = {}
	x = x//35
	y = y//35
	for crewmem in vter(shipManager.vCrewList) do
		if crewmem.iShipId == shipManager.iShipId and x == crewmem.x//35 and y == crewmem.y//35 then
			table.insert(res, crewmem)
			if maxCount and #res >= maxCount then
				return res
			end
		end
	end
	return res
end

local function get_ship_crew_room(shipManager, roomId)
	local radCrewList = {}
	for crewmem in vter(shipManager.vCrewList) do
		if crewmem.iShipId == shipManager.iShipId and crewmem.iRoomId == roomId then
			table.insert(radCrewList, crewmem)
		end
	end
	return radCrewList
end

-- written by kokoro
local function convertMousePositionToEnemyShipPosition(mousePosition)
	local cApp = Hyperspace.Global.GetInstance():GetCApp()
	local combatControl = cApp.gui.combatControl
	local position = combatControl.position
	local targetPosition = combatControl.targetPosition
	local enemyShipOriginX = position.x + targetPosition.x
	local enemyShipOriginY = position.y + targetPosition.y
	return Hyperspace.Point(mousePosition.x - enemyShipOriginX, mousePosition.y - enemyShipOriginY)
end

local function convertMousePositionToPlayerShipPosition(mousePosition)
	local cApp = Hyperspace.Global.GetInstance():GetCApp()
	local combatControl = cApp.gui.combatControl
	local playerPosition = combatControl.playerShipPosition
	return Hyperspace.Point(mousePosition.x - playerPosition.x, mousePosition.y - playerPosition.y)
end

-- Returns a table where the indices are the IDs of all rooms adjacent to the given room
-- and the values are the rooms' coordinates
local function get_adjacent_rooms(shipId, roomId, diagonals)
	local shipGraph = Hyperspace.ShipGraph.GetShipInfo(shipId)
	local roomShape = shipGraph:GetRoomShape(roomId)
	local adjacentRooms = {}
	local currentRoom = nil
	local function check_for_room(x, y)
		currentRoom = shipGraph:GetSelectedRoom(x, y, false)
		if currentRoom > -1 and not adjacentRooms[currentRoom] then
			adjacentRooms[currentRoom] = Hyperspace.Pointf(x, y)
		end
	end
	for offset = 0, roomShape.w - 35, 35 do
		check_for_room(roomShape.x + offset + 17, roomShape.y - 17)
		check_for_room(roomShape.x + offset + 17, roomShape.y + roomShape.h + 17)
	end
	for offset = 0, roomShape.h - 35, 35 do
		check_for_room(roomShape.x - 17,			   roomShape.y + offset + 17)
		check_for_room(roomShape.x + roomShape.w + 17, roomShape.y + offset + 17)
	end
	if diagonals then
		check_for_room(roomShape.x - 17,			   roomShape.y - 17)
		check_for_room(roomShape.x + roomShape.w + 17, roomShape.y - 17)
		check_for_room(roomShape.x + roomShape.w + 17, roomShape.y + roomShape.h + 17)
		check_for_room(roomShape.x - 17,			   roomShape.y + roomShape.h + 17)
	end
	return adjacentRooms
end

local RandomList = {
	New = function(self, table)
		table = table or {}
		self.__index = self
		setmetatable(table, self)
		return table
	end,

	GetItem = function(self)
		local index = Hyperspace.random32() % #self + 1
		return self[index]
	end,
}

local function round(num, numDecimalPlaces)
  local mult = 10^(numDecimalPlaces or 0)
  return math.floor(num * mult + 0.5) / mult
end

local spawn_temp_drone = mods.multiverse.spawn_temp_drone

local node_child_iter = mods.multiverse.node_child_iter
local usedFTLman = false
for _, file in ipairs(mods.multiverse.blueprintFiles) do
	local doc = RapidXML.xml_document(file)
	for node in node_child_iter(doc:first_node("FTL") or doc) do
		if node:name() == "usedFTLman" then
			usedFTLman = true
		end
	end
	doc:clear()
end

local crewShipsAch = {
	{ship = "PLAYER_SHIP_AEA_CREW1", slot = 1, ach = {"ACH_AEA_CREW_BILL"}},
	{ship = "PLAYER_SHIP_AEA_CREW2", slot = 1, ach = {"ACH_AEA_CREW_KING"}},
	{ship = "PLAYER_SHIP_AEA_CREW3", slot = 1, ach = {"ACH_AEA_CREW_TINY"}},
	{ship = "PLAYER_SHIP_AEA_CREW4", slot = 1, ach = {"ACH_AEA_CREW_JAY"}},
	{ship = "PLAYER_SHIP_AEA_CREW5", slot = 1, ach = {"ACH_AEA_CREW_SICKLE", "ACH_AEA_CREW_SORROW"}},
	{ship = "PLAYER_SHIP_AEA_CREW6", slot = 1, ach = {"ACH_AEA_CREW_ONYX"}},
	{ship = "PLAYER_SHIP_AEA_JUSTICE", slot = 1, ach = {"ACH_AEA_CREW_JUSTICIER"}},
	{ship = "PLAYER_SHIP_AEA_OLD_UNIA", slot = 1, ach = {"ACH_AEA_CREW_OLD_1"}},
	{ship = "PLAYER_SHIP_AEA_OLD_UNIA", slot = 2, ach = {"ACH_AEA_CREW_OLD_2"}},
	{ship = "PLAYER_SHIP_AEA_OLD_UNIA", slot = 3, ach = {"ACH_AEA_CREW_OLD_3"}},
	{ship = "PLAYER_SHIP_AEA_OLD_UNIB", slot = 1, ach = {"ACH_AEA_CREW_OLD_4"}},
	{ship = "PLAYER_SHIP_AEA_OLD_UNIB", slot = 2, ach = {"ACH_AEA_CREW_OLD_5"}}
} 
local function check_crew_achs()
	for _, tab in ipairs(crewShipsAch) do
		if Hyperspace.CustomShipUnlocks.instance:GetCustomShipUnlocked(tab.ship, tab.slot) then
			for _, ach in ipairs(tab.ach) do
				Hyperspace.CustomAchievementTracker.instance:SetAchievement(ach, false)
			end
		end
	end
end
script.on_init(check_crew_achs)

local shipBuilderCheck = true
script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
	if shipBuilderCheck and Hyperspace.App.menu.shipBuilder.bOpen then
		shipBuilderCheck = false
		check_crew_achs()
	end
end)

--[[print("FTLman used for patching:"..tostring(usedFTLman))
script.on_init(function() 
	if not usedFTLman and Hyperspace.metaVariables.aea_warning_message == 2 then
		Hyperspace.metaVariables.aea_warning_message = 0
	elseif usedFTLman then
	  Hyperspace.metaVariables.aea_warning_message = 2
	end
	print("init variable"..Hyperspace.metaVariables.aea_warning_message)
	if not usedFTLman and Hyperspace.metaVariables.aea_warning_message == 0 then
		Hyperspace.ErrorMessage("WARNING: It is recommended you use FTLman (FTL mod manager) instead of slipstream to patch your addons.\nThis will enable The Outer Expansion to give it's custom systems to ships not in The Outer Expansion.\nFTLman can be found here: https://github.com/afishhh/ftlman/releases/latest\nThis is completely optional,  if you're not comfortable switching ignore this message. This message can be disabled in the toggle menu.")
	end
end)]]
script.on_render_event(Defines.RenderEvents.MAIN_MENU, function() end, function()
    local menu = Hyperspace.Global.GetInstance():GetCApp().menu
    if menu.shipBuilder.bOpen or usedFTLman then
        return
    end
    Graphics.CSurface.GL_DrawRect(15, 540, 340, 165, Graphics.GL_Color(0, 0, 0, 0.8))
    Graphics.freetype.easy_print(10, 20, 545, "WARNING: It is recommended you use FTLman \ninstead of slipstream to patch your addons.")
    Graphics.freetype.easy_print(10, 20, 590, "This will enable The Outer Expansion to \ngive it's custom systems to non OE ships.")
    Graphics.freetype.easy_print(10, 20, 635, "FTLman can be found here: \nhttps://github.com/afishhh/ftlman/releases/latest\nThis is completely optional, if you're not \ncomfortable switching, ignore this message.")
end)
--[[
int iDamage;
int iShieldPiercing;
int fireChance;
int breachChance;
int stunChance;
int iIonDamage;
int iSystemDamage;
int iPersDamage;
bool bHullBuster;
int ownerId;
int selfId;
bool bLockdown;
bool crystalShard;
bool bFriendlyFire;
int iStun;]]--

local nextWeapon = {}
nextWeapon["ARTILLERY_REBEL_LASER"] = "ARTILLERY_REBEL_BEAM"
nextWeapon["ARTILLERY_REBEL_BEAM"] = "ARTILLERY_REBEL_MISSILE"
nextWeapon["ARTILLERY_REBEL_MISSILE"] = "ARTILLERY_REBEL_LASER"

local function setArtySlot(blueprintName, slot)
	if Hyperspace.ships.player.artillerySystems[slot].projectileFactory.blueprint.name == blueprintName then return end
	local shipManager = Hyperspace.ships.player
	local weapons = {}
	for weapon in vter(shipManager.weaponSystem.weapons) do
		table.insert(weapons, weapon.blueprint.name)
	end
	for _, name in ipairs(weapons) do
		shipManager.weaponSystem:RemoveWeapon(0)
	end
	local commandGui = Hyperspace.App.gui
	local equipment = commandGui.equipScreen
	local artyBlueprint = Hyperspace.Blueprints:GetWeaponBlueprint(blueprintName)
	equipment:AddWeapon(artyBlueprint, true, false)
	local artilleryWeapon = shipManager.weaponSystem.weapons[0]
	artilleryWeapon.iAmmo = 99
	shipManager.artillerySystems[slot].projectileFactory = artilleryWeapon
	shipManager.weaponSystem:RemoveWeapon(0)
	for _, name in ipairs(weapons) do
		local blueprint = Hyperspace.Blueprints:GetWeaponBlueprint(name)
		equipment:AddWeapon(blueprint, true, false)
	end
end
local allWeapons = {}
for _, file in ipairs(mods.multiverse.blueprintFiles) do
	local doc = RapidXML.xml_document(file)
	for node in node_child_iter(doc:first_node("FTL") or doc) do
		if node:name() == "weaponBlueprint" then
			table.insert(allWeapons, node:first_attribute("name"):value())
		end
	end
	doc:clear()
end

local function setArtySlotFromWeapon(slot)
	local shipManager = Hyperspace.ships.player
	local commandGui = Hyperspace.App.gui
	local equipment = commandGui.equipScreen
	local weaponName = shipManager.weaponSystem.weapons[0].blueprint.name
	for i, name in ipairs(allWeapons) do
		if name == weaponName then
			Hyperspace.playerVariables["aea_broadside_c_slot"..math.floor(slot+1)] = i
			break
		else
			Hyperspace.playerVariables["aea_broadside_c_slot"..math.floor(slot+1)] = 0
		end
	end
	if Hyperspace.playerVariables["aea_broadside_c_slot"..math.floor(slot+1)] == 0 then
		print("COULD NOT SAVE WEAPON: "..weaponName..", WILL NOT BE RETURNED AFTER A SAVE AND QUIT")
	end
	local artilleryWeapon = shipManager.weaponSystem.weapons[0]
	artilleryWeapon.iAmmo = 99
	shipManager.artillerySystems[slot].projectileFactory = artilleryWeapon
	shipManager.weaponSystem:RemoveWeapon(0)
end

script.on_game_event("AEA_BROADSIDE_CHOOSE_LASER_1", false, function()
	setArtySlot("ARTILLERY_BROADSIDE_PIERCE", 0)
end)
script.on_game_event("AEA_BROADSIDE_CHOOSE_BEAM_1", false, function()
	setArtySlot("ARTILLERY_BROADSIDE_FOCUS", 0)
end)
script.on_game_event("AEA_BROADSIDE_CHOOSE_MISSILE_1", false, function()
	setArtySlot("ARTILLERY_BROADSIDE_MISSILE", 0)
end)
script.on_game_event("AEA_BROADSIDE_CHOOSE_ION_1", false, function()
	setArtySlot("ARTILLERY_BROADSIDE_MINE", 0)
end)


script.on_game_event("AEA_BROADSIDE_CHOOSE_LASER_1", false, function()
	setArtySlot("ARTILLERY_BROADSIDE_PIERCE", 1)
end)
script.on_game_event("AEA_BROADSIDE_CHOOSE_BEAM_2", false, function()
	setArtySlot("ARTILLERY_BROADSIDE_FOCUS", 1)
end)
script.on_game_event("AEA_BROADSIDE_CHOOSE_MISSILE_2", false, function()
	setArtySlot("ARTILLERY_BROADSIDE_MISSILE", 1)
end)
script.on_game_event("AEA_BROADSIDE_CHOOSE_ION_2", false, function()
	setArtySlot("ARTILLERY_BROADSIDE_MINE", 1)
end)


script.on_game_event("AEA_BROADSIDE_CHOOSE_LASER_1", false, function()
	setArtySlot("ARTILLERY_BROADSIDE_PIERCE", 2)
end)
script.on_game_event("AEA_BROADSIDE_CHOOSE_BEAM_3", false, function()
	setArtySlot("ARTILLERY_BROADSIDE_FOCUS", 2)
end)
script.on_game_event("AEA_BROADSIDE_CHOOSE_MISSILE_3", false, function()
	setArtySlot("ARTILLERY_BROADSIDE_MISSILE", 2)
end)
script.on_game_event("AEA_BROADSIDE_CHOOSE_ION_3", false, function()
	setArtySlot("ARTILLERY_BROADSIDE_MINE", 2)
end)



script.on_game_event("AEA_BROADSIDE2_CHOOSE_LASER_1", false, function()
	setArtySlot("ARTILLERY_BROADSIDE2_LASER", 0)
end)
script.on_game_event("AEA_BROADSIDE2_CHOOSE_BEAM_1", false, function()
	setArtySlot("ARTILLERY_BROADSIDE2_BEAM", 0)
end)
script.on_game_event("AEA_BROADSIDE2_CHOOSE_MISSILE_1", false, function()
	setArtySlot("ARTILLERY_BROADSIDE2_MISSILE", 0)
end)
script.on_game_event("AEA_BROADSIDE2_CHOOSE_ION_1", false, function()
	setArtySlot("ARTILLERY_BROADSIDE2_ION", 0)
end)


script.on_game_event("AEA_BROADSIDE2_CHOOSE_LASER_1", false, function()
	setArtySlot("ARTILLERY_BROADSIDE2_LASER", 1)
end)
script.on_game_event("AEA_BROADSIDE2_CHOOSE_BEAM_2", false, function()
	setArtySlot("ARTILLERY_BROADSIDE2_BEAM", 1)
end)
script.on_game_event("AEA_BROADSIDE2_CHOOSE_MISSILE_2", false, function()
	setArtySlot("ARTILLERY_BROADSIDE2_MISSILE", 1)
end)
script.on_game_event("AEA_BROADSIDE2_CHOOSE_ION_2", false, function()
	setArtySlot("ARTILLERY_BROADSIDE2_ION", 1)
end)


script.on_game_event("AEA_BROADSIDE2_CHOOSE_LASER_1", false, function()
	setArtySlot("ARTILLERY_BROADSIDE2_LASER", 2)
end)
script.on_game_event("AEA_BROADSIDE2_CHOOSE_BEAM_3", false, function()
	setArtySlot("ARTILLERY_BROADSIDE2_BEAM", 2)
end)
script.on_game_event("AEA_BROADSIDE2_CHOOSE_MISSILE_3", false, function()
	setArtySlot("ARTILLERY_BROADSIDE2_MISSILE", 2)
end)
script.on_game_event("AEA_BROADSIDE2_CHOOSE_ION_3", false, function()
	setArtySlot("ARTILLERY_BROADSIDE2_ION", 2)
end)

local needSetArty = false
--Run on game load
script.on_init(function()
	needSetArty = true
end)

script.on_internal_event(Defines.InternalEvents.PROJECTILE_FIRE, function(projectile, weapon)
	if weapon.isArtillery and Hyperspace.ships(weapon.iShipId):HasAugmentation("SHIP_AEA_BROADSIDE3") > 0 then
		if weapon.blueprint.typeName == "BEAM" then
			projectile.sub_end = Hyperspace.Pointf(projectile.position.x, projectile.position.y - 300)
		elseif weapon.blueprint.typeName ~= "BOMB" then
			projectile.heading = -90
		end
	end
end)

script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
	if Hyperspace.ships.player and Hyperspace.ships.player.weaponSystem then
		if Hyperspace.ships.player.weaponSystem.weapons:size() > 0 then
			Hyperspace.playerVariables.aea_broadside_c_has_weapon = 1
		else
			Hyperspace.playerVariables.aea_broadside_c_has_weapon = 0
		end
	end
end)

script.on_game_event("AEA_BROADSIDE_C_SLOT1", false, function()
	setArtySlotFromWeapon(0)
end)
script.on_game_event("AEA_BROADSIDE_C_SLOT2", false, function()
	setArtySlotFromWeapon(1)
end)
script.on_game_event("AEA_BROADSIDE_C_SLOT3", false, function()
	setArtySlotFromWeapon(2)
end)

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	if Hyperspace.ships.player and needSetArty and shipManager:HasAugmentation("SHIP_AEA_BROADSIDE") > 0 and Hyperspace.playerVariables.aea_broadside_slot1 > 0 then
		needSetArty = flase
		if Hyperspace.playerVariables.aea_broadside_slot1 == 1 then
			setArtySlot("ARTILLERY_BROADSIDE_PIERCE", 0)
		elseif Hyperspace.playerVariables.aea_broadside_slot1 == 2 then
			setArtySlot("ARTILLERY_BROADSIDE_FOCUS", 0)
		elseif Hyperspace.playerVariables.aea_broadside_slot1 == 3 then
			setArtySlot("ARTILLERY_BROADSIDE_MISSILE", 0)
		elseif Hyperspace.playerVariables.aea_broadside_slot1 == 4 then
			setArtySlot("ARTILLERY_BROADSIDE_MINE", 0)
		end
		if Hyperspace.playerVariables.aea_broadside_slot2 == 1 then
			setArtySlot("ARTILLERY_BROADSIDE_PIERCE", 1)
		elseif Hyperspace.playerVariables.aea_broadside_slot2 == 2 then
			setArtySlot("ARTILLERY_BROADSIDE_FOCUS", 1)
		elseif Hyperspace.playerVariables.aea_broadside_slot2 == 3 then
			setArtySlot("ARTILLERY_BROADSIDE_MISSILE", 1)
		elseif Hyperspace.playerVariables.aea_broadside_slot2 == 4 then
			setArtySlot("ARTILLERY_BROADSIDE_MINE", 1)
		end
		if Hyperspace.playerVariables.aea_broadside_slot3 == 1 then
			setArtySlot("ARTILLERY_BROADSIDE_PIERCE", 2)
		elseif Hyperspace.playerVariables.aea_broadside_slot3 == 2 then
			setArtySlot("ARTILLERY_BROADSIDE_FOCUS", 2)
		elseif Hyperspace.playerVariables.aea_broadside_slot3 == 3 then
			setArtySlot("ARTILLERY_BROADSIDE_MISSILE", 2)
		elseif Hyperspace.playerVariables.aea_broadside_slot3 == 4 then
			setArtySlot("ARTILLERY_BROADSIDE_MINE", 2)
		end
	elseif Hyperspace.ships.player and needSetArty and shipManager:HasAugmentation("SHIP_AEA_BROADSIDE2") > 0 and Hyperspace.playerVariables.aea_broadside_slot1 > 0 then
		--print("SET slot1:"..Hyperspace.playerVariables.aea_broadside_slot1.. " slot2:"..Hyperspace.playerVariables.aea_broadside_slot2.." slot3:"..Hyperspace.playerVariables.aea_broadside_slot3)
		needSetArty = flase
		if Hyperspace.playerVariables.aea_broadside_slot1 == 1 then
			setArtySlot("ARTILLERY_BROADSIDE2_LASER", 0)
		elseif Hyperspace.playerVariables.aea_broadside_slot1 == 2 then
			setArtySlot("ARTILLERY_BROADSIDE2_BEAM", 0)
		elseif Hyperspace.playerVariables.aea_broadside_slot1 == 3 then
			setArtySlot("ARTILLERY_BROADSIDE2_MISSILE", 0)
		elseif Hyperspace.playerVariables.aea_broadside_slot1 == 4 then
			setArtySlot("ARTILLERY_BROADSIDE2_ION", 0)
		end
		if Hyperspace.playerVariables.aea_broadside_slot2 == 1 then
			setArtySlot("ARTILLERY_BROADSIDE2_LASER", 1)
		elseif Hyperspace.playerVariables.aea_broadside_slot2 == 2 then
			setArtySlot("ARTILLERY_BROADSIDE2_BEAM", 1)
		elseif Hyperspace.playerVariables.aea_broadside_slot2 == 3 then
			setArtySlot("ARTILLERY_BROADSIDE2_MISSILE", 1)
		elseif Hyperspace.playerVariables.aea_broadside_slot2 == 4 then
			setArtySlot("ARTILLERY_BROADSIDE2_ION", 1)
		end
		if Hyperspace.playerVariables.aea_broadside_slot3 == 1 then
			setArtySlot("ARTILLERY_BROADSIDE2_LASER", 2)
		elseif Hyperspace.playerVariables.aea_broadside_slot3 == 2 then
			setArtySlot("ARTILLERY_BROADSIDE2_BEAM", 2)
		elseif Hyperspace.playerVariables.aea_broadside_slot3 == 3 then
			setArtySlot("ARTILLERY_BROADSIDE2_MISSILE", 2)
		elseif Hyperspace.playerVariables.aea_broadside_slot3 == 4 then
			setArtySlot("ARTILLERY_BROADSIDE2_ION", 2)
		end
	elseif Hyperspace.ships.player and needSetArty and shipManager:HasAugmentation("SHIP_AEA_BROADSIDE3") > 0 and Hyperspace.playerVariables.aea_broadside_slot1 > 0 then
		needSetArty = false
		if Hyperspace.playerVariables.aea_broadside_c_slot1 > 0 then
			setArtySlot(allWeapons[Hyperspace.playerVariables.aea_broadside_c_slot1], 0)
		end
		if Hyperspace.playerVariables.aea_broadside_c_slot2 > 0 then
			setArtySlot(allWeapons[Hyperspace.playerVariables.aea_broadside_c_slot2], 1)
		end
		if Hyperspace.playerVariables.aea_broadside_c_slot3 > 0 then
			setArtySlot(allWeapons[Hyperspace.playerVariables.aea_broadside_c_slot3], 2)
		end
	elseif Hyperspace.ships.player and needSetArty and shipManager.iShipId == 0 and Hyperspace.playerVariables.aea_broadside_slot1 > 0 then
		needSetArty = false
	end
end)

local missileToggle = false
local broadSideFocusBlueprint = Hyperspace.Blueprints:GetWeaponBlueprint("AEA_BROADSIDE_FOCUS_BEAM")
script.on_internal_event(Defines.InternalEvents.PROJECTILE_FIRE, function(projectile, weapon)
	if projectile.extend.name == "ARTILLERY_BROADSIDE_PIERCE" then
		projectile.heading = -90
		local spaceManager = Hyperspace.App.world.space
		local laser = spaceManager:CreateLaserBlast(
			weapon.blueprint,
			Hyperspace.Pointf(projectile.position.x + 7, projectile.position.y),
			projectile.currentSpace,
			projectile.ownerId,
			Hyperspace.Pointf(projectile.target.x + 7, projectile.target.y),
			projectile.destinationSpace,
			projectile.heading)
		laser.entryAngle = projectile.entryAngle

		projectile.position = Hyperspace.Pointf(projectile.position.x - 7, projectile.position.y)
		projectile.target = Hyperspace.Pointf(projectile.target.x - 7, projectile.target.y)		
	elseif projectile.extend.name == "ARTILLERY_BROADSIDE_MISSILE" then
		projectile.heading = -90
		if missileToggle then
			projectile.position = Hyperspace.Pointf(projectile.position.x - 7 - 16, projectile.position.y)
		else
			projectile.position = Hyperspace.Pointf(projectile.position.x + 7 - 17, projectile.position.y)
		end
		missileToggle = not missileToggle
	elseif projectile.extend.name == "ARTILLERY_BROADSIDE_MINE" then
		projectile.heading = -90
	elseif projectile.extend.name == "ARTILLERY_BROADSIDE_FOCUS" then
		local spaceManager = Hyperspace.App.world.space
		local beam1 = spaceManager:CreateBeam(
			broadSideFocusBlueprint, 
			projectile.position, 
			projectile.currentSpace, 
			projectile.ownerId, 
			projectile.target, 
			Hyperspace.Pointf(projectile.target.x, projectile.target.y + 1), 
			projectile.destinationSpace, 
			1, 
			-0.1)
		beam1.sub_end = Hyperspace.Pointf(projectile.position.x, projectile.position.y - 300)
		projectile:Kill()
	elseif projectile.extend.name == "ARTILLERY_BROADSIDE_PIERCE_ENEMY" or projectile.extend.name == "ARTILLERY_BROADSIDE_PIERCE_ENEMY_OFFSET" then
		projectile.heading = -180
		local spaceManager = Hyperspace.App.world.space
		local laser = spaceManager:CreateLaserBlast(
			weapon.blueprint,
			Hyperspace.Pointf(projectile.position.x, projectile.position.y + 7),
			projectile.currentSpace,
			projectile.ownerId,
			Hyperspace.Pointf(projectile.target.x, projectile.target.y + 7),
			projectile.destinationSpace,
			projectile.heading)
		laser.entryAngle = projectile.entryAngle

		projectile.position = Hyperspace.Pointf(projectile.position.x, projectile.position.y - 7)
		projectile.target = Hyperspace.Pointf(projectile.target.x, projectile.target.y - 7)	
	elseif projectile.extend.name == "ARTILLERY_BROADSIDE2_LASER" or projectile.extend.name == "ARTILLERY_BROADSIDE2_ION" then
		projectile.heading = -90
	elseif projectile.extend.name == "ARTILLERY_BROADSIDE2_MISSILE" then
		projectile.heading = -90
		projectile.position = Hyperspace.Pointf(projectile.position.x - 8, projectile.position.y)
	elseif projectile.extend.name == "ARTILLERY_BROADSIDE2_BEAM" then
		projectile.sub_end = Hyperspace.Pointf(projectile.position.x, projectile.position.y - 300)
	end
end)

--[[ Remove OE blue options if you have FR's narrator augment
script.on_internal_event(Defines.InternalEvents.PRE_CREATE_CHOICEBOX, function(event)
  local ShipManager = Hyperspace.ships.player
  if ShipManager and true then
    local startEventOE = string.sub(event.eventName, 1, 4) == "AEA_" or string.match(event.eventName, "_AEA_")
    Choices = event:GetChoices()
    for choice in vter(Choices) do
      local choiceEventOE = string.sub(choice.event.eventName, 1, 4) == "AEA_" or string.match(choice.event.eventName, "_AEA_")
      if choice.requirement.blue or choice.requirement.object == "FR_NARRATIVE_SHIELD" and (startEventOE or choiceEventOE) then
        choice.hiddenReward = true
        choice.text.literal = true
        choice.text.data = "Outer Expansion Blue Option removed."
        choice.event.stuff.missiles = -999
        choice.event.stuff.scrap = -9999
      end
    end
  end
end)]]

local inCombatReq = {}
for crew in vter(Hyperspace.Blueprints:GetBlueprintList("LIST_CREW_AEA_CULT")) do
    inCombatReq[crew] = true
end

script.on_internal_event(Defines.InternalEvents.POWER_READY, function(power, powerState)
	if inCombatReq[power.crew.type] and power.crew.iShipId == 1 and Hyperspace.ships.enemy and Hyperspace.ships.enemy._targetable.hostile then
		return Defines.Chain.CONTINUE, Hyperspace.PowerReadyState.POWER_NOT_READY_OUT_OF_COMBAT
	end
	return Defines.Chain.CONTINUE, powerState
end)