local root = document.root

for blueprint in root:children() do
    if blueprint.name == "shipBlueprint" then
    	local layoutString = blueprint.attrs.layout --find the layout so we can read the text file later
        local a = nil
        pcall(function() a = mod.vfs.pkg:read("/data/"..layoutString..".txt") end)
        local aea_layout = mod.xml.element("aea_layout", {name = layoutString})
        if a then
        	local roomList = {}
            for idx, x, y, w, h in string.gmatch(a, "ROOM%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)") do
            	local room_node = mod.xml.element("room", {})
            	room_node:append(idx)
            	aea_layout:append(room_node)
            end
        end
        root:append(aea_layout)
    end
end