--!strict
-- FleetService (Knit Service)
-- Owns plane acquisition, the logical state machine, delivery timers, hangar
-- capacity, and repair/upgrade progression.  Wraps PlaneService (which handles
-- the 3D model lifecycle) while owning the durable empire state that persists
-- across sessions.
--
-- State machine:
--   Locked → AvailableToBuy → Ordered → Delivered → Stored
--   Stored → Assigned → InFlight → (Stored | Damaged | Destroyed)
--   Damaged → Stored (after repair)
--   Stored  → Upgrading → Stored (after upgrade timer)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit      = require(ReplicatedStorage.Packages.Knit)
local PlaneData = require(ReplicatedStorage.ContraBandShared.Data.PlaneData)

-- How often to poll delivery timers (seconds)
local DELIVERY_POLL_INTERVAL = 5

-- ─────────────────────────────────────────────────────────────────────────────

export type FleetPlaneState =
    "Locked"
    | "AvailableToBuy"
    | "Ordered"
    | "Delivered"
    | "Stored"
    | "Assigned"
    | "InFlight"
    | "Damaged"
    | "Destroyed"
    | "Upgrading"

export type FleetPlaneEntry = {
    planeType    : string,
    state        : FleetPlaneState,
    hubId        : string,
    durability   : number,
    orderedAt    : number?,  -- os.clock() when order was placed
    deliveryTime : number?,  -- seconds from orderedAt until Delivered
    robloxId     : string?,  -- PlaneService plane ID when model is spawned
}

-- ─────────────────────────────────────────────────────────────────────────────

local FleetService = Knit.CreateService({
    Name = "FleetService",

    Client = {
        PlaneOrdered      = Knit.CreateSignal(), -- (fleetId: string, planeType: string)
        PlaneDelivered    = Knit.CreateSignal(), -- (fleetId: string)
        PlaneStateChanged = Knit.CreateSignal(), -- (fleetId: string, newState: string)
    },

    _fleetCounter = 0,
})

-- ─────────────────────────────────────────────────────────────────────────────
-- Private helpers
-- ─────────────────────────────────────────────────────────────────────────────

local function getEmpireData(): any?
    local EmpireService = Knit.GetService("EmpireService")
    return EmpireService:GetEmpireData()
end

local function fleet(data: any): { [string]: FleetPlaneEntry }
    return data.Fleet :: { [string]: FleetPlaneEntry }
end

function FleetService:_newId(): string
    self._fleetCounter += 1
    return "Fleet_" .. self._fleetCounter
end

function FleetService:_setState(data: any, fleetId: string, newState: FleetPlaneState)
    local entry = fleet(data)[fleetId]
    if not entry then return end
    entry.state = newState
    self.Client.PlaneStateChanged:FireAll(fleetId, newState)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Runway / Hangar gating
-- ─────────────────────────────────────────────────────────────────────────────

local RANGE_ORDER: { [string]: number } = { Regional = 1, Continental = 2, Global = 3 }

--- Highest plane Range unlocked by the Runway at `hubId`.
local function getUnlockedRange(hubId: string): string
    local BuildService = Knit.GetService("BuildService")
    local level = BuildService:GetStructureLevel(hubId, "Runway")
    if level >= 3 then return "Global"
    elseif level >= 2 then return "Continental"
    else return "Regional" end
end

local function rangeAtLeast(actual: string, required: string): boolean
    return (RANGE_ORDER[actual] or 0) >= (RANGE_ORDER[required] or 0)
end

--- Maximum planes that can be stored/assigned at `hubId`.
--- Baseline: 1 before any Hangar; each Hangar level adds capacity.
local function maxStoredAt(hubId: string): number
    local BuildService = Knit.GetService("BuildService")
    local hangarLevel  = BuildService:GetStructureLevel(hubId, "Hangar")
    local lrLevel      = BuildService:GetStructureLevel(hubId, "LongRangeHangar")
    -- Hangar: 2 / 5 / 8 planes per level 1 / 2 / 3
    local cap = hangarLevel >= 3 and 8 or hangarLevel >= 2 and 5 or hangarLevel >= 1 and 2 or 1
    cap += lrLevel * 3
    return cap
end

local function countAtHub(f: { [string]: FleetPlaneEntry }, hubId: string): number
    local n = 0
    for _, e in f do
        if e.hubId == hubId and (e.state == "Stored" or e.state == "Assigned" or e.state == "Delivered") then
            n += 1
        end
    end
    return n
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Public API
-- ─────────────────────────────────────────────────────────────────────────────

--- Order a new plane of type `planeType` for `hubId`.
--- Deducts BlackMoney + Parts; plane enters "Ordered" state with a delivery timer.
function FleetService:OrderPlane(hubId: string, planeType: string): (boolean, string?)
    local data = getEmpireData()
    if not data then return false, "Empire data not loaded" end

    local def = PlaneData[planeType]
    if not def then return false, "Unknown plane type: " .. planeType end

    -- Runway range gate
    if not rangeAtLeast(getUnlockedRange(hubId), def.Range) then
        return false, def.DisplayName .. " requires a higher Runway level at " .. hubId
    end

    -- Hangar capacity gate
    if countAtHub(fleet(data), hubId) >= maxStoredAt(hubId) then
        return false, "Hangar at " .. hubId .. " is full — build or upgrade a Hangar first"
    end

    -- Deduct resources
    local ResourceService = Knit.GetService("ResourceService")
    local cost: { [string]: number } = {
        BlackMoney = def.Cost.BlackMoney,
        Parts      = def.Cost.Parts,
    }
    if not ResourceService:SpendMultiple(cost) then
        return false, "Not enough resources to order " .. def.DisplayName
    end

    local fleetId = self:_newId()
    fleet(data)[fleetId] = {
        planeType    = planeType,
        state        = "Ordered",
        hubId        = hubId,
        durability   = def.Durability,
        orderedAt    = os.clock(),
        deliveryTime = def.DeliveryTime,
        robloxId     = nil,
    }

    self.Client.PlaneOrdered:FireAll(fleetId, planeType)
    return true, fleetId
end

--- Move a Stored/Delivered plane to active duty at `hubId`.
function FleetService:AssignPlane(fleetId: string, hubId: string): (boolean, string?)
    local data = getEmpireData()
    if not data then return false, "Empire data not loaded" end

    local entry = fleet(data)[fleetId]
    if not entry then return false, "Unknown fleet plane: " .. fleetId end
    if entry.state ~= "Stored" and entry.state ~= "Delivered" then
        return false, "Plane is not in storage (state: " .. entry.state .. ")"
    end

    entry.hubId = hubId
    self:_setState(data, fleetId, "Assigned")
    return true, nil
end

--- Spawn the plane model via PlaneService and mark it InFlight.
--- Called by EmpireService just before RouteService:StartFlight.
--- Returns (robloxId, errorMessage?).
function FleetService:PrepareForFlight(fleetId: string): (string?, string?)
    local data = getEmpireData()
    if not data then return nil, "Empire data not loaded" end

    local entry = fleet(data)[fleetId]
    if not entry then return nil, "Unknown fleet plane: " .. fleetId end
    if entry.state ~= "Assigned" then
        return nil, "Plane must be Assigned to launch (state: " .. entry.state .. ")"
    end

    local PlaneService = Knit.GetService("PlaneService")
    local robloxId = PlaneService:SpawnPlane(entry.hubId, entry.planeType)
    if not robloxId then
        return nil, "Failed to spawn plane model at hub: " .. entry.hubId
    end

    entry.robloxId = robloxId
    self:_setState(data, fleetId, "InFlight")
    return robloxId, nil
end

--- Return a plane from a flight.  Applies `damageDealt` (default 0) and sets
--- the next state (Stored / Damaged / Destroyed).  Cleans up the 3D model.
function FleetService:ReturnFromFlight(fleetId: string, damageDealt: number?)
    local data = getEmpireData()
    if not data then return end

    local entry = fleet(data)[fleetId]
    if not entry then return end

    local damage = damageDealt or 0
    entry.durability = math.max((entry.durability or 0) - damage, 0)

    local newState: FleetPlaneState
    if entry.durability <= 0 then
        newState = "Destroyed"
    elseif entry.durability <= 30 then
        newState = "Damaged"
    else
        newState = "Stored"
    end

    -- Destroy the 3D model
    if entry.robloxId then
        local PlaneService = Knit.GetService("PlaneService")
        PlaneService:DestroyPlane(entry.robloxId)
        entry.robloxId = nil
    end

    self:_setState(data, fleetId, newState)
end

--- Repair a Damaged plane. Requires Hangar level ≥ 3 at the plane's hub.
function FleetService:RepairPlane(fleetId: string): (boolean, string?)
    local data = getEmpireData()
    if not data then return false, "Empire data not loaded" end

    local entry = fleet(data)[fleetId]
    if not entry then return false, "Unknown fleet plane: " .. fleetId end
    if entry.state ~= "Damaged" then
        return false, "Plane is not damaged (state: " .. entry.state .. ")"
    end

    local BuildService = Knit.GetService("BuildService")
    if BuildService:GetStructureLevel(entry.hubId, "Hangar") < 3 then
        return false, "Hangar Level 3 required for repairs at " .. entry.hubId
    end

    local def = PlaneData[entry.planeType]
    local partsCost = math.max(math.floor((def and def.Cost.Parts or 10) * 0.5), 1)
    local ResourceService = Knit.GetService("ResourceService")
    if not ResourceService:Spend("Parts", partsCost) then
        return false, "Not enough Parts to repair (" .. partsCost .. " needed)"
    end

    entry.durability = def and def.Durability or 100
    self:_setState(data, fleetId, "Stored")
    return true, nil
end

--- Upgrade a Stored plane to the next type in its upgrade chain.
function FleetService:UpgradePlane(fleetId: string): (boolean, string?)
    local data = getEmpireData()
    if not data then return false, "Empire data not loaded" end

    local entry = fleet(data)[fleetId]
    if not entry then return false, "Unknown fleet plane: " .. fleetId end
    if entry.state ~= "Stored" then
        return false, "Plane must be Stored to upgrade (state: " .. entry.state .. ")"
    end

    -- Find the plane type whose UpgradesFrom matches the current type
    local upgradeTo: string? = nil
    for typeId, def in PlaneData do
        if def.UpgradesFrom == entry.planeType then
            upgradeTo = typeId
            break
        end
    end
    if not upgradeTo then
        return false, entry.planeType .. " has no upgrade path"
    end

    local upgDef = PlaneData[upgradeTo]
    local ResourceService = Knit.GetService("ResourceService")
    local cost: { [string]: number } = {
        BlackMoney = upgDef.Cost.BlackMoney,
        Parts      = upgDef.Cost.Parts,
    }
    if not ResourceService:SpendMultiple(cost) then
        return false, "Not enough resources to upgrade to " .. upgDef.DisplayName
    end

    self:_setState(data, fleetId, "Upgrading")

    -- Apply the upgrade after half the delivery time
    task.delay(upgDef.DeliveryTime * 0.5, function()
        local d2 = getEmpireData()
        if not d2 then return end
        local e2 = fleet(d2)[fleetId]
        if not e2 then return end
        e2.planeType   = upgradeTo
        e2.durability  = upgDef.Durability
        self:_setState(d2, fleetId, "Stored")
    end)

    return true, nil
end

--- Return the state of a fleet plane (or nil if not found).
function FleetService:GetState(fleetId: string): FleetPlaneState?
    local data = getEmpireData()
    if not data then return nil end
    local entry = fleet(data)[fleetId]
    return entry and entry.state or nil
end

--- Return all fleet entries currently assigned to a hub.
function FleetService:GetFleetAtHub(hubId: string): { [string]: FleetPlaneEntry }
    local data = getEmpireData()
    if not data then return {} end
    local result: { [string]: FleetPlaneEntry } = {}
    for id, entry in fleet(data) do
        if entry.hubId == hubId then result[id] = entry end
    end
    return result
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Delivery timer loop
-- ─────────────────────────────────────────────────────────────────────────────

function FleetService:_pollDeliveries()
    local data = getEmpireData()
    if not data then return end

    local now = os.clock()
    for fleetId, entry in fleet(data) do
        if entry.state == "Ordered" and entry.orderedAt and entry.deliveryTime then
            if (now - entry.orderedAt) >= entry.deliveryTime then
                entry.orderedAt    = nil
                entry.deliveryTime = nil
                entry.state        = "Delivered"
                self.Client.PlaneDelivered:FireAll(fleetId)
                self.Client.PlaneStateChanged:FireAll(fleetId, "Delivered")
            end
        end
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Client-facing wrappers
-- ─────────────────────────────────────────────────────────────────────────────

function FleetService.Client:OrderPlane(_player: Player, hubId: string, planeType: string): (boolean, string?)
    return self.Server:OrderPlane(hubId, planeType)
end

function FleetService.Client:AssignPlane(_player: Player, fleetId: string, hubId: string): (boolean, string?)
    return self.Server:AssignPlane(fleetId, hubId)
end

function FleetService.Client:RepairPlane(_player: Player, fleetId: string): (boolean, string?)
    return self.Server:RepairPlane(fleetId)
end

function FleetService.Client:UpgradePlane(_player: Player, fleetId: string): (boolean, string?)
    return self.Server:UpgradePlane(fleetId)
end

function FleetService.Client:GetFleetAtHub(_player: Player, hubId: string): { [string]: any }
    return self.Server:GetFleetAtHub(hubId)
end

-- ─────────────────────────────────────────────────────────────────────────────

function FleetService:KnitInit() end

function FleetService:KnitStart()
    task.spawn(function()
        while true do
            task.wait(DELIVERY_POLL_INTERVAL)
            self:_pollDeliveries()
        end
    end)
end

return FleetService
