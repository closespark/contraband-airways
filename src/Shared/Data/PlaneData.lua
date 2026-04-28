--!strict
-- PlaneData
-- Stats and acquisition costs for every aircraft and vessel type.
-- FleetService uses these definitions to gate orders and track durability.

export type PlaneCost = {
    BlackMoney : number,
    Parts      : number,
}

export type PlaneDef = {
    DisplayName         : string,
    Description         : string,
    Slots               : number,   -- cargo slots available
    Speed               : number,   -- speed multiplier relative to BasicProp (1.0)
    FuelUse             : number,   -- Fuel units consumed on each route launch
    BaseRiskModifier    : number,   -- added to effective route risk (negative = stealth bonus)
    Range               : string,   -- "Regional" | "Continental" | "Global"
    Durability          : number,   -- hit points; Damaged below 30, Destroyed at 0
    RequiredHangarLevel : number,   -- minimum Hangar structure level needed to store this type
    Cost                : PlaneCost,
    DeliveryTime        : number,   -- seconds from order to Delivered state
    UpgradesFrom        : string?,  -- plane type this can be upgraded from (nil = no chain)
    IsSeaVessel         : boolean,  -- true = boat/ship; false = aircraft
}

local PlaneData: { [string]: PlaneDef } = {

    -- ── AIRCRAFT ──────────────────────────────────────────────────────────────

    BasicProp = {
        DisplayName         = "Basic Prop",
        Description         = "A battered single-engine workhorse. Perfect for short regional hops.",
        Slots               = 6,
        Speed               = 1.0,
        FuelUse             = 8,
        BaseRiskModifier    = 0,
        Range               = "Regional",
        Durability          = 100,
        RequiredHangarLevel = 1,
        Cost                = { BlackMoney = 1500, Parts = 5 },
        DeliveryTime        = 30,
        UpgradesFrom        = nil,
        IsSeaVessel         = false,
    },

    ReinforcedProp = {
        DisplayName         = "Reinforced Prop",
        Description         = "Armoured propeller plane with extra cargo netting. Less fragile, more load.",
        Slots               = 9,
        Speed               = 0.9,
        FuelUse             = 12,
        BaseRiskModifier    = 0.02,
        Range               = "Regional",
        Durability          = 160,
        RequiredHangarLevel = 1,
        Cost                = { BlackMoney = 3500, Parts = 12 },
        DeliveryTime        = 60,
        UpgradesFrom        = "BasicProp",
        IsSeaVessel         = false,
    },

    StealthProp = {
        DisplayName         = "Stealth Prop",
        Description         = "Radar-absorbing composite shell. Hard to spot, low cargo capacity.",
        Slots               = 5,
        Speed               = 1.2,
        FuelUse             = 10,
        BaseRiskModifier    = -0.05,
        Range               = "Regional",
        Durability          = 80,
        RequiredHangarLevel = 2,
        Cost                = { BlackMoney = 6000, Parts = 20 },
        DeliveryTime        = 90,
        UpgradesFrom        = "ReinforcedProp",
        IsSeaVessel         = false,
    },

    TwinProp = {
        DisplayName         = "Twin Prop",
        Description         = "Twin-engine medium hauler. Reliable across continental routes.",
        Slots               = 14,
        Speed               = 1.1,
        FuelUse             = 20,
        BaseRiskModifier    = 0.04,
        Range               = "Continental",
        Durability          = 200,
        RequiredHangarLevel = 2,
        Cost                = { BlackMoney = 8000, Parts = 25 },
        DeliveryTime        = 120,
        UpgradesFrom        = nil,
        IsSeaVessel         = false,
    },

    CargoJet = {
        DisplayName         = "Cargo Jet",
        Description         = "High-capacity jet with intercontinental range. Heavy Heat signature.",
        Slots               = 24,
        Speed               = 1.8,
        FuelUse             = 40,
        BaseRiskModifier    = 0.12,
        Range               = "Global",
        Durability          = 300,
        RequiredHangarLevel = 3,
        Cost                = { BlackMoney = 25000, Parts = 60 },
        DeliveryTime        = 300,
        UpgradesFrom        = nil,
        IsSeaVessel         = false,
    },

    -- ── SEA VESSELS ───────────────────────────────────────────────────────────

    FastBoat = {
        DisplayName         = "Fast Boat",
        Description         = "Nimble speedboat for short coastal sea lanes. Easy to hide.",
        Slots               = 8,
        Speed               = 0.7,
        FuelUse             = 15,
        BaseRiskModifier    = -0.03,
        Range               = "Regional",
        Durability          = 80,
        RequiredHangarLevel = 1,
        Cost                = { BlackMoney = 3000, Parts = 10 },
        DeliveryTime        = 60,
        UpgradesFrom        = nil,
        IsSeaVessel         = true,
    },

    CargoShip = {
        DisplayName         = "Cargo Ship",
        Description         = "Slow bulk freighter with enormous capacity. Nearly invisible on patrol routes.",
        Slots               = 40,
        Speed               = 0.35,
        FuelUse             = 60,
        BaseRiskModifier    = 0.05,
        Range               = "Global",
        Durability          = 500,
        RequiredHangarLevel = 3,
        Cost                = { BlackMoney = 40000, Parts = 100 },
        DeliveryTime        = 600,
        UpgradesFrom        = nil,
        IsSeaVessel         = true,
    },
}

return PlaneData
