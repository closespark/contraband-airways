--!strict
-- ProfileTemplate
-- Default data shape consumed by ProfileService for both the shared empire
-- profile and per-player personal stats.
-- All nested tables must be primitive-only (no Vector2/Color3) so ProfileService
-- can serialise them to Roblox DataStores without conversion.

local ProfileTemplate = {

    -- ── Shared empire (one profile per server, all co-op players write here) ──
    Empire = {
        -- Legacy top-level field kept for migration; zeroed by EmpireService:KnitInit
        -- after its value has been moved into Resources.BlackMoney.
        BlackMoney     = 0,       -- accumulated "cartoon currency" (legacy)
        GlobalHeat     = 0,       -- 0–1000; drives escalation events
        Tier           = 1,       -- 1 / 2 / 3

        -- ── Multi-resource economy ────────────────────────────────────────────
        -- { [resourceId] = amount }
        -- ResourceService is the single owner of these values at runtime.
        Resources = {
            BlackMoney = 0,
            CleanCash  = 0,
            Parts      = 0,
            Fuel       = 100,   -- starter fuel so the first route can launch
            Influence  = 0,
            Intel      = 0,
        },

        -- ── Fleet (logical plane registry) ───────────────────────────────────
        -- { [fleetId] = { planeType, state, hubId, durability, ... } }
        -- FleetService owns this at runtime.
        Fleet = {} :: { [string]: any },

        -- ── Build queue ───────────────────────────────────────────────────────
        -- { [hubId] = { { uid, startTime, duration } } }
        -- BuildService owns this at runtime.
        BuildQueue = {} :: { [string]: { any } },

        -- ── Structure state (canonical; supersedes HubLayouts) ────────────────
        -- { [hubId] = { [uid] = { state, level, gridX, gridZ } } }
        -- BuildService owns this at runtime.
        Structures = {} :: { [string]: { [string]: any } },

        -- { [routeId] = true }
        UnlockedRoutes = {} :: { [string]: boolean },

        -- { [routeId] = true }  — routes completed at least once (for unlock checks)
        CompletedRoutes = {} :: { [string]: boolean },

        -- { [hubId] = true }
        UnlockedHubs   = {} :: { [string]: boolean },

        -- Legacy hub layout kept for backward compatibility with UpgradeService.
        -- BuildService mirrors new structure levels here so existing code keeps working.
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
