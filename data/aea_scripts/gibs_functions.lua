mods.aea = {}

-----------------------
-- UTILITY FUNCTIONS --
-----------------------

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
        check_for_room(roomShape.x - 17,               roomShape.y + offset + 17)
        check_for_room(roomShape.x + roomShape.w + 17, roomShape.y + offset + 17)
    end
    if diagonals then
        check_for_room(roomShape.x - 17,               roomShape.y - 17)
        check_for_room(roomShape.x + roomShape.w + 17, roomShape.y - 17)
        check_for_room(roomShape.x + roomShape.w + 17, roomShape.y + roomShape.h + 17)
        check_for_room(roomShape.x - 17,               roomShape.y + roomShape.h + 17)
    end
    return adjacentRooms
end

mods.aea.gibs_table = {}
mods.aea.stain_table = {}

gibImages = RandomList:New{"aea_gibs/human1.png", "aea_gibs/human2.png", "aea_gibs/human3.png"}

function mods.aea.createGib(position)
    local newGib = {}
    newGib.x = position.x
    newGib.y = position.y
    newGib.image = Hyperspace.Resources:CreateImagePrimitiveString(gibImages:GetItem(), 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
    newGib.size = 4.0
    newGib.velocityX = 0
    newGib.velocityY = 0
    table.insert(gibs_table, newGib)
end

script.on_render_event(Defines.RenderEvents.SHIP_SPARKS, function()
end, function() end)