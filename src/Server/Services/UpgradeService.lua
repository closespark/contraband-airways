--!strict
-- UpgradeService (Knit Service)
-- Purchase and level up SimCity-style buildings + global network upgrades.
-- Pattern: tycoon-kit "upgrade button pressed → server validates cost → apply
-- to hub layout → update risk/decay formulae downstream".

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit        = require(ReplicatedStorage.Packages.Knit)
local UpgradeData = require(ReplicatedStorage.ContraBandShared.Data.UpgradeData)
local CargoData   = require(ReplicatedStorage.ContraBandShared.Data.CargoData)
local RouteData   = require(ReplicatedStorage.ContraBandShared.Data.RouteData)

-- ─────────────────────────────────────────────────────────────────────────────

local UpgradeService = Knit.CreateService({
    Name = "UpgradeService",

    Client = {
        UpgradePurchased = Knit.CreateSignal(), -- (scope: "hub"|"global", id, hubName, newLevel)
        UpgradeFailed    = Knit.CreateSignal(), -- (reason: string)
    },
})

-- Defence bonus tuning (shared source of truth — RouteService reads via GetDefenceBonus)
local ROUTE_COUNTER_MULTIPLIER = 1.25  -- bonus when upgrade is in route's CounterUpgrades list
local CARGO_COUNTER_MULTIPLIER = 1.10  -- bonus when upgrade is in cargo's BestCounters list
local DEFENCE_BONUS_CAP        = 0.80  -- maximum total risk reduction from upgrades

-- ─────────────────────────────────────────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────────────────────────────────────────

local function costForLevel(upgradeId: string, targetLevel: number): number
    local def = UpgradeData[upgradeId]
    if not def then return math.huge end
    return math.floor(def.Cost * (def.LevelCostMultiplier ^ (targetLevel - 1)))
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Public API
-- ─────────────────────────────────────────────────────────────────────────────

--- Attempt to purchase / level up an upgrade.
--- upgradesRef is mutated on success (the caller owns and persists it).
--- Returns (success, newLevel | errorMsg).
function UpgradeService:PurchaseUpgrade(
    upgradeId    : string,
    hubName      : string,
    blackMoney   : number,
    upgradesRef  : { [string]: number },
    empireTier   : number
): (boolean, number | string)
    local def = UpgradeData[upgradeId]
    if not def then return false, "Unknown upgrade: " .. upgradeId end

    if def.Tier > empireTier then
        return false, def.DisplayName .. " requires Tier " .. def.Tier
    end

    local current = upgradesRef[upgradeId] or 0
    if current >= def.MaxLevel then
        return false, def.DisplayName .. " is already at max level"
    end

    local targetLevel = current + 1
    local cost        = costForLevel(upgradeId, targetLevel)
    if blackMoney < cost then
        return false,
            string.format("Need %d black money (have %d)", cost, blackMoney)
    end

    upgradesRef[upgradeId] = targetLevel
    local scope = def.IsGlobal and "global" or "hub"
    self.Client.UpgradePurchased:FireAll(scope, upgradeId, hubName, targetLevel)
    return true, targetLevel
end

--- Preview cost for the next level of an upgrade.
function UpgradeService:GetUpgradeCost(upgradeId: string, currentLevel: number): number
    return costForLevel(upgradeId, currentLevel + 1)
end

--- Compute the total defence bonus a set of upgrades provides on a route/cargo combo.
--- Used by the UI to show a "risk preview" before committing to a launch,
--- and by RouteService as the single canonical calculation.
function UpgradeService:GetDefenceBonus(
    routeName     : string,
    cargo         : { any },
    hubUpgrades   : { [string]: number },
    globalUpgrades: { [string]: number }
): number
    local routeDef = RouteData[routeName]
    if not routeDef then return 0 end

    local bonus = 0
    local function processSet(ups: { [string]: number })
        for uid, level in ups do
            local upDef = UpgradeData[uid]
            if not upDef then continue end

            local reduction = upDef.RiskReduction * level

            for _, c in routeDef.CounterUpgrades do
                if c == uid then reduction *= ROUTE_COUNTER_MULTIPLIER; break end
            end
            for _, manifest in cargo do
                local cd = CargoData[manifest.cargoType]
                if cd then
                    for _, c in cd.BestCounters do
                        if c == uid then reduction *= CARGO_COUNTER_MULTIPLIER; break end
                    end
                end
            end

            bonus += reduction
        end
    end

    processSet(hubUpgrades)
    processSet(globalUpgrades)
    return math.min(bonus, DEFENCE_BONUS_CAP)
end

--- Sum the total HeatDecayBonus granted by all hub and global upgrades.
--- Used by HeatService's decay-bonus callback (registered in EmpireService:KnitInit).
function UpgradeService:GetTotalHeatDecayBonus(
    hubLayouts    : { [string]: { [string]: any } },
    globalUpgrades: { [string]: number }
): number
    local bonus = 0
    for _, layout in hubLayouts do
        for uid, info in layout do
            if type(info) == "table" and info.level then
                local def = UpgradeData[uid]
                if def then bonus += def.HeatDecayBonus * info.level end
            end
        end
    end
    for uid, level in globalUpgrades do
        local def = UpgradeData[uid]
        if def then bonus += def.HeatDecayBonus * level end
    end
    return bonus
end

--- All upgrade IDs available at or below a given empire tier.
function UpgradeService:GetAvailableUpgrades(empireTier: number): { string }
    local result = {}
    for id, def in UpgradeData do
        if def.Tier <= empireTier then
            table.insert(result, id)
        end
    end
    return result
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Client-facing wrappers
-- ─────────────────────────────────────────────────────────────────────────────

function UpgradeService.Client:PurchaseUpgrade(
    player   : Player,
    upgradeId: string,
    hubName  : string
): (boolean, number | string)
    local EmpireService = Knit.GetService("EmpireService")
    local empireData    = EmpireService:GetEmpireData()
    if not empireData then return false, "Empire data not loaded" end

    local def = UpgradeData[upgradeId]
    if not def then return false, "Unknown upgrade: " .. upgradeId end

    -- Choose the right upgrades table (hub or global)
    local upgradesRef: { [string]: number }
    if def.IsGlobal then
        upgradesRef = empireData.GlobalUpgrades
    else
        if not empireData.HubLayouts[hubName] then
            empireData.HubLayouts[hubName] = {}
        end
        local layout = empireData.HubLayouts[hubName]
        -- Flatten { [id] = { level = N } } → { [id] = N } for the check
        upgradesRef = {}
        for id, info in layout do
            if type(info) == "table" then
                upgradesRef[id] = info.level or 0
            end
        end
    end

    local currentLevel = upgradesRef[upgradeId] or 0
    local cost = self.Server:GetUpgradeCost(upgradeId, currentLevel)

    local ok, result = self.Server:PurchaseUpgrade(
        upgradeId, hubName,
        empireData.BlackMoney, upgradesRef,
        empireData.Tier
    )

    if ok then
        -- Deduct cost via EmpireService (single source of truth for money)
        EmpireService:SpendMoney(cost)
        -- Write new level back into the persistent hub layout
        if not def.IsGlobal then
            local layout = empireData.HubLayouts[hubName]
            if not layout[upgradeId] then
                layout[upgradeId] = { level = 0, gridX = 0, gridZ = 0 }
            end
            layout[upgradeId].level = result :: number
        end
    end

    return ok, result
end

function UpgradeService.Client:GetAvailableUpgrades(_player: Player): { string }
    local EmpireService = Knit.GetService("EmpireService")
    return self.Server:GetAvailableUpgrades(EmpireService:GetEmpireTier())
end

function UpgradeService.Client:GetUpgradeCost(
    _player: Player, upgradeId: string, currentLevel: number
): number
    return self.Server:GetUpgradeCost(upgradeId, currentLevel)
end

function UpgradeService.Client:GetDefenceBonus(
    _player: Player,
    routeName     : string,
    cargo         : { any },
    hubUpgrades   : { [string]: number },
    globalUpgrades: { [string]: number }
): number
    return self.Server:GetDefenceBonus(routeName, cargo, hubUpgrades, globalUpgrades)
end

-- ─────────────────────────────────────────────────────────────────────────────

function UpgradeService:KnitInit() end
function UpgradeService:KnitStart() end

return UpgradeService
