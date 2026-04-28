--!strict
-- WorldService
-- Creates a tester-ready in-game world entirely from code so the project
-- is playable without manually authoring a Studio place.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Packages.Knit)

local RouteData = require(ReplicatedStorage.ContraBandShared.Data.RouteData)

local MAP_CENTER = Vector3.new(0, 50, 0)
local MAP_SIZE = Vector3.new(2000, 2, 1000)

local TILE_SIZE = 18

local WorldService = Knit.CreateService({
	Name = "WorldService",

	_lastReconcile = 0,
})

local function getOrCreateFolder(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Folder") then return existing end
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function getOrCreateModel(parent: Instance, name: string): Model
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Model") then return existing end
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function setPrimary(model: Model, part: BasePart)
	if model.PrimaryPart == part then return end
	model.PrimaryPart = part
end

local function ensureBasePart(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3): BasePart
	local existing = parent:FindFirstChild(name)
	local p: BasePart
	if existing and existing:IsA("BasePart") then
		p = existing
	else
		p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = parent
	end

	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.CanCollide = true
	return p
end

local function clearModelChildren(m: Model)
	for _, c in m:GetChildren() do
		if c:IsA("BasePart") then c:Destroy() end
	end
end

local function ensureRunway(m: Model, cf: CFrame, level: number)
	clearModelChildren(m)
	m.Name = "Structure_Runway"

	local base = Instance.new("Part")
	base.Name = "Tarmac"
	base.Anchored = true
	base.Material = Enum.Material.Asphalt
	base.Color = Color3.fromRGB(35, 35, 35)
	base.Size = Vector3.new(100, 2, 24)
	base.CFrame = cf * CFrame.new(0, 2, 0)
	base.Parent = m
	m.PrimaryPart = base

	-- White center stripes
	for i = -4, 4 do
		local stripe = Instance.new("Part")
		stripe.Anchored = true
		stripe.Material = Enum.Material.SmoothPlastic
		stripe.Color = Color3.fromRGB(230, 230, 230)
		stripe.Size = Vector3.new(8, 0.2, 2)
		stripe.CFrame = base.CFrame * CFrame.new(i * 10, 1.1, 0)
		stripe.Parent = m
	end

	-- Runway lights (more as level increases)
	local lights = 4 + level * 2
	for i = 1, lights do
		local z = (i / lights - 0.5) * base.Size.X
		for side = -1, 1, 2 do
			local bulb = Instance.new("Part")
			bulb.Anchored = true
			bulb.Material = Enum.Material.Neon
			bulb.Color = Color3.fromRGB(120, 190, 255)
			bulb.Size = Vector3.new(1, 1, 1)
			bulb.CFrame = base.CFrame * CFrame.new(z, 2.0, side * (base.Size.Z / 2 + 1.2))
			bulb.Parent = m
		end
	end
end

local function ensureHangar(m: Model, cf: CFrame, level: number)
	clearModelChildren(m)
	m.Name = "Structure_Hangar"
	local w = 36 + level * 6
	local h = 16 + level * 3
	local d = 30

	local body = Instance.new("Part")
	body.Name = "Shell"
	body.Anchored = true
	body.Material = Enum.Material.Metal
	body.Color = Color3.fromRGB(120, 125, 140)
	body.Size = Vector3.new(w, h, d)
	body.CFrame = cf * CFrame.new(0, h / 2 + 1, 0)
	body.Parent = m
	m.PrimaryPart = body

	local door = Instance.new("Part")
	door.Name = "Door"
	door.Anchored = true
	door.Material = Enum.Material.Metal
	door.Color = Color3.fromRGB(70, 75, 90)
	door.Size = Vector3.new(w - 4, h - 4, 1)
	door.CFrame = body.CFrame * CFrame.new(0, 0, d / 2)
	door.Parent = m
end

local function ensureFuelDepot(m: Model, cf: CFrame, level: number)
	clearModelChildren(m)
	m.Name = "Structure_FuelDepot"

	local pad = Instance.new("Part")
	pad.Name = "Pad"
	pad.Anchored = true
	pad.Material = Enum.Material.Concrete
	pad.Color = Color3.fromRGB(60, 60, 70)
	pad.Size = Vector3.new(34, 2, 22)
	pad.CFrame = cf * CFrame.new(0, 2, 0)
	pad.Parent = m
	m.PrimaryPart = pad

	for i = 1, math.clamp(2 + level, 2, 5) do
		local tank = Instance.new("Part")
		tank.Name = "Tank" .. i
		tank.Anchored = true
		tank.Material = Enum.Material.Metal
		tank.Color = Color3.fromRGB(140, 160, 170)
		tank.Shape = Enum.PartType.Cylinder
		tank.Size = Vector3.new(10, 14, 10)
		tank.CFrame = pad.CFrame * (CFrame.new(-10 + i * 7, 8, 0) * CFrame.Angles(0, 0, math.rad(90)))
		tank.Parent = m
	end
end

local function ensureBribeOffice(m: Model, cf: CFrame, level: number)
	clearModelChildren(m)
	m.Name = "Structure_BribeOffice"

	local base = Instance.new("Part")
	base.Name = "Base"
	base.Anchored = true
	base.Material = Enum.Material.SmoothPlastic
	base.Color = Color3.fromRGB(240, 220, 80)
	base.Size = Vector3.new(18, 10 + level * 3, 18)
	base.CFrame = cf * CFrame.new(0, base.Size.Y / 2 + 1, 0)
	base.Parent = m
	m.PrimaryPart = base

	local sign = Instance.new("Part")
	sign.Name = "Sign"
	sign.Anchored = true
	sign.Material = Enum.Material.Neon
	sign.Color = Color3.fromRGB(255, 120, 40)
	sign.Size = Vector3.new(12, 2, 1)
	sign.CFrame = base.CFrame * CFrame.new(0, 2, base.Size.Z / 2 + 0.6)
	sign.Parent = m
end

local function computeHubPositions(): { [string]: Vector3 }
	-- Infer hub anchors from the first/last waypoint of each route.
	-- This matches the repo’s documented coordinate system and keeps data-driven placement.
	local positions: { [string]: Vector3 } = {}
	for _, def in RouteData do
		if #def.Waypoints >= 1 then
			local origin = def.Waypoints[1]
			local dest = def.Waypoints[#def.Waypoints]
			if not positions[def.OriginHub] then
				positions[def.OriginHub] = Vector3.new(origin.X, MAP_CENTER.Y + 4, origin.Z)
			end
			if not positions[def.DestinationHub] then
				positions[def.DestinationHub] = Vector3.new(dest.X, MAP_CENTER.Y + 4, dest.Z)
			end
		end
	end
	return positions
end

function WorldService:_ensureMap()
	local mapFolder = getOrCreateFolder(Workspace, "Map")
	ensureBasePart(
		mapFolder,
		"WorldMap",
		MAP_SIZE,
		CFrame.new(MAP_CENTER),
		Color3.fromRGB(35, 35, 45)
	)

	-- Simple boundary frame for visual orientation
	ensureBasePart(
		mapFolder,
		"MapFrame",
		Vector3.new(MAP_SIZE.X + 8, 4, MAP_SIZE.Z + 8),
		CFrame.new(MAP_CENTER - Vector3.new(0, -2, 0)),
		Color3.fromRGB(60, 60, 80)
	).Transparency = 0.85
end

function WorldService:_ensureHubs()
	local hubsFolder = getOrCreateFolder(Workspace, "Hubs")
	local positions = computeHubPositions()

	for hubId, pos in positions do
		local hubModel = getOrCreateModel(hubsFolder, hubId)

		local base = ensureBasePart(
			hubModel,
			"HubBase",
			Vector3.new(60, 2, 60),
			CFrame.new(pos - Vector3.new(0, 2, 0)),
			Color3.fromRGB(80, 80, 95)
		)
		setPrimary(hubModel, base)

		-- Spawn + landing pads required by PlaneService / RouteService
		ensureBasePart(
			hubModel,
			"SpawnPad",
			Vector3.new(20, 1, 20),
			CFrame.new(pos + Vector3.new(-18, 1, 0)),
			Color3.fromRGB(80, 200, 120)
		)
		ensureBasePart(
			hubModel,
			"LandingPad",
			Vector3.new(20, 1, 20),
			CFrame.new(pos + Vector3.new(18, 1, 0)),
			Color3.fromRGB(120, 160, 255)
		)

		-- Build plot marker (placeholder visual for structure placements)
		ensureBasePart(
			hubModel,
			"BuildPlot",
			Vector3.new(120, 1, 120),
			CFrame.new(pos + Vector3.new(0, 0.5, 85)),
			Color3.fromRGB(45, 45, 55)
		).Transparency = 0.35
	end
end

function WorldService:_ensureStructureVisuals()
	-- Mirror built structures into Workspace so testers can see progress even without a full UI.
	local EmpireService = Knit.GetService("EmpireService")
	local data = EmpireService:GetEmpireData()
	if not data then return end

	local hubsFolder = Workspace:FindFirstChild("Hubs")
	if not hubsFolder then return end

	for hubId, structures in data.Structures do
		local hubModel = hubsFolder:FindFirstChild(hubId)
		if hubModel and hubModel:IsA("Model") then
			local buildPlot = hubModel:FindFirstChild("BuildPlot") :: BasePart?
			local plotCf = buildPlot and buildPlot.CFrame or CFrame.new(hubModel:GetPivot().Position)

			for uid, entry in structures do
				if type(entry) == "table" and entry.state == "Built" then
					local level = tonumber(entry.level) or 1
					local gridX = tonumber(entry.gridX) or 0
					local gridZ = tonumber(entry.gridZ) or 0

					local name = "Structure_" .. uid
					local existing = hubModel:FindFirstChild(name)

					local m: Model
					if existing and existing:IsA("Model") then
						m = existing
					else
						m = Instance.new("Model")
						m.Name = name
						m.Parent = hubModel
					end
					local localOffset = Vector3.new((gridX - 3) * TILE_SIZE, 0, (gridZ - 3) * TILE_SIZE)
					local structureCf = plotCf * CFrame.new(localOffset)

					-- High-signal early buildings get nicer placeholder skins
					if uid == "Runway" then
						ensureRunway(m, structureCf, level)
					elseif uid == "Hangar" then
						ensureHangar(m, structureCf, level)
					elseif uid == "FuelDepot" then
						ensureFuelDepot(m, structureCf, level)
					elseif uid == "BribeOffice" then
						ensureBribeOffice(m, structureCf, level)
					else
						-- Generic block for everything else
						if not m.PrimaryPart or not m.PrimaryPart:IsA("BasePart") then
							local block = Instance.new("Part")
							block.Name = "Block"
							block.Anchored = true
							block.TopSurface = Enum.SurfaceType.Smooth
							block.BottomSurface = Enum.SurfaceType.Smooth
							block.Material = Enum.Material.SmoothPlastic
							block.Parent = m
							m.PrimaryPart = block
						end
						local block = m.PrimaryPart :: BasePart
						local height = 6 + (level - 1) * 3
						block.Size = Vector3.new(12, height, 12)
						block.Color = Color3.fromRGB(200 - math.min(level * 10, 80), 120, 220)
						block.CFrame = structureCf * CFrame.new(0, height / 2 + 1, 0)
					end
				end
			end
		end
	end
end

function WorldService:KnitInit() end

function WorldService:KnitStart()
	self:_ensureMap()
	self:_ensureHubs()

	-- Light reconcile loop so new builds show up visually.
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - self._lastReconcile >= 2 then
			self._lastReconcile = now
			self:_ensureStructureVisuals()
		end
	end)
end

return WorldService

