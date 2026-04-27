--!strict
-- StructureData
-- Building definitions for the construction queue system.
-- BuildService uses these for cost validation, build timers, and effect application.
-- Effects activate only once State == "Built".

export type StructureCost = {
    BlackMoney : number?,
    CleanCash  : number?,
    Parts      : number?,
    Fuel       : number?,
    Influence  : number?,
    Intel      : number?,
}

export type StructureEffects = {
    -- Passive resource income per ProductionService tick (per level)
    PassiveGeneration  : { [string]: number }?,
    -- Risk / heat modifiers (same semantics as UpgradeData)
    RiskReduction      : number?,
    HeatDecayBonus     : number?,
    PoliceRiskReduction: number?,
    -- Fleet / logistics gates
    MaxStoredPlanes    : number?,   -- hangar capacity added per level
    RepairEnabled      : boolean?,  -- enables RepairPlane at Hangar level 3+
    UnlocksPlaneRange  : string?,   -- "Regional" | "Continental" | "Global" (highest range unlocked)
    FuelRouteBonus     : number?,   -- extra simultaneous route slots per level
    SurpriseReduction  : number?,   -- reduces chaos event probability per level
    MultiLaunchSlots   : number?,   -- command bunker: simultaneous fleet launches
}

export type StructureDef = {
    DisplayName : string,
    Description : string,
    Tier        : number,
    Cost        : StructureCost,
    BuildTime   : number,       -- seconds to complete construction
    MaxLevel    : number,
    Effects     : StructureEffects,
    Unlocks     : { string },   -- route / plane / structure IDs granted on completion
}

local StructureData: { [string]: StructureDef } = {

    -- ── EARLY-GAME (Tier 1) ───────────────────────────────────────────────────

    HiddenWarehouse = {
        DisplayName = "Hidden Warehouse",
        Description = "Disguised storage unit. Increases cargo pool and generates Parts.",
        Tier        = 1,
        Cost        = { BlackMoney = 800 },
        BuildTime   = 30,
        MaxLevel    = 3,
        Effects     = { PassiveGeneration = { Parts = 1 } },
        Unlocks     = {},
    },

    FuelDepot = {
        DisplayName = "Fuel Depot",
        Description = "Underground fuel tank. Passively generates Fuel and enables extra route launches.",
        Tier        = 1,
        Cost        = { BlackMoney = 1200, Parts = 5 },
        BuildTime   = 45,
        MaxLevel    = 3,
        Effects     = { PassiveGeneration = { Fuel = 5 }, FuelRouteBonus = 1 },
        Unlocks     = {},
    },

    ScrapYard = {
        DisplayName = "Scrap Yard",
        Description = "Strips wrecked vehicles for usable components. Steady Parts income.",
        Tier        = 1,
        Cost        = { BlackMoney = 600 },
        BuildTime   = 30,
        MaxLevel    = 3,
        Effects     = { PassiveGeneration = { Parts = 2 } },
        Unlocks     = {},
    },

    LookoutPost = {
        DisplayName = "Lookout Post",
        Description = "Eyes and ears on the street. Generates Intel and reduces surprise events.",
        Tier        = 1,
        Cost        = { BlackMoney = 500, Influence = 2 },
        BuildTime   = 20,
        MaxLevel    = 3,
        Effects     = { PassiveGeneration = { Intel = 1 }, SurpriseReduction = 0.05 },
        Unlocks     = {},
    },

    FakeOffice = {
        DisplayName = "Fake Office",
        Description = "Legitimate-looking front business. Slowly converts Black Money into Clean Cash.",
        Tier        = 1,
        Cost        = { BlackMoney = 1000, Influence = 3 },
        BuildTime   = 60,
        MaxLevel    = 3,
        Effects     = { PassiveGeneration = { CleanCash = 3 } },
        Unlocks     = {},
    },

    BribeOffice = {
        DisplayName = "Bribe Office",
        Description = "Comically shifty building with a coin slot. Pays off inspectors on arrival.",
        Tier        = 1,
        Cost        = { BlackMoney = 2500, Influence = 5 },
        BuildTime   = 60,
        MaxLevel    = 4,
        Effects     = { PoliceRiskReduction = 0.08, HeatDecayBonus = 0.01 },
        Unlocks     = { "CaribbeanShadowHop" },
    },

    -- ── RUNWAYS & HANGARS ─────────────────────────────────────────────────────

    Runway = {
        DisplayName = "Runway",
        Description = "Levels up to enable larger aircraft. Essential for any air operation.",
        Tier        = 1,
        Cost        = { BlackMoney = 2000, Parts = 10 },
        BuildTime   = 90,
        MaxLevel    = 3,
        Effects     = { UnlocksPlaneRange = "Regional" },
        Unlocks     = { "BasicProp" },
    },

    Hangar = {
        DisplayName = "Hangar",
        Description = "Stores and protects your fleet. Higher levels allow more planes and repairs.",
        Tier        = 1,
        Cost        = { BlackMoney = 3000, Parts = 15 },
        BuildTime   = 120,
        MaxLevel    = 3,
        Effects     = { MaxStoredPlanes = 2, RepairEnabled = false },
        Unlocks     = {},
    },

    -- ── MID-GAME (Tier 2) ─────────────────────────────────────────────────────

    PartsYard = {
        DisplayName = "Parts Yard",
        Description = "Manufacturing yard for plane components. Faster builds and repairs.",
        Tier        = 2,
        Cost        = { BlackMoney = 4000, Parts = 20, Influence = 5 },
        BuildTime   = 180,
        MaxLevel    = 3,
        Effects     = { PassiveGeneration = { Parts = 4 } },
        Unlocks     = { "TwinProp", "CargoShip" },
    },

    RadarTower = {
        DisplayName = "Radar Tower",
        Description = "Spinning dish spots incoming events early. Reduces chaos event probability.",
        Tier        = 2,
        Cost        = { BlackMoney = 1800, Parts = 8 },
        BuildTime   = 90,
        MaxLevel    = 3,
        Effects     = { SurpriseReduction = 0.10, RiskReduction = 0.08 },
        Unlocks     = {},
    },

    CommandBunker = {
        DisplayName = "Command Bunker",
        Description = "The fortress brain. Enables multi-plane launches and unlocks Tier 3 routes.",
        Tier        = 2,
        Cost        = { BlackMoney = 5000, Parts = 30, Influence = 10 },
        BuildTime   = 300,
        MaxLevel    = 3,
        Effects     = { MultiLaunchSlots = 2, RiskReduction = 0.20, HeatDecayBonus = 5 },
        Unlocks     = { "AtlanticCrossing", "NorthernPassage" },
    },

    -- ── LATE-GAME (Tier 3) ────────────────────────────────────────────────────

    LongRangeHangar = {
        DisplayName = "Long Range Hangar",
        Description = "Extended maintenance bays for intercontinental aircraft.",
        Tier        = 3,
        Cost        = { BlackMoney = 20000, Parts = 60, Influence = 10 },
        BuildTime   = 480,
        MaxLevel    = 2,
        Effects     = { MaxStoredPlanes = 3, UnlocksPlaneRange = "Global", RepairEnabled = true },
        Unlocks     = { "CargoJet" },
    },

    GlobalFuelNetwork = {
        DisplayName = "Global Fuel Network",
        Description = "Empire-wide automated tanker grid. Massive passive Fuel income.",
        Tier        = 3,
        Cost        = { BlackMoney = 30000, CleanCash = 5000, Parts = 80, Influence = 20 },
        BuildTime   = 600,
        MaxLevel    = 2,
        Effects     = { PassiveGeneration = { Fuel = 20 } },
        Unlocks     = {},
    },

    InternationalLaunderingOffice = {
        DisplayName = "International Laundering Office",
        Description = "Converts black money into clean cash empire-wide and bleeds global Heat.",
        Tier        = 3,
        Cost        = { BlackMoney = 20000, CleanCash = 2000, Influence = 25 },
        BuildTime   = 600,
        MaxLevel    = 3,
        Effects     = { PassiveGeneration = { CleanCash = 15 }, HeatDecayBonus = 15 },
        Unlocks     = {},
    },

    PlanePartsFactory = {
        DisplayName = "Plane Parts Factory",
        Description = "Industrial-scale parts production. Enables fast fleet expansion.",
        Tier        = 3,
        Cost        = { BlackMoney = 40000, Parts = 100, Intel = 20 },
        BuildTime   = 900,
        MaxLevel    = 2,
        Effects     = { PassiveGeneration = { Parts = 10 } },
        Unlocks     = { "CargoJet" },
    },

    PortAuthorityFront = {
        DisplayName = "Port Authority Front",
        Description = "Fake government office. Generates Influence and unlocks sea lane networks.",
        Tier        = 3,
        Cost        = { BlackMoney = 35000, CleanCash = 8000, Influence = 15 },
        BuildTime   = 600,
        MaxLevel    = 2,
        Effects     = { PassiveGeneration = { Influence = 3 } },
        Unlocks     = { "SilkSeaLane", "TransPacificFreighter" },
    },

    SatelliteIntelNetwork = {
        DisplayName = "Satellite Intel Network",
        Description = "Empire-wide satellite coverage. Maximises Intel income and reduces risk.",
        Tier        = 3,
        Cost        = { BlackMoney = 50000, CleanCash = 10000, Intel = 30 },
        BuildTime   = 1200,
        MaxLevel    = 2,
        Effects     = { PassiveGeneration = { Intel = 8 }, SurpriseReduction = 0.25 },
        Unlocks     = {},
    },
}

return StructureData
