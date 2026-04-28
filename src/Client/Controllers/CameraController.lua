--!strict
-- CameraController (Knit Controller)
-- Overhead SimCity-style isometric camera.
-- Pan: WASD / arrow keys.  Zoom: scroll wheel.
-- FocusOn(position): snap to a hub or plane click.
--
-- Pattern pulled from common Roblox top-down tycoon camera implementations
-- and adapted for a global-map overhead view.

local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

-- ─────────────────────────────────────────────────────────────────────────────

local CAM_PITCH_DEG = 60     -- degrees tilted from straight-down
local PAN_SPEED     = 1.0    -- focus-units per stud of zoom, per second
local ZOOM_MIN      = 100
local ZOOM_MAX      = 700
local ZOOM_STEP     = 25     -- studs per scroll tick

-- ─────────────────────────────────────────────────────────────────────────────

local CameraController = Knit.CreateController({ Name = "CameraController" })

local camera: Camera
local focus   = Vector3.new(0, 0, 0)    -- world point the camera orbits
local zoom    = 350                      -- distance from focus

-- ─────────────────────────────────────────────────────────────────────────────

local function applyCamera()
    local rad     = math.rad(CAM_PITCH_DEG)
    local height  = zoom * math.cos(rad)
    local depth   = zoom * math.sin(rad)
    local camPos  = focus + Vector3.new(0, height, depth)
    camera.CFrame = CFrame.lookAt(camPos, focus)
end

-- ─────────────────────────────────────────────────────────────────────────────

function CameraController:KnitInit()
    camera = workspace.CurrentCamera
    camera.CameraType = Enum.CameraType.Scriptable
end

function CameraController:KnitStart()
    -- Pan each frame
    RunService.Heartbeat:Connect(function(dt: number)
        local speed = PAN_SPEED * zoom * dt
        local delta = Vector3.zero

        if UserInputService:IsKeyDown(Enum.KeyCode.W)
            or UserInputService:IsKeyDown(Enum.KeyCode.Up)    then delta += Vector3.new(0, 0, -speed) end
        if UserInputService:IsKeyDown(Enum.KeyCode.S)
            or UserInputService:IsKeyDown(Enum.KeyCode.Down)  then delta += Vector3.new(0, 0,  speed) end
        if UserInputService:IsKeyDown(Enum.KeyCode.A)
            or UserInputService:IsKeyDown(Enum.KeyCode.Left)  then delta += Vector3.new(-speed, 0, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.D)
            or UserInputService:IsKeyDown(Enum.KeyCode.Right) then delta += Vector3.new( speed, 0, 0) end

        if delta.Magnitude > 0 then
            focus = focus + delta
        end

        applyCamera()
    end)

    -- Zoom on scroll
    UserInputService.InputChanged:Connect(function(input: InputObject)
        if input.UserInputType == Enum.UserInputType.MouseWheel then
            zoom = math.clamp(zoom - input.Position.Z * ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
        end
    end)
end

--- Snap the camera focus to a world-space position (e.g. clicking a hub).
function CameraController:FocusOn(position: Vector3)
    focus = Vector3.new(position.X, 0, position.Z)
end

--- Set zoom level directly (e.g. when loading a saved view).
function CameraController:SetZoom(level: number)
    zoom = math.clamp(level, ZOOM_MIN, ZOOM_MAX)
end

return CameraController
