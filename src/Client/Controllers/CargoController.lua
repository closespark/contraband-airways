--!strict
-- CargoController (Knit Controller)
-- Overhead drag-to-load cargo panel built with Fusion.
-- One click on a parked plane → panel slides in with a grid of cargo buttons.
-- Each button shows: icon colour, display name, slot cost, payout ★★★.
-- "Load" fires CargoService:LoadCargo; "Launch" fires EmpireService:LaunchRun.
--
-- Pattern: Fusion Value state per plane selection → Computed UI regenerates
-- automatically.  No imperative DOM-diffing needed.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")

local Knit   = require(ReplicatedStorage.Packages.Knit)
local Fusion = require(ReplicatedStorage.Packages.Fusion)

local New      = Fusion.New
local Children = Fusion.Children
local Value    = Fusion.Value
local Computed = Fusion.Computed
local Spring   = Fusion.Spring
local Event    = Fusion.OnEvent

local CargoData = require(ReplicatedStorage.ContraBandShared.Data.CargoData)
local RouteData = require(ReplicatedStorage.ContraBandShared.Data.RouteData)

-- ─────────────────────────────────────────────────────────────────────────────

local CargoController = Knit.CreateController({ Name = "CargoController" })

-- ── Panel state ───────────────────────────────────────────────────────────────

local selectedPlaneId = Value("")         -- "" = panel closed
local selectedRoute   = Value("")         -- route chosen in the dropdown
local manifest        = Value({} :: { [string]: number }) -- cargoType → amount
local feedbackMsg     = Value("")         -- load / launch result text

-- ─────────────────────────────────────────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────────────────────────────────────────

local STAR_LABELS = { "★", "★★", "★★★", "★★★★", "★★★★★" }

local function starsForMultiplier(mult: number): string
    local idx = math.clamp(math.round(mult), 1, 5)
    return STAR_LABELS[idx] or "★"
end

local function slotBar(used: number, total: number): string
    local filled = math.clamp(used, 0, total)
    return string.rep("▮", filled) .. string.rep("▯", total - filled)
        .. string.format("  %d/%d", used, total)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Per-cargo-type button
-- ─────────────────────────────────────────────────────────────────────────────

local function makeCargoButton(cargoId: string, cargoDef: typeof(CargoData.ShinyRocks)): Frame
    local count = Computed(function()
        return manifest:get()[cargoId] or 0
    end)

    local bgColor = Spring(
        Computed(function()
            return (manifest:get()[cargoId] or 0) > 0
                and cargoDef.Color
                or Color3.fromRGB(50, 50, 55)
        end),
        10
    )

    return New("Frame")({
        Name             = "CargoBtn_" .. cargoId,
        Size             = UDim2.new(1, 0, 0, 56),
        BackgroundColor3 = bgColor,
        BorderSizePixel  = 0,
        [Children] = {
            -- Colour swatch
            New("Frame")({
                Name             = "Swatch",
                Size             = UDim2.new(0, 8, 1, 0),
                BackgroundColor3 = cargoDef.Color,
                BorderSizePixel  = 0,
            }),
            -- Name + stars
            New("TextLabel")({
                Name                   = "Label",
                Position               = UDim2.new(0, 14, 0, 4),
                Size                   = UDim2.new(0.6, -14, 0.5, 0),
                BackgroundTransparency = 1,
                Text                   = cargoDef.DisplayName,
                TextColor3             = Color3.new(1, 1, 1),
                TextXAlignment         = Enum.TextXAlignment.Left,
                TextScaled             = true,
                Font                   = Enum.Font.GothamBold,
            }),
            New("TextLabel")({
                Name                   = "Stars",
                Position               = UDim2.new(0, 14, 0.5, 0),
                Size                   = UDim2.new(0.6, -14, 0.5, 0),
                BackgroundTransparency = 1,
                Text                   = starsForMultiplier(cargoDef.PayoutMultiplier)
                    .. "  " .. cargoDef.Slots .. " slot" .. (cargoDef.Slots > 1 and "s" or ""),
                TextColor3             = Color3.fromRGB(255, 215, 0),
                TextXAlignment         = Enum.TextXAlignment.Left,
                TextScaled             = true,
                Font                   = Enum.Font.Gotham,
            }),
            -- Amount stepper
            New("TextButton")({
                Name             = "Minus",
                Position         = UDim2.new(0.65, 0, 0.1, 0),
                Size             = UDim2.new(0, 28, 0.8, 0),
                Text             = "−",
                TextColor3       = Color3.new(1, 1, 1),
                BackgroundColor3 = Color3.fromRGB(80, 30, 30),
                Font             = Enum.Font.GothamBold,
                TextScaled       = true,
                [Event("Activated")] = function()
                    local m = table.clone(manifest:get())
                    m[cargoId] = math.max((m[cargoId] or 0) - 1, 0)
                    manifest:set(m)
                end,
            }),
            New("TextLabel")({
                Name                   = "Count",
                Position               = UDim2.new(0.65, 32, 0.1, 0),
                Size                   = UDim2.new(0, 28, 0.8, 0),
                BackgroundTransparency = 1,
                Text                   = Computed(function()
                    return tostring(manifest:get()[cargoId] or 0)
                end),
                TextColor3  = Color3.new(1, 1, 1),
                TextScaled  = true,
                Font        = Enum.Font.GothamBold,
            }),
            New("TextButton")({
                Name             = "Plus",
                Position         = UDim2.new(0.65, 64, 0.1, 0),
                Size             = UDim2.new(0, 28, 0.8, 0),
                Text             = "+",
                TextColor3       = Color3.new(1, 1, 1),
                BackgroundColor3 = Color3.fromRGB(30, 80, 30),
                Font             = Enum.Font.GothamBold,
                TextScaled       = true,
                [Event("Activated")] = function()
                    local m = table.clone(manifest:get())
                    m[cargoId] = (m[cargoId] or 0) + 1
                    manifest:set(m)
                end,
            }),
        },
    })
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Route selector row
-- ─────────────────────────────────────────────────────────────────────────────

local function makeRouteSelector(availableRoutes: { string }): Frame
    local buttons = {}
    for _, routeId in availableRoutes do
        local rd   = RouteData[routeId]
        local name = rd and rd.DisplayName or routeId

        table.insert(buttons, New("TextButton")({
            Name             = "RouteBtn_" .. routeId,
            Size             = UDim2.new(0, 160, 0, 32),
            Text             = name,
            TextScaled       = true,
            Font             = Enum.Font.Gotham,
            TextColor3       = Color3.new(1, 1, 1),
            BackgroundColor3 = Computed(function()
                return selectedRoute:get() == routeId
                    and Color3.fromRGB(60, 120, 220)
                    or  Color3.fromRGB(40, 40, 50)
            end),
            BorderSizePixel  = 0,
            [Event("Activated")] = function()
                selectedRoute:set(routeId)
            end,
        }))
    end

    return New("ScrollingFrame")({
        Name             = "RouteScroll",
        Size             = UDim2.new(1, 0, 0, 40),
        BackgroundTransparency = 1,
        ScrollBarThickness = 4,
        AutomaticCanvasSize = Enum.AutomaticSize.X,
        CanvasSize       = UDim2.new(0, 0, 0, 0),
        [Children] = {
            New("UIListLayout")({
                FillDirection = Enum.FillDirection.Horizontal,
                Padding       = UDim.new(0, 6),
            }),
            table.unpack(buttons),
        },
    })
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Main panel
-- ─────────────────────────────────────────────────────────────────────────────

local function buildPanel(): Frame
    local CargoService  = Knit.GetService("CargoService")
    local EmpireService = Knit.GetService("EmpireService")
    local RouteService  = Knit.GetService("RouteService")
    local PlaneService  = Knit.GetService("PlaneService")

    -- Slide-in spring: panel X goes from 1 (off-screen right) to 0.65 (visible)
    local panelX = Spring(
        Computed(function()
            return selectedPlaneId:get() ~= "" and 0.65 or 1.05
        end),
        14
    )

    -- Available cargo types for current tier (fetched once on open; re-fetched on tier change)
    local availableTypes = Value({} :: { string })
    local availableRoutes = Value({} :: { string })

    -- Fetch fresh lists when a plane is selected
    local function refreshLists()
        task.spawn(function()
            local ok1, types = pcall(function() return CargoService:GetAvailableTypes() end)
            if ok1 and types then
                availableTypes:set(types)
            else
                feedbackMsg:set("⚠ Failed to load cargo list")
            end

            local ok2, tier = pcall(function() return EmpireService:GetEmpireTier() end)
            if ok2 and tier then
                local ok3, routes = pcall(function() return RouteService:GetRoutesForTier(tier) end)
                if ok3 and routes then
                    availableRoutes:set(routes)
                else
                    feedbackMsg:set("⚠ Failed to load route list")
                end
            end
        end)
    end

    -- Cargo button list (recomputed when available types change)
    local cargoButtons = Computed(function()
        local btns = {}
        for _, cargoId in availableTypes:get() do
            local def = CargoData[cargoId]
            if def then
                table.insert(btns, makeCargoButton(cargoId, def))
            end
        end
        return btns
    end)

    return New("Frame")({
        Name             = "CargoPanel",
        Size             = UDim2.new(0.34, 0, 0.9, 0),
        Position         = Computed(function()
            return UDim2.new(panelX:get(), 0, 0.05, 0)
        end),
        BackgroundColor3 = Color3.fromRGB(18, 18, 24),
        BorderSizePixel  = 0,

        [Children] = {
            New("UICorner")({ CornerRadius = UDim.new(0, 8) }),

            -- Header
            New("TextLabel")({
                Name             = "Title",
                Size             = UDim2.new(1, -8, 0, 32),
                Position         = UDim2.new(0, 4, 0, 4),
                BackgroundTransparency = 1,
                Text             = Computed(function()
                    local pid = selectedPlaneId:get()
                    if pid == "" then return "No plane selected" end
                    local data = PlaneService:GetPlaneData(pid)
                    if not data then return "Plane: " .. pid end
                    return string.format(
                        "✈  %s  |  %s",
                        pid,
                        slotBar(data.usedSlots, data.totalSlots)
                    )
                end),
                TextColor3   = Color3.new(1, 1, 1),
                TextScaled   = true,
                Font         = Enum.Font.GothamBold,
                TextXAlignment = Enum.TextXAlignment.Left,
            }),

            -- Route selector
            Computed(function()
                return makeRouteSelector(availableRoutes:get())
            end),

            -- Cargo scroll list
            New("ScrollingFrame")({
                Name              = "CargoScroll",
                Position          = UDim2.new(0, 0, 0, 82),
                Size              = UDim2.new(1, 0, 1, -170),
                BackgroundTransparency = 1,
                ScrollBarThickness = 6,
                AutomaticCanvasSize = Enum.AutomaticSize.Y,
                CanvasSize        = UDim2.new(0, 0, 0, 0),
                [Children] = {
                    New("UIListLayout")({
                        Padding       = UDim.new(0, 4),
                        SortOrder     = Enum.SortOrder.Name,
                    }),
                    cargoButtons,
                },
            }),

            -- Feedback line
            New("TextLabel")({
                Name             = "Feedback",
                Position         = UDim2.new(0, 8, 1, -80),
                Size             = UDim2.new(1, -16, 0, 24),
                BackgroundTransparency = 1,
                Text             = feedbackMsg,
                TextColor3       = Color3.fromRGB(200, 200, 100),
                TextScaled       = true,
                Font             = Enum.Font.Gotham,
                TextXAlignment   = Enum.TextXAlignment.Left,
            }),

            -- Load button
            New("TextButton")({
                Name             = "LoadBtn",
                Position         = UDim2.new(0.05, 0, 1, -52),
                Size             = UDim2.new(0.42, 0, 0, 38),
                Text             = "📦  Load Cargo",
                TextColor3       = Color3.new(1, 1, 1),
                BackgroundColor3 = Color3.fromRGB(40, 100, 180),
                BorderSizePixel  = 0,
                Font             = Enum.Font.GothamBold,
                TextScaled       = true,
                [Children] = { New("UICorner")({ CornerRadius = UDim.new(0, 6) }) },
                [Event("Activated")] = function()
                    local pid = selectedPlaneId:get()
                    if pid == "" then feedbackMsg:set("Select a plane first!"); return end

                    local anyLoaded = false
                    for cargoId, amount in manifest:get() do
                        if amount > 0 then
                            local ok, err = CargoService:LoadCargo(pid, cargoId, amount)
                            if ok then
                                anyLoaded = true
                            else
                                feedbackMsg:set("❌ " .. (err or "Load failed"))
                                return
                            end
                        end
                    end

                    if anyLoaded then
                        manifest:set({})
                        feedbackMsg:set("✅ Cargo loaded!")
                    else
                        feedbackMsg:set("Add cargo first!")
                    end
                end,
            }),

            -- Launch button
            New("TextButton")({
                Name             = "LaunchBtn",
                Position         = UDim2.new(0.53, 0, 1, -52),
                Size             = UDim2.new(0.42, 0, 0, 38),
                Text             = "🚀  Launch!",
                TextColor3       = Color3.new(1, 1, 1),
                BackgroundColor3 = Color3.fromRGB(180, 60, 30),
                BorderSizePixel  = 0,
                Font             = Enum.Font.GothamBold,
                TextScaled       = true,
                [Children] = { New("UICorner")({ CornerRadius = UDim.new(0, 6) }) },
                [Event("Activated")] = function()
                    local pid   = selectedPlaneId:get()
                    local route = selectedRoute:get()
                    if pid == "" then feedbackMsg:set("Select a plane first!"); return end
                    if route == "" then feedbackMsg:set("Choose a route first!"); return end

                    EmpireService:LaunchRun(pid, route)
                    feedbackMsg:set("✈ Plane launched on " .. route)
                    selectedPlaneId:set("")  -- close panel
                end,
            }),
        },
    })
end

-- ─────────────────────────────────────────────────────────────────────────────

function CargoController:KnitInit()
    local gui = New("ScreenGui")({
        Name           = "CargoOverlay",
        ResetOnSpawn   = false,
        IgnoreGuiInset = true,
        Parent         = Players.LocalPlayer:WaitForChild("PlayerGui"),
        [Children]     = { buildPanel() },
    })
end

function CargoController:KnitStart()
    local PlaneService  = Knit.GetService("PlaneService")
    local EmpireService = Knit.GetService("EmpireService")

    -- Run-completed feedback
    EmpireService.Client.RunCompleted:Connect(function(
        planeId: string, payout: number, isSuccess: boolean
    )
        if isSuccess then
            feedbackMsg:set(string.format("💰 +%d  Run complete!", payout))
        else
            feedbackMsg:set(string.format("💥 Busted!  Cargo lost on %s.", planeId))
        end
    end)

    -- Open panel when a plane in the world is clicked
    UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
        if processed then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end

        local target = workspace.CurrentCamera:ScreenPointToRay(
            input.Position.X, input.Position.Y
        )
        local result = workspace:Raycast(
            target.Origin, target.Direction * 1000,
            RaycastParams.new()
        )
        if not result then return end

        local hit = result.Instance
        local model = hit:FindFirstAncestorOfClass("Model")
        if not model then return end

        local planeId = model:GetAttribute("PlaneId")
        if not planeId then return end

        -- Toggle panel
        if selectedPlaneId:get() == planeId then
            selectedPlaneId:set("")
        else
            selectedPlaneId:set(planeId)
            manifest:set({})
            selectedRoute:set("")
            feedbackMsg:set("")
        end
    end)
end

--- Programmatically open the cargo panel for a specific plane (e.g. from the map).
function CargoController:OpenForPlane(planeId: string)
    selectedPlaneId:set(planeId)
    manifest:set({})
    selectedRoute:set("")
    feedbackMsg:set("")
end

return CargoController
