--!strict
-- MapController (Knit Controller)
-- Fusion-reactive world-map overlay drawn on a ScreenGui.
-- Shows:  active flight arcs, hub Heat badges, global Heat bar,
--         escalation alert banners, route unlock highlights.
--
-- Fusion pattern: Value / Computed / Spring state drives every label and
-- colour — no manual :FindFirstChild() polling needed.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local Knit   = require(ReplicatedStorage.Packages.Knit)
local Fusion = require(ReplicatedStorage.Packages.Fusion)

local New      = Fusion.New
local Children = Fusion.Children
local Value    = Fusion.Value
local Computed = Fusion.Computed
local Spring   = Fusion.Spring

local RouteData = require(ReplicatedStorage.ContraBandShared.Data.RouteData)

-- ─────────────────────────────────────────────────────────────────────────────

local HEAT_MAX       = 1000
local ALERT_DURATION = 6   -- seconds an alert banner stays visible

-- ─────────────────────────────────────────────────────────────────────────────

local MapController = Knit.CreateController({ Name = "MapController" })

-- ── Reactive state atoms ─────────────────────────────────────────────────────

local globalHeat       = Value(0)           -- 0–1000
local activePlanes: Value<{ [string]: string }> = Value({})  -- planeId → routeName
local alertQueue: Value<{ string }>         = Value({})      -- ordered alert messages
local unlockedHubs: Value<{ [string]: boolean }> = Value({}) -- hubId → true

-- ─────────────────────────────────────────────────────────────────────────────
-- UI construction helpers
-- ─────────────────────────────────────────────────────────────────────────────

-- Heat bar colour: green → amber → red
local heatBarColor = Computed(function()
    local t = globalHeat:get() / HEAT_MAX
    if t < 0.4 then
        return Color3.fromRGB(80, 200, 80)
    elseif t < 0.7 then
        return Color3.fromRGB(255, 170, 0)
    else
        return Color3.fromRGB(220, 50, 50)
    end
end)

local heatBarWidth = Spring(
    Computed(function()
        return UDim2.fromScale(globalHeat:get() / HEAT_MAX, 1)
    end),
    12   -- spring speed
)

local function makeHeatBar(): Frame
    return New("Frame")({
        Name            = "HeatBarBg",
        Size            = UDim2.new(0.3, 0, 0, 18),
        Position        = UDim2.new(0.35, 0, 0, 8),
        BackgroundColor3 = Color3.fromRGB(40, 40, 40),
        BorderSizePixel  = 0,
        [Children] = {
            New("Frame")({
                Name             = "Fill",
                Size             = heatBarWidth,
                BackgroundColor3 = heatBarColor,
                BorderSizePixel  = 0,
            }),
            New("TextLabel")({
                Name             = "Label",
                Size             = UDim2.fromScale(1, 1),
                BackgroundTransparency = 1,
                Text             = Computed(function()
                    return string.format("🌡 Heat  %d / %d", globalHeat:get(), HEAT_MAX)
                end),
                TextColor3       = Color3.new(1, 1, 1),
                TextScaled       = true,
                Font             = Enum.Font.GothamBold,
            }),
        },
    })
end

-- Floating plane label pinned above the plane model in world space
local function makePlaneTag(planeId: string, routeName: string): BillboardGui
    local routeDef = RouteData[routeName]
    local label    = routeDef and routeDef.DisplayName or routeName

    return New("BillboardGui")({
        Name          = "PlaneTag_" .. planeId,
        Size          = UDim2.new(0, 120, 0, 36),
        StudsOffset   = Vector3.new(0, 8, 0),
        AlwaysOnTop   = true,
        [Children] = {
            New("TextLabel")({
                Size             = UDim2.fromScale(1, 1),
                BackgroundColor3 = Color3.fromRGB(20, 20, 20),
                BackgroundTransparency = 0.3,
                Text             = "✈ " .. label,
                TextColor3       = Color3.new(1, 1, 1),
                TextScaled       = true,
                Font             = Enum.Font.Gotham,
            }),
        },
    })
end

-- Alert banner at the top-centre of the screen
local function makeAlertBanner(message: string): Frame
    return New("Frame")({
        Name             = "AlertBanner",
        Size             = UDim2.new(0.6, 0, 0, 40),
        Position         = UDim2.new(0.2, 0, 0, 34),
        BackgroundColor3 = Color3.fromRGB(200, 60, 30),
        BorderSizePixel  = 0,
        [Children] = {
            New("TextLabel")({
                Size             = UDim2.fromScale(1, 1),
                BackgroundTransparency = 1,
                Text             = message,
                TextColor3       = Color3.new(1, 1, 1),
                TextScaled       = true,
                Font             = Enum.Font.GothamBold,
            }),
        },
    })
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Alert queue helpers
-- ─────────────────────────────────────────────────────────────────────────────

local function pushAlert(message: string)
    local q = alertQueue:get()
    local next = table.clone(q)
    table.insert(next, 1, message)
    alertQueue:set(next)

    task.delay(ALERT_DURATION, function()
        local current = alertQueue:get()
        local updated = table.clone(current)
        local idx = table.find(updated, message)
        if idx then table.remove(updated, idx) end
        alertQueue:set(updated)
    end)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Controller lifecycle
-- ─────────────────────────────────────────────────────────────────────────────

function MapController:KnitInit()
    -- Build root ScreenGui
    local gui = New("ScreenGui")({
        Name            = "MapOverlay",
        ResetOnSpawn    = false,
        IgnoreGuiInset  = true,
        Parent          = Players.LocalPlayer:WaitForChild("PlayerGui"),

        [Children] = {
            makeHeatBar(),

            -- Alert banner driven by the first item in the queue
            Computed(function()
                local q = alertQueue:get()
                if #q == 0 then return nil end
                return makeAlertBanner(q[1])
            end),
        },
    })
end

function MapController:KnitStart()
    -- ── Service signal hooks ────────────────────────────────────────────────

    local HeatService    = Knit.GetService("HeatService")
    local PlaneService   = Knit.GetService("PlaneService")
    local RouteService   = Knit.GetService("RouteService")
    local EventManager   = Knit.GetService("EventManager")
    local EmpireService  = Knit.GetService("EmpireService")

    -- Heat updates
    HeatService.Client.GlobalHeatChanged:Connect(function(heat: number)
        globalHeat:set(heat)
    end)

    -- Escalation alerts
    HeatService.Client.EscalationTriggered:Connect(function(eventName: string)
        local messages: { [string]: string } = {
            TaskForce     = "⚠️  TASK FORCE mobilised — empire under attack!",
            SuperRival    = "😈  SUPER-RIVAL declared war on your syndicate!",
            GlobalShutdown = "🔴  GLOBAL SHUTDOWN — all hubs locked until Heat drops!",
        }
        pushAlert(messages[eventName] or "⚠️ " .. eventName)
    end)

    -- Flight started — attach a tag billboard to the plane model
    RouteService.Client.FlightStarted:Connect(function(planeId: string, routeName: string)
        local planes = table.clone(activePlanes:get())
        planes[planeId] = routeName
        activePlanes:set(planes)

        -- Attach BillboardGui to the plane model
        local model = workspace.PlanesFolder and workspace.PlanesFolder:FindFirstChild(planeId)
        if not model then
            -- Fallback: search by attribute
            for _, m in workspace:GetDescendants() do
                if m:IsA("Model") and m:GetAttribute("PlaneId") == planeId then
                    model = m
                    break
                end
            end
        end
        if model then
            local tag = makePlaneTag(planeId, routeName)
            tag.Parent = model
        end
    end)

    -- Plane destroyed — remove from active table
    PlaneService.Client.PlaneDestroyed:Connect(function(planeId: string)
        local planes = table.clone(activePlanes:get())
        planes[planeId] = nil
        activePlanes:set(planes)
    end)

    -- Chaos event alerts
    EventManager.Client.ChaosEventFired:Connect(function(
        _planeId: string, _eventName: string, _idx: number, message: string
    )
        pushAlert(message)
    end)

    -- Hub unlocks
    EmpireService.Client.HubUnlocked:Connect(function(hubName: string)
        local hubs = table.clone(unlockedHubs:get())
        hubs[hubName] = true
        unlockedHubs:set(hubs)
        pushAlert("🏠  New hub unlocked: " .. hubName)
    end)

    -- Tier unlocked
    EmpireService.Client.TierUnlocked:Connect(function(tier: number)
        pushAlert(
            string.format("🌍  TIER %d UNLOCKED — new routes and upgrades available!", tier)
        )
    end)

    -- Seed current heat from server
    task.spawn(function()
        local heat = HeatService:GetGlobalHeat()
        globalHeat:set(heat)
    end)
end

return MapController
