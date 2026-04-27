--!strict
-- EmpireService (Knit Service)
-- ─────────────────────────────────────────────────────────────────────────────
-- The game brain.  Combines three existing Roblox patterns into one new loop:
--
--   1. ProfileService (madstudioroblox) — session-locked DataStore saving,
--      used here for the shared empire profile + per-player stats.
--
--   2. Tycoon-kit income loop — earn money → spend on upgrades → earn more.
--      Here: successful run → AddMoney → Tier unlock → better routes.
--
--   3. Knit service orchestration — coordinates PlaneService, RouteService,
--      HeatService, CargoService, UpgradeService through one LaunchRun call.
-- ─────────────────────────────────────────────────────────────────────────────

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Knit           = require(ReplicatedStorage.Packages.Knit)
local ProfileService = require(ServerScriptService.Packages.ProfileService)

local ProfileTemplate = require(ReplicatedStorage.ContraBandShared.ProfileTemplate)
local CargoData       = require(ReplicatedStorage.ContraBandShared.Data.CargoData)
local RouteData       = require(ReplicatedStorage.ContraBandShared.Data.RouteData)

-- ─────────────────────────────────────────────────────────────────────────────
-- ProfileService stores
-- ─────────────────────────────────────────────────────────────────────────────

-- One shared empire profile for the whole co-op server.
-- (Swap to per-player profiles for a competitive/solo mode.)
local EmpireStore = ProfileService.GetProfileStore("ContrabandEmpire_v1", ProfileTemplate)
local PlayerStore = ProfileService.GetProfileStore("ContrabandPlayer_v1", ProfileTemplate)

-- ─────────────────────────────────────────────────────────────────────────────
-- Tier unlock thresholds (black money)
-- ─────────────────────────────────────────────────────────────────────────────

local DEFAULT_HEAT_MULTIPLIER = 1.0  -- fallback when routeDef has no HeatMultiplier

local TIER_THRESHOLDS: { [number]: number } = {
    [1] = 0,
    [2] = 50000,
    [3] = 500000,
}

-- Hubs unlocked automatically when a Tier is first reached.
local TIER_HUB_UNLOCKS: { [number]: { string } } = {
    [1] = { "HomeBase", "CaribbeanHub", "BorderHub" },
    [2] = { "AndesHub", "WestAfricaHub" },
    [3] = { "EuropeHub", "SEAsiaHub", "PacificHub", "MiddleEastHub", "EastAfricaHub", "NorthAmericaHub" },
}

-- ─────────────────────────────────────────────────────────────────────────────

local EmpireService = Knit.CreateService({
    Name = "EmpireService",

    Client = {
        EmpireDataChanged = Knit.CreateSignal(), -- (empireSnapshot)
        TierUnlocked      = Knit.CreateSignal(), -- (newTier: number)
        HubUnlocked       = Knit.CreateSignal(), -- (hubName: string)
        RunCompleted      = Knit.CreateSignal(), -- (planeId, payout, isSuccess: bool)
        MoneyChanged      = Knit.CreateSignal(), -- (newAmount: number)
    },

    _empireProfile  = nil :: any,
    _playerProfiles = {} :: { [number]: any },
})

-- ─────────────────────────────────────────────────────────────────────────────
-- Data accessors (used by other services via Knit.GetService)
-- ─────────────────────────────────────────────────────────────────────────────

function EmpireService:GetEmpireData(): typeof(ProfileTemplate.Empire)?
    return self._empireProfile and self._empireProfile.Data.Empire or nil
end

function EmpireService:GetEmpireTier(): number
    local data = self:GetEmpireData()
    return data and data.Tier or 1
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Money management  (tycoon-kit income pattern)
-- ─────────────────────────────────────────────────────────────────────────────

function EmpireService:AddMoney(amount: number)
    local data = self:GetEmpireData()
    if not data then return end

    data.BlackMoney += amount
    self.Client.MoneyChanged:FireAll(data.BlackMoney)
    self.Client.EmpireDataChanged:FireAll(data)
    self:_checkTierUnlock(data)
end

function EmpireService:SpendMoney(amount: number): boolean
    local data = self:GetEmpireData()
    if not data then return false end
    if data.BlackMoney < amount then return false end

    data.BlackMoney -= amount
    self.Client.MoneyChanged:FireAll(data.BlackMoney)
    self.Client.EmpireDataChanged:FireAll(data)
    return true
end

function EmpireService:_checkTierUnlock(data: any)
    for tier = 3, 2, -1 do
        if data.BlackMoney >= TIER_THRESHOLDS[tier] and data.Tier < tier then
            data.Tier = tier
            for _, hubName in (TIER_HUB_UNLOCKS[tier] or {}) do
                if not data.UnlockedHubs[hubName] then
                    data.UnlockedHubs[hubName] = true
                    self.Client.HubUnlocked:FireAll(hubName)
                end
            end
            self.Client.TierUnlocked:FireAll(tier)
        end
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- The Core Feedback Loop  ← this is the new part that combines everything
-- ─────────────────────────────────────────────────────────────────────────────
--
--   Prepare (cargo loaded via CargoService)
--   └─► LaunchRun  ← entry point here
--       ├─► RouteService:StartFlight (waypoint tween loop)
--       │   ├─► EventManager:TriggerChaosEvent (per waypoint)
--       │   └─► onComplete / onBust callbacks below
--       ├─► onComplete → AddMoney, HeatService:AddHeat, update player stats
--       └─► onBust    → HeatService:AddHeat (bust penalty), update player stats

function EmpireService:LaunchRun(player: Player, planeId: string, routeName: string)
    local data = self:GetEmpireData()
    if not data then
        warn("[EmpireService] LaunchRun: empire data not loaded")
        return
    end

    local PlaneService  = Knit.GetService("PlaneService")
    local RouteService  = Knit.GetService("RouteService")
    local HeatService   = Knit.GetService("HeatService")

    local planeData = PlaneService:GetPlaneData(planeId)
    if not planeData then
        warn("[EmpireService] LaunchRun: unknown planeId", planeId)
        return
    end

    local status = planeData.status
    if status ~= "Parked" and status ~= "Loading" then
        warn("[EmpireService] LaunchRun: plane not ready (status:", status .. ")")
        return
    end

    -- Gather hub upgrades for the origin hub
    local origin      = planeData.hubOrigin
    local hubLayout   = data.HubLayouts[origin] or {}
    local hubUpgrades: { [string]: number } = {}
    for uid, info in hubLayout do
        if type(info) == "table" and info.level then
            hubUpgrades[uid] = info.level
        end
    end

    local routeDef = RouteData[routeName]

    -- ── onComplete ────────────────────────────────────────────────────────────
    local function onComplete(payout: number)
        self:AddMoney(payout)

        -- Heat accumulation scaled by cargo type
        for _, manifest in planeData.cargo do
            local cd = CargoData[manifest.cargoType]
            if cd then
                HeatService:AddHeat(
                    cd.HeatOnSuccess * manifest.amount,
                    origin,
                    routeDef and routeDef.HeatMultiplier or DEFAULT_HEAT_MULTIPLIER
                )
            end
        end

        -- Per-player contribution stats
        local pp = self._playerProfiles[player.UserId]
        if pp then
            pp.Data.Player.ContributedMoney   += payout
            pp.Data.Player.TotalRunsCompleted += 1
            -- Track favourite cargo type
            local counts: { [string]: number } = {}
            for _, m in planeData.cargo do
                counts[m.cargoType] = (counts[m.cargoType] or 0) + m.amount
            end
            local topType, topAmt = "", 0
            for t, amt in counts do if amt > topAmt then topType = t; topAmt = amt end end
            if topType ~= "" then pp.Data.Player.FavoriteCargoType = topType end
        end

        self.Client.RunCompleted:FireAll(planeId, payout, true)

        -- Clean up the plane after a short visual delay
        task.delay(3, function()
            PlaneService:DestroyPlane(planeId)
        end)
    end

    -- ── onBust ────────────────────────────────────────────────────────────────
    local function onBust(_waypointIdx: number)
        for _, manifest in planeData.cargo do
            local cd = CargoData[manifest.cargoType]
            if cd then
                HeatService:AddHeat(cd.HeatOnBust * manifest.amount, origin)
            end
        end

        local pp = self._playerProfiles[player.UserId]
        if pp then
            pp.Data.Player.TotalRunsFailed += 1
        end

        self.Client.RunCompleted:FireAll(planeId, 0, false)
        task.delay(3, function()
            PlaneService:DestroyPlane(planeId)
        end)
    end

    -- Hand off to RouteService — everything from here is async
    RouteService:StartFlight(
        planeId, routeName,
        hubUpgrades, data.GlobalUpgrades,
        onComplete, onBust
    )
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Client-facing wrappers
-- ─────────────────────────────────────────────────────────────────────────────

function EmpireService.Client:LaunchRun(player: Player, planeId: string, routeName: string)
    self.Server:LaunchRun(player, planeId, routeName)
end

function EmpireService.Client:GetEmpireData(_player: Player)
    return self.Server:GetEmpireData()
end

function EmpireService.Client:SpendMoney(_player: Player, amount: number): boolean
    return self.Server:SpendMoney(amount)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Lifecycle
-- ─────────────────────────────────────────────────────────────────────────────

function EmpireService:KnitInit()
    -- Load shared empire profile
    -- "ForceLoad" is appropriate here: one server owns the empire at a time.
    local profile = EmpireStore:LoadProfileAsync("SharedEmpire", "ForceLoad")
    if profile then
        profile:AddUserId(0)
        profile:Reconcile()
        self._empireProfile = profile
    else
        warn("[EmpireService] Failed to load empire profile!")
    end

    -- Wire Heat decay bonus into HeatService once all services are initialised
    task.defer(function()
        local HeatService    = Knit.GetService("HeatService")
        local UpgradeService = Knit.GetService("UpgradeService")
        HeatService:SetDecayBonusCallback(function(): number
            local d = self:GetEmpireData()
            if not d then return 0 end
            return UpgradeService:GetTotalHeatDecayBonus(d.HubLayouts, d.GlobalUpgrades)
        end)
    end)
end

function EmpireService:KnitStart()
    -- Per-player profile loading / unloading
    Players.PlayerAdded:Connect(function(player: Player)
        local key = "Player_" .. player.UserId
        local profile = PlayerStore:LoadProfileAsync(key)
        if profile then
            profile:AddUserId(player.UserId)
            profile:Reconcile()
            self._playerProfiles[player.UserId] = profile
        end

        -- Grant starter hub on first ever join
        local empireData = self:GetEmpireData()
        if empireData and not empireData.UnlockedHubs["HomeBase"] then
            empireData.UnlockedHubs["HomeBase"] = true
        end
    end)

    Players.PlayerRemoving:Connect(function(player: Player)
        local profile = self._playerProfiles[player.UserId]
        if profile then
            profile:Release()
            self._playerProfiles[player.UserId] = nil
        end
    end)

    -- ProfileService handles auto-save internally; explicit Release on close
    game:BindToClose(function()
        if self._empireProfile then
            self._empireProfile:Release()
        end
        for _, profile in self._playerProfiles do
            profile:Release()
        end
    end)
end

return EmpireService
