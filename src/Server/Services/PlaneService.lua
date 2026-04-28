--!strict
-- PlaneService (Knit Service)
-- Combines the tycoon-kit "dropper / income object" pattern with a flight model:
--   spawn → load cargo → take off → fly waypoints → land / bust → destroy.
-- All plane state lives on the server; clients receive signals via Knit.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Packages.Knit)

local CargoData = require(ReplicatedStorage.ContraBandShared.Data.CargoData)

-- ─────────────────────────────────────────────────────────────────────────────

export type CargoManifest = {
    cargoType : string,
    amount    : number,
}

export type PlaneStatus =
    "Parked"
    | "Loading"
    | "TakingOff"
    | "Flying"
    | "Landing"
    | "Busted"

export type PlaneData = {
    hubOrigin  : string,
    routeName  : string?,
    cargo      : { CargoManifest },
    status     : PlaneStatus,
    totalSlots : number,
    usedSlots  : number,
}

-- ─────────────────────────────────────────────────────────────────────────────

local PlaneService = Knit.CreateService({
    Name = "PlaneService",

    -- RemoteSignals replicated to all clients
    Client = {
        PlaneLaunched       = Knit.CreateSignal(), -- (planeId: string, routeName: string)
        PlaneArrived        = Knit.CreateSignal(), -- (planeId: string, hubName: string)
        PlaneBusted         = Knit.CreateSignal(), -- (planeId: string, waypointIdx: number)
        PlaneStatusChanged  = Knit.CreateSignal(), -- (planeId: string, status: string)
        PlaneDestroyed      = Knit.CreateSignal(), -- (planeId: string)
    },

    -- Private
    _planes       = {} :: { [string]: { model: Model, data: PlaneData } },
    _planeCounter = 0,
})

-- ─────────────────────────────────────────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────────────────────────────────────────

local function planesFolder(): Folder
    local f = workspace:FindFirstChild("PlanesFolder") :: Folder?
    if not f then
        f = Instance.new("Folder")
        f.Name   = "PlanesFolder"
        f.Parent = workspace
    end
    return f :: Folder
end

local function getSpawnCFrame(hubName: string): CFrame?
    local hubs = workspace:FindFirstChild("Hubs")
    if not hubs then return nil end
    local hub = hubs:FindFirstChild(hubName)
    if not hub  then return nil end
    local pad = hub:FindFirstChild("SpawnPad") :: BasePart?
    return pad and pad.CFrame or nil
end

local function buildPlaceholderModel(planeType: string): Model
    local body     = Instance.new("Part")
    body.Name      = "Body"
    body.Size      = Vector3.new(8, 2, 20)
    body.BrickColor = BrickColor.new("Bright blue")
    body.Anchored  = true

    local model         = Instance.new("Model")
    model.Name          = planeType
    body.Parent         = model
    model.PrimaryPart   = body
    return model
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Public API
-- ─────────────────────────────────────────────────────────────────────────────

--- Spawn a plane at a hub's SpawnPad.
--- Returns a planeId string, or nil if the hub has no SpawnPad.
function PlaneService:SpawnPlane(hubName: string, planeType: string?): string?
    local cf = getSpawnCFrame(hubName)
    if not cf then
        warn("[PlaneService] No SpawnPad in hub:", hubName)
        return nil
    end

    -- Try to find a pre-built model in ReplicatedStorage assets
    local templates = ReplicatedStorage:FindFirstChild("Assets")
        and ReplicatedStorage.Assets:FindFirstChild("PlaneModels") :: Folder?
    local template: Model? = nil
    if templates and planeType then
        template = templates:FindFirstChild(planeType) :: Model?
    end

    local planeModel = (template and template:Clone()) or buildPlaceholderModel(planeType or "DefaultPlane")
    planeModel:SetPrimaryPartCFrame(cf + Vector3.new(0, 10, 0))
    planeModel.Parent = planesFolder()
    CollectionService:AddTag(planeModel, "Plane")

    self._planeCounter += 1
    local planeId = "Plane_" .. self._planeCounter

    -- Name the model after the planeId so client UI can find it cheaply.
    planeModel.Name = planeId
    planeModel:SetAttribute("PlaneId", planeId)

    self._planes[planeId] = {
        model = planeModel,
        data  = {
            hubOrigin  = hubName,
            routeName  = nil,
            cargo      = {},
            status     = "Parked",
            totalSlots = 12,
            usedSlots  = 0,
        },
    }

    return planeId
end

--- Add a cargo manifest to a parked plane.
--- Returns (ok, errorMessage?).
function PlaneService:LoadCargo(planeId: string, manifest: CargoManifest): (boolean, string?)
    local entry = self._planes[planeId]
    if not entry then return false, "Unknown plane: " .. planeId end

    local s = entry.data.status
    if s ~= "Parked" and s ~= "Loading" then
        return false, "Plane is not available for loading (status: " .. s .. ")"
    end

    local cargoDef = CargoData[manifest.cargoType]
    if not cargoDef then return false, "Unknown cargo type: " .. manifest.cargoType end

    local needed = cargoDef.Slots * manifest.amount
    local free   = entry.data.totalSlots - entry.data.usedSlots
    if needed > free then
        return false,
            string.format("Not enough slots (%d needed, %d free)", needed, free)
    end

    entry.data.status    = "Loading"
    entry.data.usedSlots += needed
    table.insert(entry.data.cargo, manifest)
    return true, nil
end

--- Remove all cargo from a plane.
function PlaneService:ClearCargo(planeId: string)
    local entry = self._planes[planeId]
    if not entry then return end
    entry.data.cargo     = {}
    entry.data.usedSlots = 0
end

--- Update plane status and notify all clients.
function PlaneService:SetStatus(planeId: string, status: PlaneStatus)
    local entry = self._planes[planeId]
    if not entry then return end
    entry.data.status = status
    self.Client.PlaneStatusChanged:FireAll(planeId, status)
end

--- Set the assigned route on a plane's data.
function PlaneService:SetRoute(planeId: string, routeName: string)
    local entry = self._planes[planeId]
    if entry then entry.data.routeName = routeName end
end

--- Read-only snapshot of a plane's data.
function PlaneService:GetPlaneData(planeId: string): PlaneData?
    local entry = self._planes[planeId]
    if not entry then return nil end
    -- Return a shallow copy so callers cannot mutate internals
    local d = entry.data
    return {
        hubOrigin  = d.hubOrigin,
        routeName  = d.routeName,
        cargo      = d.cargo,
        status     = d.status,
        totalSlots = d.totalSlots,
        usedSlots  = d.usedSlots,
    }
end

--- Return the live Model for a planeId (used by RouteService for tweening).
function PlaneService:GetPlaneModel(planeId: string): Model?
    local entry = self._planes[planeId]
    return entry and entry.model or nil
end

--- Destroy a plane model and remove it from the active table.
function PlaneService:DestroyPlane(planeId: string)
    local entry = self._planes[planeId]
    if not entry then return end
    entry.model:Destroy()
    self._planes[planeId] = nil
    self.Client.PlaneDestroyed:FireAll(planeId)
end

--- All active plane IDs.
function PlaneService:GetActivePlaneIds(): { string }
    local ids = {}
    for id in self._planes do
        table.insert(ids, id)
    end
    return ids
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Client-facing wrappers (Knit RemoteFunctions)
-- ─────────────────────────────────────────────────────────────────────────────

function PlaneService.Client:GetPlaneData(_player: Player, planeId: string): PlaneData?
    return self.Server:GetPlaneData(planeId)
end

function PlaneService.Client:GetActivePlaneIds(_player: Player): { string }
    return self.Server:GetActivePlaneIds()
end

-- ─────────────────────────────────────────────────────────────────────────────

function PlaneService:KnitInit() end
function PlaneService:KnitStart() end

return PlaneService
