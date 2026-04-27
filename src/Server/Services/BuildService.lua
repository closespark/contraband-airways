--!strict
-- BuildService (Knit Service)
-- Manages the per-hub construction queue: validates costs, deducts resources,
-- runs build timers via RunService.Heartbeat, and activates Effects on completion.
-- Mirrors completed structure levels into the legacy HubLayouts table so that
-- UpgradeService (which computes heat-decay / defence bonuses) keeps working.

local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit          = require(ReplicatedStorage.Packages.Knit)
local StructureData = require(ReplicatedStorage.ContraBandShared.Data.StructureData)

-- Process the build queue this often (seconds).
local TICK_INTERVAL = 1

-- ─────────────────────────────────────────────────────────────────────────────

local BuildService = Knit.CreateService({
    Name = "BuildService",

    Client = {
        BuildQueued    = Knit.CreateSignal(), -- (hubId: string, uid: string, duration: number)
        BuildCompleted = Knit.CreateSignal(), -- (hubId: string, uid: string)
        BuildFailed    = Knit.CreateSignal(), -- (hubId: string, uid: string, reason: string)
    },

    _lastTick = 0,
})

-- ─────────────────────────────────────────────────────────────────────────────
-- Private helpers
-- ─────────────────────────────────────────────────────────────────────────────

local function getEmpireData(): any?
    local EmpireService = Knit.GetService("EmpireService")
    return EmpireService:GetEmpireData()
end

local function getEntry(structures: any, hubId: string, uid: string): any?
    local hub = structures[hubId]
    return hub and hub[uid] or nil
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Completion handler — called when a queued item finishes
-- ─────────────────────────────────────────────────────────────────────────────

function BuildService:_completeStructure(data: any, hubId: string, uid: string)
    local entry = getEntry(data.Structures, hubId, uid)
    if not entry then return end

    entry.level     = (entry.level or 0) + 1
    entry.state     = "Built"
    entry.startTime = nil
    entry.duration  = nil

    -- Mirror into legacy HubLayouts so UpgradeService formulae keep working
    if not data.HubLayouts[hubId] then
        data.HubLayouts[hubId] = {}
    end
    if not data.HubLayouts[hubId][uid] then
        data.HubLayouts[hubId][uid] = { level = 0, gridX = 0, gridZ = 0 }
    end
    data.HubLayouts[hubId][uid].level = entry.level

    -- Grant Unlocks listed in StructureData
    local def = StructureData[uid]
    if def and #def.Unlocks > 0 then
        local UnlockService = Knit.GetService("UnlockService")
        for _, unlockId in def.Unlocks do
            UnlockService:GrantUnlock(unlockId)
        end
    end

    self.Client.BuildCompleted:FireAll(hubId, uid)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Heartbeat tick — drains finished items from every hub's queue
-- ─────────────────────────────────────────────────────────────────────────────

function BuildService:_processTick()
    local data = getEmpireData()
    if not data then return end

    local now = os.clock()
    for hubId, queue in data.BuildQueue do
        local remaining = {}
        for _, item in queue do
            if (now - item.startTime) >= item.duration then
                self:_completeStructure(data, hubId, item.uid)
            else
                table.insert(remaining, item)
            end
        end
        data.BuildQueue[hubId] = remaining
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Public API
-- ─────────────────────────────────────────────────────────────────────────────

--- Queue a build or upgrade for structure `uid` at `hubId`.
--- Returns (success, errorMessage?).
function BuildService:QueueBuild(hubId: string, uid: string): (boolean, string?)
    local data = getEmpireData()
    if not data then return false, "Empire data not loaded" end

    local def = StructureData[uid]
    if not def then return false, "Unknown structure: " .. uid end

    -- Tier gate
    local EmpireService = Knit.GetService("EmpireService")
    if def.Tier > EmpireService:GetEmpireTier() then
        return false, def.DisplayName .. " requires Tier " .. def.Tier
    end

    -- Initialise hub entry if needed
    if not data.Structures[hubId] then data.Structures[hubId] = {} end
    if not data.Structures[hubId][uid] then
        data.Structures[hubId][uid] = { state = "Available", level = 0, gridX = 0, gridZ = 0 }
    end

    local entry = data.Structures[hubId][uid]
    local state = entry.state or "Available"

    if state == "UnderConstruction" or state == "Upgrading" then
        return false, def.DisplayName .. " is already being constructed"
    end
    if state == "Built" and (entry.level or 0) >= def.MaxLevel then
        return false, def.DisplayName .. " is already at max level"
    end

    -- Deduct resources atomically
    local ResourceService = Knit.GetService("ResourceService")
    if not ResourceService:SpendMultiple(def.Cost) then
        return false, "Not enough resources to build " .. def.DisplayName
    end

    local isUpgrade = (state == "Built")
    entry.state     = isUpgrade and "Upgrading" or "UnderConstruction"
    entry.startTime = os.clock()
    entry.duration  = def.BuildTime

    -- Register in build queue
    if not data.BuildQueue[hubId] then data.BuildQueue[hubId] = {} end
    table.insert(data.BuildQueue[hubId], {
        uid       = uid,
        startTime = entry.startTime,
        duration  = def.BuildTime,
    })

    self.Client.BuildQueued:FireAll(hubId, uid, def.BuildTime)
    return true, nil
end

--- Return the current state string for a structure ("Available", "UnderConstruction",
--- "Upgrading", "Built", "Damaged", "Disabled").
function BuildService:GetStructureState(hubId: string, uid: string): string
    local data = getEmpireData()
    if not data then return "Available" end
    local entry = getEntry(data.Structures, hubId, uid)
    return entry and (entry.state or "Available") or "Available"
end

--- Return the current level (0 = not built) for a structure.
function BuildService:GetStructureLevel(hubId: string, uid: string): number
    local data = getEmpireData()
    if not data then return 0 end
    local entry = getEntry(data.Structures, hubId, uid)
    return entry and (entry.level or 0) or 0
end

--- Return true if `uid` is "Built" at any unlocked hub.
function BuildService:IsBuiltAnywhere(uid: string): boolean
    local data = getEmpireData()
    if not data then return false end
    for _, hubStructures in data.Structures do
        local entry = hubStructures[uid]
        if entry and entry.state == "Built" then return true end
    end
    return false
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Client-facing wrappers
-- ─────────────────────────────────────────────────────────────────────────────

function BuildService.Client:QueueBuild(_player: Player, hubId: string, uid: string): (boolean, string?)
    return self.Server:QueueBuild(hubId, uid)
end

function BuildService.Client:GetStructureState(_player: Player, hubId: string, uid: string): string
    return self.Server:GetStructureState(hubId, uid)
end

function BuildService.Client:GetStructureLevel(_player: Player, hubId: string, uid: string): number
    return self.Server:GetStructureLevel(hubId, uid)
end

function BuildService.Client:IsBuiltAnywhere(_player: Player, uid: string): boolean
    return self.Server:IsBuiltAnywhere(uid)
end

-- ─────────────────────────────────────────────────────────────────────────────

function BuildService:KnitInit() end

function BuildService:KnitStart()
    RunService.Heartbeat:Connect(function()
        local now = os.clock()
        if now - self._lastTick >= TICK_INTERVAL then
            self._lastTick = now
            self:_processTick()
        end
    end)
end

return BuildService
