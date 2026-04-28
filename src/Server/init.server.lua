-- Server bootstrap
-- Loads every Knit service in dependency order then starts the framework.

local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Knit = require(ReplicatedStorage.Packages.Knit)

-- Order matters: services lower in the list may call Knit.GetService() on
-- those above, but only after KnitStart fires (they use task.defer / Knit
-- lazy lookup — safe either way).
require(script.Services.WorldService)        -- creates workspace map + hubs/pads
require(script.Services.PlaneService)
require(script.Services.RouteService)
require(script.Services.HeatService)
require(script.Services.EventManager)
require(script.Services.CargoService)
require(script.Services.UpgradeService)
-- New economy services (must be registered before EmpireService)
require(script.Services.ResourceService)
require(script.Services.BuildService)
require(script.Services.FleetService)
require(script.Services.ProductionService)
require(script.Services.UnlockService)
require(script.Services.EmpireService)   -- goes last: uses all of the above

Knit.Start()
    :andThen(function()
        print("[Contraband Airways] ✈  Server ready")
    end)
    :catch(function(err)
        warn("[Contraband Airways] Server start failed:", err)
    end)
