--!strict
-- UnlockData
-- Maps each unlockable entity to the conditions required before it becomes
-- available.  UnlockService evaluates these after every empire state change.
--
-- Categories: "Route" | "Plane" | "Structure" | "Hub"

export type UnlockCondition = {
    Tier               : number?,               -- minimum empire Tier
    RequiredStructures : { string }?,           -- all listed structure IDs must be "Built" somewhere
    RequiredResources  : { [string]: number }?, -- empire must currently hold at least this much
    RequiredRoutes     : { string }?,           -- all listed routes must have been completed once
    RequiredHubs       : { string }?,           -- all listed hubs must already be unlocked
}

export type UnlockEntry = {
    Category  : string,
    Condition : UnlockCondition,
}

local UnlockData: { [string]: UnlockEntry } = {

    -- ── ROUTES ────────────────────────────────────────────────────────────────

    CaribbeanShadowHop = {
        Category  = "Route",
        Condition = { Tier = 1 },
    },

    AndesExpress = {
        Category  = "Route",
        Condition = { Tier = 1, RequiredStructures = { "Runway" } },
    },

    BorderBlitz = {
        Category  = "Route",
        Condition = { Tier = 1, RequiredStructures = { "Runway" } },
    },

    AtlanticCrossing = {
        Category  = "Route",
        Condition = { Tier = 2, RequiredStructures = { "CommandBunker", "LongRangeHangar" } },
    },

    SahelSparkleRun = {
        Category  = "Route",
        Condition = { Tier = 2, RequiredStructures = { "Runway" } },
    },

    GoldenTriangleDash = {
        Category  = "Route",
        Condition = { Tier = 2, RequiredStructures = { "Runway" } },
    },

    WestAfricaSeaLane = {
        Category  = "Route",
        Condition = { Tier = 2, RequiredStructures = { "Hangar" } },
    },

    PacificRimOrbit = {
        Category  = "Route",
        Condition = { Tier = 3, RequiredStructures = { "CommandBunker" } },
    },

    IndianOceanArc = {
        Category  = "Route",
        Condition = { Tier = 3 },
    },

    MediterraneanRun = {
        Category  = "Route",
        Condition = { Tier = 3, RequiredStructures = { "BribeOffice" } },
    },

    NorthernPassage = {
        Category  = "Route",
        Condition = { Tier = 3, RequiredStructures = { "CommandBunker" } },
    },

    SouthernCross = {
        Category  = "Route",
        Condition = { Tier = 3 },
    },

    SilkSeaLane = {
        Category  = "Route",
        Condition = { Tier = 3, RequiredStructures = { "PortAuthorityFront" } },
    },

    TransPacificFreighter = {
        Category  = "Route",
        Condition = { Tier = 3, RequiredStructures = { "PortAuthorityFront" } },
    },

    -- ── PLANES ────────────────────────────────────────────────────────────────

    BasicProp = {
        Category  = "Plane",
        Condition = { Tier = 1, RequiredStructures = { "Runway" } },
    },

    ReinforcedProp = {
        Category  = "Plane",
        Condition = {
            Tier               = 1,
            RequiredStructures = { "Hangar" },
            RequiredRoutes     = { "CaribbeanShadowHop" },
        },
    },

    StealthProp = {
        Category  = "Plane",
        Condition = { Tier = 2, RequiredStructures = { "Hangar" } },
    },

    TwinProp = {
        Category  = "Plane",
        Condition = { Tier = 2, RequiredStructures = { "PartsYard" } },
    },

    CargoJet = {
        Category  = "Plane",
        Condition = { Tier = 3, RequiredStructures = { "LongRangeHangar", "PlanePartsFactory" } },
    },

    FastBoat = {
        Category  = "Plane",
        Condition = { Tier = 1, RequiredStructures = { "Hangar" } },
    },

    CargoShip = {
        Category  = "Plane",
        Condition = { Tier = 2, RequiredStructures = { "PartsYard" } },
    },

    -- ── STRUCTURES ────────────────────────────────────────────────────────────

    HiddenWarehouse = {
        Category  = "Structure",
        Condition = { Tier = 1 },
    },

    FuelDepot = {
        Category  = "Structure",
        Condition = { Tier = 1 },
    },

    ScrapYard = {
        Category  = "Structure",
        Condition = { Tier = 1 },
    },

    LookoutPost = {
        Category  = "Structure",
        Condition = { Tier = 1 },
    },

    FakeOffice = {
        Category  = "Structure",
        Condition = { Tier = 1 },
    },

    BribeOffice = {
        Category  = "Structure",
        Condition = { Tier = 1 },
    },

    Runway = {
        Category  = "Structure",
        Condition = { Tier = 1 },
    },

    Hangar = {
        Category  = "Structure",
        Condition = { Tier = 1, RequiredStructures = { "Runway" } },
    },

    PartsYard = {
        Category  = "Structure",
        Condition = { Tier = 2 },
    },

    RadarTower = {
        Category  = "Structure",
        Condition = { Tier = 2 },
    },

    CommandBunker = {
        Category  = "Structure",
        Condition = { Tier = 2, RequiredStructures = { "Hangar" } },
    },

    LongRangeHangar = {
        Category  = "Structure",
        Condition = { Tier = 3, RequiredStructures = { "CommandBunker" } },
    },

    GlobalFuelNetwork = {
        Category  = "Structure",
        Condition = { Tier = 3 },
    },

    InternationalLaunderingOffice = {
        Category  = "Structure",
        Condition = { Tier = 3 },
    },

    PlanePartsFactory = {
        Category  = "Structure",
        Condition = { Tier = 3 },
    },

    PortAuthorityFront = {
        Category  = "Structure",
        Condition = { Tier = 3 },
    },

    SatelliteIntelNetwork = {
        Category  = "Structure",
        Condition = { Tier = 3 },
    },

    -- ── HUBS ──────────────────────────────────────────────────────────────────
    -- Tier-based hubs are also granted automatically in EmpireService via
    -- TIER_HUB_UNLOCKS.  Influence-gated hubs can be unlocked earlier by
    -- spending Influence through UnlockService:CheckUnlocks.

    AndesHub = {
        Category  = "Hub",
        Condition = { Tier = 2, RequiredResources = { Influence = 10 } },
    },

    WestAfricaHub = {
        Category  = "Hub",
        Condition = { Tier = 2, RequiredResources = { Influence = 10 } },
    },

    EuropeHub = {
        Category  = "Hub",
        Condition = { Tier = 3, RequiredResources = { Influence = 20 } },
    },

    SEAsiaHub = {
        Category  = "Hub",
        Condition = { Tier = 3, RequiredResources = { Influence = 20 } },
    },

    PacificHub = {
        Category  = "Hub",
        Condition = { Tier = 3, RequiredResources = { Influence = 25 } },
    },

    MiddleEastHub = {
        Category  = "Hub",
        Condition = { Tier = 3, RequiredResources = { Influence = 25 } },
    },

    EastAfricaHub = {
        Category  = "Hub",
        Condition = { Tier = 3, RequiredResources = { Influence = 30 } },
    },

    NorthAmericaHub = {
        Category  = "Hub",
        Condition = { Tier = 3, RequiredResources = { Influence = 35 } },
    },
}

return UnlockData
