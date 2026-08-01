mods.aea.crewListener = {}
mods.aea.crewListener.internal = {}
local CrewListener = mods.aea.crewListener
local Internals = mods.aea.crewListener.internal
CrewListener.__index = CrewListener

local function NOOP() end
local sCrewListeners = {}


---@return table
---To deregister functions, call with a no-op function on the same object.
function CrewListener.new()
    local self = setmetatable({}, CrewListener)
    table.insert(sCrewListeners, self)
    self.onDarkJusticierPower = NOOP
    self.onTargetedCultistPower = NOOP
    self.onCultistTargetSelected = NOOP

    return self
end

---Register a listener to be called when a dark justicier activates their spellcasting power.  
---@param onDarkJusticierPower function takes a Hyperspace.CrewMember, the dark justicier using their power.
function CrewListener:setOnDarkJusticierPower(onDarkJusticierPower)
    self.onDarkJusticierPower = onDarkJusticierPower
end

function Internals.onDarkJusticierPower(crewmem)
    for _,listener in ipairs(sCrewListeners) do
        listener.onDarkJusticierPower(crewmem)
    end
end

---Register a listener to be called when a vampweed cultist uses a targeted power
---@param onTargetedCultistPower function takes an ActivatedPower
function CrewListener:setOnTargetedCultistPower(onTargetedCultistPower)
    self.onTargetedCultistPower = onTargetedCultistPower
end

function Internals.onTargetedCultistPower(crewmem)
    for _,listener in ipairs(sCrewListeners) do
        listener.onTargetedCultistPower(crewmem)
    end
end

---Register a listener to be called when a target is selected for a vampweed cultist power
---@param onCultistTargetSelected function takes a CrewMember, the power user, and Hyperspace.Point, the Hyperspace.Mouse.position at time of selection.
function CrewListener:setOnCultistTargetSelected(onCultistTargetSelected)
    self.onCultistTargetSelected = onCultistTargetSelected
end

function Internals.onCultistTargetSelected(crewmem)
    local mousePos = Hyperspace.Mouse.position
    for _,listener in ipairs(sCrewListeners) do
        listener.onCultistTargetSelected(crewmem, mousePos)
    end
end