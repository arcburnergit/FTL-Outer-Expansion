-- https://gist.github.com/jaredallard/ddb152179831dd23b230
function string:split(delimiter)
  local result = { }
  local from  = 1
  local delim_from, delim_to = string.find( self, delimiter, from  )
  while delim_from do
    table.insert( result, string.sub( self, from , delim_from-1 ) )
    from  = delim_to + 1
    delim_from, delim_to = string.find( self, delimiter, from  )
  end
  table.insert( result, string.sub( self, from  ) )
  return result
end

local vter = mods.multiverse.vter

mods.aea.better_juke = true
if not mods.better_juke then
	--print("better jukebox own mod")
	local emptyReq = Hyperspace.ChoiceReq()
	local blueReq = Hyperspace.ChoiceReq()
	blueReq.object = "pilot"
	blueReq.blue = true
	blueReq.max_level = mods.multiverse.INT_MAX
	blueReq.max_group = -1

	local juke_event_name = "STORAGE_CHECK_JUKEBOX"
	local juke_event_empty = "STORAGE_CHECK_JUKEBOX_EMPTY"
	local juke_event_empty_load = "STORAGE_CHECK_JUKEBOX_EMPTY_LOAD"

	local choice_table = {}
	local ips_source = {
		["FTL Multiverse"] = "MV",
		["STL Multiverse"] = "MV",
		["FTL Launch Release"] = "Vanilla",
		["FTL Advanced Edition"] = "Vanilla",
		["Outer Expansion"] = "OE",
		["Fishier Than Light"] = "Fishing",
		["Darkest Desire"] = "DD",
		["CE"] = "UC",
		["Unknown Contacts"] = "UC",
		["FTL Captain's Edition"] = "UC",
		["Forgotten Races"] = "FR",
		["Cosmic Metaloid Expansion"] = "CME",
		["Forgemaster"] = "FM",
	}

	script.on_internal_event(Defines.InternalEvents.PRE_CREATE_CHOICEBOX, function(event)
		local eventManager = Hyperspace.Event
		if event.eventName == juke_event_name and Hyperspace.metaVariables.better_juke_enabled == 0 then
			--event:RemoveChoice(0)--remove the exit event option
			choice_table = {}
			for current_choice in vter(event:GetChoices()) do
				local reqMet = false
				if current_choice.requirement then
					local req = current_choice.requirement
					local val = Hyperspace.ships.player:HasEquipment(req.object)
					--print("has req:"..tostring(req.object).." min:"..tostring(req.min_level).." max:"..tostring(req.max_level).." val:"..tostring(val))
					if (val >= (req.min_level or 1) and val <= (req.max_level or math.huge)) or req.object == "" then
						reqMet = true
					end
				else
					reqMet = true
				end
				if reqMet then
					local text_full = string.gsub(current_choice.text:GetText(), "%b[]", "")
					local text_list = text_full:split("\n")
					local first_line = text_list[1]

					local year = string.match(first_line, "%b()")
					if year then
						first_line = string.gsub(first_line, " %b()", "")
					end

					local version = string.match(first_line, "v[%.%d]+")
					if version then
						first_line = string.gsub(first_line, " v[%.%d]+", "")
					end

					local source = " "
					local title = first_line

					local colon_index = string.find(first_line, ":")
					if colon_index then
						source = string.sub(first_line, 1, colon_index - 1)
						title = string.sub(first_line, colon_index + 1, -1)
					end
					if ips_source[source] then source = ips_source[source] end

					local extra = ""
					if #text_list > 1 then
						extra = text_list[2]
					end

					--replace first character if it is a " "
					title = string.gsub(title, "^ ", "", 1)
					extra = string.gsub(extra, "^ ", "", 1)

					table.insert(choice_table, {event = current_choice.event.eventName, title = title, extra = extra, source = source, version = version, year = year})
				end
			end
			event.choices:clear()
			event.text.data = " "
			local emptyEvent = eventManager:CreateEvent("STORAGE_CHECK_JUKEBOX_EMPTY", 0, false)
			event:AddChoice(emptyEvent, " ", emptyReq, true)
		elseif event.eventName == juke_event_empty then
			event.text.data = " "
		end
	end)

	local render_juke = false
	local last_hovered = nil
	local scroll = 0
	local juke_stencil = Hyperspace.Resources:CreateImagePrimitiveString("event_stencil.png", 0, 0, 0, Graphics.GL_Color(0, 0, 0, 1), 1, false)
	local juke_box = Hyperspace.Resources:CreateImagePrimitiveString("event_juke_box.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false)
	local juke_select = Hyperspace.Resources:CreateImagePrimitiveString("event_juke_box_select.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false)
	local juke_popup = Hyperspace.Resources:CreateImagePrimitiveString("juke_popup_box.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false)

	script.on_internal_event(Defines.InternalEvents.POST_CREATE_CHOICEBOX, function(choiceBox, event)
		if event.eventName == juke_event_name and Hyperspace.metaVariables.better_juke_enabled == 0 then
			render_juke = true
			last_hovered = nil
		elseif event.eventName ~= juke_event_empty and event.eventName ~= juke_event_empty_load then
			render_juke = false
		end
	end)

	script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
		local menu = Hyperspace.App.menu
		if render_juke and menu.shipBuilder.bOpen then
			render_juke = false
			last_hovered = nil
		end
	end)

	script.on_init(function()
		if render_juke then
			render_juke = false
			last_hovered = nil
		end
	end)

	script.on_render_event(Defines.RenderEvents.MAIN_MENU, function() end, function()
		if render_juke then
			render_juke = false
			last_hovered = nil
		end
	end)

	local hovered_juke = nil
	local hovered_scroll = false
	local mouse_hold_scroll = nil

	local unknown_source = Hyperspace.Resources:CreateImagePrimitiveString("addons/unknown_source.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false)
	local juke_return = Hyperspace.Resources:CreateImagePrimitiveString("addons/juke_box_return.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false)
	local juke_off = Hyperspace.Resources:CreateImagePrimitiveString("addons/juke_box_off.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false)
	local addon_images = {
		["MV"] = {name = "FTL: Multiverse", image = Hyperspace.Resources:CreateImagePrimitiveString("addons/juke_mv_on.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false)},
		["Vanilla"] = {name = "Vanilla FTL", image = Hyperspace.Resources:CreateImagePrimitiveString("addons/juke_ftl_on.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false)},
		["OE"] = {name = "Outer Expansion", image = Hyperspace.Resources:CreateImagePrimitiveString("addons/aea_select2.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false)},
		["Fishing"] = {name = "Fishing", image = Hyperspace.Resources:CreateImagePrimitiveString("addons/fish_select2.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false)},
		["DD"] = {name = "Darkest Desire", image = Hyperspace.Resources:CreateImagePrimitiveString("addons/dd_select2.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false)},
		["UC"] = {name = "AI Cruisers", image = unknown_source},
		["FR"] = {name = "Forgotten Races", image = Hyperspace.Resources:CreateImagePrimitiveString("addons/fr_select2.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false)},
		["CME"] = {name = "Cosmic Metaloid Expansion", image = unknown_source},
		["FM"] = {name = "Forgemaster", image = Hyperspace.Resources:CreateImagePrimitiveString("addons/fm_select2.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false)}
	}
	local window = {x = 338, y = 151, w = 594, h = 369}
	local juke = {p = 6, w = 76, h = 42, icon_x = 51, icon_y = 27}
	local text = {x = 4, y = 4, w = 69, h = 32}
	local max_span = 7
	local sBox = {x = 580, y = 6, w = 8, h = 357}

	local popup = {x = 479, y = 524, icon_x = 276, icon_y = 12}
	local popup_source = {x = 101, y = 13, w = 173, h = 13}
	local popup_title = {x = 101, y = 28, w = 198, h = 66}
	local popup_extra = {x = 101, y = popup_title.h + 2, w = 198, h = 24}
	script.on_render_event(Defines.RenderEvents.CHOICE_BOX, function() end, function()
		local commandGui = Hyperspace.App.gui
		local eventManager = Hyperspace.Event
		hovered_juke = nil
		hovered_scroll = false
		if commandGui.event_pause and render_juke then
			--print("render")
			local window_offset = 0
			if Hyperspace.ships.enemy and Hyperspace.ships.enemy.ship.hullIntegrity.first > 0 then
				window_offset =  -150
			end
			Graphics.CSurface.GL_PushStencilMode()
			Graphics.CSurface.GL_SetStencilMode(Graphics.STENCIL_SET, 1,1)
			Graphics.CSurface.GL_ClearAll()
			Graphics.CSurface.GL_SetStencilMode(Graphics.STENCIL_SET, 1,1)
			Graphics.CSurface.GL_PushMatrix()
			Graphics.CSurface.GL_Translate(window.x + window_offset, window.y, 0)
			Graphics.CSurface.GL_RenderPrimitive(juke_stencil)
			Graphics.CSurface.GL_PopMatrix()
			Graphics.CSurface.GL_SetStencilMode(Graphics.STENCIL_USE, 1,1)

			local mPos = Hyperspace.Mouse.position

			local total_length = math.floor((#choice_table-1)/max_span) * (juke.h + juke.p) + juke.h + 3 * juke.p
			local window_length = window.h
			local scroll_ratio = math.max(1, total_length/window_length)
			--print("scroll total:"..tostring(total_length).." window:"..tostring(window_length).." ratio:"..tostring(scroll_ratio))
			local bar_size_mult = 1/scroll_ratio

			local scroll_max = sBox.h - (sBox.h * bar_size_mult)

			local bar = {x = window.x + window_offset + sBox.x, y = window.y + sBox.y + scroll}

			if mouse_hold_scroll then
				scroll = scroll + (Hyperspace.Mouse.position.y - mouse_hold_scroll)
				mouse_hold_scroll = Hyperspace.Mouse.position.y
			end

			if scroll > scroll_max then
				local scroll_diff = scroll - scroll_max
				scroll = scroll - (Hyperspace.FPS.SpeedFactor/16) * math.max(5 * scroll_diff, 25)
			elseif scroll < 0 then
				scroll = scroll + (Hyperspace.FPS.SpeedFactor/16) * math.max(-5 * scroll, 25)
			end

			if (mPos.x >= bar.x and mPos.x < bar.x + sBox.w and mPos.y >= bar.y and mPos.y < bar.y + sBox.h * bar_size_mult) or mouse_hold_scroll then
				Graphics.CSurface.GL_DrawRect(bar.x, bar.y, sBox.w, sBox.h * bar_size_mult, Graphics.GL_Color((58/255), (127/255), 1, 1))
				hovered_scroll = true
			else
				Graphics.CSurface.GL_DrawRect(bar.x, bar.y, sBox.w, sBox.h * bar_size_mult, Graphics.GL_Color(1, 1, 1, 1))
			end

			--local bar_ratio = total_length/sBox.h
			local scroll_translate = scroll * scroll_ratio
			for i, juke_tab in ipairs(choice_table) do
				local xOff = window.x + window_offset + juke.p + ((i-1)%max_span) * (juke.w + juke.p)
				local yOff = window.y - scroll_translate + juke.p + math.floor((i-1)/max_span) * (juke.h + juke.p)
				Graphics.CSurface.GL_PushMatrix()
				Graphics.CSurface.GL_Translate(xOff, yOff, 0)
				Graphics.CSurface.GL_RenderPrimitive(juke_box)

				--Graphics.freetype.easy_printAutoNewlines(6, source.x, source.y, source.w, juke_tab.source)
				Graphics.freetype.easy_printAutoNewlines(51, text.x, text.y, text.w, juke_tab.title)

				local source_image = (addon_images[juke_tab.source] and addon_images[juke_tab.source].image) or unknown_source
				if i == 1 then
					source_image = juke_return
				elseif i == 2 then
					source_image = juke_off
				end
				Graphics.CSurface.GL_PushMatrix()
				Graphics.CSurface.GL_Translate(juke.icon_x, juke.icon_y, 0)
				Graphics.CSurface.GL_RenderPrimitive(source_image)
				Graphics.CSurface.GL_PopMatrix()

				if mPos.x >= window.x + window_offset and mPos.x < window.x + window_offset + window.w and mPos.y >= window.y and mPos.y < window.y + window.h then
					if mPos.x >= xOff and mPos.x < xOff + juke.w and mPos.y >= yOff and mPos.y < yOff + juke.h then
						hovered_juke = i
						last_hovered = hovered_juke
						Graphics.CSurface.GL_RenderPrimitive(juke_select)
					end
				end
				Graphics.CSurface.GL_PopMatrix()
				
			end
			Graphics.CSurface.GL_SetStencilMode(Graphics.STENCIL_IGNORE, 1,1)
			Graphics.CSurface.GL_PopStencilMode()

			-- now handle popup
			if last_hovered then
				local juke_current = choice_table[last_hovered]
				Graphics.CSurface.GL_PushMatrix()
				Graphics.CSurface.GL_Translate(popup.x, popup.y, 0)
				Graphics.CSurface.GL_RenderPrimitive(juke_popup)

				local source = addon_images[juke_current.source] or {name = juke_current.source, image = unknown_source}
				if last_hovered == 1 then
					source = {name = juke_current.source, image = juke_return}
				elseif last_hovered == 2 then
					source = {name = juke_current.source, image = juke_off}
				end
				Graphics.CSurface.GL_PushMatrix()
				Graphics.CSurface.GL_Translate(popup.icon_x, popup.icon_y, 0)
				Graphics.CSurface.GL_RenderPrimitive(source.image)
				Graphics.CSurface.GL_PopMatrix()

				local extra = juke_current.extra
				if juke_current.version or juke_current.year then
					extra = extra.."\n"
				end
				if juke_current.version then
					extra = extra..juke_current.version.." "
				end
				if juke_current.year then
					extra = extra..juke_current.year
				end

				Graphics.freetype.easy_printAutoNewlines(5, popup_source.x, popup_source.y, popup_source.w, source.name..(juke_current.year or ""))
				Graphics.freetype.easy_printAutoNewlines(13, popup_title.x, popup_title.y, popup_title.w, juke_current.title)
				Graphics.freetype.easy_printAutoNewlines(6, popup_extra.x, popup_extra.y, popup_extra.w, juke_current.extra)

				Graphics.CSurface.GL_PopMatrix()
			end
		end
	end)

	script.on_internal_event(Defines.InternalEvents.ON_MOUSE_L_BUTTON_DOWN, function(x,y)
		local commandGui = Hyperspace.App.gui
		if hovered_juke and commandGui.event_pause then
			local juke_current = choice_table[hovered_juke]
			if hovered_juke == 2 then
				print("Now Playing: Current Sector Tracks")
			elseif hovered_juke ~= 1 then
				print("Now Playing: "..juke_current.title)
			end
			local worldManager = Hyperspace.App.world
			Hyperspace.CustomEventsParser.GetInstance():LoadEvent(worldManager, juke_current.event, false,-1)
		elseif hovered_scroll then
			mouse_hold_scroll = Hyperspace.Mouse.position.y
		end
		return Defines.Chain.CONTINUE
	end)

	script.on_internal_event(Defines.InternalEvents.ON_MOUSE_L_BUTTON_UP, function(x, y)
		local commandGui = Hyperspace.App.gui
		if mouse_hold_scroll and commandGui.event_pause then
			mouse_hold_scroll = nil
		end
		return Defines.Chain.CONTINUE
	end)

	script.on_internal_event(Defines.InternalEvents.ON_MOUSE_SCROLL, function(dir)
		local commandGui = Hyperspace.App.gui
		if render_juke and commandGui.event_pause then
			scroll = scroll + 10 * dir
		end
		return Defines.Chain.CONTINUE
	end)
end