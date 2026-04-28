--!strict
-- CargoData
-- Defines stats for every cartoon contraband type.
-- All names are fictional placeholders; no real-world goods are modelled.

export type CargoDef = {
    DisplayName       : string,
    Description       : string,
    Color             : Color3,
    Slots             : number,           -- plane cargo slots consumed per crate
    PayoutMultiplier  : number,           -- multiplied against the route's BasePayout
    BaseDetectionRisk : number,           -- 0–1 added risk on top of the route's BaseRisk
    HeatOnSuccess     : number,           -- global Heat added after a clean run
    HeatOnBust        : number,           -- global Heat added on failure
    ChaosEvent        : string,           -- EventManager event most likely for this type
    ChaosChance       : number,           -- 0–1 per-waypoint chance of the chaos event
    BestCounters      : { string },       -- upgrade IDs that most reduce this type's risk
    UnlockTier        : number,           -- minimum empire Tier needed to load this cargo
}

local CargoData: { [string]: CargoDef } = {

    -- ── Sparkly gem crates ──────────────────────────────────────────
    ShinyRocks = {
        DisplayName       = "Shiny Rocks",
        Description       = "Sparkly gem crates that tinkle when loaded.",
        Color             = Color3.fromRGB(100, 200, 255),
        Slots             = 1,
        PayoutMultiplier  = 5.0,
        BaseDetectionRisk = 0.40,
        HeatOnSuccess     = 8,
        HeatOnBust        = 20,
        ChaosEvent        = "RivalTheft",
        ChaosChance       = 0.25,
        BestCounters      = { "PerimeterFence", "Watchtowers", "FakeCargoDepots" },
        UnlockTier        = 1,
    },

    -- ── Colourful powder sacks ──────────────────────────────────────
    MysteryPowder = {
        DisplayName       = "Mystery Powder",
        Description       = "Colourful mystery powder sacks that puff on impact.",
        Color             = Color3.fromRGB(255, 200, 50),
        Slots             = 2,
        PayoutMultiplier  = 4.0,
        BaseDetectionRisk = 0.60,
        HeatOnSuccess     = 10,
        HeatOnBust        = 25,
        ChaosEvent        = "LeakSpill",
        ChaosChance       = 0.30,
        BestCounters      = { "LaunderingOffice", "CamouflageLandscaping", "Cleaners" },
        UnlockTier        = 1,
    },

    -- ── Heavy glowing tool crates ───────────────────────────────────
    HeavyToolkits = {
        DisplayName       = "Heavy Toolkits",
        Description       = "Heavy locked toolboxes that glow at the seams.",
        Color             = Color3.fromRGB(150, 80, 30),
        Slots             = 3,
        PayoutMultiplier  = 5.0,
        BaseDetectionRisk = 0.75,
        HeatOnSuccess     = 15,
        HeatOnBust        = 35,
        ChaosEvent        = "MilitaryPatrol",
        ChaosChance       = 0.35,
        BestCounters      = { "JammingTower", "UndergroundHangar", "CommandBunker" },
        UnlockTier        = 2,
    },

    -- ── Floating data orbs ──────────────────────────────────────────
    GlowDisks = {
        DisplayName       = "Glow-Disks",
        Description       = "Floating data orbs that quietly creep up the Heat meter.",
        Color             = Color3.fromRGB(200, 50, 255),
        Slots             = 1,
        PayoutMultiplier  = 3.0,
        BaseDetectionRisk = 0.30,
        HeatOnSuccess     = 5,
        HeatOnBust        = 15,
        ChaosEvent        = "DigitalTrace",
        ChaosChance       = 0.20,
        BestCounters      = { "ReputationPRBuilding", "BribeOffice", "RadarTower" },
        UnlockTier        = 1,
    },

    -- ── Cartoon critters & rare art (late-game bonus variety) ───────
    ExoticGoods = {
        DisplayName       = "Exotic Goods",
        Description       = "Cartoon caged critters and rolled-up mystery canvases.",
        Color             = Color3.fromRGB(50, 200, 100),
        Slots             = 2,
        PayoutMultiplier  = 3.5,
        BaseDetectionRisk = 0.45,
        HeatOnSuccess     = 6,
        HeatOnBust        = 18,
        ChaosEvent        = "PetEscape",
        ChaosChance       = 0.20,
        BestCounters      = { "PerimeterFence", "LaunderingOffice" },
        UnlockTier        = 3,
    },
}

return CargoData
