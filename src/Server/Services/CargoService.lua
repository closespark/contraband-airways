--!strict
-- CargoService (Knit Service)
-- Server-side validation for cargo loading requests from clients.
-- Mirrors the tycoon-kit "purchase button → server validates → apply" pattern.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit      = require(ReplicatedStorage.Packages.Knit)
local CargoData = require(ReplicatedStorage.ContraBandShared.Data.CargoData)

-- ─────────────────────────────────────────────────────────────────────────────

local CargoService = Knit.CreateService({
    Name = "CargoService",

    Client = {
        CargoLoaded  = Knit.CreateSignal(), -- (planeId, cargoType, amount)
        CargoCleared = Knit.CreateSignal(), -- (planeId)
        LoadFailed   = Knit.CreateSignal(), -- (planeId, reason: string)
    },
})

-- ─────────────────────────────────────────────────────────────────────────────
-- Public API
-- ─────────────────────────────────────────────────────────────────────────────

--- Validate and apply a cargo-load request.
--- empireTier is injected by EmpireService so CargoService stays stateless.
function CargoService:LoadCargo(
    _player   : Player,
    planeId   : string,
    cargoType : string,
    amount    : number,
    empireTier: number
): (boolean, string?)
    -- Validate type exists
    local cargoDef = CargoData[cargoType]
    if not cargoDef then
        return false, "Unknown cargo type: " .. cargoType
    end

    -- Tier gate
    if cargoDef.UnlockTier > empireTier then
        return false,
            cargoDef.DisplayName .. " unlocks at Tier " .. cargoDef.UnlockTier
    end

    -- Delegate slot check to PlaneService
    local PlaneService = Knit.GetService("PlaneService")
    local ok, err = PlaneService:LoadCargo(planeId, {
        cargoType = cargoType,
        amount    = amount,
    })
    if not ok then return false, err end

    self.Client.CargoLoaded:FireAll(planeId, cargoType, amount)
    return true, nil
end

--- Clear all cargo from a plane (after bust or manual unload).
function CargoService:ClearCargo(planeId: string)
    local PlaneService = Knit.GetService("PlaneService")
    PlaneService:ClearCargo(planeId)
    self.Client.CargoCleared:FireAll(planeId)
end

--- Return cargo-type IDs available for the given empire tier.
function CargoService:GetAvailableTypes(empireTier: number): { string }
    local result = {}
    for id, def in CargoData do
        if def.UnlockTier <= empireTier then
            table.insert(result, id)
        end
    end
    return result
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Client-facing wrappers
-- ─────────────────────────────────────────────────────────────────────────────

function CargoService.Client:LoadCargo(
    player   : Player,
    planeId  : string,
    cargoType: string,
    amount   : number
): (boolean, string?)
    local EmpireService = Knit.GetService("EmpireService")
    local tier = EmpireService:GetEmpireTier()
    local ok, err = self.Server:LoadCargo(player, planeId, cargoType, amount, tier)
    if not ok then
        self.Server.Client.LoadFailed:Fire(player, planeId, err or "Load failed")
    end
    return ok, err
end

function CargoService.Client:GetAvailableTypes(_player: Player): { string }
    local EmpireService = Knit.GetService("EmpireService")
    return self.Server:GetAvailableTypes(EmpireService:GetEmpireTier())
end

-- ─────────────────────────────────────────────────────────────────────────────

function CargoService:KnitInit() end
function CargoService:KnitStart() end

return CargoService
