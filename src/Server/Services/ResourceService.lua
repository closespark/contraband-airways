--!strict
-- ResourceService (Knit Service)
-- Single source of truth for all empire resource balances.
-- All other services call Add / Spend / Get rather than touching profile data directly.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit         = require(ReplicatedStorage.Packages.Knit)
local ResourceData = require(ReplicatedStorage.ContraBandShared.Data.ResourceData)

-- ─────────────────────────────────────────────────────────────────────────────

local ResourceService = Knit.CreateService({
    Name = "ResourceService",

    Client = {
        ResourceChanged = Knit.CreateSignal(), -- (resourceId: string, newAmount: number)
    },
})

-- ─────────────────────────────────────────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────────────────────────────────────────

local function getResources(): { [string]: number }?
    local EmpireService = Knit.GetService("EmpireService")
    local data = EmpireService:GetEmpireData()
    return data and data.Resources or nil
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Public API
-- ─────────────────────────────────────────────────────────────────────────────

--- Add `amount` of `resourceId` to the empire balance.
function ResourceService:Add(resourceId: string, amount: number)
    if amount <= 0 then return end
    local res = getResources()
    if not res then return end

    res[resourceId] = (res[resourceId] or 0) + amount

    -- Enforce cap
    local def = ResourceData[resourceId]
    if def and def.Cap > 0 and res[resourceId] > def.Cap then
        res[resourceId] = def.Cap
    end

    self.Client.ResourceChanged:FireAll(resourceId, res[resourceId])
end

--- Spend `amount` of `resourceId`.  Returns true on success, false if insufficient.
function ResourceService:Spend(resourceId: string, amount: number): boolean
    if amount <= 0 then return true end
    local res = getResources()
    if not res then return false end

    local current = res[resourceId] or 0
    if current < amount then return false end

    res[resourceId] = current - amount
    self.Client.ResourceChanged:FireAll(resourceId, res[resourceId])
    return true
end

--- Return the current balance for `resourceId`.
function ResourceService:Get(resourceId: string): number
    local res = getResources()
    if not res then return 0 end
    return res[resourceId] or 0
end

--- Return a snapshot of all resource balances.
function ResourceService:GetAll(): { [string]: number }
    local res = getResources()
    if not res then return {} end
    local copy: { [string]: number } = {}
    for k, v in res do copy[k] = v end
    return copy
end

--- Atomically validate and spend multiple resources.
--- Returns true only if ALL resources can be afforded; deducts nothing on failure.
function ResourceService:SpendMultiple(costs: { [string]: number }): boolean
    local res = getResources()
    if not res then return false end

    -- Validate first, commit nothing
    for resourceId, amount in costs do
        if amount > 0 and (res[resourceId] or 0) < amount then
            return false
        end
    end

    -- All clear — deduct
    for resourceId, amount in costs do
        if amount > 0 then
            res[resourceId] = (res[resourceId] or 0) - amount
            self.Client.ResourceChanged:FireAll(resourceId, res[resourceId])
        end
    end
    return true
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Client-facing wrappers
-- ─────────────────────────────────────────────────────────────────────────────

function ResourceService.Client:GetAll(_player: Player): { [string]: number }
    return self.Server:GetAll()
end

function ResourceService.Client:Get(_player: Player, resourceId: string): number
    return self.Server:Get(resourceId)
end

-- ─────────────────────────────────────────────────────────────────────────────

function ResourceService:KnitInit() end
function ResourceService:KnitStart() end

return ResourceService
