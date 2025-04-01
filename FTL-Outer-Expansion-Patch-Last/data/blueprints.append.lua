local root = document.root

-- file example: "/data/kestral.txt
local function getRoomCount(file)
    local file_as_string = mod.vfs.pkg:read(file)
    local rooms_iter = string.gmatch(file_as_string, "ROOM%s+(%d+)")
    return mod.iter.count(rooms_iter)
end

local systemsToAppend = {}
systemsToAppend["aea_super_shields"] = {attributes = {power = 1, start = "false"}, manning = true, replace_sys = "cloaking", 
    image_list = {{room_image = "room_shields", w = 2, h = 2, top = "00", bottom = "11", left="10", right="01", manning_slot = 0, manning_direction = "left"},
        {room_image = "room_shields_aea_r", w = 2, h = 2, top = "01", bottom = "10", left="11", right="00", manning_slot = 1, manning_direction = "up"},
        {room_image = "room_shields_aea_rr", w = 2, h = 2, top = "11", bottom = "00", left="10", right="01", manning_slot = 3, manning_direction = "right"},
        {room_image = "room_shields_aea_rrr", w = 2, h = 2, top = "01", bottom = "10", left="00", right="11", manning_slot = 2, manning_direction = "down"},
        {room_image = "room_shields_2", w = 2, h = 2, top = "10", bottom = "00", left="10", right="01", manning_slot = 0, manning_direction = "left"},
        {room_image = "room_shields_aea_2_r", w = 2, h = 2, top = "01", bottom = "10", left="00", right="10", manning_slot = 1, manning_direction = "up"},
        {room_image = "room_shields_aea_2_rr", w = 2, h = 2, top = "00", bottom = "01", left="10", right="01", manning_slot = 3, manning_direction = "right"},
        {room_image = "room_shields_aea_2_rrr", w = 2, h = 2, top = "01", bottom = "10", left="01", right="00", manning_slot = 2, manning_direction = "down"},
        {room_image = "room_shields_3", w = 2, h = 2, top = "01", bottom = "00", left="01", right="10", manning_slot = 2, manning_direction = "left"},
        {room_image = "room_shields_aea_3_r", w = 2, h = 2, top = "10", bottom = "01", left="00", right="01", manning_slot = 0, manning_direction = "up"},
        {room_image = "room_shields_aea_3_rr", w = 2, h = 2, top = "00", bottom = "10", left="01", right="10", manning_slot = 1, manning_direction = "right"},
        {room_image = "room_shields_aea_3_rrr", w = 2, h = 2, top = "10", bottom = "01", left="10", right="00", manning_slot = 3, manning_direction = "down"},
        {room_image = "room_shields_4", w = 2, h = 2, top = "11", bottom = "00", left="10", right="00", manning_slot = 0, manning_direction = "left"},
        {room_image = "room_shields_5", w = 2, h = 2, top = "10", bottom = "10", left="01", right="00", manning_slot = 0, manning_direction = "up"},
        {room_image = "room_shields_6", w = 2, h = 2, top = "10", bottom = "01", left="10", right="00", manning_slot = 0, manning_direction = "left"},
        {room_image = "room_shields_7", w = 2, h = 2, top = "01", bottom = "01", left="10", right="00", manning_slot = 1, manning_direction = "up"},
        {room_image = "room_shields_8", w = 2, h = 2, top = "00", bottom = "00", left="10", right="11", manning_slot = 0, manning_direction = "left"},
        {room_image = "room_shields_9", w = 2, h = 2, top = "01", bottom = "01", left="00", right="01", manning_slot = 1, manning_direction = "up"},
        {room_image = "room_shields_10", w = 2, h = 2, top = "01", bottom = "01", left="00", right="01", manning_slot = 3, manning_direction = "down"},
        {room_image = "room_shields_11", w = 2, h = 1, top = "00", bottom = "11", left="0", right="1", manning_slot = 1, manning_direction = "down"},
        {room_image = "room_shields_aea_cloak", w = 2, h = 2, top = "01", bottom = "00", left="00", right="10", manning_slot = 1, manning_direction = "up"},
        {room_image = "room_shields_aea_cloak_2", w = 2, h = 2, top = "00", bottom = "01", left="00", right="01", manning_slot = 3, manning_direction = "right"},
        {room_image = "room_shields_aea_cloak_10", w = 2, h = 2, top = "10", bottom = "00", left="10", right="00", manning_slot = 0, manning_direction = "left"},
        {room_image = "room_shields_aea_cloak_11", w = 2, h = 2, top = "00", bottom = "10", left="01", right="00", manning_slot = 1, manning_direction = "down"},
        {room_image = "room_shields_aea_cloak_3", w = 2, h = 1, top = "11", bottom = "00", left="0", right="0", manning_slot = 0, manning_direction = "up"},
        {room_image = "room_shields_aea_cloak_12", w = 2, h = 2, top = "00", bottom = "11", left="00", right="00", manning_slot = 3, manning_direction = "down"},
        {room_image = "room_shields_aea_11_r", w = 1, h = 2, top = "0", bottom = "1", left="11", right="00", manning_slot = 1, manning_direction = "left"},
        {room_image = "room_shields_aea_11_rr", w = 2, h = 1, top = "11", bottom = "00", left="1", right="0", manning_slot = 0, manning_direction = "up"},
        {room_image = "room_shields_aea_11_rrr", w = 1, h = 2, top = "1", bottom = "0", left="00", right="11", manning_slot = 0, manning_direction = "right"},
        {room_image = "room_shields_aea_11_f", w = 2, h = 1, top = "00", bottom = "11", left="1", right="0", manning_slot = 0, manning_direction = "down"},
        {room_image = "room_shields_aea_11_fr", w = 1, h = 2, top = "1", bottom = "0", left="11", right="00", manning_slot = 0, manning_direction = "left"},
        {room_image = "room_shields_aea_11_frr", w = 2, h = 1, top = "11", bottom = "00", left="0", right="1", manning_slot = 1, manning_direction = "up"},
        {room_image = "room_shields_aea_11_frrr", w = 1, h = 2, top = "0", bottom = "1", left="00", right="11", manning_slot = 1, manning_direction = "right"},
        {room_image = "room_shields_aea_1", w = 1, h = 1, top = "1", bottom = "0", left="0", right="0", manning_slot = 0, manning_direction = "up"},
        {room_image = "room_shields_aea_2", w = 1, h = 1, top = "0", bottom = "0", left="0", right="1", manning_slot = 0, manning_direction = "right"},
        {room_image = "room_shields_aea_3", w = 1, h = 1, top = "0", bottom = "1", left="0", right="0", manning_slot = 0, manning_direction = "down"},
        {room_image = "room_shields_aea_4", w = 1, h = 1, top = "0", bottom = "0", left="1", right="0", manning_slot = 0, manning_direction = "left"},
        {room_image = "room_shields_aea_5", w = 2, h = 1, top = "0", bottom = "0", left="0", right="1", manning_slot = 1, manning_direction = "right"},
        {room_image = "room_shields_aea_6", w = 3, h = 1, top = "0", bottom = "0", left="0", right="1", manning_slot = 2, manning_direction = "right"},
        {room_image = "room_shields_aea_7", w = 4, h = 1, top = "0", bottom = "0", left="0", right="1", manning_slot = 3, manning_direction = "right"},
        {room_image = "room_shields_aea_8", w = 1, h = 2, top = "0", bottom = "1", left="00", right="00", manning_slot = 1, manning_direction = "down"},
        {room_image = "room_shields_aea_9", w = 1, h = 3, top = "0", bottom = "1", left="000", right="000", manning_slot = 2, manning_direction = "down"},
        {room_image = "room_shields_aea_10", w = 1, h = 4, top = "0", bottom = "1", left="0000", right="0000", manning_slot = 3, manning_direction = "down"},
    }
}

local function noDoorOverlap(rT, rB, rL, rR, iT, iB, iL, iR, shipName)
    local room = table.concat({rT,rB,rL,rR},"")
    local roomNumber = tonumber(room,2)
    local image = table.concat({iT,iB,iL,iR},"")
    local imageNumber = tonumber(image,2)
    return roomNumber & imageNumber == 0
end

local patchedOE = false
for child in root:children() do
    if child.name == "patchedOE" then
        patchedOE = true
        print("OE was patched before OE patch last")
    end
end

for blueprint in root:children() do
    if blueprint.name == "shipBlueprint" and patchedOE then
        local layoutString = blueprint.attrs.layout --find the layout so we can read the text file later
        local a = nil
        pcall(function() a = mod.vfs.pkg:read("/data/"..layoutString..".txt") end) 
        if a then
            local roomList = {}
            for idx, x, y, w, h in string.gmatch(a, "ROOM%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)") do
                roomList[idx+1] = { x = tonumber(x), y = tonumber(y), w = tonumber(w), h = tonumber(h), size = (w*h)}
            end

            local doorList = {}
            for x, y, r1, r2, vert in string.gmatch(a, "DOOR%s+(%d+)%s+(%d+)%s+(-?%d+)%s+(-?%d+)%s+(%d+)") do
                doorList[#doorList + 1] = { x = tonumber(x), y = tonumber(y), rl = tonumber(r1), rr = tonumber(r2), vert = tonumber(vert)}
            end
            local shipName = ""

            local roomDoors = {}
            if blueprint.attrs.name then shipName = blueprint.attrs.name end
            for room, roomTable in ipairs(roomList) do
                local wallTop = {}
                local wallBottom = {}
                local wallLeft = {}
                local wallRight = {}
                local airlock = false

                for i = 1, roomTable.w do
                    wallTop[i] = 0
                    wallBottom[i] = 0
                end
                for i = 1, roomTable.h do
                    wallLeft[i] = 0
                    wallRight[i] = 0
                end
                --print("ROOM:"..(room-1).." w:"..roomTable.w.." h:"..roomTable.h)
                for idx, doorTable in ipairs(doorList) do
                    local x = doorTable.x - roomTable.x
                    local y = doorTable.y - roomTable.y
                    if doorTable.vert == 0 then
                        if y == 0 and x >= 0 and x < roomTable.w then
                            wallTop[x+1] = 1
                            if doorTable.rl < 0 or doorTable.rr < 0 then
                                airlock = true
                            end
                        elseif y == roomTable.h and x >= 0 and x < roomTable.w then
                            wallBottom[x+1] = 1
                            if doorTable.rl < 0 or doorTable.rr < 0 then
                                airlock = true
                            end
                        end
                    else
                        if x == 0 and y >= 0 and y < roomTable.h then
                            wallLeft[y+1] = 1
                            if doorTable.rl < 0 or doorTable.rr < 0 then
                                airlock = true
                            end
                        elseif x == roomTable.w and y >= 0 and y < roomTable.h then
                            wallRight[y+1] = 1
                            if doorTable.rl < 0 or doorTable.rr < 0 then
                                airlock = true
                            end
                        end
                    end
                end

                local wallTopString = table.concat(wallTop, "")
                local wallBottomString = table.concat(wallBottom, "")
                local wallLeftString = table.concat(wallLeft, "")
                local wallRightString = table.concat(wallRight, "")
                
                --print("ROOM:"..(room-1).." top:"..wallTopString.." bottom:"..wallBottomString.." left:"..wallLeftString.." right:"..wallRightString)
                roomDoors[room-1] = {w = roomTable.w, h = roomTable.h, top = wallTopString, bottom = wallBottomString, left = wallLeftString, right = wallRightString, airlock = airlock}
            end

            local isEnemyShip = true
            local systemListElement = nil
            -- find systemList
            for systemList in blueprint:children() do
                if systemList.name == "name" then
                    isEnemyShip = false
                elseif systemList.name == "systemList" then
                    systemListElement = systemList
                end
            end


            if not isEnemyShip then
                local takenRooms = {}
                for system in systemListElement:children() do
                    --print("SYSTEM:"..system.name)
                    local start = true
                    local room = nil
                    for name, attribute in system:attrs() do
                        if name=="start" then
                            start = attribute
                        elseif name=="room" then
                            room = attribute
                            --takenRooms[attribute] = system.name
                        end
                    end
                    if room and (system.name ~= "artillery" or start == true) then
                        if not takenRooms[room] then
                            takenRooms[room] = {}
                        end
                        takenRooms[room][system.name] = true
                    end
                end
                -- append new systems
                --print("searching ship:"..shipName)
                for system, sysInfo in pairs(systemsToAppend) do
                    local hasSystem = false
                    local targetRoom = nil
                    local targetRoomSize = nil
                    if sysInfo.replace_sys then
                        for room, roomTable in ipairs(roomList) do
                            if takenRooms[room-1] and takenRooms[room-1][sysInfo.replace_sys] then
                                targetRoom = room-1
                                targetRoomSize = roomTable.size
                            end
                            if takenRooms[room-1] and takenRooms[room-1][system] then
                                hasSystem = true
                            end
                        end
                    end
                    if not targetRoom then
                        for room, roomTable in ipairs(roomList) do
                            if not takenRooms[room-1] and not roomDoors[room-1].airlock then 
                                if not targetRoom or not targetRoomSize then
                                    targetRoom = room-1
                                    targetRoomSize = roomTable.size
                                elseif roomTable.size > targetRoomSize then
                                    targetRoom = room-1
                                    targetRoomSize = roomTable.size
                                end
                            elseif takenRooms[room-1] and takenRooms[room-1][system] then
                                hasSystem = true
                            end
                        end
                    end
                    if not targetRoom then
                        for room, roomTable in ipairs(roomList) do
                            if not takenRooms[room-1] then 
                                if not targetRoom or not targetRoomSize  then
                                    targetRoom = room-1
                                    targetRoomSize = roomTable.size
                                elseif roomTable.size > targetRoomSize then
                                    targetRoom = room-1
                                    targetRoomSize = roomTable.size
                                end
                            end
                        end
                    end
                    if targetRoom and not hasSystem then
                        print("Applying to ship:"..shipName)
                        local newSystem = mod.xml.element(system, sysInfo.attributes)
                        newSystem.attrs.room = targetRoom

                        local roomTable = roomDoors[targetRoom]
                        local roomImage = nil
                        local manningSlot = nil
                        local manningDirection = nil
                        for idx, roomImageTable in ipairs(sysInfo.image_list) do
                            if not (roomImage) and roomImageTable.w <= roomTable.w and roomImageTable.h <= roomTable.h then
                                --print("check image")
                                local roomTop = roomTable.top
                                local roomBottom = roomTable.bottom
                                local roomLeft = roomTable.left
                                local roomRight = roomTable.right
                                local longString = "1111111111111111111111111111111111111111111111111111111111111111"
                                if roomImageTable.w < roomTable.w and roomImageTable.h == roomTable.h then
                                    roomRight = string.sub(longString, 1, roomImageTable.h)
                                    roomTop = string.sub(roomTable.top, 1, roomImageTable.w)
                                    roomBottom = string.sub(roomTable.bottom, 1, roomImageTable.w)
                                elseif roomImageTable.w == roomTable.w and roomImageTable.h < roomTable.h then
                                    roomBottom = string.sub(longString, 1, roomImageTable.w)
                                    roomLeft = string.sub(roomTable.left, 1, roomImageTable.h)
                                    roomRight = string.sub(roomTable.right, 1, roomImageTable.h)
                                elseif roomImageTable.w < roomTable.w and roomImageTable.h < roomTable.h then
                                    roomRight = string.sub(longString, 1, roomImageTable.h)
                                    roomBottom = string.sub(longString, 1, roomImageTable.w)
                                    roomTop = string.sub(roomTable.top, 1, roomImageTable.w)
                                    roomLeft = string.sub(roomTable.left, 1, roomImageTable.h)
                                end
                                if noDoorOverlap(roomTop, roomBottom, roomLeft, roomRight, roomImageTable.top, roomImageTable.bottom, roomImageTable.left, roomImageTable.right, shipName) then
                                    roomImage = roomImageTable.room_image
                                    --print("image safe")
                                    if sysInfo.manning == true then
                                        if roomImageTable.manning_slot >= roomImageTable.w then
                                            manningSlot = roomImageTable.manning_slot + roomTable.w - roomImageTable.w
                                        else
                                            manningSlot = roomImageTable.manning_slot
                                        end
                                        manningDirection = roomImageTable.manning_direction
                                    end
                                end
                            end
                        end
                        if roomImage then
                            --print("image added")
                            newSystem.attrs.img = roomImage
                        end
                        if manningSlot and manningDirection then
                            local slot = mod.xml.element("slot", {})
                            local direction = mod.xml.element("direction", {})
                            local number = mod.xml.element("number", {})
                            direction:append(manningDirection)
                            number:append(tostring(manningSlot))
                            slot:append(direction)
                            slot:append(number)
                            newSystem:append(slot)
                        elseif sysInfo.manning == true then
                            --print("USED BACKUP MANNING IMAGE IN:"..shipName)
                            newSystem.attrs.img = "room_computer"
                            local slot = mod.xml.element("slot", {})
                            local direction = mod.xml.element("direction", {})
                            local number = mod.xml.element("number", {})
                            direction:append("up")
                            number:append("0")
                            slot:append("up")
                            slot:append("0")
                            newSystem:append(slot)
                        end

                        systemListElement:append(newSystem)
                        for name, attribute in newSystem:attrs() do
                            if name=="room" then
                                takenRooms[attribute] = newSystem.name
                            end
                        end
                    end

                end
            end
        end
    end
end

--print("systems appended")

local function printSystemLists()
    for blueprint in root:children() do
        if blueprint.name == "shipBlueprint" then
            for name, attribute in blueprint:attrs() do
                if name == "name" then
                    print("ship:"..attribute)
                end
            end

            local isEnemyShip = true
            -- find systemList
            for systemList in blueprint:children() do
                if systemList.name == "name" then
                    isEnemyShip = false
                elseif systemList.name == "systemList" and not isEnemyShip then
                    for system in systemList:children() do
                        mod.debug.pretty_print("  "..system.name)
                        for name, attribute in system:attrs() do
                            mod.debug.pretty_print("    "..name..":"..tostring(attribute))
                        end
                        for slot in system:children() do
                            if slot.name == "slot" then
                                local direction = "none"
                                local number = -1
                                for child in slot:children() do
                                    if child.name == "direction" then
                                        direction = child.textContent
                                    elseif child.name == "number" then
                                        number = tonumber(child.textContent)
                                    end
                                end
                                mod.debug.pretty_print("      slot direction:"..direction.." number:"..number)
                            end
                        end
                    end
                end
            end
        end
    end
end

--printSystemLists()