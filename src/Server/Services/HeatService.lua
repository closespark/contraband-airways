--!strict
-- HeatService (Knit Service)
-- Global Heat (0–1000) is the escalation meter: the more valuable runs you
-- complete, the more Heat builds, making every route riskier until you invest
-- in decay buildings.  Mirrors the tycoon-kit "global pressure" pattern.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit        = require(ReplicatedStorage.Packages.Knit)
local UpgradeData = require(ReplicatedStorage.ContraBandShared.Data.UpgradeData)

-- ─────────────────────────────────────────────────────────────────────────────

local HEAT_CAP     = 1000
local DECAY_TICK   = 60   -- seconds between passive decay pulses
local BASE_DECAY   = 1    -- Heat removed per tick before upgrade bonuses

-- Escalation events fired when Heat crosses these thresholds
local ESCALATION: { [number]: string } = {
    [300] = "TaskForce",
    [600] = "SuperRival",
    [900] = "GlobalShutdown",
}

-- ─────────────────────────────────────────────────────────────────────────────

local HeatService = Knit.CreateService({
    Name = "HeatService",

    Client = {
        GlobalHeatChanged    = Knit.CreateSignal(), -- (newHeat: number)
        EscalationTriggered  = Knit.CreateSignal(), -- (eventName: string)
    },

    -- State
    _globalHeat          = 0,
    _hubHeat             = {} :: { [string]: number },
    _escalationFired     = {} :: { [string]: boolean },
    _decayBonusCallback  = nil :: (() -> number)?,
})

-- ─────────────────────────────────────────────────────────────────────────────
-- Public API
-- ─────────────────────────────────────────────────────────────────────────────

function HeatService:GetGlobalHeat(): number
    return self._globalHeat
end

function HeatService:GetHubHeat(hubName: string): number
    return self._hubHeat[hubName] or 0
end

--- Add heat globally; optionally spread a portion to a specific hub.
function HeatService:AddHeat(amount: number, hubName: string?, heatMult: number?)
    local delta = amount * (heatMult or 1.0)

    self._globalHeat = math.clamp(self._globalHeat + delta, 0, HEAT_CAP)
    if hubName then
        self._hubHeat[hubName] = math.clamp(
            (self._hubHeat[hubName] or 0) + delta * 0.5, 0, HEAT_CAP
        )
    end

    self.Client.GlobalHeatChanged:FireAll(self._globalHeat)
    self:_checkEscalation()
end

--- Emergency reset (dev product or late-game event).
function HeatService:ResetHeat(partial: boolean?)
    if partial then
        self._globalHeat = math.max(self._globalHeat - 100, 0)
    else
        self._globalHeat = 0
        table.clear(self._hubHeat)
        table.clear(self._escalationFired)
    end
    self.Client.GlobalHeatChanged:FireAll(self._globalHeat)
end

--- Register a callback that returns the current total HeatDecayBonus.
--- Called by EmpireService once upgrades are loaded.
function HeatService:SetDecayBonusCallback(cb: () -> number)
    self._decayBonusCallback = cb
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Private
-- ─────────────────────────────────────────────────────────────────────────────

function HeatService:_checkEscalation()
    for threshold, eventName in ESCALATION do
        if self._globalHeat >= threshold and not self._escalationFired[eventName] then
            self._escalationFired[eventName] = true
            self.Client.EscalationTriggered:FireAll(eventName)
        end
        -- Reset flag when Heat drops back below threshold
        if self._globalHeat < threshold then
            self._escalationFired[eventName] = false
        end
    end
end

function HeatService:_decayTick()
    local bonus = self._decayBonusCallback and self._decayBonusCallback() or 0
    local decay = BASE_DECAY + bonus

    self._globalHeat = math.max(self._globalHeat - decay, 0)
    for hub in self._hubHeat do
        self._hubHeat[hub] = math.max(self._hubHeat[hub] - decay * 0.5, 0)
    end

    self.Client.GlobalHeatChanged:FireAll(self._globalHeat)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Client passthroughs
-- ─────────────────────────────────────────────────────────────────────────────

function HeatService.Client:GetGlobalHeat(_player: Player): number
    return self.Server:GetGlobalHeat()
end

function HeatService.Client:GetHubHeat(_player: Player, hubName: string): number
    return self.Server:GetHubHeat(hubName)
end

-- ─────────────────────────────────────────────────────────────────────────────

function HeatService:KnitInit() end

function HeatService:KnitStart()
    -- Passive decay loop
    task.spawn(function()
        while true do
            task.wait(DECAY_TICK)
            self:_decayTick()
        end
    end)
end

return HeatService
