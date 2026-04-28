--!strict
-- UpgradeData
-- SimCity-style buildings (per-hub) and empire-wide network upgrades.
-- Each building placed on a hub grid directly reduces risk / adds Heat decay.

export type UpgradeDef = {
    DisplayName          : string,
    Description          : string,
    Color                : Color3,
    Cost                 : number,           -- base cost in black money
    Tier                 : number,           -- empire Tier required to unlock
    IsGlobal             : boolean,          -- true = empire-wide; no grid model
    GridSize             : { number },       -- { width, depth } in hub-grid tiles
    RiskReduction        : number,           -- per level, flat reduction to matching risks
    HeatDecayBonus       : number,           -- Heat units removed per passive decay tick
    CountersEvents       : { string },       -- chaos-event IDs this building reduces chance of
    CountersCargo        : { string },       -- cargo IDs this building benefits most
    MaxLevel             : number,
    LevelCostMultiplier  : number,           -- cost at level N = Cost × multiplier^(N-1)
}

local UpgradeData: { [string]: UpgradeDef } = {

    -- ══════════════════════════  PER-HUB BUILDINGS  ══════════════════════════

    PerimeterFence = {
        DisplayName         = "Perimeter Fence",
        Description         = "Cartoon picket fence around the hub. Cuts rival theft chances.",
        Color               = Color3.fromRGB(180, 160, 100),
        Cost                = 500,
        Tier                = 1,
        IsGlobal            = false,
        GridSize            = { 1, 3 },
        RiskReduction       = 0.08,
        HeatDecayBonus      = 0,
        CountersEvents      = { "RivalTheft" },
        CountersCargo       = { "ShinyRocks" },
        MaxLevel            = 3,
        LevelCostMultiplier = 1.8,
    },

    Watchtowers = {
        DisplayName         = "Watchtowers",
        Description         = "Tall cartoon towers with spinning spotlight heads. Spots rival scouts early.",
        Color               = Color3.fromRGB(220, 180, 60),
        Cost                = 800,
        Tier                = 1,
        IsGlobal            = false,
        GridSize            = { 1, 1 },
        RiskReduction       = 0.10,
        HeatDecayBonus      = 0,
        CountersEvents      = { "RivalTheft", "RivalSabotage" },
        CountersCargo       = { "ShinyRocks" },
        MaxLevel            = 3,
        LevelCostMultiplier = 1.8,
    },

    FakeCargoDepots = {
        DisplayName         = "Fake Cargo Depots",
        Description         = "Dummy warehouses stuffed with cardboard boxes. Confuse police scanners.",
        Color               = Color3.fromRGB(210, 200, 180),
        Cost                = 600,
        Tier                = 1,
        IsGlobal            = false,
        GridSize            = { 2, 2 },
        RiskReduction       = 0.10,
        HeatDecayBonus      = 1,
        CountersEvents      = { "PoliceRaid" },
        CountersCargo       = { "ShinyRocks", "ExoticGoods" },
        MaxLevel            = 3,
        LevelCostMultiplier = 1.7,
    },

    LaunderingOffice = {
        DisplayName         = "Laundering Office",
        Description         = "Bouncy cartoon office tower. Converts Heat into passive decay over time.",
        Color               = Color3.fromRGB(80, 120, 220),
        Cost                = 1200,
        Tier                = 1,
        IsGlobal            = false,
        GridSize            = { 2, 2 },
        RiskReduction       = 0.05,
        HeatDecayBonus      = 3,
        CountersEvents      = {},
        CountersCargo       = { "MysteryPowder", "ExoticGoods" },
        MaxLevel            = 5,
        LevelCostMultiplier = 2.0,
    },

    CamouflageLandscaping = {
        DisplayName         = "Camouflage Landscaping",
        Description         = "Cartoon bushes and camo netting over the runway. Powder runs harder to spot.",
        Color               = Color3.fromRGB(60, 140, 60),
        Cost                = 700,
        Tier                = 1,
        IsGlobal            = false,
        GridSize            = { 3, 1 },
        RiskReduction       = 0.12,
        HeatDecayBonus      = 0,
        CountersEvents      = { "PoliceRaid", "LeakSpill" },
        CountersCargo       = { "MysteryPowder" },
        MaxLevel            = 3,
        LevelCostMultiplier = 1.6,
    },

    Cleaners = {
        DisplayName         = "Cleaners Crew",
        Description         = "Cartoon mop-wielding cleaners who sprint to any spill site instantly.",
        Color               = Color3.fromRGB(200, 230, 255),
        Cost                = 900,
        Tier                = 1,
        IsGlobal            = false,
        GridSize            = { 2, 1 },
        RiskReduction       = 0.08,
        HeatDecayBonus      = 2,
        CountersEvents      = { "LeakSpill" },
        CountersCargo       = { "MysteryPowder" },
        MaxLevel            = 3,
        LevelCostMultiplier = 1.7,
    },

    JammingTower = {
        DisplayName         = "Jamming Tower",
        Description         = "Shoots cartoon lightning bolts at radar screens. Military patrols fly blind.",
        Color               = Color3.fromRGB(255, 120, 0),
        Cost                = 2000,
        Tier                = 2,
        IsGlobal            = false,
        GridSize            = { 1, 1 },
        RiskReduction       = 0.15,
        HeatDecayBonus      = 0,
        CountersEvents      = { "MilitaryPatrol" },
        CountersCargo       = { "HeavyToolkits" },
        MaxLevel            = 4,
        LevelCostMultiplier = 2.0,
    },

    UndergroundHangar = {
        DisplayName         = "Underground Hangar",
        Description         = "Secret cartoon cavern under the runway. Planes park completely unseen.",
        Color               = Color3.fromRGB(80, 60, 40),
        Cost                = 3000,
        Tier                = 2,
        IsGlobal            = false,
        GridSize            = { 4, 2 },
        RiskReduction       = 0.18,
        HeatDecayBonus      = 2,
        CountersEvents      = { "MilitaryPatrol", "PoliceRaid" },
        CountersCargo       = { "HeavyToolkits" },
        MaxLevel            = 3,
        LevelCostMultiplier = 2.2,
    },

    CommandBunker = {
        DisplayName         = "Command Bunker",
        Description         = "The big cartoon fortress brain. Unlocks Tier 3 global upgrades and cuts all risk.",
        Color               = Color3.fromRGB(60, 60, 90),
        Cost                = 5000,
        Tier                = 2,
        IsGlobal            = false,
        GridSize            = { 3, 3 },
        RiskReduction       = 0.20,
        HeatDecayBonus      = 5,
        CountersEvents      = { "MilitaryPatrol", "RivalTheft", "PoliceRaid" },
        CountersCargo       = { "HeavyToolkits" },
        MaxLevel            = 3,
        LevelCostMultiplier = 2.5,
    },

    BribeOffice = {
        DisplayName         = "Bribe Office",
        Description         = "Comically shifty little building with a coin slot. Pays off inspectors on arrival.",
        Color               = Color3.fromRGB(240, 210, 50),
        Cost                = 1000,
        Tier                = 1,
        IsGlobal            = false,
        GridSize            = { 1, 1 },
        RiskReduction       = 0.12,
        HeatDecayBonus      = 1,
        CountersEvents      = { "PoliceRaid", "CoastGuard" },
        CountersCargo       = { "GlowDisks", "MysteryPowder" },
        MaxLevel            = 4,
        LevelCostMultiplier = 1.9,
    },

    ReputationPRBuilding = {
        DisplayName         = "PR Building",
        Description         = "Glowing billboard of good vibes. Reduces DigitalTrace and passive Heat creep.",
        Color               = Color3.fromRGB(255, 60, 180),
        Cost                = 1500,
        Tier                = 2,
        IsGlobal            = false,
        GridSize            = { 2, 1 },
        RiskReduction       = 0.10,
        HeatDecayBonus      = 4,
        CountersEvents      = { "DigitalTrace" },
        CountersCargo       = { "GlowDisks" },
        MaxLevel            = 3,
        LevelCostMultiplier = 1.8,
    },

    RadarTower = {
        DisplayName         = "Radar Tower",
        Description         = "Spinning dish that spots incoming events 1 waypoint early.",
        Color               = Color3.fromRGB(180, 220, 255),
        Cost                = 1800,
        Tier                = 2,
        IsGlobal            = false,
        GridSize            = { 1, 1 },
        RiskReduction       = 0.08,
        HeatDecayBonus      = 0,
        CountersEvents      = { "DigitalTrace", "RivalSabotage" },
        CountersCargo       = { "GlowDisks" },
        MaxLevel            = 3,
        LevelCostMultiplier = 1.8,
    },

    FakeTerminal = {
        DisplayName         = "Fake Terminal",
        Description         = "Fake customs terminal with rubber-stamp officials. Planes look legit on radar.",
        Color               = Color3.fromRGB(200, 200, 200),
        Cost                = 1100,
        Tier                = 1,
        IsGlobal            = false,
        GridSize            = { 2, 2 },
        RiskReduction       = 0.12,
        HeatDecayBonus      = 1,
        CountersEvents      = { "PoliceRaid" },
        CountersCargo       = { "MysteryPowder", "ShinyRocks" },
        MaxLevel            = 3,
        LevelCostMultiplier = 1.7,
    },

    -- ════════════════════════  GLOBAL (EMPIRE-WIDE) UPGRADES  ════════════════

    DecoyFleet = {
        DisplayName         = "Decoy Fleet Command",
        Description         = "Auto-launches cartoon ghost planes from any hub to confuse rivals and patrols.",
        Color               = Color3.fromRGB(255, 200, 100),
        Cost                = 8000,
        Tier                = 2,
        IsGlobal            = true,
        GridSize            = { 0, 0 },
        RiskReduction       = 0.15,
        HeatDecayBonus      = 0,
        CountersEvents      = { "MilitaryPatrol", "RivalTheft", "RivalSabotage" },
        CountersCargo       = { "HeavyToolkits", "ShinyRocks" },
        MaxLevel            = 2,
        LevelCostMultiplier = 2.5,
    },

    SatelliteJammingNetwork = {
        DisplayName         = "Satellite Jamming Network",
        Description         = "Empire-wide jamming. All long-haul routes get –40% military intercept chance.",
        Color               = Color3.fromRGB(100, 100, 255),
        Cost                = 15000,
        Tier                = 3,
        IsGlobal            = true,
        GridSize            = { 0, 0 },
        RiskReduction       = 0.20,
        HeatDecayBonus      = 0,
        CountersEvents      = { "MilitaryPatrol" },
        CountersCargo       = { "HeavyToolkits" },
        MaxLevel            = 2,
        LevelCostMultiplier = 3.0,
    },

    InternationalLaunderingWeb = {
        DisplayName         = "International Laundering Web",
        Description         = "Slowly converts black money from any hub and bleeds global Heat over time.",
        Color               = Color3.fromRGB(50, 220, 150),
        Cost                = 20000,
        Tier                = 3,
        IsGlobal            = true,
        GridSize            = { 0, 0 },
        RiskReduction       = 0.05,
        HeatDecayBonus      = 15,
        CountersEvents      = {},
        CountersCargo       = {},
        MaxLevel            = 3,
        LevelCostMultiplier = 2.5,
    },
}

return UpgradeData
