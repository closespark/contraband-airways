--!strict
-- UnlockService (Knit Service)
-- Evaluates conditions from UnlockData after any empire state change and grants
-- unlocks automatically.  Also handles explicit Influence-funded hub unlocks.
--
-- Call CheckUnlocks() after: tier changes, structure completions, run completions.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit       = require(ReplicatedStorage.Packages.Knit)
local UnlockData = require(ReplicatedStorage.ContraBandShared.Data.UnlockData)

-- ─────────────────────────────────────────────────────────────────────────────

local UnlockService = Knit.CreateService({
    Name = "UnlockService",

    Client = {
        Unlocked = Knit.CreateSignal(), -- (category: string, id: string)
    },
})

-- ─────────────────────────────────────────────────────────────────────────────
-- Private helpers
-- ─────────────────────────────────────────────────────────────────────────────

local function getEmpireData(): any?
    local EmpireService = Knit.GetService("EmpireService")
    return EmpireService:GetEmpireData()
end

--- Return true when all conditions in `condition` are met by `data`.
local function conditionMet(data: any, condition: UnlockData.UnlockCondition): boolean
    -- Tier
    if condition.Tier and data.Tier < condition.Tier then return false end

    -- Required structures: each must be "Built" at any hub
    if condition.RequiredStructures then
        local BuildService = Knit.GetService("BuildService")
        for _, uid in condition.RequiredStructures do
            if not BuildService:IsBuiltAnywhere(uid) then return false end
        end
    end

    -- Required resources (current balance must meet floor)
    if condition.RequiredResources then
        local ResourceService = Knit.GetService("ResourceService")
        for resourceId, minAmount in condition.RequiredResources do
            if ResourceService:Get(resourceId) < minAmount then return false end
        end
    end

    -- Required routes completed at least once
    if condition.RequiredRoutes then
        for _, routeId in condition.RequiredRoutes do
            if not (data.CompletedRoutes and data.CompletedRoutes[routeId]) then
                return false
            end
        end
    end

    -- Required hubs already unlocked
    if condition.RequiredHubs then
        for _, hubId in condition.RequiredHubs do
            if not data.UnlockedHubs[hubId] then return false end
        end
    end

    return true
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Public API
-- ─────────────────────────────────────────────────────────────────────────────

--- Force-grant the unlock for `id` (called by BuildService on structure completion
--- and by EmpireService when a tier is reached).
function UnlockService:GrantUnlock(id: string)
    local entry = UnlockData[id]
    if not entry then return end

    local data = getEmpireData()
    if not data then return end

    if entry.Category == "Route" then
        if not data.UnlockedRoutes[id] then
            data.UnlockedRoutes[id] = true
            self.Client.Unlocked:FireAll("Route", id)
        end
    elseif entry.Category == "Hub" then
        if not data.UnlockedHubs[id] then
            data.UnlockedHubs[id] = true
            self.Client.Unlocked:FireAll("Hub", id)
        end
    else
        -- Planes and structures: availability is checked on-demand via data files.
        -- Fire so clients can refresh their UI.
        self.Client.Unlocked:FireAll(entry.Category, id)
    end
end

--- Unlock a hub by spending Influence (player-initiated).
--- Returns (success, errorMessage?).
function UnlockService:UnlockHub(hubId: string): (boolean, string?)
    local entry = UnlockData[hubId]
    if not entry or entry.Category ~= "Hub" then
        return false, "Unknown hub: " .. hubId
    end

    local data = getEmpireData()
    if not data then return false, "Empire data not loaded" end
    if data.UnlockedHubs[hubId] then return true, nil end -- already unlocked

    if not conditionMet(data, entry.Condition) then
        return false, "Conditions not yet met for " .. hubId
    end

    -- Spend Influence if required
    local requiredRes = entry.Condition.RequiredResources
    if requiredRes then
        local ResourceService = Knit.GetService("ResourceService")
        if not ResourceService:SpendMultiple(requiredRes) then
            return false, "Not enough resources to unlock " .. hubId
        end
    end

    data.UnlockedHubs[hubId] = true
    self.Client.Unlocked:FireAll("Hub", hubId)
    return true, nil
end

--- Scan all unlock entries and grant anything whose conditions are now met.
--- Call this after tier changes, structure completions, and run completions.
function UnlockService:CheckUnlocks(data: any?)
    data = data or getEmpireData()
    if not data then return end

    for id, entry in UnlockData do
        if not conditionMet(data, entry.Condition) then continue end

        if entry.Category == "Route" then
            if not data.UnlockedRoutes[id] then
                data.UnlockedRoutes[id] = true
                self.Client.Unlocked:FireAll("Route", id)
            end
        elseif entry.Category == "Hub" then
            -- Hub unlocks are handled via GrantUnlock / UnlockHub (spending Influence)
            -- Auto-grant only if tier-unlocked without resource cost.
            if not entry.Condition.RequiredResources then
                if not data.UnlockedHubs[id] then
                    data.UnlockedHubs[id] = true
                    self.Client.Unlocked:FireAll("Hub", id)
                end
            end
        else
            -- Plane / Structure: notify clients so they can refresh availability UI.
            self.Client.Unlocked:FireAll(entry.Category, id)
        end
    end
end

--- Return all route IDs currently in UnlockedRoutes.
function UnlockService:GetUnlockedRoutes(): { string }
    local data = getEmpireData()
    if not data then return {} end
    local result = {}
    for id in data.UnlockedRoutes do table.insert(result, id) end
    return result
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Client-facing wrappers
-- ─────────────────────────────────────────────────────────────────────────────

function UnlockService.Client:GetUnlockedRoutes(_player: Player): { string }
    return self.Server:GetUnlockedRoutes()
end

function UnlockService.Client:CheckUnlocks(_player: Player)
    self.Server:CheckUnlocks()
end

function UnlockService.Client:UnlockHub(_player: Player, hubId: string): (boolean, string?)
    return self.Server:UnlockHub(hubId)
end

-- ─────────────────────────────────────────────────────────────────────────────

function UnlockService:KnitInit() end
function UnlockService:KnitStart() end

return UnlockService
