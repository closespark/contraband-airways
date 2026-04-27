--!strict
-- ProfileTemplate
-- Default data shape consumed by ProfileService for both the shared empire
-- profile and per-player personal stats.
-- All nested tables must be primitive-only (no Vector2/Color3) so ProfileService
-- can serialise them to Roblox DataStores without conversion.

local ProfileTemplate = {

    -- ── Shared empire (one profile per server, all co-op players write here) ──
    Empire = {
        BlackMoney     = 0,       -- accumulated "cartoon currency"
        GlobalHeat     = 0,       -- 0–1000; drives escalation events
        Tier           = 1,       -- 1 / 2 / 3

        -- { [routeId] = true }
        UnlockedRoutes = {} :: { [string]: boolean },

        -- { [hubId] = true }
        UnlockedHubs   = {} :: { [string]: boolean },

        -- { [hubId] = { [upgradeId] = { level = N, gridX = N, gridZ = N } } }
        HubLayouts     = {} :: { [string]: { [string]: { level: number, gridX: number, gridZ: number } } },

        -- { [upgradeId] = level }  — empire-wide (global) upgrades
        GlobalUpgrades = {} :: { [string]: number },
    },

    -- ── Per-player personal stats ─────────────────────────────────────────────
    Player = {
        ContributedMoney    = 0,
        TotalRunsCompleted  = 0,
        TotalRunsFailed     = 0,
        FavoriteCargoType   = "",      -- set automatically on most-used cargo type
        Role                = "",      -- e.g. "DiamondRunner", "ToolkitDefender"
        Badges              = {} :: { [string]: boolean },
    },
}

return ProfileTemplate
