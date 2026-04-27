--!strict
-- BuildController (Knit Controller)
-- Client-side building UI: auto-build mode (predefined plot slots per hub) and
-- layout mode (free-placement grid, unlocked later).
-- Listens to BuildService signals to keep a local state cache in sync,
-- then exposes helpers for UI components to drive.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit          = require(ReplicatedStorage.Packages.Knit)
local StructureData = require(ReplicatedStorage.ContraBandShared.Data.StructureData)

-- ─────────────────────────────────────────────────────────────────────────────
-- Auto-build slot table
-- Each hub lists predefined grid positions per structure (auto-build mode).
-- gridX / gridZ are tile indices in the hub's build grid.
-- ─────────────────────────────────────────────────────────────────────────────

local HUB_PLOT_SLOTS: { [string]: { { uid: string, gridX: number, gridZ: number } } } = {
    HomeBase = {
        { uid = "HiddenWarehouse",  gridX = 0, gridZ = 0 },
        { uid = "FuelDepot",        gridX = 2, gridZ = 0 },
        { uid = "ScrapYard",        gridX = 4, gridZ = 0 },
        { uid = "LookoutPost",      gridX = 0, gridZ = 2 },
        { uid = "FakeOffice",       gridX = 2, gridZ = 2 },
        { uid = "BribeOffice",      gridX = 4, gridZ = 2 },
        { uid = "Runway",           gridX = 0, gridZ = 4 },
        { uid = "Hangar",           gridX = 3, gridZ = 4 },
        { uid = "RadarTower",       gridX = 6, gridZ = 4 },
        { uid = "CommandBunker",    gridX = 0, gridZ = 7 },
        { uid = "PartsYard",        gridX = 4, gridZ = 7 },
    },
}

-- ─────────────────────────────────────────────────────────────────────────────

local BuildController = Knit.CreateController({ Name = "BuildController" })

-- { [hubId] = { [uid] = stateString } }
BuildController._stateCache = {} :: { [string]: { [string]: string } }

-- ─────────────────────────────────────────────────────────────────────────────
-- Private helpers
-- ─────────────────────────────────────────────────────────────────────────────

function BuildController:_setCache(hubId: string, uid: string, state: string)
    if not self._stateCache[hubId] then self._stateCache[hubId] = {} end
    self._stateCache[hubId][uid] = state
    self:_onStateChange(hubId, uid, state)
end

--- Stub for UI integration — override in a Fusion component or UI script.
--- Called whenever a structure's state changes in the local cache.
function BuildController:_onStateChange(hubId: string, uid: string, state: string)
    local def = StructureData[uid]
    local label = def and def.DisplayName or uid
    -- Replace this print with your Fusion UI update when building the full UI.
    print(string.format("[BuildController] %s › %s = %s", hubId, label, state))
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Public API
-- ─────────────────────────────────────────────────────────────────────────────

--- Request a build for `uid` at `hubId`.
--- Auto-build mode: grid position comes from HUB_PLOT_SLOTS.
--- Returns nothing — success/failure arrives via BuildQueued / BuildFailed signals.
function BuildController:RequestBuild(hubId: string, uid: string)
    local BuildService = Knit.GetService("BuildService")
    local ok, err = BuildService:QueueBuild(hubId, uid)
    if ok then
        self:_setCache(hubId, uid, "UnderConstruction")
    else
        warn(string.format("[BuildController] Build failed (%s @ %s): %s", uid, hubId, tostring(err)))
    end
end

--- Return the locally cached state string for a structure, or fetch from server.
function BuildController:GetStructureState(hubId: string, uid: string): string
    local cached = self._stateCache[hubId] and self._stateCache[hubId][uid]
    if cached then return cached end
    local BuildService = Knit.GetService("BuildService")
    local state = BuildService:GetStructureState(hubId, uid)
    self:_setCache(hubId, uid, state)
    return state
end

--- Return the predefined grid slot for `uid` at `hubId`, or {0, 0} as fallback.
function BuildController:GetSlot(hubId: string, uid: string): { number }
    local slots = HUB_PLOT_SLOTS[hubId] or {}
    for _, slot in slots do
        if slot.uid == uid then return { slot.gridX, slot.gridZ } end
    end
    return { 0, 0 }
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Lifecycle
-- ─────────────────────────────────────────────────────────────────────────────

function BuildController:KnitInit() end

function BuildController:KnitStart()
    local BuildService = Knit.GetService("BuildService")

    BuildService.BuildQueued:Connect(function(hubId: string, uid: string, _duration: number)
        self:_setCache(hubId, uid, "UnderConstruction")
    end)

    BuildService.BuildCompleted:Connect(function(hubId: string, uid: string)
        self:_setCache(hubId, uid, "Built")
    end)

    BuildService.BuildFailed:Connect(function(hubId: string, uid: string, reason: string)
        warn(string.format("[BuildController] Build of %s @ %s failed: %s", uid, hubId, reason))
        -- Revert to Available so the UI doesn't show a stuck UnderConstruction badge
        self:_setCache(hubId, uid, "Available")
    end)
end

return BuildController
