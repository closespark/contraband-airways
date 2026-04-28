--!strict
-- UIController
-- "First 10 minutes" HUD: welcome bonus popup + Build/Fleet menus (hotkeys).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Fusion = require(ReplicatedStorage.Packages.Fusion)

local New = Fusion.New
local Children = Fusion.Children
local Value = Fusion.Value
local Computed = Fusion.Computed
local Spring = Fusion.Spring
local OnEvent = Fusion.OnEvent

local StructureData = require(ReplicatedStorage.ContraBandShared.Data.StructureData)
local PlaneData = require(ReplicatedStorage.ContraBandShared.Data.PlaneData)

local UIController = Knit.CreateController({ Name = "UIController" })

local isOpen = Value(false)
local activeTab = Value("Build") -- "Build" | "Fleet"
local toast = Value("")
local showWelcome = Value(false)
local welcomeText = Value("")

local function roundedButton(label: any, bg: any, onActivate: () -> (), position: UDim2?): TextButton
	return New("TextButton")({
		Size = UDim2.new(0, 140, 0, 34),
		Position = position,
		BackgroundColor3 = bg,
		BorderSizePixel = 0,
		Text = label,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
		Font = Enum.Font.GothamBold,
		[Children] = {
			New("UICorner")({ CornerRadius = UDim.new(0, 8) }),
		},
		[OnEvent("Activated")] = onActivate,
	})
end

local function panelFrame(children: any): Frame
	return New("Frame")({
		Size = UDim2.new(0, 420, 0, 520),
		Position = UDim2.new(0, 18, 0.5, -260),
		BackgroundColor3 = Color3.fromRGB(18, 18, 24),
		BorderSizePixel = 0,
		Visible = Computed(function() return isOpen:get() end),
		[Children] = {
			New("UICorner")({ CornerRadius = UDim.new(0, 10) }),
			New("UIStroke")({ Thickness = 1, Color = Color3.fromRGB(60, 60, 80), Transparency = 0.2 }),
			children,
		},
	})
end

local function titleBar(): Frame
	return New("Frame")({
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = Color3.fromRGB(24, 24, 34),
		BorderSizePixel = 0,
		[Children] = {
			New("UICorner")({ CornerRadius = UDim.new(0, 10) }),
			New("TextLabel")({
				Size = UDim2.new(1, -12, 1, 0),
				Position = UDim2.new(0, 12, 0, 0),
				BackgroundTransparency = 1,
				Text = Computed(function()
					return activeTab:get() == "Build" and "Build (B)" or "Fleet (V)"
				end),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				Font = Enum.Font.GothamBold,
			}),
		},
	})
end

local function toastBar(): Frame
	local alpha = Spring(Computed(function()
		return toast:get() ~= "" and 0 or 1
	end), 20)

	return New("Frame")({
		Size = UDim2.new(0, 460, 0, 34),
		Position = UDim2.new(0.5, -230, 0, 14),
		BackgroundColor3 = Color3.fromRGB(30, 30, 40),
		BorderSizePixel = 0,
		BackgroundTransparency = alpha,
		[Children] = {
			New("UICorner")({ CornerRadius = UDim.new(0, 10) }),
			New("TextLabel")({
				Size = UDim2.new(1, -16, 1, 0),
				Position = UDim2.new(0, 8, 0, 0),
				BackgroundTransparency = 1,
				Text = toast,
				TextColor3 = Color3.fromRGB(240, 240, 240),
				TextScaled = true,
				Font = Enum.Font.Gotham,
			}),
		},
	})
end

local function makeBuildList(): ScrollingFrame
	local BuildController = Knit.GetController("BuildController")

	local items = {}
	for uid, def in StructureData do
		-- Focus early game items for first session feel
		if def.Tier <= 2 then
			table.insert(items, { uid = uid, def = def })
		end
	end
	table.sort(items, function(a, b)
		if a.def.Tier ~= b.def.Tier then return a.def.Tier < b.def.Tier end
		return a.def.DisplayName < b.def.DisplayName
	end)

	local rows = {}
	for _, it in items do
		local uid = it.uid
		local def = it.def

		table.insert(rows, New("Frame")({
			Size = UDim2.new(1, -16, 0, 64),
			BackgroundColor3 = Color3.fromRGB(28, 28, 38),
			BorderSizePixel = 0,
			[Children] = {
				New("UICorner")({ CornerRadius = UDim.new(0, 10) }),
				New("TextLabel")({
					Size = UDim2.new(1, -160, 0, 26),
					Position = UDim2.new(0, 12, 0, 6),
					BackgroundTransparency = 1,
					Text = def.DisplayName .. "  (Tier " .. def.Tier .. ")",
					TextXAlignment = Enum.TextXAlignment.Left,
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					Font = Enum.Font.GothamBold,
				}),
				New("TextLabel")({
					Size = UDim2.new(1, -160, 0, 24),
					Position = UDim2.new(0, 12, 0, 34),
					BackgroundTransparency = 1,
					Text = def.Description,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextColor3 = Color3.fromRGB(200, 200, 210),
					TextScaled = true,
					Font = Enum.Font.Gotham,
				}),
				roundedButton("Build", Color3.fromRGB(50, 120, 220), function()
					BuildController:RequestBuild("HomeBase", uid)
					toast:set("Queued: " .. def.DisplayName)
					task.delay(2.5, function()
						if toast:get():find(def.DisplayName, 1, true) then toast:set("") end
					end)
				end, UDim2.new(1, -150, 0.5, -17)),
			},
		}))
	end

	return New("ScrollingFrame")({
		Size = UDim2.new(1, 0, 1, -60),
		Position = UDim2.new(0, 0, 0, 52),
		BackgroundTransparency = 1,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		[Children] = {
			New("UIPadding")({ PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
			New("UIListLayout")({ Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
			table.unpack(rows),
		},
	})
end

local function makeFleetList(): ScrollingFrame
	local FleetService = Knit.GetService("FleetService")

	local items = {}
	for planeType, def in PlaneData do
		if not def.IsSeaVessel then
			table.insert(items, { planeType = planeType, def = def })
		end
	end
	table.sort(items, function(a, b) return a.def.Cost.BlackMoney < b.def.Cost.BlackMoney end)

	local rows = {}
	for _, it in items do
		local planeType = it.planeType
		local def = it.def

		table.insert(rows, New("Frame")({
			Size = UDim2.new(1, -16, 0, 64),
			BackgroundColor3 = Color3.fromRGB(28, 28, 38),
			BorderSizePixel = 0,
			[Children] = {
				New("UICorner")({ CornerRadius = UDim.new(0, 10) }),
				New("TextLabel")({
					Size = UDim2.new(1, -160, 0, 26),
					Position = UDim2.new(0, 12, 0, 6),
					BackgroundTransparency = 1,
					Text = def.DisplayName .. "  (" .. def.Range .. ")",
					TextXAlignment = Enum.TextXAlignment.Left,
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					Font = Enum.Font.GothamBold,
				}),
				New("TextLabel")({
					Size = UDim2.new(1, -160, 0, 24),
					Position = UDim2.new(0, 12, 0, 34),
					BackgroundTransparency = 1,
					Text = string.format("Cost: ₿%d + %d Parts   Slots: %d", def.Cost.BlackMoney, def.Cost.Parts, def.Slots),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextColor3 = Color3.fromRGB(200, 200, 210),
					TextScaled = true,
					Font = Enum.Font.Gotham,
				}),
				roundedButton("Order", Color3.fromRGB(40, 160, 90), function()
					local ok, res = FleetService:OrderPlane("HomeBase", planeType)
					if ok then
						toast:set("Ordered: " .. def.DisplayName)
					else
						toast:set("Can't order: " .. tostring(res))
					end
					task.delay(3, function() toast:set("") end)
				end, UDim2.new(1, -150, 0.5, -17)),
			},
		}))
	end

	return New("ScrollingFrame")({
		Size = UDim2.new(1, 0, 1, -60),
		Position = UDim2.new(0, 0, 0, 52),
		BackgroundTransparency = 1,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		[Children] = {
			New("UIPadding")({ PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
			New("UIListLayout")({ Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
			table.unpack(rows),
		},
	})
end

local function welcomePopup(): Frame
	local visible = Computed(function() return showWelcome:get() end)
	local scale = Spring(Computed(function() return showWelcome:get() and 1 or 0.9 end), 18)

	return New("Frame")({
		Visible = visible,
		Size = UDim2.new(0, 520, 0, 180),
		Position = UDim2.new(0.5, -260, 0.18, 0),
		BackgroundColor3 = Color3.fromRGB(22, 22, 30),
		BorderSizePixel = 0,
		[Children] = {
			New("UICorner")({ CornerRadius = UDim.new(0, 12) }),
			New("UIStroke")({ Thickness = 1, Color = Color3.fromRGB(70, 70, 95), Transparency = 0.15 }),
			New("UIScale")({ Scale = scale }),
			New("TextLabel")({
				Size = UDim2.new(1, -24, 0, 40),
				Position = UDim2.new(0, 12, 0, 12),
				BackgroundTransparency = 1,
				Text = "Welcome to Contraband Airways",
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				Font = Enum.Font.GothamBlack,
			}),
			New("TextLabel")({
				Size = UDim2.new(1, -24, 0, 70),
				Position = UDim2.new(0, 12, 0, 54),
				BackgroundTransparency = 1,
				Text = welcomeText,
				TextWrapped = true,
				TextColor3 = Color3.fromRGB(220, 220, 235),
				TextScaled = true,
				Font = Enum.Font.Gotham,
			}),
			roundedButton("Open Build (B)", Color3.fromRGB(60, 120, 220), function()
				showWelcome:set(false)
				isOpen:set(true)
				activeTab:set("Build")
			end, UDim2.new(0, 12, 1, -46)),
			roundedButton("Close", Color3.fromRGB(60, 60, 80), function()
				showWelcome:set(false)
			end, UDim2.new(1, -152, 1, -46)),
		},
	})
end

function UIController:KnitInit()
	local gui = New("ScreenGui")({
		Name = "ContrabandHUD",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
		[Children] = {
			toastBar(),
			welcomePopup(),
			panelFrame(New("Frame")({
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				[Children] = {
					titleBar(),
					New("Frame")({
						Size = UDim2.new(1, 0, 0, 46),
						Position = UDim2.new(0, 0, 0, 44),
						BackgroundTransparency = 1,
						[Children] = {
							roundedButton("Build", Computed(function()
								return activeTab:get() == "Build"
									and Color3.fromRGB(60, 120, 220)
									or Color3.fromRGB(45, 45, 60)
							end), function() activeTab:set("Build") end, UDim2.new(0, 10, 0, 6)),
							roundedButton("Fleet", Computed(function()
								return activeTab:get() == "Fleet"
									and Color3.fromRGB(60, 120, 220)
									or Color3.fromRGB(45, 45, 60)
							end), function() activeTab:set("Fleet") end, UDim2.new(0, 160, 0, 6)),
							roundedButton("Close", Color3.fromRGB(70, 70, 90), function() isOpen:set(false) end, UDim2.new(1, -150, 0, 6)),
						},
					}),
					Computed(function()
						return activeTab:get() == "Build" and makeBuildList() or makeFleetList()
					end),
				},
			})),
		},
	})
end

function UIController:KnitStart()
	local EmpireService = Knit.GetService("EmpireService")

	-- Hotkeys
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then return end
		if input.KeyCode == Enum.KeyCode.B then
			isOpen:set(not isOpen:get())
			activeTab:set("Build")
		elseif input.KeyCode == Enum.KeyCode.V then
			isOpen:set(not isOpen:get())
			activeTab:set("Fleet")
		elseif input.KeyCode == Enum.KeyCode.Escape and isOpen:get() then
			isOpen:set(false)
		end
	end)

	-- Welcome bonus banner based on the first snapshot we receive.
	local seenSnapshot = false
	EmpireService.Client.EmpireDataChanged:Connect(function(empireData: any)
		if seenSnapshot then return end
		seenSnapshot = true
		local bm = empireData.Resources and empireData.Resources.BlackMoney or 0
		local parts = empireData.Resources and empireData.Resources.Parts or 0
		welcomeText:set(string.format("Starter stash: ₿%d and %d Parts.\nPress B to build, click a plane to load cargo.", bm, parts))
		showWelcome:set(true)
	end)
end

return UIController

