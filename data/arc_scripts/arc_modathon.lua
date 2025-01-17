mods.amod = {}

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

local function midPoint(point1, point2)
    return Hyperspace.Pointf((point1.x + point2.x)/2, (point1.y + point2.y)/2)
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
    return Hyperspace.Pointf(mousePosition.x - enemyShipOriginX, mousePosition.y - enemyShipOriginY)
end

-- written by kokoro
local function enemyToGlobalSpace(pos)
    local cApp = Hyperspace.Global.GetInstance():GetCApp()
    local combatControl = cApp.gui.combatControl
    local position = combatControl.position
    local targetPosition = combatControl.targetPosition
    local enemyShipOriginX = position.x + targetPosition.x
    local enemyShipOriginY = position.y + targetPosition.y
    return Hyperspace.Pointf(pos.x + enemyShipOriginX, pos.y + enemyShipOriginY)
end

local function convertMousePositionToPlayerShipPosition(mousePosition)
    local cApp = Hyperspace.Global.GetInstance():GetCApp()
    local combatControl = cApp.gui.combatControl
    local playerPosition = combatControl.playerShipPosition
    return Hyperspace.Pointf(mousePosition.x - playerPosition.x, mousePosition.y - playerPosition.y)
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
local beamBlueprint = Hyperspace.Blueprints:GetWeaponBlueprint("AMOD_BEAM_MULTI")
script.on_internal_event(Defines.InternalEvents.PROJECTILE_FIRE, function(projectile, weapon)
    if projectile.extend.name == "AMOD_BEAM_MULTI" and weapon.boostLevel > 0 then
        --print("BOOST LEVEL:"..tostring(weapon.boostLevel))
        local spaceManager = Hyperspace.Global.GetInstance():GetCApp().world.space
        local target1 = projectile.target1
        local target2 = projectile.target2
        local left = true
        for id = 1, weapon.boostLevel - 1, 1 do
            local offset = math.ceil(id/2) 
            --print("ID:"..tostring(id).."OFFSET:"..tostring(offset))
            local newBeam11 = get_point_local_offset(target1, target2, 0, 25 * offset)
            local newBeam12 = get_point_local_offset(target2, target1, 0, -25 * offset)
            if left then
                newBeam11 = get_point_local_offset(target1, target2, 0, -25 * offset)
                newBeam12 = get_point_local_offset(target2, target1, 0, 25 * offset)
            end

            local beam1 = spaceManager:CreateBeam(
            beamBlueprint, 
            projectile.position, 
            projectile.currentSpace, 
            projectile.ownerId, 
            newBeam11, 
            newBeam12, 
            projectile.destinationSpace, 
            projectile.length, 
            projectile.heading)
            beam1.sub_start = projectile.sub_start
            left = not left
        end
    end
end)

local weaponName = nil
local lastMouseDown = {x = -1, y = -1}
local aiming = false
local touched = false
--local weaponSet = nil
local weaponBoost = 0
local weaponAutofiring = false


script.on_render_event(Defines.RenderEvents.SHIP, function() end, function(ship)
    if ship.iShipId == 0 then return end
    local shipManager = Hyperspace.ships(1-ship.iShipId)
    local cApp = Hyperspace.Global.GetInstance():GetCApp()
    local combatControl = cApp.gui.combatControl
    for weapon in vter(shipManager:GetWeaponList()) do
        if weapon.blueprint.name == "AMOD_BEAM_MULTI" then
            if weapon.targets:size() > 1 and weapon.boostLevel > 0 then
                local left = false
                local target1 = weapon.targets[0]
                local target2 = weapon.targets[1]

                for id = 1, weapon.boostLevel, 1 do
                    local offset = math.ceil(id/2) 
                    local newBeam11 = get_point_local_offset(target1, target2, 0, 25 * offset)
                    local newBeam12 = get_point_local_offset(target2, target1, 0, -25 * offset)
                    if left then
                        newBeam11 = get_point_local_offset(target1, target2, 0, -25 * offset)
                        newBeam12 = get_point_local_offset(target2, target1, 0, 25 * offset)
                    end

                    local midPoint1 = midPoint(newBeam11, newBeam12)
                    local alpha1 = math.atan((newBeam11.y-newBeam12.y), (newBeam11.x-newBeam12.x)) * 180 / math.pi
                    local beamString = "amod_beam.png"
                    if weapon.autoFiring then
                        beamString = "amod_beam_yellow.png"
                    else
                        beamString = "amod_beam.png"
                    end
                    local beam1 = Hyperspace.Resources:CreateImagePrimitiveString(beamString, -31, -9, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false)
                    beam1.textureAntialias = true
                    Graphics.CSurface.GL_PushMatrix()
                    Graphics.CSurface.GL_Translate(midPoint1.x,midPoint1.y,0)
                    Graphics.CSurface.GL_Scale(1,1,1)
                    Graphics.CSurface.GL_Rotate(alpha1, 0, 0, 1)
                    Graphics.CSurface.GL_RenderPrimitive(beam1)
                    Graphics.CSurface.GL_PopMatrix()
                    Graphics.CSurface.GL_DestroyPrimitive(beam1)
                    left = not left
                end
                
            end
        end
    end
    --[[
    if combatControl.weapControl.armedWeapon then
        local weapon = combatControl.weapControl.armedWeapon
        if weapon.blueprint.name == "AMOD_BEAM_MULTI" then
            if combatControl.aimingPoints:size() > 0 then
                local target1 = combatControl.aimingPoints[0]
                local target2 = combatControl.potentialAiming
                print("--------------------\nT1 X:"..tostring(target1.x).." T1 Y:"..tostring(target1.y).." T2 X:"..tostring(target2.x).." T2 Y:"..tostring(target2.y))

                local newBeam11 = get_point_local_offset(target1, target2, 0, 25)
                local newBeam12 = get_point_local_offset(target1, target2, 60, -25)
                print("B11 X:"..tostring(newBeam11.x).." B11 Y:"..tostring(newBeam11.y).." B12 X:"..tostring(newBeam12.x).." B12 Y:"..tostring(newBeam12.y))
                Graphics.CSurface.GL_DrawLine(newBeam11.x, newBeam11.y, newBeam12.x, newBeam12.y, 4, Graphics.GL_Color(0, 0, 0, 1))
                Graphics.CSurface.GL_DrawLine(newBeam11.x, newBeam11.y, newBeam12.x, newBeam12.y, 2, Graphics.GL_Color(1, 1, 1, 1))

                local newBeam21 = get_point_local_offset(target1, target2, 0, -25)
                local newBeam22 = get_point_local_offset(target1, target2, 60, 25)
                print("B21 X:"..tostring(newBeam21.x).." B21 Y:"..tostring(newBeam21.y).." B22 X:"..tostring(newBeam22.x).." B22 Y:"..tostring(newBeam22.y))
                Graphics.CSurface.GL_DrawLine(newBeam21.x, newBeam21.y, newBeam22.x, newBeam22.y, 4, Graphics.GL_Color(0, 0, 0, 1))
                Graphics.CSurface.GL_DrawLine(newBeam21.x, newBeam21.y, newBeam22.x, newBeam22.y, 2, Graphics.GL_Color(1, 1, 1, 1))
            end
        end
    end]]
    if weaponName and weaponName == "AMOD_BEAM_MULTI" and weaponBoost > 0 then
        --local weapon = weaponSet
        local target1 = Hyperspace.Pointf(lastMouseDown.x, lastMouseDown.y)
        if target1.x == -1 or target1.y == -1 then return end
        local target2 = combatControl.potentialAiming
        if target2.x == -1 or target2.y == -1 then return end

        local left = true
        for id = 1, weaponBoost, 1 do
            local offset = math.ceil(id/2) 
            local newBeam11 = get_point_local_offset(target1, target2, 0, 25 * offset)
            local newBeam12 = get_point_local_offset(target2, target1, 0, -25 * offset)
            if left then
                newBeam11 = get_point_local_offset(target1, target2, 0, -25 * offset)
                newBeam12 = get_point_local_offset(target2, target1, 0, 25 * offset)
            end

            local midPoint1 = midPoint(newBeam11, newBeam12)
            local alpha1 = math.atan((newBeam11.y-newBeam12.y), (newBeam11.x-newBeam12.x)) * 180 / math.pi
            local beamString = "amod_beam.png"
            if weaponAutofiring then
                beamString = "amod_beam_yellow.png"
            else
                beamString = "amod_beam.png"
            end
            local beam1 = Hyperspace.Resources:CreateImagePrimitiveString(beamString, -30, -9, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false)
            beam1.textureAntialias = true
            Graphics.CSurface.GL_PushMatrix()
            Graphics.CSurface.GL_Translate(midPoint1.x,midPoint1.y,0)
            Graphics.CSurface.GL_Scale(1,1,1)
            Graphics.CSurface.GL_Rotate(alpha1, 0, 0, 1)
            Graphics.CSurface.GL_RenderPrimitive(beam1)
            Graphics.CSurface.GL_PopMatrix()
            Graphics.CSurface.GL_DestroyPrimitive(beam1)
            left = not left
        end
    end
    --print("isAimingTouch:"..tostring(combatControl.isAimingTouch))]]
end)


script.on_internal_event(Defines.InternalEvents.SELECT_ARMAMENT_PRE, function(slot)
    --print(slot)
    local slotCount = 0
    for weapon in vter(Hyperspace.ships.player:GetWeaponList()) do
        if slotCount == slot then
            lastMouseDown = {x = -1, y = -1}
            weaponName = weapon.blueprint.name
            weaponBoost = weapon.boostLevel
            weaponAutofiring = weapon.autoFiring
            --weaponSet = weapon
            touched = false
            --print("SET NAME: "..weaponName)
        end
        slotCount = slotCount + 1
    end
    return Defines.Chain.CONTINUE, slot
end)


script.on_internal_event(Defines.InternalEvents.ON_MOUSE_L_BUTTON_DOWN, function(x,y) 
    if touched then
        weaponName = nil
        --print("reset")
        touched = false
        lastMouseDown = {x = -1, y = -1}
    end
    if Hyperspace.Global.GetInstance():GetCApp().world.bStartedGame and weaponName then 
        
        local cApp = Hyperspace.Global.GetInstance():GetCApp()
        local combatControl = cApp.gui.combatControl
        lastMouseDown.x = combatControl.potentialAiming.x
        lastMouseDown.y = combatControl.potentialAiming.y
        if lastMouseDown.x >= 0 and lastMouseDown.y >= 0 then
            touched = true
        end
        --print("SET_AIMING")
    end
    return Defines.Chain.CONTINUE
end)
script.on_internal_event(Defines.InternalEvents.ON_MOUSE_R_BUTTON_DOWN, function(x,y) 
    if touched then
        weaponName = nil
        --print("reset")
        touched = false
        lastMouseDown = {x = -1, y = -1}
    end
end)

