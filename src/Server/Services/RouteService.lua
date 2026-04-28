--!strict
-- RouteService (Knit Service)
-- Drives a plane along its route waypoints using TweenService (the same
-- "flight arc" pattern found in Roblox vehicle/tycoon kits, now chained
-- through all waypoints of a global route).
--
-- Per-waypoint: risk roll → optional chaos event → tween to next point.
-- On final waypoint: land and fire onComplete callback with the payout.
--
-- Defence bonus calculation is delegated to UpgradeService to keep the
-- formula in one canonical place.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Packages.Knit)

local RouteData = require(ReplicatedStorage.ContraBandShared.Data.RouteData)
local CargoData = require(ReplicatedStorage.ContraBandShared.Data.CargoData)

-- ─────────────────────────────────────────────────────────────────────────────

local AIR_SPEED = 300  -- studs / second for air routes
local SEA_SPEED = 100  -- studs / second for sea lanes

-- Risk / payout tuning constants
local CARGO_RISK_CONTRIBUTION = 0.50  -- fraction of cargo BaseDetectionRisk added to route risk
local CARGO_PAYOUT_FACTOR     = 0.20  -- per-crate payout = BasePayout × PayoutMult × this × amount
local CHAOS_EVENT_CHANCE_MULT = 0.35  -- chaos probability = route BaseRisk × this (per waypoint)

-- ─────────────────────────────────────────────────────────────────────────────

local RouteService = Knit.CreateService({
    Name = "RouteService",

    Client = {
        FlightStarted   = Knit.CreateSignal(), -- (planeId, routeName)
        WaypointReached = Knit.CreateSignal(), -- (planeId, waypointIndex)
        FlightComplete  = Knit.CreateSignal(), -- (planeId, destinationHub, payout)
        FlightBusted    = Knit.CreateSignal(), -- (planeId, waypointIndex)
    },
})

-- ─────────────────────────────────────────────────────────────────────────────
-- Risk / payout maths  (mirrors tycoon-kit income-formula patterns)
-- Defence bonus is the single-source-of-truth function in UpgradeService.
-- ─────────────────────────────────────────────────────────────────────────────

--- Effective bust-probability for the whole flight.
local function calcEffectiveRisk(
    routeDef     : RouteData.RouteDef,
    cargo        : { any },
    defenceBonus : number
): number
    local risk = routeDef.BaseRisk
    for _, manifest in cargo do
        local cd = CargoData[manifest.cargoType]
        if cd then risk += cd.BaseDetectionRisk * CARGO_RISK_CONTRIBUTION end
    end
    risk = math.min(risk, 1.0)
    return math.max(risk * (1 - defenceBonus), 0.05)
end

--- Black-money payout for the run.
local function calcPayout(routeDef: RouteData.RouteDef, cargo: { any }): number
    local payout = routeDef.BasePayout
    for _, manifest in cargo do
        local cd = CargoData[manifest.cargoType]
        if cd then
            payout += routeDef.BasePayout * cd.PayoutMultiplier * CARGO_PAYOUT_FACTOR * manifest.amount
        end
    end
    return math.floor(payout)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Flight coroutine
-- ─────────────────────────────────────────────────────────────────────────────

local function tweenToPoint(planeModel: Model, target: Vector3, speed: number)
    local part = planeModel.PrimaryPart
    if not part then return end

    local dist = (target - part.Position).Magnitude
    local secs = math.max(dist / speed, 0.1)

    -- Snap nose toward waypoint before tweening position
    local fwd = (target - part.Position).Unit
    if fwd.Magnitude > 0 then
        planeModel:SetPrimaryPartCFrame(CFrame.lookAt(part.Position, target))
    end

    local t = TweenService:Create(
        part,
        TweenInfo.new(secs, Enum.EasingStyle.Linear),
        { Position = target }
    )
    t:Play()
    t.Completed:Wait()
end

function RouteService:_flyRoute(
    planeId       : string,
    routeName     : string,
    hubUpgrades   : { [string]: number },
    globalUpgrades: { [string]: number },
    onComplete    : (payout: number) -> (),
    onBust        : (waypointIdx: number) -> ()
)
    local PlaneService    = Knit.GetService("PlaneService")
    local EventManager    = Knit.GetService("EventManager")
    local UpgradeService  = Knit.GetService("UpgradeService")

    local planeData  = PlaneService:GetPlaneData(planeId)
    local planeModel = PlaneService:GetPlaneModel(planeId)
    local routeDef   = RouteData[routeName]

    if not planeData or not planeModel or not routeDef then
        warn("[RouteService] _flyRoute: missing plane/route data", planeId, routeName)
        return
    end

    local speed       = routeDef.IsSeaLane and SEA_SPEED or AIR_SPEED
    -- Delegate to UpgradeService — single canonical formula
    local defBonus    = UpgradeService:GetDefenceBonus(routeName, planeData.cargo, hubUpgrades, globalUpgrades)
    local totalRisk   = calcEffectiveRisk(routeDef, planeData.cargo, defBonus)
    local payout      = calcPayout(routeDef, planeData.cargo)
    local numWaypts   = #routeDef.Waypoints

    -- Takeoff climb (air routes only)
    PlaneService:SetStatus(planeId, "TakingOff")
    self.Client.FlightStarted:FireAll(planeId, routeName)

    if not routeDef.IsSeaLane then
        local pp = planeModel.PrimaryPart
        if pp then
            local climb = TweenService:Create(
                pp,
                TweenInfo.new(4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
                { Position = pp.Position + Vector3.new(0, 150, 0) }
            )
            climb:Play()
            climb.Completed:Wait()
        end
    end

    PlaneService:SetStatus(planeId, "Flying")

    -- Waypoint loop — the core flight tick
    for i, waypoint in routeDef.Waypoints do
        -- Per-waypoint detection roll (spread total risk across all waypoints)
        local bustRoll  = math.random()
        local bustThreshold = totalRisk / numWaypts

        -- Optional chaos event (independent from bust roll)
        if math.random() < routeDef.BaseRisk * CHAOS_EVENT_CHANCE_MULT then
            EventManager:TriggerChaosEvent(planeId, routeName, planeData.cargo, i)
        end

        if bustRoll < bustThreshold then
            -- BUSTED
            PlaneService:SetStatus(planeId, "Busted")
            self.Client.WaypointReached:FireAll(planeId, i)
            self.Client.FlightBusted:FireAll(planeId, i)
            onBust(i)
            return
        end

        tweenToPoint(planeModel, waypoint, speed)
        self.Client.WaypointReached:FireAll(planeId, i)
    end

    -- Landing descent
    PlaneService:SetStatus(planeId, "Landing")
    local destHub = workspace:FindFirstChild("Hubs")
        and workspace.Hubs:FindFirstChild(routeDef.DestinationHub)
    local landPad = destHub and destHub:FindFirstChild("LandingPad") :: BasePart?
    if landPad then
        tweenToPoint(planeModel, landPad.Position, speed)
    end

    self.Client.FlightComplete:FireAll(planeId, routeDef.DestinationHub, payout)
    onComplete(payout)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Public API
-- ─────────────────────────────────────────────────────────────────────────────

--- Kick off a flight asynchronously (task.spawn so it never yields callers).
function RouteService:StartFlight(
    planeId       : string,
    routeName     : string,
    hubUpgrades   : { [string]: number },
    globalUpgrades: { [string]: number },
    onComplete    : (payout: number) -> (),
    onBust        : (waypointIdx: number) -> ()
)
    if not RouteData[routeName] then
        warn("[RouteService] Unknown route:", routeName)
        return
    end
    task.spawn(function()
        self:_flyRoute(
            planeId, routeName,
            hubUpgrades, globalUpgrades,
            onComplete, onBust
        )
    end)
end

--- Return all route IDs available up to (and including) a given tier.
function RouteService:GetRoutesForTier(tier: number): { string }
    local result = {}
    for id, def in RouteData do
        if def.Tier <= tier then
            table.insert(result, id)
        end
    end
    return result
end

-- Client passthroughs
function RouteService.Client:GetRoutesForTier(_player: Player, tier: number): { string }
    return self.Server:GetRoutesForTier(tier)
end

function RouteService.Client:GetRouteData(_player: Player, routeName: string): RouteData.RouteDef?
    return RouteData[routeName]
end

-- ─────────────────────────────────────────────────────────────────────────────

function RouteService:KnitInit() end
function RouteService:KnitStart() end

return RouteService
