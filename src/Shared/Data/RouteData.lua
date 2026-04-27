--!strict
-- RouteData
-- All flight (and sea-lane) routes available in Contraband Airways.
--
-- Waypoints are studs on a 2 000 × 1 000-stud stylised world-map BasePart
-- centred at (0, 50, 0).  X = west → east, Z = north → south.
-- Air routes fly at Y = 200; sea lanes use Y = 50 (map surface layer).
--
-- Tiers:
--   1 – Regional   (home base + 3–4 nearby routes)
--   2 – Continental (Americas + Africa links; small jets)
--   3 – Global      (intercontinental flights + full sea lane network)

export type RouteDef = {
    DisplayName         : string,
    Description         : string,
    Tier                : number,           -- 1 / 2 / 3
    IsSeaLane           : boolean,
    BasePayout          : number,           -- flat black-money before cargo multiplier
    BaseRisk            : number,           -- 0–1 route risk before upgrades
    LengthLabel         : string,           -- "Short" | "Medium" | "Long" | "Intercontinental"
    BestCargo           : { string },       -- cargo IDs with best payout/risk on this lane
    KeyThreats          : { string },       -- chaos-event IDs most common here
    CounterUpgrades     : { string },       -- upgrade IDs that most reduce this lane's risk
    OriginHub           : string,
    DestinationHub      : string,
    HeatMultiplier      : number,           -- Heat added = base × this
    Waypoints           : { Vector3 },
    -- Economy-gating fields (all optional; nil = no requirement)
    RequiredPlaneRange  : string?,          -- "Regional" | "Continental" | "Global"
    RequiredStructures  : { string }?,      -- structure IDs that must be "Built" at origin hub
    FuelCost            : number?,          -- Fuel units deducted on launch
    HeatGain            : number?,          -- flat Heat added on successful completion
}

local Y_AIR = 200   -- altitude for air routes
local Y_SEA =  50   -- sea surface for sea lanes

local RouteData: { [string]: RouteDef } = {

    -- ════════════════════════════  TIER 1 – REGIONAL  ════════════════════════

    CaribbeanShadowHop = {
        DisplayName         = "Caribbean Shadow Hop",
        Description         = "A short, nimble hop through warm-water islands. Good starter route.",
        Tier                = 1,
        IsSeaLane           = false,
        BasePayout          = 500,
        BaseRisk            = 0.35,
        LengthLabel         = "Short",
        BestCargo           = { "MysteryPowder", "ShinyRocks" },
        KeyThreats          = { "PoliceRaid", "RivalTheft" },
        CounterUpgrades     = { "BribeOffice", "FakeTerminal", "PerimeterFence" },
        OriginHub           = "HomeBase",
        DestinationHub      = "CaribbeanHub",
        HeatMultiplier      = 1.0,
        RequiredPlaneRange  = "Regional",
        RequiredStructures  = nil,
        FuelCost            = 8,
        HeatGain            = 4,
        Waypoints           = {
            Vector3.new(-500, Y_AIR,  100),
            Vector3.new(-450, Y_AIR,   60),
            Vector3.new(-400, Y_AIR,   80),
            Vector3.new(-360, Y_AIR,  100),
        },
    },

    AndesExpress = {
        DisplayName         = "Andes Express",
        Description         = "High-altitude mountain dash. Big rewards, heavy military presence.",
        Tier                = 1,
        IsSeaLane           = false,
        BasePayout          = 800,
        BaseRisk            = 0.60,
        LengthLabel         = "Medium",
        BestCargo           = { "MysteryPowder", "HeavyToolkits" },
        KeyThreats          = { "MilitaryPatrol", "LeakSpill" },
        CounterUpgrades     = { "UndergroundHangar", "JammingTower" },
        OriginHub           = "HomeBase",
        DestinationHub      = "AndesHub",
        HeatMultiplier      = 1.2,
        RequiredPlaneRange  = "Regional",
        RequiredStructures  = { "Runway" },
        FuelCost            = 12,
        HeatGain            = 6,
        Waypoints           = {
            Vector3.new(-500, Y_AIR,  100),
            Vector3.new(-540, Y_AIR,   50),
            Vector3.new(-580, Y_AIR,    0),
            Vector3.new(-600, Y_AIR,  -50),
        },
    },

    BorderBlitz = {
        DisplayName         = "Border Blitz",
        Description         = "Low-altitude dash across a busy crossing. Any cargo works; every threat shows up.",
        Tier                = 1,
        IsSeaLane           = false,
        BasePayout          = 600,
        BaseRisk            = 0.50,
        LengthLabel         = "Short",
        BestCargo           = { "ShinyRocks", "GlowDisks", "MysteryPowder", "HeavyToolkits" },
        KeyThreats          = { "PoliceRaid", "MilitaryPatrol", "RivalTheft" },
        CounterUpgrades     = { "FakeTerminal", "CamouflageLandscaping", "DecoyFleet" },
        OriginHub           = "HomeBase",
        DestinationHub      = "BorderHub",
        HeatMultiplier      = 1.1,
        RequiredPlaneRange  = "Regional",
        RequiredStructures  = { "Runway" },
        FuelCost            = 10,
        HeatGain            = 5,
        Waypoints           = {
            Vector3.new(-500, Y_AIR,  100),
            Vector3.new(-470, Y_AIR,   90),
            Vector3.new(-440, Y_AIR,  110),
            Vector3.new(-420, Y_AIR,  130),
        },
    },

    -- ═══════════════════════════  TIER 2 – CONTINENTAL  ═════════════════════

    AtlanticCrossing = {
        DisplayName         = "Atlantic Crossing",
        Description         = "Gruelling transatlantic arc over open ocean. Multi-leg; bring your best defences.",
        Tier                = 2,
        IsSeaLane           = false,
        BasePayout          = 2000,
        BaseRisk            = 0.80,
        LengthLabel         = "Long",
        BestCargo           = { "HeavyToolkits", "ShinyRocks" },
        KeyThreats          = { "MilitaryPatrol", "RivalTheft", "DigitalTrace" },
        CounterUpgrades     = { "SatelliteJammingNetwork", "CommandBunker", "DecoyFleet" },
        OriginHub           = "AndesHub",
        DestinationHub      = "WestAfricaHub",
        HeatMultiplier      = 1.5,
        RequiredPlaneRange  = "Continental",
        RequiredStructures  = { "CommandBunker", "LongRangeHangar" },
        FuelCost            = 40,
        HeatGain            = 12,
        Waypoints           = {
            Vector3.new(-600, Y_AIR,  -50),
            Vector3.new(-450, Y_AIR,  -80),
            Vector3.new(-250, Y_AIR,  -60),
            Vector3.new(-100, Y_AIR,   20),
            Vector3.new(  50, Y_AIR,   80),
            Vector3.new( 100, Y_AIR,  100),
        },
    },

    SahelSparkleRun = {
        DisplayName         = "Sahel Sparkle Run",
        Description         = "Shiny Rocks move fast across this sun-baked corridor. Rivals patrol in force.",
        Tier                = 2,
        IsSeaLane           = false,
        BasePayout          = 1600,
        BaseRisk            = 0.65,
        LengthLabel         = "Medium",
        BestCargo           = { "ShinyRocks" },
        KeyThreats          = { "RivalTheft", "PoliceRaid" },
        CounterUpgrades     = { "Watchtowers", "FakeCargoDepots", "PerimeterFence" },
        OriginHub           = "WestAfricaHub",
        DestinationHub      = "EuropeHub",
        HeatMultiplier      = 1.3,
        RequiredPlaneRange  = "Continental",
        RequiredStructures  = { "Runway" },
        FuelCost            = 25,
        HeatGain            = 8,
        Waypoints           = {
            Vector3.new( 100, Y_AIR,  100),
            Vector3.new( 120, Y_AIR,   40),
            Vector3.new( 140, Y_AIR,  -20),
            Vector3.new( 160, Y_AIR,  -80),
            Vector3.new( 170, Y_AIR, -140),
        },
    },

    GoldenTriangleDash = {
        DisplayName         = "Golden Triangle Dash",
        Description         = "Glow-Disks and powder sacks race through jungle air corridors. Rivals love the sabotage button here.",
        Tier                = 2,
        IsSeaLane           = false,
        BasePayout          = 1400,
        BaseRisk            = 0.55,
        LengthLabel         = "Medium",
        BestCargo           = { "GlowDisks", "MysteryPowder" },
        KeyThreats          = { "RivalSabotage", "DigitalTrace" },
        CounterUpgrades     = { "ReputationPRBuilding", "CamouflageLandscaping", "BribeOffice" },
        OriginHub           = "SEAsiaHub",
        DestinationHub      = "PacificHub",
        HeatMultiplier      = 1.2,
        RequiredPlaneRange  = "Continental",
        RequiredStructures  = { "Runway" },
        FuelCost            = 22,
        HeatGain            = 7,
        Waypoints           = {
            Vector3.new( 500, Y_AIR,   50),
            Vector3.new( 550, Y_AIR,   20),
            Vector3.new( 600, Y_AIR,    0),
            Vector3.new( 650, Y_AIR,  -10),
        },
    },

    -- ── Tier 2 sea lane ──────────────────────────────────────────────────────

    WestAfricaSeaLane = {
        DisplayName         = "West Africa Sea Lane",
        Description         = "Cargo ships crawl up the Atlantic seaboard. Slow, but the coast guard rarely bothers.",
        Tier                = 2,
        IsSeaLane           = true,
        BasePayout          = 1200,
        BaseRisk            = 0.40,
        LengthLabel         = "Long",
        BestCargo           = { "ShinyRocks", "ExoticGoods" },
        KeyThreats          = { "CoastGuard", "PirateRaid" },
        CounterUpgrades     = { "Watchtowers", "DecoyFleet", "FakeCargoDepots" },
        OriginHub           = "WestAfricaHub",
        DestinationHub      = "EuropeHub",
        HeatMultiplier      = 0.8,
        RequiredPlaneRange  = "Regional",
        RequiredStructures  = { "Hangar" },
        FuelCost            = 30,
        HeatGain            = 5,
        Waypoints           = {
            Vector3.new( 100, Y_SEA,  150),
            Vector3.new( 110, Y_SEA,  100),
            Vector3.new( 130, Y_SEA,   40),
            Vector3.new( 150, Y_SEA,  -40),
            Vector3.new( 160, Y_SEA, -120),
        },
    },

    -- ══════════════════════════════  TIER 3 – GLOBAL  ════════════════════════

    PacificRimOrbit = {
        DisplayName         = "Pacific Rim Orbit",
        Description         = "Glow-Disks zip quietly across the Pacific to tech-hub drop zones.",
        Tier                = 3,
        IsSeaLane           = false,
        BasePayout          = 2500,
        BaseRisk            = 0.45,
        LengthLabel         = "Intercontinental",
        BestCargo           = { "GlowDisks" },
        KeyThreats          = { "DigitalTrace", "RivalTheft" },
        CounterUpgrades     = { "RadarTower", "InternationalLaunderingWeb", "SatelliteJammingNetwork" },
        OriginHub           = "SEAsiaHub",
        DestinationHub      = "PacificHub",
        HeatMultiplier      = 1.0,
        RequiredPlaneRange  = "Global",
        RequiredStructures  = { "CommandBunker" },
        FuelCost            = 55,
        HeatGain            = 9,
        Waypoints           = {
            Vector3.new( 500, Y_AIR,   50),
            Vector3.new( 600, Y_AIR,   10),
            Vector3.new( 700, Y_AIR,  -20),
            Vector3.new( 800, Y_AIR,  -35),
            Vector3.new( 900, Y_AIR,  -20),
        },
    },

    IndianOceanArc = {
        DisplayName         = "Indian Ocean Arc",
        Description         = "Sweeping sea lane from East Africa to South Asia. Low heat; Exotic Goods move well.",
        Tier                = 3,
        IsSeaLane           = true,
        BasePayout          = 2200,
        BaseRisk            = 0.35,
        LengthLabel         = "Intercontinental",
        BestCargo           = { "ExoticGoods", "ShinyRocks" },
        KeyThreats          = { "PirateRaid", "CoastGuard" },
        CounterUpgrades     = { "DecoyFleet", "PerimeterFence", "BribeOffice" },
        OriginHub           = "EastAfricaHub",
        DestinationHub      = "SEAsiaHub",
        HeatMultiplier      = 0.9,
        RequiredPlaneRange  = "Global",
        RequiredStructures  = nil,
        FuelCost            = 60,
        HeatGain            = 7,
        Waypoints           = {
            Vector3.new( 200, Y_SEA,  200),
            Vector3.new( 280, Y_SEA,  150),
            Vector3.new( 360, Y_SEA,  100),
            Vector3.new( 440, Y_SEA,   80),
            Vector3.new( 500, Y_SEA,   60),
        },
    },

    MediterraneanRun = {
        DisplayName         = "Mediterranean Run",
        Description         = "Police-heavy hop through tourist skies. Fast money if the bribes are in place.",
        Tier                = 3,
        IsSeaLane           = false,
        BasePayout          = 1800,
        BaseRisk            = 0.60,
        LengthLabel         = "Medium",
        BestCargo           = { "GlowDisks", "ShinyRocks" },
        KeyThreats          = { "PoliceRaid", "DigitalTrace" },
        CounterUpgrades     = { "BribeOffice", "ReputationPRBuilding", "FakeTerminal" },
        OriginHub           = "EuropeHub",
        DestinationHub      = "MiddleEastHub",
        HeatMultiplier      = 1.1,
        RequiredPlaneRange  = "Continental",
        RequiredStructures  = { "BribeOffice" },
        FuelCost            = 35,
        HeatGain            = 8,
        Waypoints           = {
            Vector3.new( 170, Y_AIR, -140),
            Vector3.new( 200, Y_AIR, -160),
            Vector3.new( 240, Y_AIR, -180),
            Vector3.new( 270, Y_AIR, -170),
        },
    },

    NorthernPassage = {
        DisplayName         = "Northern Passage",
        Description         = "Icy polar arc — military presence is thin but cold kills careless planes.",
        Tier                = 3,
        IsSeaLane           = false,
        BasePayout          = 3000,
        BaseRisk            = 0.70,
        LengthLabel         = "Intercontinental",
        BestCargo           = { "HeavyToolkits" },
        KeyThreats          = { "MilitaryPatrol", "WeatherEvent" },
        CounterUpgrades     = { "CommandBunker", "UndergroundHangar", "JammingTower" },
        OriginHub           = "EuropeHub",
        DestinationHub      = "NorthAmericaHub",
        HeatMultiplier      = 1.4,
        RequiredPlaneRange  = "Global",
        RequiredStructures  = { "CommandBunker" },
        FuelCost            = 80,
        HeatGain            = 15,
        Waypoints           = {
            Vector3.new( 170, Y_AIR, -140),
            Vector3.new(  80, Y_AIR, -250),
            Vector3.new( -80, Y_AIR, -300),
            Vector3.new(-250, Y_AIR, -260),
            Vector3.new(-380, Y_AIR, -200),
            Vector3.new(-460, Y_AIR, -120),
        },
    },

    SouthernCross = {
        DisplayName         = "Southern Cross",
        Description         = "Ultra-long South polar haul. Almost no patrols — just distance. Maximum payout.",
        Tier                = 3,
        IsSeaLane           = false,
        BasePayout          = 3500,
        BaseRisk            = 0.30,
        LengthLabel         = "Intercontinental",
        BestCargo           = { "ShinyRocks", "GlowDisks" },
        KeyThreats          = { "WeatherEvent" },
        CounterUpgrades     = { "SatelliteJammingNetwork", "InternationalLaunderingWeb" },
        OriginHub           = "AndesHub",
        DestinationHub      = "EastAfricaHub",
        HeatMultiplier      = 0.7,
        RequiredPlaneRange  = "Global",
        RequiredStructures  = nil,
        FuelCost            = 70,
        HeatGain            = 6,
        Waypoints           = {
            Vector3.new(-600, Y_AIR,  -50),
            Vector3.new(-500, Y_AIR,  200),
            Vector3.new(-200, Y_AIR,  350),
            Vector3.new( 100, Y_AIR,  350),
            Vector3.new( 200, Y_AIR,  250),
        },
    },

    -- ── Tier 3 sea lanes ─────────────────────────────────────────────────────

    SilkSeaLane = {
        DisplayName         = "Silk Sea Lane",
        Description         = "Container ships hug ancient trade routes across Asia. GlowDisks and ExoticGoods favour this lane.",
        Tier                = 3,
        IsSeaLane           = true,
        BasePayout          = 2800,
        BaseRisk            = 0.40,
        LengthLabel         = "Intercontinental",
        BestCargo           = { "GlowDisks", "ExoticGoods" },
        KeyThreats          = { "CoastGuard", "DigitalTrace" },
        CounterUpgrades     = { "BribeOffice", "RadarTower", "InternationalLaunderingWeb" },
        OriginHub           = "MiddleEastHub",
        DestinationHub      = "SEAsiaHub",
        HeatMultiplier      = 0.85,
        RequiredPlaneRange  = "Global",
        RequiredStructures  = { "PortAuthorityFront" },
        FuelCost            = 65,
        HeatGain            = 8,
        Waypoints           = {
            Vector3.new( 270, Y_SEA, -170),
            Vector3.new( 330, Y_SEA, -100),
            Vector3.new( 390, Y_SEA,  -20),
            Vector3.new( 440, Y_SEA,   40),
            Vector3.new( 490, Y_SEA,   60),
        },
    },

    TransPacificFreighter = {
        DisplayName         = "Trans-Pacific Freighter",
        Description         = "A behemoth cargo ship that crawls from Pacific ports to the Americas. Virtually invisible — if you can wait.",
        Tier                = 3,
        IsSeaLane           = true,
        BasePayout          = 3200,
        BaseRisk            = 0.25,
        LengthLabel         = "Intercontinental",
        BestCargo           = { "ExoticGoods", "ShinyRocks" },
        KeyThreats          = { "CoastGuard", "PirateRaid" },
        CounterUpgrades     = { "DecoyFleet", "FakeCargoDepots", "Watchtowers" },
        OriginHub           = "PacificHub",
        DestinationHub      = "NorthAmericaHub",
        HeatMultiplier      = 0.7,
        RequiredPlaneRange  = "Global",
        RequiredStructures  = { "PortAuthorityFront" },
        FuelCost            = 80,
        HeatGain            = 6,
        Waypoints           = {
            Vector3.new( 900, Y_SEA,  -20),
            Vector3.new( 700, Y_SEA,   20),
            Vector3.new( 400, Y_SEA,   60),
            Vector3.new( 100, Y_SEA,   80),
            Vector3.new(-200, Y_SEA,   60),
            Vector3.new(-400, Y_SEA,   40),
        },
    },
}

return RouteData
