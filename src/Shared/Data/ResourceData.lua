--!strict
-- ResourceData
-- Defines the six resource types used across the Contraband Airways economy.
-- ResourceService uses these definitions for caps and display metadata.

export type ResourceDef = {
    DisplayName    : string,
    Description    : string,
    Cap            : number,    -- maximum storable amount (0 = unlimited)
    StartingAmount : number,    -- empire starts with this much
}

local ResourceData: { [string]: ResourceDef } = {

    BlackMoney = {
        DisplayName    = "Black Money",
        Description    = "Street cash earned from runs and scavenging. Used for most buildings and planes.",
        Cap            = 0,
        StartingAmount = 0,
    },

    CleanCash = {
        DisplayName    = "Clean Cash",
        Description    = "Laundered funds for public-facing upgrades and permits.",
        Cap            = 0,
        StartingAmount = 0,
    },

    Parts = {
        DisplayName    = "Parts",
        Description    = "Salvaged and manufactured components for planes, hangars, and repairs.",
        Cap            = 500,
        StartingAmount = 0,
    },

    Fuel = {
        DisplayName    = "Fuel",
        Description    = "Aviation and marine fuel required to launch routes.",
        Cap            = 1000,
        StartingAmount = 100,
    },

    Influence = {
        DisplayName    = "Influence",
        Description    = "Street credibility and political connections. Unlocks hubs and bribes.",
        Cap            = 200,
        StartingAmount = 0,
    },

    Intel = {
        DisplayName    = "Intel",
        Description    = "Gathered intelligence that reveals route risks and unlocks targets.",
        Cap            = 100,
        StartingAmount = 0,
    },
}

return ResourceData
