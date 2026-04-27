--!strict
-- EventManager (Knit Service)
-- Fires cartoon chaos events mid-flight based on cargo type.
-- Players have a response window; missing it adds Heat automatically.
-- Design: each event is a timed "group moment" — everyone on the shared
-- empire map sees the alert and can click to respond.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit      = require(ReplicatedStorage.Packages.Knit)
local CargoData = require(ReplicatedStorage.ContraBandShared.Data.CargoData)

-- ─────────────────────────────────────────────────────────────────────────────

type EventDef = {
    Message         : string,
    EffectTag       : string,   -- CollectionService tag for visual effect parts
    HeatPenalty     : number,   -- Heat added if nobody responds in time
    ResponseWindow  : number,   -- seconds players have to respond
}

local EVENTS: { [string]: EventDef } = {
    RivalTheft = {
        Message        = "👀 Rival scouts spotted! Protect the Shiny Rocks!",
        EffectTag      = "FX_RivalScout",
        HeatPenalty    = 10,
        ResponseWindow = 20,
    },
    LeakSpill = {
        Message        = "💨 Mystery Powder leak detected! Deploy cleaners!",
        EffectTag      = "FX_SpillPuff",
        HeatPenalty    = 15,
        ResponseWindow = 30,
    },
    MilitaryPatrol = {
        Message        = "🚁 Military patrol incoming! Launch decoys!",
        EffectTag      = "FX_PatrolAlert",
        HeatPenalty    = 20,
        ResponseWindow = 25,
    },
    DigitalTrace = {
        Message        = "📡 Digital trace detected — Heat is creeping up...",
        EffectTag      = "FX_Glitch",
        HeatPenalty    = 12,
        ResponseWindow = 45,
    },
    PetEscape = {
        Message        = "🐾 A cartoon critter escaped its crate! Catch it!",
        EffectTag      = "FX_PetEscape",
        HeatPenalty    = 8,
        ResponseWindow = 40,
    },
    PoliceRaid = {
        Message        = "🚔 Police raid icon at the hub! Bribe or hide!",
        EffectTag      = "FX_Raid",
        HeatPenalty    = 18,
        ResponseWindow = 20,
    },
    RivalSabotage = {
        Message        = "💣 Rival sabotage attempt on the route! Deflect it!",
        EffectTag      = "FX_Sabotage",
        HeatPenalty    = 22,
        ResponseWindow = 20,
    },
    CoastGuard = {
        Message        = "⚓ Coast guard cutter spotted the freighter!",
        EffectTag      = "FX_CoastGuard",
        HeatPenalty    = 16,
        ResponseWindow = 30,
    },
    PirateRaid = {
        Message        = "🏴‍☠️ Cartoon pirates are boarding! Repel them!",
        EffectTag      = "FX_Pirates",
        HeatPenalty    = 20,
        ResponseWindow = 25,
    },
    WeatherEvent = {
        Message        = "🌪️ Cartoon storm! Reroute or the plane takes a detour.",
        EffectTag      = "FX_Storm",
        HeatPenalty    = 0,
        ResponseWindow = 15,
    },
}

-- ─────────────────────────────────────────────────────────────────────────────

local EventManager = Knit.CreateService({
    Name = "EventManager",

    Client = {
        ChaosEventFired    = Knit.CreateSignal(), -- (planeId, eventName, waypointIdx, message)
        ChaosEventResolved = Knit.CreateSignal(), -- (planeId, eventName, resolvedByPlayer: bool)
    },

    -- Active events: key = planeId.."_"..eventName, value = deadline (os.clock)
    _active = {} :: { [string]: number },
})

-- ─────────────────────────────────────────────────────────────────────────────
-- Public API
-- ─────────────────────────────────────────────────────────────────────────────

--- Choose and fire the most appropriate chaos event for the current cargo mix.
function EventManager:TriggerChaosEvent(
    planeId    : string,
    _routeName : string,
    cargo      : { any },
    waypointIdx: number
)
    -- Weight events by cargo presence
    local weights: { [string]: number } = {}
    for _, manifest in cargo do
        local cd = CargoData[manifest.cargoType]
        if cd then
            local ev = cd.ChaosEvent
            weights[ev] = (weights[ev] or 0) + manifest.amount * cd.ChaosChance
        end
    end

    -- Pick highest-weight candidate (fall back to PoliceRaid)
    local chosen = "PoliceRaid"
    local best   = 0
    for ev, w in weights do
        if w > best then best = w; chosen = ev end
    end

    local def = EVENTS[chosen]
    if not def then return end

    local key      = planeId .. "_" .. chosen
    local deadline = os.clock() + def.ResponseWindow
    self._active[key] = deadline

    self.Client.ChaosEventFired:FireAll(planeId, chosen, waypointIdx, def.Message)

    -- Auto-penalise if nobody responds within the window
    task.delay(def.ResponseWindow, function()
        if self._active[key] then
            self._active[key] = nil
            local HeatService = Knit.GetService("HeatService")
            HeatService:AddHeat(def.HeatPenalty)
            self.Client.ChaosEventResolved:FireAll(planeId, chosen, false)
        end
    end)
end

--- Players call this to respond to (and cancel) an active chaos event.
function EventManager:RespondToEvent(planeId: string, eventName: string)
    local key = planeId .. "_" .. eventName
    if self._active[key] then
        self._active[key] = nil
        self.Client.ChaosEventResolved:FireAll(planeId, eventName, true)
    end
end

-- Client passthroughs
function EventManager.Client:RespondToEvent(
    _player: Player, planeId: string, eventName: string
)
    self.Server:RespondToEvent(planeId, eventName)
end

function EventManager.Client:GetEventInfo(
    _player: Player, eventName: string
): EventDef?
    return EVENTS[eventName] :: EventDef?
end

-- ─────────────────────────────────────────────────────────────────────────────

function EventManager:KnitInit() end
function EventManager:KnitStart() end

return EventManager
