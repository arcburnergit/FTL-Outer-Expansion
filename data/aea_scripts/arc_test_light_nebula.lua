local nebulaClouds = {}
local hubClouds = {}

local rows = 6
local columns = 9

local hubNumber = 5
local hubGenTime = 3
local hubScaleMin = 1
local hubScaleMax = 1.25

local cloudRegens = 3

local xJump = 160
local yJump = 144

local minScale = 0.5
local maxScaleRandom = 0.65
local scaleIncrease = 0.15

local lifeTime = 12
local fadeInTime = 3
local fadeOutTime = 3

local minOpacity = 0.7
local maxOpacity = 0.8

local imageString = "stars/nebula_large_c.png"
local eventString = "NEBULA_LIGHT"
local playerVar = "arc_test_light_nebula"

local warningString = "warnings/danger_aea_acidic.png"
local warningImage = Hyperspace.Resources:CreateImagePrimitiveString(warningString, 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false)
local warningX = 660
local warningY = 72
local warningSizeX = 60
local warningSizeY = 58
local warningText = "You're inside an Acidic nebula. Your sensors will not function and your empty rooms will be slowly breached at random by the Acidic clouds."

local initialPosX = (math.random() * 131072) % 131 - 65
local initialPosY = (math.random() * 131072) % 81 - 40

local function genHubClouds()
	for k = 1, hubNumber, 1  do
		local x = math.random(0, columns)
		local y = math.random(0, rows)
		hubClouds[k] = {x = x, y = x, scale = 1, genTimer = 0}
		local hubCloud = hubClouds[k]
		hubCloud.scale = (math.random() * (hubScaleMax - hubScaleMin)) + hubScaleMin
		hubCloud.genTimer = math.random() * hubGenTime
	end
end
genHubClouds()

script.on_internal_event(Defines.InternalEvents.PRE_CREATE_CHOICEBOX, function(event)
	if string.sub(event.eventName, 0, string.len(eventString)) == eventString and Hyperspace.playerVariables[playerVar] == 0 then
		Hyperspace.playerVariables[playerVar] = 1
		genHubClouds()
		initialPosX = (math.random() * 131072) % 131 - 65
		initialPosY = (math.random() * 131072) % 81 - 40
	end
end)

script.on_internal_event(Defines.InternalEvents.JUMP_ARRIVE, function(shipManager)
	Hyperspace.playerVariables[playerVar] = 0
end)

function createCloud(x, y, regens)
	local cloudTemp = {x = 0, y = 0, scale = 1.5, timerScale = 0, opacity = 1, revOp = 0, fade = 0, exists = 1, regens = 1}
	cloudTemp.x = x
	cloudTemp.y = y

	cloudTemp.scale = (math.random() * (maxScaleRandom - minScale)) + minScale
	cloudTemp.timerScale = 0

	cloudTemp.opacity = 0.05
	cloudTemp.revOp = math.random(0,1)
	cloudTemp.regens = regens
	return cloudTemp
end

script.on_render_event(Defines.RenderEvents.LAYER_FOREGROUND, function() 
	if not Hyperspace.Global.GetInstance():GetCApp().world.bStartedGame or (Hyperspace.Global.GetInstance():GetCApp().world.bStartedGame and Hyperspace.playerVariables[playerVar] == 1) then
		local commandGui = Hyperspace.Global.GetInstance():GetCApp().gui
		for k, hubTable in ipairs(hubClouds) do
			if Hyperspace.Global.GetInstance():GetCApp().world.bStartedGame then
				local cloudImageTemp = Hyperspace.Resources:CreateImagePrimitiveString(imageString, -256, -200, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false)
				
				Graphics.CSurface.GL_PushMatrix()
				Graphics.CSurface.GL_Translate((hubTable.x * xJump + initialPosX) - 20, (hubTable.y * yJump + initialPosX) - 16, 0)
				Graphics.CSurface.GL_Scale(hubTable.scale,hubTable.scale,0)

				if (commandGui.bPaused or commandGui.event_pause or commandGui.menu_pause) then
					Graphics.CSurface.GL_SetColorTint(Graphics.GL_Color(0.5, 0.5, 0.5, 1))
				end
				Graphics.CSurface.GL_RenderPrimitive(cloudImageTemp)
				Graphics.CSurface.GL_RemoveColorTint()
				Graphics.CSurface.GL_PopMatrix()
				Graphics.CSurface.GL_DestroyPrimitive(cloudImageTemp)
			end
			if not Hyperspace.Global.GetInstance():GetCApp().world.bStartedGame or (Hyperspace.Global.GetInstance():GetCApp().world.bStartedGame and Hyperspace.Settings.lowend == false and not (commandGui.bPaused or commandGui.event_pause or commandGui.menu_pause)) then
				hubTable.genTimer = hubTable.genTimer - Hyperspace.FPS.SpeedFactor/16
				if hubTable.genTimer <= 0 then
					hubTable.genTimer = hubGenTime
					local newx = hubTable.x + math.random(-1, 1)
					local newy = hubTable.y + math.random(-1, 1)
					if newx <= 0 then newx = 0 end
					if newx >= columns then newx = columns end
					if newy <= 0 then newy = 0 end
					if newy >= rows then newy = rows end
					table.insert(nebulaClouds, createCloud(newx, newy, cloudRegens))
				end
			end
		end
	end
	if not Hyperspace.Global.GetInstance():GetCApp().world.bStartedGame or (Hyperspace.Global.GetInstance():GetCApp().world.bStartedGame and Hyperspace.playerVariables[playerVar] == 1 and Hyperspace.Settings.lowend == false) then
		for k, cloud in ipairs(nebulaClouds) do
			if cloud.exists == 1 then
				local commandGui = Hyperspace.Global.GetInstance():GetCApp().gui
				if Hyperspace.Global.GetInstance():GetCApp().world.bStartedGame then
					local cloudImageTemp = Hyperspace.Resources:CreateImagePrimitiveString(imageString, -256, -200, 0, Graphics.GL_Color(1, 1, 1, 1), cloud.opacity, false)
					
					Graphics.CSurface.GL_PushMatrix()
					Graphics.CSurface.GL_Translate((cloud.x * xJump + initialPosX) - 20, (cloud.y * yJump + initialPosX) - 16, 0)
					Graphics.CSurface.GL_Scale(cloud.scale,cloud.scale,0)

					if (commandGui.bPaused or commandGui.event_pause or commandGui.menu_pause) then
						Graphics.CSurface.GL_SetColorTint(Graphics.GL_Color(0.5, 0.5, 0.5, 1))
					end
					Graphics.CSurface.GL_RenderPrimitive(cloudImageTemp)
					Graphics.CSurface.GL_RemoveColorTint()
					Graphics.CSurface.GL_PopMatrix()
					Graphics.CSurface.GL_DestroyPrimitive(cloudImageTemp)
				end

				if not (commandGui.bPaused or commandGui.event_pause or commandGui.menu_pause) then
					cloud.timerScale = cloud.timerScale + (Hyperspace.FPS.SpeedFactor/16)
					cloud.scale = cloud.scale + ((scaleIncrease/lifeTime) * (Hyperspace.FPS.SpeedFactor/16))
					if cloud.timerScale >= lifeTime then
						table.remove(nebulaClouds, k)
					end

					if cloud.timerScale >= (lifeTime - fadeOutTime) then
						cloud.opacity = math.max(cloud.opacity - ((1/fadeOutTime) * (Hyperspace.FPS.SpeedFactor/16)), 0.025)
						if cloud.fade == 0 then
							cloud.fade = 1
							if cloud.regens > 0 then

								for k2, cloudNew in ipairs(nebulaClouds) do
									if cloudNew.exists == 0 then
										--print("New Cloud at: "..tostring(k2))
										--[[local newx = cloud.x
										local newy = cloud.y
										--No Bias
										if newx <= 0 then
											newx = newx + math.random(0, 1)
										elseif newx >= columns then
											newx = newx + math.random(-1, 0)
										else
											newx = newx + math.random(-1, 1)
										end
										if newy <= 0 then
											newy = newy + math.random(0, 1)
										elseif newy >= rows then
											newy = newy + math.random(-1, 0)
										else
											newy = newy + math.random(-1, 1)
										end]]

										--Biased Towards edges
										newx = newx + math.random(-1, 1)
										newy = newy + math.random(-1, 1)
										if newx <= 0 then newx = 0 end
										if newx >= columns then newx = columns end
										if newy <= 0 then newy = 0 end
										if newy >= rows then newy = rows end
										--print("oldX:"..cloud.x/xJump.." oldY:"..cloud.y/yJump.." newY:"..newx.." newY:"..newy)
										table.insert(nebulaClouds, createCloud(newx , newy, cloud.regens - 1))
										break
									end
								end
							end
						end
					elseif cloud.timerScale < fadeInTime then
						cloud.opacity = math.min(cloud.opacity + ((1/fadeInTime) * (Hyperspace.FPS.SpeedFactor/16)), maxOpacity)

					elseif cloud.revOp == 0 then
						cloud.opacity = math.min(cloud.opacity + (0.1 * (Hyperspace.FPS.SpeedFactor/16)), maxOpacity)
						if cloud.opacity >= maxOpacity then
							cloud.revOp = 1
						end
					else
						cloud.opacity = cloud.opacity - (0.1 * (Hyperspace.FPS.SpeedFactor/16))
						if cloud.opacity <= minOpacity then
							cloud.revOp = 0
						end
					end
				end
			end
		end
	end
end, function() end)

script.on_render_event(Defines.RenderEvents.MOUSE_CONTROL, function()
	local commandGui = Hyperspace.Global.GetInstance():GetCApp().gui
	if Hyperspace.Global.GetInstance():GetCApp().world.bStartedGame and Hyperspace.playerVariables[playerVar] == 1 and not (commandGui.menu_pause or commandGui.event_pause) then
		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(warningX,warningY,0)
		Graphics.CSurface.GL_RenderPrimitive(warningImage)
		Graphics.CSurface.GL_PopMatrix()
		local mousePos = Hyperspace.Mouse.position
		if mousePos.x >= warningX and mousePos.x < (warningX + warningSizeX) and mousePos.y >= warningY and mousePos.y < (warningY + warningSizeY) then
			Hyperspace.Mouse.tooltip = warningText
		end
	end
end, function() end)