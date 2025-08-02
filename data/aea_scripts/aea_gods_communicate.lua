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

local offset_point_direction = mods.multiverse.offset_point_direction

local emptyReq = Hyperspace.ChoiceReq()
local blueReq = Hyperspace.ChoiceReq()
blueReq.object = "pilot"
blueReq.blue = true
blueReq.max_level = mods.multiverse.INT_MAX
blueReq.max_group = -1

mods.aea.godEvents = {}
local godEvents = mods.aea.godEvents
godEvents["AEA_JUSTICIER_BOOK_UNLOCK"] = {
	varient = 1,
	event = {
		text="You are a peculiar one, you have a... strange essense about you, it's as if another like me has left their mark on you.\nNever the less, you are promising, take my book, it is a powerful tool should you attract the attention of #############.\nI will make it available to you from the start, do not be afraid to take it.", 
		choices={
			{
				text="I, uh, who are you?", 
				event = {
					text="That is unimportant, for now I am your master and you are my disciple.\n\nNow I must go, look for my book, and good luck.",
					choices={
						{
							text="Continue...", finish=true
						}
					}
				}
			}
		}
	},
	finish = "AEA_JUSTICIER_BOOK_LOAD_UNLOCK"
}
godEvents["AEA_JUSTICIER_BOOK_UNLOCK"] = {
	varient = 1,
	event = {
		text="You are back. I will grant you my power, do not disappoint me.", 
		choices={
			{
				text="Continue...", 
				finish=true
			}
		}
	},
	finish = "AEA_JUSTICIER_BOOK_LOAD"
}
godEvents["AEA_POWER_CELL_SPEAK"] = {
	varient = 2,
	event = {
		text="And Whoooo are yooou my strange friend...\n                     \nMy my, you are strong of mind aren't you- Or is that another I sense on you...\n                     \nYes, yes, another has left their mark on you, that I am sure, I do not recognise whoever that is though.\nIt is strange that they appear to be protecting you, preventing you from being pulled in...\n                     \nYou are surely a mystery, however you do not seem to be a threat, take the item and be away from here.", 
		choices={
			{
				text="I, uh, what-", 
				finish=true
			}
		}
	},
	finish = "AEA_EVENT_EXIT"
}
godEvents["AEA_OLD_GATE_SPEAK"] = {
	varient = 2,
	event = {
		text="Ooooohhh noooooo what have you done, you've doomed yourself and everyone else.\n                     \nYou must undo this, yes, come to me.\nYou must destroy the gate, but not on this side no, you must come here and destroy it on the other side.", 
		choices={
			{
				text="Where? Do what?", 
				event={
					text="I will pull you in. Find the Lylmik fleet and destroy the gate, or else I fear this reality will fall to them.\nSucceed and I will let you and your peers go home, fail and you won't have a home to go to...\n                     \nGood luck.",
					choices={
						{
							text="Continue...", 
							finish=true
						}
					}
				}
			}
		}
	},
	finish = "AEA_OLD_GATE_WARP"
}
godEvents["AEA_OLD_VICTORY_SPEAK"] = {
	varient = 2,
	event = {
		text="The gate is destroyed, I will save you and your crew and send you home, you've done more than you can imagine here today.\nI will answer ONE of your questions before releasing you.", 
		choices={
			{
				text="Who are you?", 
				event={
					text="You can call me Balance.\nI keep my two siblings in check, both are far more powerful than me, but without me inbetween they will destroy each other,\nand perhaps even the multiverse.\nGood luck on your adventures, Captain.",
					choices={
						{
							text="Continue...", 
							finish=true
						}
					}
				}
			},
			{
				text="What are you?", 
				event={
					text="I am one of three, although from what I've sensed on you there are more like us out there.\nWe came from a far away cluster, however I have been trapped here with the Lylmik's, they keep me here and feed off my power, but in retribution I trap them in the few universes they have control over.\nGood luck on your adventures, Captain.",
					choices={
						{
							text="Continue...", 
							finish=true
						}
					}
				}
			},
			{
				text="Who is the one with the red book?", 
				req="aea_dark_book_unlock",
				event={
					text="That would be my sibling, Antithesis, they are locked in an eternal struggle with my other Sibling, Contradiction. If you have met either of them you must not listen to their plans, no good will come from it.\nGood luck on your adventures, Captain.",
					choices={
						{
							text="Continue...", 
							finish=true
						}
					}
				}
			}
		}
	},
	finish = "AEA_OLD_VICTORY_WIN"
}

script.on_internal_event(Defines.InternalEvents.PRE_CREATE_CHOICEBOX, function(event)
	local eventManager = Hyperspace.Event
	if godEvents[event.eventName] then
		event:RemoveChoice(0)
		event.text.data = " "
		local emptyEvent = eventManager:CreateEvent("AEA_EVENT_EMPTY", 0, false)
		event:AddChoice(emptyEvent, " ", emptyReq, true)
	end
end)

local renderEvent = nil
local choicesChosenList = {}
local timer = 0
local fade = 0

script.on_internal_event(Defines.InternalEvents.POST_CREATE_CHOICEBOX, function(choiceBox, event)
	if godEvents[event.eventName] then
		renderEvent = event.eventName
		choicesChosenList = {}
		timer = 0
		fade = 0
	elseif event.eventName ~= "AEA_EVENT_EMPTY" and event.eventName ~= "AEA_EVENT_EMPTY_LOAD" then
		renderEvent = nil
	end
end)

local padding = {x = 16, y = 8}

local wavy_stencil = {image = Hyperspace.Resources:CreateImagePrimitiveString("wavy_stencil.png", -612, -612, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false),
	image_inverse = Hyperspace.Resources:CreateImagePrimitiveString("wavy_stencil_inverse.png", -612, -612, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false),
	width = 612,
	height = 612
}

local hex_stencil = {image = Hyperspace.Resources:CreateImagePrimitiveString("hex_stencil.png", 0, -400, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false),
	width = 400,
	height = 400
}

local teardrop = Hyperspace.Resources:CreateImagePrimitiveString("teardrop.png", -10, -800, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false)

local varient1 = {lastFlash = 0, random = 5, colour = {r = 0.25, g = 0, b = 0}, drops = {}}
local varient2 = {offset = {x = 612/2, y = 612/2}, velocity = {x = 0, y = 0}, aimAngle = 0, aimSpeed = 0, lastSetTime = 0, setTimer = 0}

local speedUp = false
local hoveredChoice = nil
local lastVarient = nil
script.on_render_event(Defines.RenderEvents.CHOICE_BOX, function() end, function()
	local commandGui = Hyperspace.App.gui
	local eventManager = Hyperspace.Event
	hoveredChoice = nil
	if commandGui.event_pause and renderEvent then
		local textColourDefault = {r = 1, g = 1, b = 1}
		local textColourSelect = {r = 1, g = 1, b = 0}
		local varient = godEvents[renderEvent].varient
		lastVarient = varient
		local source = godEvents[renderEvent].event
		local choicesDepth = {}
		local i = 1
		while #choicesDepth < #choicesChosenList do
			local choices = source.choices
			local chosen = choicesChosenList[i]
			table.insert(choicesDepth, chosen)
			local chosenChoice = choices[chosen]
			if chosenChoice.finish then
				varient = 0
				local worldManager = Hyperspace.App.world
				Hyperspace.CustomEventsParser.GetInstance():LoadEvent(worldManager, godEvents[renderEvent].finish, false,-1)
				renderEvent = nil
			else
				source = chosenChoice.event
			end
			i = i + 1
		end
		if fade < 1 then
			fade = math.min(1, fade + Hyperspace.FPS.SpeedFactor/16)
		elseif fade == 1 and speedUp then
			timer = timer + 20 * Hyperspace.FPS.SpeedFactor/16
		elseif fade == 1 then
			timer = timer + 2 * Hyperspace.FPS.SpeedFactor/16
		end
		if varient == 1 then
			if timer >= varient1.lastFlash + varient1.random then
				varient1.colour.r = 0.5
				varient1.lastFlash = timer
				varient1.random = math.random(5, 10)
			end
			if varient1.colour.r > 0.25 then
				varient1.colour.r = math.max(0.25, varient1.colour.r - ((speedUp and 20) or 1) * Hyperspace.FPS.SpeedFactor/16)
			end
			Graphics.CSurface.GL_DrawRect(0, 0, 1280, 720, Graphics.GL_Color(varient1.colour.r, varient1.colour.b, varient1.colour.b, fade))
			if #varient1.drops == 0 then
				for i = 0, 99 do
					local dropSpeed = math.random(20, 60)
					local x = math.random(-10, 1290)
					local y = math.random(-10, 720)
					table.insert(varient1.drops, {speed = dropSpeed, x = x, y = y, fade = 1})
				end
			elseif #varient1.drops <= 100 then
				local dropSpeed = math.random(20, 60)
				local x = math.random(-10, 1290)
				local y = -10
				table.insert(varient1.drops, {speed = dropSpeed, x = x, y = y, fade = 1})
			end
			local iRemove = nil
			for i, dropTable in ipairs(varient1.drops) do
				if dropTable.y <= 750 then
					dropTable.y = dropTable.y + dropTable.speed * ((speedUp and 20) or 1) * Hyperspace.FPS.SpeedFactor/16
				else
					dropTable.fade = math.max(0, dropTable.fade - 0.25 * ((speedUp and 20) or 1) * Hyperspace.FPS.SpeedFactor/16)
					if dropTable.fade == 0 then
						iRemove = i
					end
				end
				local dropFade = fade == 1 and dropTable.fade or fade
				Graphics.CSurface.GL_PushMatrix()
				Graphics.CSurface.GL_Translate(dropTable.x, dropTable.y, 0)
			    Graphics.CSurface.GL_RenderPrimitiveWithColor(teardrop, Graphics.GL_Color(1, 1, 1, dropFade))
			    Graphics.CSurface.GL_PopMatrix()
			end
			if iRemove then
				table.remove(varient1.drops, iRemove)
			end
		elseif varient == 2 then
			Graphics.CSurface.GL_DrawRect(0, 0, 1280, 720, Graphics.GL_Color(0.35, 0.35, 0.35, fade))
			if timer >= varient2.lastSetTime + varient2.setTimer then
				varient2.aimAngle = math.random() * 2 * math.pi
				varient2.aimSpeed = 10 + math.random() * 25
				varient2.lastSetTime = timer
				varient2.setTimer = math.random(5, 10)
			end
			local maxSpeed = 35
			local minSpeed = 10
			local updateSpeed = 0.5
			local aimVector = {x = varient2.aimSpeed * math.cos(varient2.aimAngle), y = varient2.aimSpeed * math.sin(varient2.aimAngle)}
			local sumVector = {x = varient2.velocity.x + aimVector.x * updateSpeed * (((speedUp and 20) or 1) * Hyperspace.FPS.SpeedFactor/16), y = varient2.velocity.y + aimVector.y * updateSpeed * (Hyperspace.FPS.SpeedFactor/16)}

			local currentSpeed = math.sqrt(sumVector.x^2 + sumVector.y^2)
		    if currentSpeed > maxSpeed then
		        currentSpeed = maxSpeed
		        local ratio = maxSpeed / math.sqrt(sumVector.x^2 + sumVector.y^2)
		        sumVector.x = sumVector.x * ratio
		        sumVector.y = sumVector.y * ratio
		    elseif currentSpeed < minSpeed then
		        currentSpeed = minSpeed
		        local ratio = minSpeed / math.sqrt(sumVector.x^2 + sumVector.y^2)
		        sumVector.x = sumVector.x * ratio
		        sumVector.y = sumVector.y * ratio
		    end

			varient2.velocity = sumVector

			varient2.offset.x = varient2.offset.x + varient2.velocity.x * (((speedUp and 20) or 1) * Hyperspace.FPS.SpeedFactor/16)
			if varient2.offset.x >= wavy_stencil.width then
				varient2.offset.x = varient2.offset.x - wavy_stencil.width
			elseif varient2.offset.x < 0 then 
				varient2.offset.x = varient2.offset.x + wavy_stencil.width
			end

			varient2.offset.y = varient2.offset.y + varient2.velocity.y * (((speedUp and 20) or 1) * Hyperspace.FPS.SpeedFactor/16)
			if varient2.offset.y >= wavy_stencil.height then
				varient2.offset.y = varient2.offset.y - wavy_stencil.height
			elseif varient2.offset.y < 0 then 
				varient2.offset.y = varient2.offset.y + wavy_stencil.height
			end

		    for yMult = 0, math.ceil(720/wavy_stencil.height) do
		    	for xMult = 0, math.ceil(1280/wavy_stencil.width) do
				    Graphics.CSurface.GL_PushMatrix()
					Graphics.CSurface.GL_Translate(varient2.offset.x + wavy_stencil.width * xMult, varient2.offset.y + wavy_stencil.height  * yMult, 0)
				    Graphics.CSurface.GL_RenderPrimitiveWithColor(wavy_stencil.image_inverse, Graphics.GL_Color(0.4, 0.4, 0.45, fade))
				    Graphics.CSurface.GL_PopMatrix()
				end
			end
		elseif varient == 3 then
			textColourDefault = {r = 0, g = 0, b = 0}
			--textColourSelect = {r = 0.5, g = 0.5, b = 0}
			Graphics.CSurface.GL_DrawRect(0, 0, 1280, 720, Graphics.GL_Color(1, 1, 0.95, fade))
			local speed = 5
		    for yMult = 0, math.ceil(720/hex_stencil.height) do
		    	for xMult = 0, math.ceil(1280/hex_stencil.width) do
					Graphics.CSurface.GL_PushMatrix()
					Graphics.CSurface.GL_Translate(hex_stencil.width * xMult, (timer * speed) % hex_stencil.height + hex_stencil.height * yMult, 0)
				    Graphics.CSurface.GL_RenderPrimitiveWithColor(hex_stencil.image, Graphics.GL_Color(0.9, 0.9, 0.85, fade))
				    Graphics.CSurface.GL_PopMatrix()
				end
			end
		end
		Graphics.CSurface.GL_RenderPrimitiveWithColor(wavy_stencil.image, Graphics.GL_Color(1, 1, 1, 1)) -- reset colours because sometimes using this just breaks rendering???
		if varient ~= 0 then
			local currentCharacter = math.floor(timer * 5)
			local lineBreakStart, lineBreakEnd = string.find(source.text, "\n", currentCharacter)
			local shownText = string.sub(source.text, 1, currentCharacter) .. string.rep("#", string.len(string.sub(source.text, currentCharacter + 1, lineBreakStart or 1000)))
			
			local textX = 1280/2
			local textY = (720/2) - 200
	    	Graphics.CSurface.GL_SetColorTint(Graphics.GL_Color(textColourDefault.r, textColourDefault.g, textColourDefault.b, fade))
    		Graphics.freetype.easy_printNewlinesCentered(13, textX, textY, 1140, shownText)
	    	Graphics.CSurface.GL_RemoveColorTint()
    		local mousePos = Hyperspace.Mouse.position
    		textY = 720/2 + 200
    		if currentCharacter > string.len(source.text) then
	    		for i, choice in ipairs(source.choices) do
	    			if not choice.req or Hyperspace.metaVariables[choice.req] >= 1 then
		    			textY = 720/2 + 50 * i
		    			local choiceText = choice.text
		    			--print(choice.text)
						local hitbox = Graphics.freetype.easy_measurePrintLines(13, 0, 0, 1140, choiceText)
						--local originalColour = Graphics.GL_GetColorTint()
			    		if mousePos.x >= textX - (hitbox.x/2) - padding.x and mousePos.x <= textX + (hitbox.x/2) + padding.x and mousePos.y >= textY - (hitbox.y/2) - padding.y and mousePos.y <= textY + (hitbox.y/2) + padding.y then
			    			hoveredChoice = i
		    				Graphics.CSurface.GL_SetColorTint(Graphics.GL_Color(textColourSelect.r, textColourSelect.g, textColourSelect.b, fade))
		    			else
		    				Graphics.CSurface.GL_SetColorTint(Graphics.GL_Color(textColourDefault.r, textColourDefault.g, textColourDefault.b, fade))
			    		end
			    		Graphics.freetype.easy_printNewlinesCentered(13, textX, textY, 1140, choiceText)
		    			Graphics.CSurface.GL_RemoveColorTint()
		    		end
		    	end
		    end
		end
	end
end)

script.on_render_event(Defines.RenderEvents.GUI_CONTAINER, function() end, function()
	--print(fade)
	if fade > 0 and not renderEvent then
		--print("should fade")
		fade = math.max(0, fade - Hyperspace.FPS.SpeedFactor/16)
		if lastVarient == 1 then
			Graphics.CSurface.GL_DrawRect(0, 0, 1280, 720, Graphics.GL_Color(1, 0.5, 0.5, fade))
		elseif lastVarient == 2 then
			Graphics.CSurface.GL_DrawRect(0, 0, 1280, 720, Graphics.GL_Color(0.8, 0.8, 0.75, fade))
		elseif lastVarient == 3 then
			Graphics.CSurface.GL_DrawRect(0, 0, 1280, 720, Graphics.GL_Color(1, 1, 1, fade))
		end
	end
end)

script.on_internal_event(Defines.InternalEvents.ON_MOUSE_L_BUTTON_DOWN, function(x,y)
	local commandGui = Hyperspace.App.gui
	if hoveredChoice and commandGui.event_pause then
		timer = 0
		varient1.lastFlash = 0
		varient2.lastSetTime = 0
		table.insert(choicesChosenList, hoveredChoice)
		hoveredChoice = nil
	elseif renderEvent then
		speedUp = true
	end
	return Defines.Chain.CONTINUE
end)

script.on_internal_event(Defines.InternalEvents.ON_MOUSE_L_BUTTON_UP, function(x,y)
	if speedUp then
		speedUp = false
	end
	return Defines.Chain.CONTINUE
end)


--[[Graphics.CSurface.GL_PushStencilMode()
		    Graphics.CSurface.GL_SetStencilMode(1,1,1)
		    Graphics.CSurface.GL_ClearAll()
		    Graphics.CSurface.GL_SetStencilMode(1,1,1)
		    for yMult = 0, 2 do
		    	for xMult = 0, 3 do
				    Graphics.CSurface.GL_PushMatrix()
					Graphics.CSurface.GL_Translate(varient2.offset.x + wavy_stencil.width * xMult, varient2.offset.y + wavy_stencil.height  * yMult, 0)
				    Graphics.CSurface.GL_RenderPrimitiveWithColor(wavy_stencil.image, Graphics.GL_Color(0, 0, 0, 1))
				    Graphics.CSurface.GL_PopMatrix()
		    	end
		    end
		    Graphics.CSurface.GL_SetStencilMode(2,1,1)
		    for yMult = 0, 2 do
		    	for xMult = 0, 3 do
				    --Graphics.CSurface.GL_PushMatrix()
					--Graphics.CSurface.GL_Translate(wavy_stencil.width * xMult, wavy_stencil.height * yMult, 0)
				    --Graphics.CSurface.GL_RenderPrimitiveWithColor(wavy_stencil.image, Graphics.GL_Color(0.9, 0.9, 0.875, fade))
				    --Graphics.CSurface.GL_PopMatrix()
				    Graphics.CSurface.GL_PushMatrix()
					Graphics.CSurface.GL_Translate(wavy_stencil.width - varient2.offset.x + wavy_stencil.width * xMult, wavy_stencil.height - varient2.offset.y + wavy_stencil.height  * yMult, 0)
				    Graphics.CSurface.GL_RenderPrimitiveWithColor(wavy_stencil.image, Graphics.GL_Color(0.9, 0.9, 0.875, 1))
				    Graphics.CSurface.GL_PopMatrix()
		    	end
		    end
		    Graphics.CSurface.GL_SetStencilMode(0,1,1)
			Graphics.CSurface.GL_PopStencilMode()]]