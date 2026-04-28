-- Client bootstrap
-- Loads every Knit controller then starts the framework.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

require(script.Controllers.CameraController)
require(script.Controllers.MapController)
require(script.Controllers.CargoController)
require(script.Controllers.BuildController)
require(script.Controllers.UIController)

Knit.Start()
    :andThen(function()
        print("[Contraband Airways] 🖥  Client ready")
    end)
    :catch(function(err)
        warn("[Contraband Airways] Client start failed:", err)
    end)
