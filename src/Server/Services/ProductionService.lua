--!strict
-- ProductionService (Knit Service)
-- Ticks passive resource generation from all Built structures once per minute.
-- Reads StructureData[uid].Effects.PassiveGeneration and calls ResourceService:Add
-- scaled by the structure's current level (higher levels yield more per tick).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit          = require(ReplicatedStorage.Packages.Knit)
local StructureData = require(ReplicatedStorage.ContraBandShared.Data.StructureData)

-- Production tick interval in seconds.
local TICK_INTERVAL = 60

-- ─────────────────────────────────────────────────────────────────────────────

local ProductionService = Knit.CreateService({
    Name   = "ProductionService",
    Client = {},
})

-- ─────────────────────────────────────────────────────────────────────────────

function ProductionService:_tick()
    local EmpireService   = Knit.GetService("EmpireService")
    local ResourceService = Knit.GetService("ResourceService")

    local data = EmpireService:GetEmpireData()
    if not data then return end

    for _hubId, hubStructures in data.Structures do
        for uid, entry in hubStructures do
            if type(entry) ~= "table" then continue end
            if entry.state ~= "Built" then continue end

            local def = StructureData[uid]
            if not def then continue end

            local gen = def.Effects.PassiveGeneration
            if not gen then continue end

            local level = math.max(entry.level or 1, 1)
            for resourceId, amountPerLevel in gen do
                ResourceService:Add(resourceId, amountPerLevel * level)
            end
        end
    end
end

-- ─────────────────────────────────────────────────────────────────────────────

function ProductionService:KnitInit() end

function ProductionService:KnitStart()
    task.spawn(function()
        while true do
            task.wait(TICK_INTERVAL)
            self:_tick()
        end
    end)
end

return ProductionService
