-- Combined Aimbot Script with Mercury Library GUI

-- Define globals for Roblox exploits (prevents undefined global warnings)
local Drawing = Drawing or {}
local getgenv = getgenv or function() return _G end

-- Add wrapper functions for drawing objects
local setrenderproperty = function(Object, Key, Value)
    if Object and typeof(Object) == "table" and Object[Key] ~= nil then
        Object[Key] = Value
    end
end

local getrenderproperty = function(Object, Key)
    if Object and typeof(Object) == "table" and Object[Key] ~= nil then
        return Object[Key]
    end
    return nil
end

-- Add mousemoverel fallback
if not mousemoverel then
    mousemoverel = function(x, y)
        warn("mousemoverel function not available in this environment")
    end
end

-- Initialize game services
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Helper functions
local function GetMouseLocation()
    return UserInputService:GetMouseLocation()
end

local function ConvertVector(Vector)
    return Vector2.new(Vector.X, Vector.Y)
end

-- Initialize aimbot environment
local aimbot = {
    -- Core shared settings between both aimbots
    Active = false,
    Mode = "Legit", -- "Legit" or "Blatant"
    
    -- Player targeting
    TargetMode = "All", -- "All" or "Specific"
    SpecificTarget = nil, -- Store the specific player to target
    
    -- FOV objects
    FOVCircle = Drawing.new("Circle"),
    FOVCircleOutline = Drawing.new("Circle"), -- Only used in blatant mode
    TracerLine = Drawing.new("Line"), -- Only used in blatant mode
    
    -- State tracking
    CurrentHighlight = nil,
    Target = nil,
    IsAiming = false,
    Loaded = false,
    
    -- Common Settings
    Settings = {
        Enabled = false, -- Start with aimbot disabled
        TeamCheck = false,
        AliveCheck = true,
        WallCheck = false,
        TriggerKey = Enum.UserInputType.MouseButton2,
        LockPart = "Head",
        MaxDistance = 1000,
    },
    
    -- FOV Settings (shared with some variations)
    FOVSettings = {
        Enabled = false, -- Start with FOV disabled
        Visible = false, -- Start with FOV circle hidden
        Radius = 80,
        Transparency = 0.3,
        Color = Color3.fromRGB(255, 255, 255),
        OutlineColor = Color3.fromRGB(0, 0, 0), -- For blatant mode
        LockedColor = Color3.fromRGB(255, 150, 150), -- For blatant mode
        Thickness = 1,
        NumSides = 60,
        Filled = false
    },
    
    -- Legitimate Aimbot Settings
    Legit = {
        Smoothness = 0.5,
        AimStrength = 0.6,
        AimAssistRadius = 80,
        ShakeReduction = 0.3,
        LockOnTarget = true,
        StrongLock = true,
        StrongLockStrength = 0.9
    },
    
    -- Blatant Aimbot Settings
    Blatant = {
        Toggle = false, -- Hold vs toggle mode
        LockMode = 1, -- 1 = CFrame, 2 = Mousemoverel
        SnapSpeed = 1,
        HighlightTarget = true,
        ESPSettings = {
            FillColor = Color3.fromRGB(255, 0, 4),
            OutlineColor = Color3.fromRGB(255, 255, 255),
            FillTransparency = 0.5,
            OutlineTransparency = 0
        }
    }
}

-- Initialize Drawing objects
setrenderproperty(aimbot.FOVCircle, "Visible", false)
setrenderproperty(aimbot.FOVCircle, "Radius", aimbot.FOVSettings.Radius)
setrenderproperty(aimbot.FOVCircle, "Color", aimbot.FOVSettings.Color)
setrenderproperty(aimbot.FOVCircle, "Thickness", aimbot.FOVSettings.Thickness)
setrenderproperty(aimbot.FOVCircle, "Filled", aimbot.FOVSettings.Filled)
setrenderproperty(aimbot.FOVCircle, "Transparency", aimbot.FOVSettings.Transparency)
setrenderproperty(aimbot.FOVCircle, "NumSides", aimbot.FOVSettings.NumSides)

setrenderproperty(aimbot.FOVCircleOutline, "Visible", false)
setrenderproperty(aimbot.FOVCircleOutline, "Radius", aimbot.FOVSettings.Radius)
setrenderproperty(aimbot.FOVCircleOutline, "Color", aimbot.FOVSettings.OutlineColor)
setrenderproperty(aimbot.FOVCircleOutline, "Thickness", aimbot.FOVSettings.Thickness + 1)
setrenderproperty(aimbot.FOVCircleOutline, "Filled", false)
setrenderproperty(aimbot.FOVCircleOutline, "NumSides", aimbot.FOVSettings.NumSides)
setrenderproperty(aimbot.FOVCircleOutline, "Transparency", aimbot.FOVSettings.Transparency)

setrenderproperty(aimbot.TracerLine, "Visible", false)
setrenderproperty(aimbot.TracerLine, "Thickness", 2)
setrenderproperty(aimbot.TracerLine, "Color", Color3.fromRGB(255, 0, 0))
setrenderproperty(aimbot.TracerLine, "Transparency", 1)

-- Core targeting helpers (shared)
local function IsTeammate(Player)
    if not aimbot.Settings.TeamCheck then return false end
    return Player.Team == LocalPlayer.Team
end

local function IsAlive(Character)
    if not aimbot.Settings.AliveCheck then return true end
    local Humanoid = Character:FindFirstChildOfClass("Humanoid")
    return Humanoid and Humanoid.Health > 0
end

local function IsVisible(Part)
    if not aimbot.Settings.WallCheck then return true end
    
    local RayOrigin = Camera.CFrame.Position
    local RayDirection = (Part.Position - RayOrigin).Unit * 500
    
    local RayParams = RaycastParams.new()
    RayParams.FilterDescendantsInstances = {LocalPlayer.Character}
    RayParams.FilterType = Enum.RaycastFilterType.Blacklist
    
    local Result = workspace:Raycast(RayOrigin, RayDirection, RayParams)
    return not Result or Result.Instance:IsDescendantOf(Part.Parent)
end

-- Highlight management (used in blatant mode)
local function ApplyHighlight(character)
    -- Remove any existing highlight first
    if aimbot.CurrentHighlight and aimbot.CurrentHighlight.Parent then
        aimbot.CurrentHighlight:Destroy()
        aimbot.CurrentHighlight = nil
    end
    
    if character and aimbot.Blatant.HighlightTarget then
        -- Create a new Highlight instance and set properties
        local highlight = Instance.new("Highlight")
        highlight.Archivable = true
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop -- Ensures highlight is always visible
        highlight.Enabled = true
        highlight.FillColor = aimbot.Blatant.ESPSettings.FillColor
        highlight.OutlineColor = aimbot.Blatant.ESPSettings.OutlineColor
        highlight.FillTransparency = aimbot.Blatant.ESPSettings.FillTransparency
        highlight.OutlineTransparency = aimbot.Blatant.ESPSettings.OutlineTransparency
        highlight.Parent = character
        
        aimbot.CurrentHighlight = highlight
    end
end

local function RemoveHighlight()
    if aimbot.CurrentHighlight and aimbot.CurrentHighlight.Parent then
        aimbot.CurrentHighlight:Destroy()
    end
    aimbot.CurrentHighlight = nil
end

-- Target acquisition function (shared with mode-specific differences)
local function GetTarget()
    local RequiredDistance = aimbot.FOVSettings.Enabled and aimbot.FOVSettings.Radius or 2000
    local ClosestTarget = nil
    
    -- If in specific target mode and we have a valid target, only check that player
    if aimbot.TargetMode == "Specific" and aimbot.SpecificTarget then
        local Player = aimbot.SpecificTarget
        
        -- Check if player is still in the game
        if Player and Player.Parent and Player ~= LocalPlayer then
            if not IsTeammate(Player) then
                local Character = Player.Character
                if Character then
                    if IsAlive(Character) then
                        local TargetPart = Character:FindFirstChild(aimbot.Settings.LockPart)
                        if TargetPart then
                            if IsVisible(TargetPart) then
                                local WorldDistance = (TargetPart.Position - Camera.CFrame.Position).Magnitude
                                if WorldDistance <= aimbot.Settings.MaxDistance then
                                    local ScreenPosition, OnScreen = Camera:WorldToViewportPoint(TargetPart.Position)
                                    if OnScreen then
                                        return Player
                                    end
                                end
                            end
                        end
                    end
                end
            end
        else
            -- Target is no longer valid, reset specific target
            aimbot.SpecificTarget = nil
        end
        
        return nil
    end
    
    -- Normal targeting logic for "All" mode
    for _, Player in pairs(Players:GetPlayers()) do
        if Player ~= LocalPlayer then
            if not IsTeammate(Player) then
                local Character = Player.Character
                if Character then
                    if IsAlive(Character) then
                        local TargetPart = Character:FindFirstChild(aimbot.Settings.LockPart)
                        if TargetPart then
                            if IsVisible(TargetPart) then
                                local WorldDistance = (TargetPart.Position - Camera.CFrame.Position).Magnitude
                                if WorldDistance <= aimbot.Settings.MaxDistance then
                                    local ScreenPosition, OnScreen = Camera:WorldToViewportPoint(TargetPart.Position)
                                    if OnScreen then
                                        local Vector = ConvertVector(ScreenPosition)
                                        local Distance = (GetMouseLocation() - Vector).Magnitude
                                        
                                        if Distance < RequiredDistance then
                                            RequiredDistance = Distance
                                            ClosestTarget = Player
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    return ClosestTarget
end

-- FOV circle update function
local function UpdateFOVCircle()
    if not aimbot.FOVSettings.Visible or not aimbot.Settings.Enabled then 
        setrenderproperty(aimbot.FOVCircle, "Visible", false)
        setrenderproperty(aimbot.FOVCircleOutline, "Visible", false)
        return 
    end
    
    local mousePosition = GetMouseLocation()
    
    -- Update main FOV circle
    setrenderproperty(aimbot.FOVCircle, "Visible", true)
    setrenderproperty(aimbot.FOVCircle, "Position", mousePosition)
    
    if aimbot.Mode == "Blatant" then
        -- Show outline in blatant mode
        setrenderproperty(aimbot.FOVCircleOutline, "Visible", true)
        setrenderproperty(aimbot.FOVCircleOutline, "Position", mousePosition)
        
        -- Show tracer line if target exists
        if aimbot.Target and aimbot.IsAiming and aimbot.Target.Character then
            local targetPart = aimbot.Target.Character:FindFirstChild(aimbot.Settings.LockPart)
            if targetPart then
                local targetPos = Camera:WorldToViewportPoint(targetPart.Position)
                setrenderproperty(aimbot.TracerLine, "From", mousePosition)
                setrenderproperty(aimbot.TracerLine, "To", Vector2.new(targetPos.X, targetPos.Y))
                setrenderproperty(aimbot.TracerLine, "Visible", true)
                
                -- Change FOV color when locked
                setrenderproperty(aimbot.FOVCircle, "Color", aimbot.FOVSettings.LockedColor)
            end
        else
            setrenderproperty(aimbot.TracerLine, "Visible", false)
            setrenderproperty(aimbot.FOVCircle, "Color", aimbot.FOVSettings.Color)
        end
    else
        -- Legit mode - just color change when locked
        if aimbot.Target and aimbot.IsAiming and aimbot.Target.Character then
            setrenderproperty(aimbot.FOVCircle, "Color", Color3.fromRGB(255, 100, 100))
        else
            setrenderproperty(aimbot.FOVCircle, "Color", aimbot.FOVSettings.Color)
        end
    end
end

-- Legitimate aiming function
local function ApplyLegitAim(TargetPart)
    if not TargetPart or not Camera then return end
    if not TargetPart.Position or typeof(TargetPart.Position) ~= "Vector3" then return end
    
    local success, result = pcall(function()
        local ScreenPosition, OnScreen = Camera:WorldToViewportPoint(TargetPart.Position)
        if not OnScreen then return false end
        
        local MousePosition = GetMouseLocation()
        local TargetPosition = Vector2.new(ScreenPosition.X, ScreenPosition.Y)
        
        -- Calculate distance to determine aim assist strength
        local Distance = (MousePosition - TargetPosition).Magnitude
        
        -- If strong lock is enabled, ignore the distance limitation
        if not aimbot.Legit.StrongLock and Distance > aimbot.Legit.AimAssistRadius then 
            return false 
        end
        
        -- Scale aim strength based on distance (closer = stronger)
        local DistanceScale = 1 - math.min(1, Distance / (aimbot.Legit.AimAssistRadius * 1.5))
        
        -- Use stronger pull when in strong lock mode
        local AimStrength = aimbot.Legit.StrongLock 
            and aimbot.Legit.StrongLockStrength 
            or (aimbot.Legit.AimStrength * DistanceScale)
        
        -- Calculate aim movement with smoothing and some randomness for natural feel
        local DeltaX = (TargetPosition.X - MousePosition.X) * AimStrength
        local DeltaY = (TargetPosition.Y - MousePosition.Y) * AimStrength
        
        -- Add slight randomization to make it look more human (reduce in strong lock mode)
        local Shake = aimbot.Legit.StrongLock 
            and (1 - aimbot.Legit.ShakeReduction) * 0.3 -- Less shake in lock mode
            or (1 - aimbot.Legit.ShakeReduction)
            
        DeltaX = DeltaX * (1 - (math.random() * Shake * 0.1))
        DeltaY = DeltaY * (1 - (math.random() * Shake * 0.1))
        
        -- Apply smoothing (lower value = smoother)
        -- Use less smoothing for stronger lock
        local Smoothness = aimbot.Legit.StrongLock 
            and aimbot.Legit.Smoothness * 0.7 -- Less smoothing (faster) when locked
            or aimbot.Legit.Smoothness
            
        DeltaX = DeltaX * Smoothness
        DeltaY = DeltaY * Smoothness
        
        -- Apply the mouse movement
        mousemoverel(DeltaX, DeltaY)
        return true
    end)
    
    if not success then
        warn("[Aimbot] Error in ApplyLegitAim: " .. tostring(result))
    end
end

-- Blatant aiming function
local function ApplyBlatantAim(TargetPart)
    if not TargetPart then return end
    
    -- Get exact position without prediction
    local TargetPosition = TargetPart.Position
    
    if aimbot.Blatant.LockMode == 2 then
        -- Mousemoverel mode - DIRECT TELEPORT to target head
        local ScreenPosition = Camera:WorldToViewportPoint(TargetPosition)
        local Vector = ConvertVector(ScreenPosition)
        local mousePosition = GetMouseLocation()
        
        -- Calculate the exact difference to move
        local deltaX = (Vector.X - mousePosition.X)
        local deltaY = (Vector.Y - mousePosition.Y)
        
        -- Direct, immediate movement to target
        mousemoverel(deltaX, deltaY)
    else
        -- CFrame mode - direct instant snap
        Camera.CFrame = CFrame.new(Camera.CFrame.Position, TargetPosition)
    end
end

-- Cancel any active locks
local function CancelLock()
    RemoveHighlight()
    aimbot.Target = nil
    aimbot.Legit.StrongLock = false
    
    if aimbot.FOVCircle then
        setrenderproperty(aimbot.FOVCircle, "Color", aimbot.FOVSettings.Color)
    end
    
    if aimbot.TracerLine then
        setrenderproperty(aimbot.TracerLine, "Visible", false)
    end
end

-- Main aimbot update loop
local function SetupAimbotLoop()
    -- Handle input for aiming
    UserInputService.InputBegan:Connect(function(Input)
        if Input.UserInputType == aimbot.Settings.TriggerKey then
            if aimbot.Mode == "Blatant" and aimbot.Blatant.Toggle then
                aimbot.IsAiming = not aimbot.IsAiming
                if not aimbot.IsAiming then
                    CancelLock()
                end
            else
                aimbot.IsAiming = true
            end
        end
    end)
    
    UserInputService.InputEnded:Connect(function(Input)
        if Input.UserInputType == aimbot.Settings.TriggerKey then
            if aimbot.Mode == "Blatant" and aimbot.Blatant.Toggle then
                -- Toggle mode is handled in InputBegan
            else
                aimbot.IsAiming = false
                CancelLock()
            end
        end
    end)
    
    -- Main rendering loop
    RunService:BindToRenderStep("AimbotUpdate", 1, function()
        -- First check if the entire aimbot is disabled
        if not aimbot.Settings.Enabled or not aimbot.Active then
            -- Make sure ALL visual elements are hidden when disabled
            setrenderproperty(aimbot.FOVCircle, "Visible", false)
            setrenderproperty(aimbot.FOVCircleOutline, "Visible", false)
            setrenderproperty(aimbot.TracerLine, "Visible", false)
            
            -- Remove highlight when disabled
            RemoveHighlight()
            
            -- Reset target
            aimbot.Target = nil
            return
        end
        
        -- Check if FOV circle should be visible based on settings
        local shouldShowFOV = aimbot.FOVSettings.Enabled and aimbot.FOVSettings.Visible
        
        -- Always update FOV visibility based on settings
        setrenderproperty(aimbot.FOVCircle, "Visible", shouldShowFOV)
        if aimbot.Mode == "Blatant" then
            setrenderproperty(aimbot.FOVCircleOutline, "Visible", shouldShowFOV)
        else
            setrenderproperty(aimbot.FOVCircleOutline, "Visible", false)
        end
        
        -- Only update FOV position if it's visible
        if shouldShowFOV then
            pcall(UpdateFOVCircle)
        else
            -- Ensure tracer is not visible when FOV is hidden
            setrenderproperty(aimbot.TracerLine, "Visible", false)
        end
        
        -- Only continue with aiming logic if actively aiming
        if aimbot.IsAiming then
            if aimbot.Mode == "Legit" then
                -- LEGIT MODE
                -- Get or update target only if we don't have one or if LockOnTarget is disabled
                if not aimbot.Target or not aimbot.Target.Character or not aimbot.Legit.LockOnTarget then
                    aimbot.Target = GetTarget()
                    -- Enable strong lock when we get a new target
                    if aimbot.Target then
                        aimbot.Legit.StrongLock = aimbot.Legit.LockOnTarget
                    end
                end
                
                -- Apply aim assist if we have a target
                if aimbot.Target and aimbot.Target.Character then
                    local TargetPart = aimbot.Target.Character:FindFirstChild(aimbot.Settings.LockPart)
                    if TargetPart then
                        ApplyLegitAim(TargetPart)
                    end
                end
            else
                -- BLATANT MODE
                -- Get a target if we don't have one
                if not aimbot.Target then
                    aimbot.Target = GetTarget()
                end
                
                -- If target exists, update highlight and aim
                if aimbot.Target and aimbot.Target.Character then
                    -- Check if target still exists and has the LockPart
                    if not aimbot.Target.Character:FindFirstChild(aimbot.Settings.LockPart) then
                        aimbot.Target = nil
                        aimbot.Target = GetTarget() -- Try to get a new target
                        if not aimbot.Target then
                            CancelLock()
                            return
                        end
                    end
                    
                    -- Apply highlight to target only if highlighting is enabled
                    if aimbot.Blatant.HighlightTarget then
                        ApplyHighlight(aimbot.Target.Character)
                    else
                        RemoveHighlight()
                    end
                    
                    -- Update locked target
                    local TargetPart = aimbot.Target.Character:FindFirstChild(aimbot.Settings.LockPart)
                    if not TargetPart then return end
                    
                    -- Apply the blatant aim
                    ApplyBlatantAim(TargetPart)
                end
                
                -- Only show tracer if FOV is visible 
                if not shouldShowFOV then
                    setrenderproperty(aimbot.TracerLine, "Visible", false)
                end
            end
        else
            -- Not aiming
            CancelLock()
        end
    end)
end

-- Mercury GUI Setup
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/deeeity/mercury-lib/master/src.lua"))()

local gui = Library:create{
    Theme = Library.Themes.Serika
}

gui:set_status("Aimbot Ready")

local aimbotTab = gui:tab{
    Icon = "rbxassetid://6034996695",
    Name = "Aimbot"
}

-- Core settings section
local coreSection = aimbotTab:section{
    Name = "Core Settings",
    Side = "left" 
}

-- Aimbot Mode Selection
coreSection:toggle{
    Name = "Enable Aimbot",
    Description = "Turn the aimbot on/off",
    Default = false, -- Start disabled
    Callback = function(value)
        aimbot.Settings.Enabled = value
        aimbot.Active = value
        
        -- Force cancel lock when disabled
        if not value then
            CancelLock()
            -- Ensure FOV elements are hidden
            setrenderproperty(aimbot.FOVCircle, "Visible", false)
            setrenderproperty(aimbot.FOVCircleOutline, "Visible", false)
            setrenderproperty(aimbot.TracerLine, "Visible", false)
        else
            -- Update visibility based on settings when enabled
            local shouldShowFOV = aimbot.FOVSettings.Enabled and aimbot.FOVSettings.Visible
            setrenderproperty(aimbot.FOVCircle, "Visible", shouldShowFOV)
            if aimbot.Mode == "Blatant" then
                setrenderproperty(aimbot.FOVCircleOutline, "Visible", shouldShowFOV)
            end
            
            -- Load the aimbot if it's not already loaded
            if not aimbot.Loaded then
                aimbot.Loaded = true
                SetupAimbotLoop()
            end
        end
        
        gui:set_status(value and "Aimbot: Active" or "Aimbot: Inactive")
    end
}

coreSection:dropdown{
    Name = "Aimbot Mode",
    Description = "Choose between Legit and Blatant aimbot",
    Default = "Legit",
    Items = {"Legit", "Blatant"},
    Callback = function(value)
        aimbot.Mode = value
        CancelLock() -- Reset when switching modes
        
        -- Update GUI status and FOV settings based on mode
        if value == "Blatant" then
            gui:set_status("Mode: Blatant")
            setrenderproperty(aimbot.FOVCircleOutline, "Visible", aimbot.Settings.Enabled and aimbot.FOVSettings.Visible)
        else
            gui:set_status("Mode: Legit")
            setrenderproperty(aimbot.FOVCircleOutline, "Visible", false)
            setrenderproperty(aimbot.TracerLine, "Visible", false)
        end
    end
}

-- Shared settings for both modes
coreSection:toggle{
    Name = "Team Check",
    Description = "Don't target teammates",
    Default = false,
    Callback = function(value)
        aimbot.Settings.TeamCheck = value
    end
}

coreSection:toggle{
    Name = "Alive Check",
    Description = "Only target alive players",
    Default = true,
    Callback = function(value)
        aimbot.Settings.AliveCheck = value
    end
}

coreSection:toggle{
    Name = "Wall Check",
    Description = "Don't target players behind walls",
    Default = false,
    Callback = function(value)
        aimbot.Settings.WallCheck = value
    end
}

coreSection:dropdown{
    Name = "Target Part",
    Description = "Body part to target",
    Default = "Head",
    Items = {"Head", "UpperTorso", "LowerTorso", "HumanoidRootPart"},
    Callback = function(value)
        aimbot.Settings.LockPart = value
    end
}

coreSection:slider{
    Name = "Max Distance",
    Description = "Maximum distance to target players",
    Default = 1000,
    Min = 100,
    Max = 10000,
    Callback = function(value)
        aimbot.Settings.MaxDistance = value
    end
}

-- FOV Settings (shared but with some mode-specific differences)
local fovSection = aimbotTab:section{
    Name = "FOV Settings",
    Side = "right"
}

fovSection:toggle{
    Name = "FOV Enabled",
    Description = "Enable FOV targeting",
    Default = false, -- Start disabled
    Callback = function(value)
        aimbot.FOVSettings.Enabled = value
        
        -- Update visibility immediately
        if not aimbot.Settings.Enabled or not aimbot.Active then
            setrenderproperty(aimbot.FOVCircle, "Visible", false)
            setrenderproperty(aimbot.FOVCircleOutline, "Visible", false)
        else
            -- Only show FOV if both Enabled and Visible are true
            local shouldShowFOV = value and aimbot.FOVSettings.Visible
            setrenderproperty(aimbot.FOVCircle, "Visible", shouldShowFOV)
            if aimbot.Mode == "Blatant" then
                setrenderproperty(aimbot.FOVCircleOutline, "Visible", shouldShowFOV)
            else
                setrenderproperty(aimbot.FOVCircleOutline, "Visible", false)
            end
        end
    end
}

fovSection:toggle{
    Name = "FOV Visible",
    Description = "Show FOV circle",
    Default = false, -- Start hidden
    Callback = function(value)
        aimbot.FOVSettings.Visible = value
        
        -- Always ensure visibility matches setting
        if not aimbot.Settings.Enabled or not aimbot.Active or not aimbot.FOVSettings.Enabled then
            setrenderproperty(aimbot.FOVCircle, "Visible", false)
            setrenderproperty(aimbot.FOVCircleOutline, "Visible", false)
        else
            setrenderproperty(aimbot.FOVCircle, "Visible", value)
            if aimbot.Mode == "Blatant" then
                setrenderproperty(aimbot.FOVCircleOutline, "Visible", value)
            else
                setrenderproperty(aimbot.FOVCircleOutline, "Visible", false)
            end
        end
    end
}

fovSection:slider{
    Name = "FOV Radius",
    Description = "Size of targeting area",
    Default = 80,
    Min = 20,
    Max = 500,
    Callback = function(value)
        aimbot.FOVSettings.Radius = value
        setrenderproperty(aimbot.FOVCircle, "Radius", value)
        setrenderproperty(aimbot.FOVCircleOutline, "Radius", value)
    end
}

fovSection:slider{
    Name = "FOV Transparency",
    Description = "Circle transparency",
    Default = 0.3,
    Min = 0.1,
    Max = 1,
    Float = 0.1, -- Use Float for Mercury decimal sliders
    Format = "%0.1f", -- Format to show one decimal place
    Callback = function(value)
        aimbot.FOVSettings.Transparency = value
        setrenderproperty(aimbot.FOVCircle, "Transparency", value)
        setrenderproperty(aimbot.FOVCircleOutline, "Transparency", value)
    end
}

fovSection:color_picker{
    Name = "FOV Color",
    Description = "FOV circle color",
    Default = Color3.fromRGB(255, 255, 255),
    Callback = function(color)
        aimbot.FOVSettings.Color = color
        setrenderproperty(aimbot.FOVCircle, "Color", color)
    end
}

-- Legitimate Aimbot Settings
local legitSection = aimbotTab:section{
    Name = "Legit Aimbot Settings",
    Side = "left"
}

legitSection:toggle{
    Name = "Lock On Target",
    Description = "Stay locked on the same target",
    Default = true,
    Callback = function(value)
        aimbot.Legit.LockOnTarget = value
    end
}

legitSection:slider{
    Name = "Smoothness",
    Description = "Lower = faster response",
    Default = 0.5,
    Min = 0.1,
    Max = 1,
    Float = 0.1, -- Use Float for Mercury decimal sliders
    Format = "%0.1f", -- Format to show one decimal place
    Callback = function(value)
        aimbot.Legit.Smoothness = value
    end
}

legitSection:slider{
    Name = "Aim Strength",
    Description = "How strongly aim assists pulls",
    Default = 0.6,
    Min = 0.1,
    Max = 1,
    Float = 0.1, -- Use Float for Mercury decimal sliders
    Format = "%0.1f", -- Format to show one decimal place
    Callback = function(value)
        aimbot.Legit.AimStrength = value
    end
}

legitSection:slider{
    Name = "Lock Strength",
    Description = "Strength when locked on target",
    Default = 0.9,
    Min = 0.1,
    Max = 1,
    Float = 0.1, -- Use Float for Mercury decimal sliders
    Format = "%0.1f", -- Format to show one decimal place
    Callback = function(value)
        aimbot.Legit.StrongLockStrength = value
    end
}

legitSection:slider{
    Name = "Natural Feel",
    Description = "Makes aim movement look more human",
    Default = 0.3,
    Min = 0.1,
    Max = 1,
    Float = 0.1, -- Use Float for Mercury decimal sliders
    Format = "%0.1f", -- Format to show one decimal place
    Callback = function(value)
        aimbot.Legit.ShakeReduction = value
    end
}

-- Blatant Aimbot Settings
local blatantSection = aimbotTab:section{
    Name = "Blatant Aimbot Settings",
    Side = "right"
}

blatantSection:toggle{
    Name = "Toggle Mode",
    Description = "Toggle instead of holding",
    Default = false,
    Callback = function(value)
        aimbot.Blatant.Toggle = value
    end
}

blatantSection:dropdown{
    Name = "Lock Mode",
    Description = "Method to control aim",
    Default = "CFrame",
    Items = {"CFrame", "Mousemoverel"},
    Callback = function(value)
        aimbot.Blatant.LockMode = value == "CFrame" and 1 or 2
    end
}

blatantSection:toggle{
    Name = "Highlight Target",
    Description = "Show visual highlight on target",
    Default = true,
    Callback = function(value)
        aimbot.Blatant.HighlightTarget = value
        if not value then
            RemoveHighlight()
        end
    end
}

-- ESP Settings for blatant mode
local espSection = aimbotTab:section{
    Name = "ESP Settings",
    Side = "right"
}

espSection:color_picker{
    Name = "Highlight Fill Color",
    Description = "Target highlight fill color",
    Default = Color3.fromRGB(255, 0, 4),
    Callback = function(color)
        aimbot.Blatant.ESPSettings.FillColor = color
        if aimbot.CurrentHighlight then
            aimbot.CurrentHighlight.FillColor = color
        end
    end
}

espSection:color_picker{
    Name = "Highlight Outline Color",
    Description = "Target highlight outline color",
    Default = Color3.fromRGB(255, 255, 255),
    Callback = function(color)
        aimbot.Blatant.ESPSettings.OutlineColor = color
        if aimbot.CurrentHighlight then
            aimbot.CurrentHighlight.OutlineColor = color
        end
    end
}

espSection:slider{
    Name = "Fill Transparency",
    Description = "Highlight fill transparency",
    Default = 0.5,
    Min = 0.1,
    Max = 1,
    Float = 0.1, -- Use Float for Mercury decimal sliders
    Format = "%0.1f", -- Format to show one decimal place
    Callback = function(value)
        aimbot.Blatant.ESPSettings.FillTransparency = value
        if aimbot.CurrentHighlight then
            aimbot.CurrentHighlight.FillTransparency = value
        end
    end
}

espSection:slider{
    Name = "Outline Transparency",
    Description = "Highlight outline transparency",
    Default = 0.1,
    Min = 0.1,
    Max = 1,
    Float = 0.1, -- Use Float for Mercury decimal sliders
    Format = "%0.1f", -- Format to show one decimal place
    Callback = function(value)
        aimbot.Blatant.ESPSettings.OutlineTransparency = value
        if aimbot.CurrentHighlight then
            aimbot.CurrentHighlight.OutlineTransparency = value
        end
    end
}

-- Add player target selection section
local targetSection = aimbotTab:section{
    Name = "Target Selection",
    Side = "left"
}

targetSection:dropdown{
    Name = "Target Mode",
    Description = "Choose to target all players or just one specific player",
    Default = "All",
    Items = {"All", "Specific"},
    Callback = function(value)
        aimbot.TargetMode = value
        if value == "All" then
            aimbot.SpecificTarget = nil
            gui:set_status("Targeting: All Players")
        else
            gui:set_status("Select a specific target from the list")
        end
    end
}

-- Function to refresh the player list
local function UpdatePlayerList()
    local playerList = {}
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(playerList, player.Name)
        end
    end
    
    return playerList
end

-- Add player selection dropdown
local playerDropdown
playerDropdown = targetSection:dropdown{
    Name = "Select Player",
    Description = "Choose a specific player to target",
    Default = "Select...",
    Items = UpdatePlayerList(),
    Callback = function(value)
        -- Find the player object with this name
        for _, player in pairs(Players:GetPlayers()) do
            if player.Name == value then
                aimbot.SpecificTarget = player
                gui:set_status("Targeting: " .. player.Name)
                break
            end
        end
    end
}

-- Add refresh button to update player list
targetSection:button{
    Name = "Refresh Player List",
    Description = "Update the list of available players",
    Callback = function()
        -- Update the player dropdown with current players
        playerDropdown:set_values(UpdatePlayerList())
        gui:set_status("Player list refreshed")
    end
}

-- Update player list when players join or leave
Players.PlayerAdded:Connect(function()
    if playerDropdown then
        playerDropdown:set_values(UpdatePlayerList())
    end
end)

Players.PlayerRemoving:Connect(function(player)
    if playerDropdown then
        playerDropdown:set_values(UpdatePlayerList())
    end
    
    -- Reset target if the removed player was our target
    if aimbot.SpecificTarget == player then
        aimbot.SpecificTarget = nil
        gui:set_status("Target left the game!")
    end
end)

-- Initialize aimbot - start with everything OFF
aimbot.Active = false
aimbot.Loaded = true

-- Make sure all visual elements are hidden on initialization
setrenderproperty(aimbot.FOVCircle, "Visible", false)
setrenderproperty(aimbot.FOVCircleOutline, "Visible", false)
setrenderproperty(aimbot.TracerLine, "Visible", false)

SetupAimbotLoop()

-- Set globals
getgenv().CombinedAimbot = aimbot
getgenv().AimbotGUI = gui

-- Replace the ESP tab section with the optimized full implementation

-- Update the existing ESP tab with optimized controls
local espTab = gui:tab{
    Icon = "rbxassetid://7743878358",
    Name = "ESP"
}

-- Create main ESP section
local espMainSection = espTab:section{
    Name = "ESP Controls",
    Side = "left"
}

-- Create appearance section
local espAppearanceSection = espTab:section{
    Name = "Appearance",
    Side = "right"
}

-- Optimize ESP implementation
local ESP = {
    Enabled = false,
    Players = {},
    TracerColor = Color3.fromRGB(255, 0, 0),
    HealthBarColor = Color3.fromRGB(0, 255, 0),
    TracerThickness = 1,
    ShowTracers = false,
    ShowNames = false,
    ShowHealthBars = false,
    TracerOrigin = "Bottom", -- "Bottom", "Middle", "Mouse"
    Box2D = {
        Enabled = false,
        Box_Color = Color3.fromRGB(255, 0, 0),
        Box_Thickness = 2,
        Team_Check = false,
        Team_Color = false,
        Autothickness = true,
        BoxObjects = {}
    },
    AutoScale = true,
    MinTextSize = 2,
    MaxTextSize = 30
}

-- Drawing object cache to prevent excessive object creation
local DrawingCache = {
    Quads = {},
    Lines = {}
}

-- Create Drawing objects more efficiently
local function CreateDrawing(type, properties)
    -- Use cached objects or create new ones
    local cache = type == "Quad" and DrawingCache.Quads or DrawingCache.Lines
    local drawing
    
    -- Try to reuse a cached drawing first
    if #cache > 0 then
        drawing = table.remove(cache)
    else
        -- Create new if none available in cache
        drawing = Drawing.new(type)
    end
    
    -- Set properties
    for prop, value in pairs(properties) do
        pcall(function() drawing[prop] = value end)
    end
    
    return drawing
end

-- Return objects to cache instead of destroying them
local function RecycleDrawing(drawing, type)
    if drawing then
        -- Reset visibility
        pcall(function() drawing.Visible = false end)
        
        -- Add to appropriate cache
        if type == "Quad" then
            table.insert(DrawingCache.Quads, drawing)
        else
            table.insert(DrawingCache.Lines, drawing)
        end
    end
end

-- Create ESP elements for a player
local function CreatePlayerESP(player)
    if player == LocalPlayer then return nil end
    
    local espData = {
        Player = player,
        Tracer = CreateDrawing("Line", {
            Visible = false,
            Thickness = ESP.TracerThickness,
            Color = ESP.TracerColor,
            Transparency = 1
        }),
        HealthBar = {
            Border = CreateDrawing("Line", {
                Visible = false,
                Thickness = 3,
                Color = Color3.new(0, 0, 0),
                Transparency = 1
            }),
            Fill = CreateDrawing("Line", {
                Visible = false,
                Thickness = 1.5,
                Color = ESP.HealthBarColor,
                Transparency = 1
            })
        },
        Name = Drawing.new("Text"),
        Distance = 0,
        Updated = tick()
    }
    
    -- Initialize Text properties
    espData.Name.Visible = false
    espData.Name.Text = player.Name
    if ESP.AutoScale then
        espData.Name.Size = ESP.MinTextSize
    else
        espData.Name.Size = 13
    end
    espData.Name.Center = true
    espData.Name.Outline = true
    espData.Name.OutlineColor = Color3.new(0, 0, 0)
    espData.Name.Color = Color3.new(1, 1, 1)
    espData.Name.Transparency = 1
    
    ESP.Players[player.Name] = espData
    return espData
end

-- Clean up ESP data for a player
local function RemovePlayerESP(playerName)
    local espData = ESP.Players[playerName]
    if not espData then return end
    
    -- Recycle all drawings (remove Box recycling)
    RecycleDrawing(espData.Tracer, "Line")
    RecycleDrawing(espData.HealthBar.Border, "Line")
    RecycleDrawing(espData.HealthBar.Fill, "Line")
    
    -- Text needs to be destroyed, can't be recycled
    if espData.Name then
        pcall(function() espData.Name:Remove() end)
    end
    
    ESP.Players[playerName] = nil
end

-- Remove all ESP elements
local function ClearAllESP()
    for _, espData in pairs(ESP.Players) do
        pcall(function() espData.Tracer.Visible = false end)
        pcall(function() espData.HealthBar.Border.Visible = false end)
        pcall(function() espData.HealthBar.Fill.Visible = false end)
        pcall(function() espData.Name.Visible = false end)
    end
end

-- Update ESP elements for all players
local function UpdateESP()
    -- If ESP is disabled, force hide everything
    if not ESP.Enabled then
        for _, espData in pairs(ESP.Players) do
            pcall(function() espData.Tracer.Visible = false end)
            pcall(function() espData.HealthBar.Border.Visible = false end)
            pcall(function() espData.HealthBar.Fill.Visible = false end)
            pcall(function() espData.Name.Visible = false end)
        end
        return -- Exit early
    end
    
    -- Process each player only if ESP is explicitly enabled
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            -- Check if player has ESP data
            local espData = ESP.Players[player.Name]
            
            -- Create ESP objects if needed
            if not espData then
                espData = CreatePlayerESP(player)
            end
            
            -- Ensure we have valid ESP data
            if espData then
                local character = player.Character
                
                -- Hide ESP objects immediately if player has no valid character
                if not character or 
                   not character:FindFirstChild("Humanoid") or 
                   not character:FindFirstChild("HumanoidRootPart") or 
                   not character:FindFirstChild("Head") or
                   character.Humanoid.Health <= 0 then
                   
                    pcall(function() espData.Tracer.Visible = false end)
                    pcall(function() espData.HealthBar.Border.Visible = false end)
                    pcall(function() espData.HealthBar.Fill.Visible = false end)
                    pcall(function() espData.Name.Visible = false end)
                else
                    -- Character exists, update ESP elements
                    local rootPart = character.HumanoidRootPart
                    local rootPos, onScreen = Camera:WorldToViewportPoint(rootPart.Position)
                    
                    -- Hide ESP objects if player is not on screen
                    if not onScreen then
                        pcall(function() espData.Tracer.Visible = false end)
                        pcall(function() espData.HealthBar.Border.Visible = false end)
                        pcall(function() espData.HealthBar.Fill.Visible = false end)
                        pcall(function() espData.Name.Visible = false end)
                    else
                        -- Calculate dimensions for positioning (still needed for other ESP elements)
                        local headPos = Camera:WorldToViewportPoint(character.Head.Position)
                        local legPos = Camera:WorldToViewportPoint(rootPart.Position - Vector3.new(0, 3, 0))
                        local height = math.abs(headPos.Y - legPos.Y)
                        local width = height * 0.6
                        
                        -- Update tracer visibility and position
                        if ESP.ShowTracers then
                            pcall(function()
                                local tracer = espData.Tracer
                                if ESP.TracerOrigin == "Bottom" then
                                    tracer.From = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y)
                                elseif ESP.TracerOrigin == "Middle" then
                                    tracer.From = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
                                elseif ESP.TracerOrigin == "Mouse" then
                                    local mousePos = UserInputService:GetMouseLocation()
                                    tracer.From = Vector2.new(mousePos.X, mousePos.Y)
                                end
                                tracer.To = Vector2.new(rootPos.X, rootPos.Y)
                                tracer.Color = ESP.TracerColor
                                tracer.Thickness = ESP.TracerThickness
                                tracer.Visible = true -- Only show if ShowTracers is true
                            end)
                        else
                            -- Explicitly hide tracer if ShowTracers is false
                            pcall(function() espData.Tracer.Visible = false end)
                        end
                        
                        -- Update health bar visibility and position
                        if ESP.ShowHealthBars then
                            pcall(function()
                                local health = character.Humanoid.Health
                                local maxHealth = character.Humanoid.MaxHealth
                                local healthPerc = math.clamp(health/maxHealth, 0, 1)
                                
                                local barPos = Vector2.new(rootPos.X - width/2 - 5, rootPos.Y)
                                local barHeight = height
                                
                                local border = espData.HealthBar.Border
                                border.From = Vector2.new(barPos.X, barPos.Y - barHeight/2)
                                border.To = Vector2.new(barPos.X, barPos.Y + barHeight/2)
                                border.Visible = true
                                
                                local fill = espData.HealthBar.Fill
                                fill.From = Vector2.new(barPos.X, barPos.Y + barHeight/2)
                                fill.To = Vector2.new(barPos.X, barPos.Y + barHeight/2 - (barHeight * healthPerc))
                                
                                local r = 1 - healthPerc
                                local g = healthPerc
                                fill.Color = Color3.new(r, g, 0)
                                fill.Visible = true
                            end)
                        else
                            -- Explicitly hide health bars if ShowHealthBars is false
                            pcall(function() espData.HealthBar.Border.Visible = false end)
                            pcall(function() espData.HealthBar.Fill.Visible = false end)
                        end
                        
                        -- Update name visibility and position
                        if ESP.ShowNames then
                            pcall(function()
                                local name = espData.Name
                                name.Text = player.Name
                                name.Position = Vector2.new(rootPos.X, rootPos.Y - height/2 - 15)
                                
                                -- Apply auto-scaling if enabled
                                if ESP.AutoScale then
                                    local distance = (Camera.CFrame.Position - rootPart.Position).Magnitude
                                    local textSize = math.clamp(1/distance * 1000, ESP.MinTextSize, ESP.MaxTextSize)
                                    name.Size = textSize
                                else
                                    name.Size = 13 -- Default size
                                end
                                
                                name.Visible = true
                            end)
                        else
                            -- Explicitly hide name if ShowNames is false
                            pcall(function() espData.Name.Visible = false end)
                        end
                    end
                end
                
                -- Update timestamp to track active ESP data
                espData.Updated = tick()
            end
        end
    end
end

-- Initialize ESP connection
local ESPConnection = nil

-- Function to start ESP update loop
local function StartESP()
    if ESPConnection then return end
    
    ESPConnection = RunService.RenderStepped:Connect(UpdateESP)
    print("ESP started")
end

-- Function to stop ESP update loop
local function StopESP()
    if ESPConnection then
        ESPConnection:Disconnect()
        ESPConnection = nil
    end
    
    -- Hide all ESP elements
    for _, espData in pairs(ESP.Players) do
        pcall(function() espData.Tracer.Visible = false end)
        pcall(function() espData.HealthBar.Border.Visible = false end)
        pcall(function() espData.HealthBar.Fill.Visible = false end)
        pcall(function() espData.Name.Visible = false end)
    end
    
    print("ESP stopped")
end

-- Setup player joining/leaving handlers
Players.PlayerAdded:Connect(function(player)
    if player ~= LocalPlayer and ESP.Enabled then
        task.delay(1, function()
            if not ESP.Players[player.Name] then
                CreatePlayerESP(player)
            end
        end)
    end
end)

Players.PlayerRemoving:Connect(function(player)
    RemovePlayerESP(player.Name)
end)

-- Connect UI elements to ESP functionality
espMainSection:toggle{
    Name = "Enable ESP",
    Description = "Toggle ESP features on/off",
    Default = false,
    Callback = function(value)
        -- Update ESP state
        ESP.Enabled = value
        
        -- Update UI status
        gui:set_status(value and "ESP: Enabled" or "ESP: Disabled")
        
        -- Handle starting/stopping ESP
        if value then
            -- Start ESP update loop
            StartESP()
        else
            -- Stop ESP update loop
            StopESP()
            
            -- Force remove all drawings
            task.spawn(function()
                for _, espData in pairs(ESP.Players) do
                    pcall(function() espData.Tracer.Visible = false end)
                    pcall(function() espData.HealthBar.Border.Visible = false end)
                    pcall(function() espData.HealthBar.Fill.Visible = false end)
                    pcall(function() espData.Name.Visible = false end)
                end
            end)
        end
    end
}

espMainSection:toggle{
    Name = "Show Tracers",
    Description = "Draw lines to players",
    Default = false, -- Start disabled 
    Callback = function(value)
        ESP.ShowTracers = value
        
        -- Immediately update visibility of existing tracers
        if not value then
            for _, espData in pairs(ESP.Players) do
                pcall(function() espData.Tracer.Visible = false end)
            end
        end
    end
}

espMainSection:toggle{
    Name = "Show Names",
    Description = "Display player names",
    Default = false, -- Start disabled
    Callback = function(value)
        ESP.ShowNames = value
        
        -- Immediately update visibility of existing name labels
        if not value then
            for _, espData in pairs(ESP.Players) do
                pcall(function() espData.Name.Visible = false end)
            end
        end
    end
}

espMainSection:toggle{
    Name = "Show Health Bars",
    Description = "Show player health bars",
    Default = false, -- Start disabled
    Callback = function(value)
        ESP.ShowHealthBars = value
        
        -- Immediately update visibility of existing health bars
        if not value then
            for _, espData in pairs(ESP.Players) do
                pcall(function() espData.HealthBar.Border.Visible = false end)
                pcall(function() espData.HealthBar.Fill.Visible = false end)
            end
        end
    end
}

espMainSection:dropdown{
    Name = "Tracer Origin",
    Description = "Where tracers start from",
    Default = "Bottom",
    Items = {"Bottom", "Middle", "Mouse"},
    Callback = function(value)
        ESP.TracerOrigin = value
    end
}

-- Add a completely fresh ClearESP function that properly removes all drawings
local function HardClearESP()
    -- Disconnect any running ESP update loop
    if ESPConnection then
        ESPConnection:Disconnect()
        ESPConnection = nil
    end
    
    -- Remove all drawings (remove Box removal)
    for playerName, espData in pairs(ESP.Players) do
        pcall(function()
            if espData.Tracer and espData.Tracer.Remove then espData.Tracer:Remove() end
            if espData.HealthBar.Border and espData.HealthBar.Border.Remove then espData.HealthBar.Border:Remove() end
            if espData.HealthBar.Fill and espData.HealthBar.Fill.Remove then espData.HealthBar.Fill:Remove() end
            if espData.Name and espData.Name.Remove then espData.Name:Remove() end
        end)
    end
    
    -- Clear the ESP Players table
    ESP.Players = {}
    
    -- Reset ESP state (remove ShowBoxes reset)
    ESP.Enabled = false
    ESP.ShowTracers = false
    ESP.ShowNames = false
    ESP.ShowHealthBars = false
    
    -- Update UI
    gui:set_status("ESP: Completely cleared and reset")
    print("ESP has been completely reset and cleared")
end

-- Replace Reset ESP button with a stronger implementation
espMainSection:button{
    Name = "COMPLETELY CLEAR ESP",
    Description = "Destroy and reset all ESP objects",
    Callback = function()
        HardClearESP()
    end
}

-- Immediately clear any existing ESP drawings
task.spawn(function()
    -- Force immediately clear all ESP objects
    for _, espData in pairs(ESP.Players) do
        -- Destroy all drawing objects (remove Box removal)
        pcall(function() 
            if espData.Tracer and espData.Tracer.Remove then espData.Tracer:Remove() end
            if espData.HealthBar.Border and espData.HealthBar.Border.Remove then espData.HealthBar.Border:Remove() end
            if espData.HealthBar.Fill and espData.HealthBar.Fill.Remove then espData.HealthBar.Fill:Remove() end
            if espData.Name and espData.Name.Remove then espData.Name:Remove() end
        end)
    end
    
    -- Clear player table
    ESP.Players = {}
    
    -- Explicitly disable ESP
    ESP.Enabled = false
    StopESP()
end)

-- Completely replace the UpdateESP function
UpdateESP = function()
    -- If ESP is disabled, force hide everything
    if not ESP.Enabled then
        for _, espData in pairs(ESP.Players) do
            pcall(function() espData.Tracer.Visible = false end)
            pcall(function() espData.HealthBar.Border.Visible = false end)
            pcall(function() espData.HealthBar.Fill.Visible = false end)
            pcall(function() espData.Name.Visible = false end)
        end
        return -- Exit early
    end
    
    -- Process each player only if ESP is explicitly enabled
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            -- Check if player has ESP data
            local espData = ESP.Players[player.Name]
            
            -- Create ESP objects if needed
            if not espData then
                espData = CreatePlayerESP(player)
            end
            
            -- Ensure we have valid ESP data
            if espData then
                local character = player.Character
                
                -- Hide ESP objects immediately if player has no valid character
                if not character or 
                   not character:FindFirstChild("Humanoid") or 
                   not character:FindFirstChild("HumanoidRootPart") or 
                   not character:FindFirstChild("Head") or
                   character.Humanoid.Health <= 0 then
                   
                    pcall(function() espData.Tracer.Visible = false end)
                    pcall(function() espData.HealthBar.Border.Visible = false end)
                    pcall(function() espData.HealthBar.Fill.Visible = false end)
                    pcall(function() espData.Name.Visible = false end)
                else
                    -- Character exists, update ESP elements
                    local rootPart = character.HumanoidRootPart
                    local rootPos, onScreen = Camera:WorldToViewportPoint(rootPart.Position)
                    
                    -- Hide ESP objects if player is not on screen
                    if not onScreen then
                        pcall(function() espData.Tracer.Visible = false end)
                        pcall(function() espData.HealthBar.Border.Visible = false end)
                        pcall(function() espData.HealthBar.Fill.Visible = false end)
                        pcall(function() espData.Name.Visible = false end)
                    else
                        -- Calculate dimensions for positioning (still needed for other ESP elements)
                        local headPos = Camera:WorldToViewportPoint(character.Head.Position)
                        local legPos = Camera:WorldToViewportPoint(rootPart.Position - Vector3.new(0, 3, 0))
                        local height = math.abs(headPos.Y - legPos.Y)
                        local width = height * 0.6
                        
                        -- Update tracer visibility and position
                        if ESP.ShowTracers then
                            pcall(function()
                                local tracer = espData.Tracer
                                if ESP.TracerOrigin == "Bottom" then
                                    tracer.From = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y)
                                elseif ESP.TracerOrigin == "Middle" then
                                    tracer.From = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
                                elseif ESP.TracerOrigin == "Mouse" then
                                    local mousePos = UserInputService:GetMouseLocation()
                                    tracer.From = Vector2.new(mousePos.X, mousePos.Y)
                                end
                                tracer.To = Vector2.new(rootPos.X, rootPos.Y)
                                tracer.Color = ESP.TracerColor
                                tracer.Thickness = ESP.TracerThickness
                                tracer.Visible = true -- Only show if ShowTracers is true
                            end)
                        else
                            -- Explicitly hide tracer if ShowTracers is false
                            pcall(function() espData.Tracer.Visible = false end)
                        end
                        
                        -- Update health bar visibility and position
                        if ESP.ShowHealthBars then
                            pcall(function()
                                local health = character.Humanoid.Health
                                local maxHealth = character.Humanoid.MaxHealth
                                local healthPerc = math.clamp(health/maxHealth, 0, 1)
                                
                                local barPos = Vector2.new(rootPos.X - width/2 - 5, rootPos.Y)
                                local barHeight = height
                                
                                local border = espData.HealthBar.Border
                                border.From = Vector2.new(barPos.X, barPos.Y - barHeight/2)
                                border.To = Vector2.new(barPos.X, barPos.Y + barHeight/2)
                                border.Visible = true
                                
                                local fill = espData.HealthBar.Fill
                                fill.From = Vector2.new(barPos.X, barPos.Y + barHeight/2)
                                fill.To = Vector2.new(barPos.X, barPos.Y + barHeight/2 - (barHeight * healthPerc))
                                
                                local r = 1 - healthPerc
                                local g = healthPerc
                                fill.Color = Color3.new(r, g, 0)
                                fill.Visible = true
                            end)
                        else
                            -- Explicitly hide health bars if ShowHealthBars is false
                            pcall(function() espData.HealthBar.Border.Visible = false end)
                            pcall(function() espData.HealthBar.Fill.Visible = false end)
                        end
                        
                        -- Update name visibility and position
                        if ESP.ShowNames then
                            pcall(function()
                                local name = espData.Name
                                name.Text = player.Name
                                name.Position = Vector2.new(rootPos.X, rootPos.Y - height/2 - 15)
                                
                                -- Apply auto-scaling if enabled
                                if ESP.AutoScale then
                                    local distance = (Camera.CFrame.Position - rootPart.Position).Magnitude
                                    local textSize = math.clamp(1/distance * 1000, ESP.MinTextSize, ESP.MaxTextSize)
                                    name.Size = textSize
                                else
                                    name.Size = 13 -- Default size
                                end
                                
                                name.Visible = true
                            end)
                        else
                            -- Explicitly hide name if ShowNames is false
                            pcall(function() espData.Name.Visible = false end)
                        end
                    end
                end
                
                -- Update timestamp to track active ESP data
                espData.Updated = tick()
            end
        end
    end
end

-- Add 2D Box ESP to the ESP section
-- Add the 2D Box settings to the ESP object
ESP.Box2D = {
    Enabled = false,
    Box_Color = Color3.fromRGB(255, 0, 0),
    Box_Thickness = 2,
    Team_Check = false,
    Team_Color = false,
    Autothickness = true,
    BoxObjects = {}
}

-- Add the 2D Box toggle to the ESP Controls section
espMainSection:toggle{
    Name = "Show 2D Boxes",
    Description = "Draw 2D corner boxes around players",
    Default = false,
    Callback = function(value)
        ESP.Box2D.Enabled = value
        
        if not value then
            -- Hide all 2D boxes when disabled
            for playerName, boxData in pairs(ESP.Box2D.BoxObjects) do
                if boxData and boxData.Library then
                    for _, line in pairs(boxData.Library) do
                        pcall(function() line.Visible = false end)
                    end
                end
            end
        end
    end
}

-- Add 2D Box settings section
local boxSettingsSection = espTab:section{
    Name = "2D Box Settings",
    Side = "right"
}

boxSettingsSection:toggle{
    Name = "Team Check",
    Description = "Use different colors for teammates",
    Default = false,
    Callback = function(value)
        ESP.Box2D.Team_Check = value
    end
}

boxSettingsSection:toggle{
    Name = "Team Colors",
    Description = "Use team colors for boxes",
    Default = false,
    Callback = function(value)
        ESP.Box2D.Team_Color = value
    end
}

boxSettingsSection:toggle{
    Name = "Auto Scale",
    Description = "Automatically scale ESP elements based on distance",
    Default = true,
    Callback = function(value)
        ESP.Box2D.Autothickness = value
    end
}

boxSettingsSection:slider{
    Name = "Box Thickness",
    Description = "Thickness of 2D box lines",
    Default = 2,
    Min = 1,
    Max = 5,
    Callback = function(value)
        ESP.Box2D.Box_Thickness = value
    end
}

boxSettingsSection:color_picker{
    Name = "Box Color",
    Description = "Color of 2D boxes",
    Default = Color3.fromRGB(255, 0, 0),
    Callback = function(color)
        ESP.Box2D.Box_Color = color
    end
}

boxSettingsSection:slider{
    Name = "Min Text Size",
    Description = "Minimum size for text when far away",
    Default = 2,
    Min = 1,
    Max = 15,
    Callback = function(value)
        ESP.MinTextSize = value
    end
}

boxSettingsSection:slider{
    Name = "Max Text Size",
    Description = "Maximum size for text when close",
    Default = 30,
    Min = 10,
    Max = 50,
    Callback = function(value)
        ESP.MaxTextSize = value
    end
}

-- Helper functions for 2D Box ESP
local function NewLine(color, thickness)
    local line = Drawing.new("Line")
    line.Visible = false
    line.From = Vector2.new(0, 0)
    line.To = Vector2.new(1, 1)
    line.Color = color
    line.Thickness = thickness
    line.Transparency = 1
    return line
end

local function Vis(lib, state)
    for _, v in pairs(lib) do
        pcall(function() v.Visible = state end)
    end
end

local function Colorize(lib, color)
    for _, v in pairs(lib) do
        pcall(function() v.Color = color end)
    end
end

-- Create origin part for 2D box calculations
local oripart = Instance.new("Part")
oripart.Parent = workspace
oripart.Transparency = 1
oripart.CanCollide = false
oripart.Size = Vector3.new(1, 1, 1)
oripart.Position = Vector3.new(0, 0, 0)

-- 2D Box creation function
local function Setup2DBox(player)
    if player == LocalPlayer then return end
    
    -- Create the box library for this player
    local boxLibrary = {
        TL1 = NewLine(ESP.Box2D.Box_Color, ESP.Box2D.Box_Thickness),
        TL2 = NewLine(ESP.Box2D.Box_Color, ESP.Box2D.Box_Thickness),
        TR1 = NewLine(ESP.Box2D.Box_Color, ESP.Box2D.Box_Thickness),
        TR2 = NewLine(ESP.Box2D.Box_Color, ESP.Box2D.Box_Thickness),
        BL1 = NewLine(ESP.Box2D.Box_Color, ESP.Box2D.Box_Thickness),
        BL2 = NewLine(ESP.Box2D.Box_Color, ESP.Box2D.Box_Thickness),
        BR1 = NewLine(ESP.Box2D.Box_Color, ESP.Box2D.Box_Thickness),
        BR2 = NewLine(ESP.Box2D.Box_Color, ESP.Box2D.Box_Thickness)
    }
    
    -- Store the box data
    ESP.Box2D.BoxObjects[player.Name] = {
        Player = player,
        Library = boxLibrary,
        Connection = nil,
        Active = false
    }
    
    return ESP.Box2D.BoxObjects[player.Name]
end

-- Update function for 2D Box ESP
local function Update2DBox(boxData)
    if not boxData or not boxData.Player or not boxData.Library then return end
    
    -- If already has an active connection, return
    if boxData.Active then return end
    
    local player = boxData.Player
    local library = boxData.Library
    
    -- Set as active
    boxData.Active = true
    
    -- Create render connection
    local connection
    connection = RunService.RenderStepped:Connect(function()
        -- Check if player is valid
        if not player or not player.Parent or not ESP.Box2D.Enabled then
            Vis(library, false)
            return
        end
        
        -- Check if character exists and is valid
        local character = player.Character
        if not character or 
           not character:FindFirstChild("Humanoid") or 
           not character:FindFirstChild("HumanoidRootPart") or 
           not character:FindFirstChild("Head") or
           character.Humanoid.Health <= 0 then
            Vis(library, false)
            return
        end
        
        -- Check if on screen
        local rootPart = character.HumanoidRootPart
        local rootPos, onScreen = Camera:WorldToViewportPoint(rootPart.Position)
        
        if not onScreen then
            Vis(library, false)
            return
        end
        
        -- Calculate box dimensions
        oripart.Size = Vector3.new(rootPart.Size.X, rootPart.Size.Y * 1.5, rootPart.Size.Z)
        oripart.CFrame = CFrame.new(rootPart.CFrame.Position, Camera.CFrame.Position)
        
        local sizeX = oripart.Size.X
        local sizeY = oripart.Size.Y
        
        local TL = Camera:WorldToViewportPoint((oripart.CFrame * CFrame.new(sizeX, sizeY, 0)).p)
        local TR = Camera:WorldToViewportPoint((oripart.CFrame * CFrame.new(-sizeX, sizeY, 0)).p)
        local BL = Camera:WorldToViewportPoint((oripart.CFrame * CFrame.new(sizeX, -sizeY, 0)).p)
        local BR = Camera:WorldToViewportPoint((oripart.CFrame * CFrame.new(-sizeX, -sizeY, 0)).p)
        
        -- Apply team check coloring
        if ESP.Box2D.Team_Check then
            if player.TeamColor == LocalPlayer.TeamColor then
                Colorize(library, Color3.fromRGB(0, 255, 0))
            else
                Colorize(library, Color3.fromRGB(255, 0, 0))
            end
        elseif ESP.Box2D.Team_Color then
            Colorize(library, player.TeamColor.Color)
        else
            Colorize(library, ESP.Box2D.Box_Color)
        end
        
        -- Calculate corner size based on distance
        local ratio = (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")) and 
                             (LocalPlayer.Character.HumanoidRootPart.Position - rootPart.Position).magnitude or 10
        local offset = math.clamp(1/ratio * 750, 2, 300)
        
        -- Update corner positions
        pcall(function()
            library.TL1.From = Vector2.new(TL.X, TL.Y)
            library.TL1.To = Vector2.new(TL.X + offset, TL.Y)
            library.TL2.From = Vector2.new(TL.X, TL.Y)
            library.TL2.To = Vector2.new(TL.X, TL.Y + offset)
            
            library.TR1.From = Vector2.new(TR.X, TR.Y)
            library.TR1.To = Vector2.new(TR.X - offset, TR.Y)
            library.TR2.From = Vector2.new(TR.X, TR.Y)
            library.TR2.To = Vector2.new(TR.X, TR.Y + offset)
            
            library.BL1.From = Vector2.new(BL.X, BL.Y)
            library.BL1.To = Vector2.new(BL.X + offset, BL.Y)
            library.BL2.From = Vector2.new(BL.X, BL.Y)
            library.BL2.To = Vector2.new(BL.X, BL.Y - offset)
            
            library.BR1.From = Vector2.new(BR.X, BR.Y)
            library.BR1.To = Vector2.new(BR.X - offset, BR.Y)
            library.BR2.From = Vector2.new(BR.X, BR.Y)
            library.BR2.To = Vector2.new(BR.X, BR.Y - offset)
        end)
        
        -- Apply autothickness
        if ESP.Box2D.Autothickness then
            local distance = (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")) and 
                             (LocalPlayer.Character.HumanoidRootPart.Position - rootPart.Position).magnitude or 10
            
            -- Use ESP.AutoScale settings for consistent scaling
            local value
            if ESP.AutoScale then
                value = math.clamp(1/distance * 100, 1, 4) -- More responsive formula
            else
                value = ESP.Box2D.Box_Thickness
            end
            
            for _, line in pairs(library) do
                pcall(function() line.Thickness = value end)
            end
        else
            for _, line in pairs(library) do
                pcall(function() line.Thickness = ESP.Box2D.Box_Thickness end)
            end
        end
        
        -- Make boxes visible
        Vis(library, true)
    end)
    
    -- Store connection for cleanup
    boxData.Connection = connection
    
    -- Monitor player removal
    task.spawn(function()
        while player and player.Parent do
            wait(1)
        end
        
        -- Player left, clean up
        if boxData.Connection then
            boxData.Connection:Disconnect()
        end
        
        for _, line in pairs(library) do
            pcall(function() line:Remove() end)
        end
        
        ESP.Box2D.BoxObjects[player.Name] = nil
    end)
end

-- Function to start 2D Box ESP
local function Start2DBoxESP()
    -- Setup boxes for existing players
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local boxData = Setup2DBox(player)
            if boxData then
                Update2DBox(boxData)
            end
        end
    end
    
    -- Monitor new players
    Players.PlayerAdded:Connect(function(player)
        if player ~= LocalPlayer then
            wait(1) -- Wait for character to load
            local boxData = Setup2DBox(player)
            if boxData then
                Update2DBox(boxData)
            end
        end
    end)
end

-- Fix duplicate Start2DBoxESP call
-- Start 2D Box ESP system
task.spawn(Start2DBoxESP)

-- Replace the current Skele ESP implementation with the new one

ESP.SkeleESP = {
    Enabled = false,
    Color = Color3.fromRGB(255, 0, 0),
    Thickness = 1,
    Players = {}
}

-- New implementation for Skeleton ESP
local function DrawLine()
    local l = Drawing.new("Line")
    l.Visible = false
    l.From = Vector2.new(0, 0)
    l.To = Vector2.new(1, 1)
    l.Color = ESP.SkeleESP.Color
    l.Thickness = ESP.SkeleESP.Thickness
    l.Transparency = 1
    return l
end

local function DrawESP(plr)
    if plr == LocalPlayer or ESP.SkeleESP.Players[plr.Name] then return end
    
    repeat wait() until plr.Character ~= nil and plr.Character:FindFirstChild("Humanoid") ~= nil
    
    local limbs = {}
    local R15 = (plr.Character.Humanoid.RigType == Enum.HumanoidRigType.R15) and true or false
    
    if R15 then 
        limbs = {
            -- Spine
            Head_UpperTorso = DrawLine(),
            UpperTorso_LowerTorso = DrawLine(),
            -- Left Arm
            UpperTorso_LeftUpperArm = DrawLine(),
            LeftUpperArm_LeftLowerArm = DrawLine(),
            LeftLowerArm_LeftHand = DrawLine(),
            -- Right Arm
            UpperTorso_RightUpperArm = DrawLine(),
            RightUpperArm_RightLowerArm = DrawLine(),
            RightLowerArm_RightHand = DrawLine(),
            -- Left Leg
            LowerTorso_LeftUpperLeg = DrawLine(),
            LeftUpperLeg_LeftLowerLeg = DrawLine(),
            LeftLowerLeg_LeftFoot = DrawLine(),
            -- Right Leg
            LowerTorso_RightUpperLeg = DrawLine(),
            RightUpperLeg_RightLowerLeg = DrawLine(),
            RightLowerLeg_RightFoot = DrawLine(),
        }
    else 
        limbs = {
            Head_Spine = DrawLine(),
            Spine = DrawLine(),
            LeftArm = DrawLine(),
            LeftArm_UpperTorso = DrawLine(),
            RightArm = DrawLine(),
            RightArm_UpperTorso = DrawLine(),
            LeftLeg = DrawLine(),
            LeftLeg_LowerTorso = DrawLine(),
            RightLeg = DrawLine(),
            RightLeg_LowerTorso = DrawLine()
        }
    end
    
    local function Visibility(state)
        for i, v in pairs(limbs) do
            v.Visible = state and ESP.SkeleESP.Enabled
        end
    end

    local function Colorize(color)
        for i, v in pairs(limbs) do
            v.Color = color
        end
    end
    
    local function UpdateThickness(thickness)
        for i, v in pairs(limbs) do
            v.Thickness = thickness
        end
    end

    local function UpdaterR15()
        local connection
        connection = RunService.RenderStepped:Connect(function()
            if not ESP.SkeleESP.Enabled then
                Visibility(false)
                return
            end
            
            if plr.Character ~= nil and plr.Character:FindFirstChild("Humanoid") ~= nil and plr.Character:FindFirstChild("HumanoidRootPart") ~= nil and plr.Character.Humanoid.Health > 0 then
                local HUM, vis = Camera:WorldToViewportPoint(plr.Character.HumanoidRootPart.Position)
                if vis then
                    -- Head
                    local H = Camera:WorldToViewportPoint(plr.Character.Head.Position)
                    if limbs.Head_UpperTorso.From ~= Vector2.new(H.X, H.Y) then
                        --Spine
                        local UT = Camera:WorldToViewportPoint(plr.Character.UpperTorso.Position)
                        local LT = Camera:WorldToViewportPoint(plr.Character.LowerTorso.Position)
                        -- Left Arm
                        local LUA = Camera:WorldToViewportPoint(plr.Character.LeftUpperArm.Position)
                        local LLA = Camera:WorldToViewportPoint(plr.Character.LeftLowerArm.Position)
                        local LH = Camera:WorldToViewportPoint(plr.Character.LeftHand.Position)
                        -- Right Arm
                        local RUA = Camera:WorldToViewportPoint(plr.Character.RightUpperArm.Position)
                        local RLA = Camera:WorldToViewportPoint(plr.Character.RightLowerArm.Position)
                        local RH = Camera:WorldToViewportPoint(plr.Character.RightHand.Position)
                        -- Left leg
                        local LUL = Camera:WorldToViewportPoint(plr.Character.LeftUpperLeg.Position)
                        local LLL = Camera:WorldToViewportPoint(plr.Character.LeftLowerLeg.Position)
                        local LF = Camera:WorldToViewportPoint(plr.Character.LeftFoot.Position)
                        -- Right leg
                        local RUL = Camera:WorldToViewportPoint(plr.Character.RightUpperLeg.Position)
                        local RLL = Camera:WorldToViewportPoint(plr.Character.RightLowerLeg.Position)
                        local RF = Camera:WorldToViewportPoint(plr.Character.RightFoot.Position)

                        --Head
                        limbs.Head_UpperTorso.From = Vector2.new(H.X, H.Y)
                        limbs.Head_UpperTorso.To = Vector2.new(UT.X, UT.Y)

                        --Spine
                        limbs.UpperTorso_LowerTorso.From = Vector2.new(UT.X, UT.Y)
                        limbs.UpperTorso_LowerTorso.To = Vector2.new(LT.X, LT.Y)

                        -- Left Arm
                        limbs.UpperTorso_LeftUpperArm.From = Vector2.new(UT.X, UT.Y)
                        limbs.UpperTorso_LeftUpperArm.To = Vector2.new(LUA.X, LUA.Y)

                        limbs.LeftUpperArm_LeftLowerArm.From = Vector2.new(LUA.X, LUA.Y)
                        limbs.LeftUpperArm_LeftLowerArm.To = Vector2.new(LLA.X, LLA.Y)

                        limbs.LeftLowerArm_LeftHand.From = Vector2.new(LLA.X, LLA.Y)
                        limbs.LeftLowerArm_LeftHand.To = Vector2.new(LH.X, LH.Y)

                        -- Right Arm
                        limbs.UpperTorso_RightUpperArm.From = Vector2.new(UT.X, UT.Y)
                        limbs.UpperTorso_RightUpperArm.To = Vector2.new(RUA.X, RUA.Y)

                        limbs.RightUpperArm_RightLowerArm.From = Vector2.new(RUA.X, RUA.Y)
                        limbs.RightUpperArm_RightLowerArm.To = Vector2.new(RLA.X, RLA.Y)

                        limbs.RightLowerArm_RightHand.From = Vector2.new(RLA.X, RLA.Y)
                        limbs.RightLowerArm_RightHand.To = Vector2.new(RH.X, RH.Y)

                        -- Left Leg
                        limbs.LowerTorso_LeftUpperLeg.From = Vector2.new(LT.X, LT.Y)
                        limbs.LowerTorso_LeftUpperLeg.To = Vector2.new(LUL.X, LUL.Y)

                        limbs.LeftUpperLeg_LeftLowerLeg.From = Vector2.new(LUL.X, LUL.Y)
                        limbs.LeftUpperLeg_LeftLowerLeg.To = Vector2.new(LLL.X, LLL.Y)

                        limbs.LeftLowerLeg_LeftFoot.From = Vector2.new(LLL.X, LLL.Y)
                        limbs.LeftLowerLeg_LeftFoot.To = Vector2.new(LF.X, LF.Y)

                        -- Right Leg
                        limbs.LowerTorso_RightUpperLeg.From = Vector2.new(LT.X, LT.Y)
                        limbs.LowerTorso_RightUpperLeg.To = Vector2.new(RUL.X, RUL.Y)

                        limbs.RightUpperLeg_RightLowerLeg.From = Vector2.new(RUL.X, RUL.Y)
                        limbs.RightUpperLeg_RightLowerLeg.To = Vector2.new(RLL.X, RLL.Y)

                        limbs.RightLowerLeg_RightFoot.From = Vector2.new(RLL.X, RLL.Y)
                        limbs.RightLowerLeg_RightFoot.To = Vector2.new(RF.X, RF.Y)
                    end

                    if limbs.Head_UpperTorso.Visible ~= true then
                        Visibility(true)
                    end
                else 
                    if limbs.Head_UpperTorso.Visible ~= false then
                        Visibility(false)
                    end
                end
            else 
                if limbs.Head_UpperTorso.Visible ~= false then
                    Visibility(false)
                end
                if not Players:FindFirstChild(plr.Name) then 
                    for i, v in pairs(limbs) do
                        v:Remove()
                    end
                    connection:Disconnect()
                    ESP.SkeleESP.Players[plr.Name] = nil
                end
            end
        end)
        
        return connection
    end

    local function UpdaterR6()
        local connection
        connection = RunService.RenderStepped:Connect(function()
            if not ESP.SkeleESP.Enabled then
                Visibility(false)
                return
            end
            
            if plr.Character ~= nil and plr.Character:FindFirstChild("Humanoid") ~= nil and plr.Character:FindFirstChild("HumanoidRootPart") ~= nil and plr.Character.Humanoid.Health > 0 then
                local HUM, vis = Camera:WorldToViewportPoint(plr.Character.HumanoidRootPart.Position)
                if vis then
                    local H = Camera:WorldToViewportPoint(plr.Character.Head.Position)
                    if limbs.Head_Spine.From ~= Vector2.new(H.X, H.Y) then
                        local T_Height = plr.Character.Torso.Size.Y/2 - 0.2
                        local UT = Camera:WorldToViewportPoint((plr.Character.Torso.CFrame * CFrame.new(0, T_Height, 0)).p)
                        local LT = Camera:WorldToViewportPoint((plr.Character.Torso.CFrame * CFrame.new(0, -T_Height, 0)).p)

                        local LA_Height = plr.Character["Left Arm"].Size.Y/2 - 0.2
                        local LUA = Camera:WorldToViewportPoint((plr.Character["Left Arm"].CFrame * CFrame.new(0, LA_Height, 0)).p)
                        local LLA = Camera:WorldToViewportPoint((plr.Character["Left Arm"].CFrame * CFrame.new(0, -LA_Height, 0)).p)

                        local RA_Height = plr.Character["Right Arm"].Size.Y/2 - 0.2
                        local RUA = Camera:WorldToViewportPoint((plr.Character["Right Arm"].CFrame * CFrame.new(0, RA_Height, 0)).p)
                        local RLA = Camera:WorldToViewportPoint((plr.Character["Right Arm"].CFrame * CFrame.new(0, -RA_Height, 0)).p)

                        local LL_Height = plr.Character["Left Leg"].Size.Y/2 - 0.2
                        local LUL = Camera:WorldToViewportPoint((plr.Character["Left Leg"].CFrame * CFrame.new(0, LL_Height, 0)).p)
                        local LLL = Camera:WorldToViewportPoint((plr.Character["Left Leg"].CFrame * CFrame.new(0, -LL_Height, 0)).p)

                        local RL_Height = plr.Character["Right Leg"].Size.Y/2 - 0.2
                        local RUL = Camera:WorldToViewportPoint((plr.Character["Right Leg"].CFrame * CFrame.new(0, RL_Height, 0)).p)
                        local RLL = Camera:WorldToViewportPoint((plr.Character["Right Leg"].CFrame * CFrame.new(0, -RL_Height, 0)).p)

                        -- Head
                        limbs.Head_Spine.From = Vector2.new(H.X, H.Y)
                        limbs.Head_Spine.To = Vector2.new(UT.X, UT.Y)

                        --Spine
                        limbs.Spine.From = Vector2.new(UT.X, UT.Y)
                        limbs.Spine.To = Vector2.new(LT.X, LT.Y)

                        --Left Arm
                        limbs.LeftArm.From = Vector2.new(LUA.X, LUA.Y)
                        limbs.LeftArm.To = Vector2.new(LLA.X, LLA.Y)

                        limbs.LeftArm_UpperTorso.From = Vector2.new(UT.X, UT.Y)
                        limbs.LeftArm_UpperTorso.To = Vector2.new(LUA.X, LUA.Y)

                        --Right Arm
                        limbs.RightArm.From = Vector2.new(RUA.X, RUA.Y)
                        limbs.RightArm.To = Vector2.new(RLA.X, RLA.Y)

                        limbs.RightArm_UpperTorso.From = Vector2.new(UT.X, UT.Y)
                        limbs.RightArm_UpperTorso.To = Vector2.new(RUA.X, RUA.Y)

                        --Left Leg
                        limbs.LeftLeg.From = Vector2.new(LUL.X, LUL.Y)
                        limbs.LeftLeg.To = Vector2.new(LLL.X, LLL.Y)

                        limbs.LeftLeg_LowerTorso.From = Vector2.new(LT.X, LT.Y)
                        limbs.LeftLeg_LowerTorso.To = Vector2.new(LUL.X, LUL.Y)

                        --Right Leg
                        limbs.RightLeg.From = Vector2.new(RUL.X, RUL.Y)
                        limbs.RightLeg.To = Vector2.new(RLL.X, RLL.Y)

                        limbs.RightLeg_LowerTorso.From = Vector2.new(LT.X, LT.Y)
                        limbs.RightLeg_LowerTorso.To = Vector2.new(RUL.X, RUL.Y)
                    end

                    if limbs.Head_Spine.Visible ~= true then
                        Visibility(true)
                    end
                else 
                    if limbs.Head_Spine.Visible ~= false then
                        Visibility(false)
                    end
                end
            else 
                if limbs.Head_Spine.Visible ~= false then
                    Visibility(false)
                end
                if not Players:FindFirstChild(plr.Name) then 
                    for i, v in pairs(limbs) do
                        v:Remove()
                    end
                    connection:Disconnect()
                    ESP.SkeleESP.Players[plr.Name] = nil
                end
            end
        end)
        
        return connection
    end

    local connection
    if R15 then
        connection = UpdaterR15()
    else 
        connection = UpdaterR6()
    end
    
    -- Handle player character respawn
    local characterAddedConnection
    characterAddedConnection = plr.CharacterAdded:Connect(function(newCharacter)
        -- Clean up old ESP
        if ESP.SkeleESP.Players[plr.Name] then
            local data = ESP.SkeleESP.Players[plr.Name]
            if data.Connection then
                data.Connection:Disconnect()
            end
            if data.CharacterAdded then
                data.CharacterAdded:Disconnect()
            end
            
            for _, line in pairs(data.Limbs) do
                line:Remove()
            end
            
            ESP.SkeleESP.Players[plr.Name] = nil
        end
        
        -- Create new ESP for new character
        wait(0.5) -- Short delay to ensure character is fully loaded
        DrawESP(plr)
    end)
    
    -- Store references
    ESP.SkeleESP.Players[plr.Name] = {
        Connection = connection,
        CharacterAdded = characterAddedConnection,
        Limbs = limbs,
        SetVisibility = Visibility,
        SetColor = Colorize,
        SetThickness = UpdateThickness,
        IsR15 = R15
    }
end

-- Function to toggle Skele ESP
local function ToggleSkeleESP(enabled)
    ESP.SkeleESP.Enabled = enabled
    
    -- Apply to all existing skeletons
    for _, data in pairs(ESP.SkeleESP.Players) do
        if data and data.SetVisibility then
            data.SetVisibility(enabled)
        end
    end
    
    -- Initialize for all players if first enable
    if enabled and next(ESP.SkeleESP.Players) == nil then
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                task.spawn(function()
                    DrawESP(player)
                end)
            end
        end
    end
end

-- Initialize Skele ESP
task.spawn(function()
    -- Setup for all existing players
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            task.spawn(function()
                DrawESP(player)
            end)
        end
    end
    
    -- Setup for future players
    Players.PlayerAdded:Connect(function(player)
        if player ~= LocalPlayer then
            task.spawn(function()
                wait(1) -- Give time for character to load
                DrawESP(player)
            end)
        end
    end)
    
    -- Handle player leaving
    Players.PlayerRemoving:Connect(function(player)
        if ESP.SkeleESP.Players[player.Name] then
            local data = ESP.SkeleESP.Players[player.Name]
            
            if data.Connection then
                data.Connection:Disconnect()
            end
            
            if data.CharacterAdded then
                data.CharacterAdded:Disconnect()
            end
            
            for _, line in pairs(data.Limbs) do
                line:Remove()
            end
            
            ESP.SkeleESP.Players[player.Name] = nil
        end
    end)
end)

-- Add Skele ESP to the UI
local SkeleESPSection = espTab:section{
    Name = "Skeleton ESP",
    Side = "left"
}

SkeleESPSection:toggle{
    Name = "Show Skeleton ESP",
    Description = "Display skeleton lines on players",
    Default = false,
    Callback = function(value)
        ToggleSkeleESP(value)
    end
}

SkeleESPSection:color_picker{
    Name = "Skeleton Color",
    Description = "Color of skeleton lines",
    Default = Color3.fromRGB(255, 0, 0),
    Callback = function(color)
        ESP.SkeleESP.Color = color
        
        for _, data in pairs(ESP.SkeleESP.Players) do
            if data and data.SetColor then
                data.SetColor(color)
            end
        end
    end
}

SkeleESPSection:slider{
    Name = "Line Thickness",
    Description = "Thickness of skeleton lines",
    Default = 1,
    Min = 0.5,
    Max = 3,
    Float = 0.1,
    Format = "%0.1f",
    Callback = function(value)
        ESP.SkeleESP.Thickness = value
        
        for _, data in pairs(ESP.SkeleESP.Players) do
            if data and data.SetThickness then
                data.SetThickness(value)
            end
        end
    end
}

SkeleESPSection:button{
    Name = "Refresh All Skeletons",
    Description = "Recreate all skeleton ESP",
    Callback = function()
        -- Clean up existing ESP
        for playerName, data in pairs(ESP.SkeleESP.Players) do
            if data then
                if data.Connection then
                    data.Connection:Disconnect()
                end
                
                if data.CharacterAdded then
                    data.CharacterAdded:Disconnect()
                end
                
                for _, line in pairs(data.Limbs) do
                    line:Remove()
                end
            end
        end
        
        ESP.SkeleESP.Players = {}
        
        -- Recreate ESP for all players
        if ESP.SkeleESP.Enabled then
            for _, player in pairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then
                    task.spawn(function()
                        DrawESP(player)
                    end)
                end
            end
        end
    end
}

-- Initialize optimize tab
local optimizeTab = nil -- Removed tab

-- This section has been removed
local performanceSection = nil

-- Print confirmation
print("[COMBINED AIMBOT] Script loaded successfully - Check console for optimization options")
print("[OPTIMIZE] Type 'getgenv().OptimizeGraphics()' in your executor console to optimize graphics directly")

-- Add enhanced Optimized tab with more comprehensive features
local optimizedTab = gui:tab{
    Icon = "rbxassetid://7734053495",
    Name = "Optimized"
}

-- Create FPS Boost section with comprehensive options
local fpsBoostSection = optimizedTab:section{
    Name = "FPS Boost Settings",
    Side = "left"
}

-- Create states for all optimization toggles
local graphicsEnabled = true
local lightingEnabled = true
local shadowsEnabled = false
local textureEnabled = true
local effectsEnabled = false
local terrainEnabled = true
local renderingEnabled = true

-- Add toggles with better descriptions
fpsBoostSection:toggle{
    Name = "Graphics Optimization",
    Description = "Lower rendering quality for better performance",
    Default = true,
    Callback = function(value)
        graphicsEnabled = value
    end
}

fpsBoostSection:toggle{
    Name = "Disable Shadows",
    Description = "Removes shadows for significant FPS boost",
    Default = true,
    Callback = function(value)
        shadowsEnabled = value
    end
}

fpsBoostSection:toggle{
    Name = "Lighting Optimization",
    Description = "Simplify lighting effects and properties",
    Default = true,
    Callback = function(value)
        lightingEnabled = value
    end
}

fpsBoostSection:toggle{
    Name = "Texture Optimization",
    Description = "Simplify textures and material properties",
    Default = true,
    Callback = function(value)
        textureEnabled = value
    end
}

fpsBoostSection:toggle{
    Name = "Terrain Optimization",
    Description = "Simplify terrain details and water effects",
    Default = true,
    Callback = function(value)
        terrainEnabled = value
    end
}

fpsBoostSection:toggle{
    Name = "Disable Particles/Effects",
    Description = "Remove visual effects like fire, smoke, etc.",
    Default = false,
    Callback = function(value)
        effectsEnabled = value
    end
}

fpsBoostSection:toggle{
    Name = "Rendering Optimizations",
    Description = "Reduce render distances and throttle",
    Default = true,
    Callback = function(value)
        renderingEnabled = value
    end
}

-- Add buttons to optimize and reset
fpsBoostSection:button{
    Name = "APPLY OPTIMIZATIONS",
    Description = "Apply selected optimizations to boost FPS",
    Callback = function()
        print("[OPTIMIZE] Starting performance optimization...")
        local optimizeCount = 0
        
        -- Apply Graphics optimizations
        if graphicsEnabled and settings then
            local RenderSettings = settings():GetService("RenderSettings")
            local UserGameSettings = UserSettings():GetService("UserGameSettings")
            
            RenderSettings.QualityLevel = Enum.QualityLevel.Level01
            RenderSettings.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level01
            UserGameSettings.SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1
            
            -- Additional graphics settings
            if renderingEnabled then
                RenderSettings.EagerBulkExecution = false
                workspace.InterpolationThrottling = Enum.InterpolationThrottlingMode.Enabled
                UserGameSettings.GraphicsQualityLevel = 1
            end
            
            optimizeCount = optimizeCount + 1
            print("[OPTIMIZE] Graphics settings optimized")
        end
        
        -- Apply Lighting optimizations
        if lightingEnabled then
            local Lighting = game:GetService("Lighting")
            
            -- Basic lighting
            Lighting.Brightness = 0.8
            Lighting.FogEnd = 100000
            
            -- Shadows control
            if shadowsEnabled then
                Lighting.GlobalShadows = false
                Lighting.ShadowSoftness = 0
            end
            
            -- Additional effects
            Lighting.Ambient = Color3.fromRGB(127, 127, 127)
            Lighting.OutdoorAmbient = Color3.fromRGB(127, 127, 127)
            
            -- Try to set technology if possible
            local sethiddenproperty = sethiddenproperty or set_hidden_property or set_hidden_prop
            if sethiddenproperty then
                pcall(function()
                    sethiddenproperty(Lighting, "Technology", Enum.Technology.Compatibility)
                end)
            end
            
            optimizeCount = optimizeCount + 1
            print("[OPTIMIZE] Lighting settings optimized")
        end
        
        -- Apply Texture optimizations
        if textureEnabled then
            -- Level of detail settings
            workspace.LevelOfDetail = Enum.ModelLevelOfDetail.Disabled
            
            -- MeshPart settings
            local sethiddenproperty = sethiddenproperty or set_hidden_property or set_hidden_prop
            if sethiddenproperty then
                pcall(function()
                    sethiddenproperty(workspace, "MeshPartHeads", Enum.MeshPartHeads.Disabled)
                    sethiddenproperty(workspace, "ModelStreamingMode", 0)
                end)
            end
            
            optimizeCount = optimizeCount + 1
            print("[OPTIMIZE] Texture settings optimized")
        end
        
        -- Apply Terrain optimizations
        if terrainEnabled then
            local Terrain = workspace.Terrain
            
            Terrain.WaterWaveSize = 0
            Terrain.WaterWaveSpeed = 0
            Terrain.WaterReflectance = 0
            Terrain.WaterTransparency = 0
            
            local sethiddenproperty = sethiddenproperty or set_hidden_property or set_hidden_prop
            if sethiddenproperty then
                pcall(function()
                    sethiddenproperty(Terrain, "Decoration", false)
                end)
            end
            
            optimizeCount = optimizeCount + 1
            print("[OPTIMIZE] Terrain settings optimized")
        end
        
        -- Process game objects in batches
        if textureEnabled or effectsEnabled or lightingEnabled then
            print("[OPTIMIZE] Processing game objects...")
            
            -- Function to process objects in batches to prevent timeout
            local function ProcessBatch(objects, startIdx, batchSize)
                local endIdx = math.min(startIdx + batchSize - 1, #objects)
                
                for i = startIdx, endIdx do
                    local Object = objects[i]
                    
                    if Object:IsA("BasePart") and textureEnabled then
                        Object.Material = Enum.Material.SmoothPlastic
                        Object.Reflectance = 0
                        optimizeCount = optimizeCount + 1
                    end
                    
                    if lightingEnabled and Object:IsA("BasePart") then
                        Object.CastShadow = false
                        optimizeCount = optimizeCount + 1
                    end
                    
                    if Object:IsA("Atmosphere") and lightingEnabled then
                        Object.Density = 0
                        Object.Offset = 0
                        Object.Glare = 0
                        Object.Haze = 0
                        optimizeCount = optimizeCount + 1
                    end
                    
                    if Object:IsA("SurfaceAppearance") and textureEnabled then
                        Object.AlphaMode = Enum.AlphaMode.Overlay
                        Object.MetalnessScale = 0
                        Object.RoughnessScale = 0
                        optimizeCount = optimizeCount + 1
                    end
                    
                    if (Object:IsA("Decal") or Object:IsA("Texture")) and textureEnabled then
                        -- Preserve face UI like nametags
                        if Object.Parent and not Object.Parent:IsA("Head") then
                            Object.Transparency = 1
                            optimizeCount = optimizeCount + 1
                        end
                    end
                    
                    if effectsEnabled and (
                        Object:IsA("ParticleEmitter") or
                        Object:IsA("Fire") or
                        Object:IsA("Smoke") or
                        Object:IsA("Sparkles") or
                        Object:IsA("Trail")
                    ) then
                        Object.Enabled = false
                        optimizeCount = optimizeCount + 1
                    end
                    
                    if effectsEnabled and (
                        Object:IsA("BloomEffect") or
                        Object:IsA("BlurEffect") or
                        Object:IsA("ColorCorrectionEffect") or
                        Object:IsA("SunRaysEffect") or
                        Object:IsA("DepthOfFieldEffect")
                    ) then
                        Object.Enabled = false
                        optimizeCount = optimizeCount + 1
                    end
                end
                
                -- If there are more objects to process, schedule next batch
                if endIdx < #objects then
                    print("[OPTIMIZE] Processing: " .. math.floor((endIdx / #objects) * 100) .. "% complete")
                    task.delay(0.1, function()
                        ProcessBatch(objects, endIdx + 1, batchSize)
                    end)
                else
                    print("[OPTIMIZE] Complete - Optimized " .. optimizeCount .. " objects and settings")
                    gui:set_status("Optimizations applied: " .. optimizeCount .. " items")
                end
            end
            
            -- Start processing in batches
            local allObjects = game:GetDescendants()
            ProcessBatch(allObjects, 1, 500)
        else
            print("[OPTIMIZE] Complete - Optimized " .. optimizeCount .. " settings")
            gui:set_status("Optimizations applied: " .. optimizeCount .. " settings")
        end
    end
}

fpsBoostSection:button{
    Name = "RESET GAME GRAPHICS",
    Description = "Restore default graphics settings",
    Callback = function()
        gui:set_status("Resetting graphics settings...")
        print("[OPTIMIZE] Restoring default graphics settings")
        
        if settings then
            local RenderSettings = settings():GetService("RenderSettings")
            local UserGameSettings = UserSettings():GetService("UserGameSettings")
            
            RenderSettings.QualityLevel = Enum.QualityLevel.Level21
            RenderSettings.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level04
            UserGameSettings.SavedQualityLevel = Enum.SavedQualitySetting.Automatic
            UserGameSettings.GraphicsQualityLevel = 10
            
            if workspace.InterpolationThrottling ~= Enum.InterpolationThrottlingMode.Default then
                workspace.InterpolationThrottling = Enum.InterpolationThrottlingMode.Default
            end
            
            if workspace.LevelOfDetail ~= Enum.ModelLevelOfDetail.StreamingMesh then
                workspace.LevelOfDetail = Enum.ModelLevelOfDetail.StreamingMesh
            end
        end
        
        -- Reset lighting
        local Lighting = game:GetService("Lighting")
        Lighting.GlobalShadows = true
        Lighting.Brightness = 3
        Lighting.Ambient = Color3.fromRGB(0, 0, 0)
        Lighting.OutdoorAmbient = Color3.fromRGB(70, 70, 70)
        Lighting.FogEnd = 10000
        
        -- Reset terrain
        local Terrain = workspace.Terrain
        Terrain.WaterWaveSize = 0.15
        Terrain.WaterWaveSpeed = 10
        Terrain.WaterReflectance = 1
        Terrain.WaterTransparency = 0.3
        
        print("[OPTIMIZE] Graphics settings reset to defaults")
        gui:set_status("Graphics reset to defaults")
    end
}

-- Create Memory section with additional controls
local memorySection = optimizedTab:section{
    Name = "Memory & Performance",
    Side = "right"
}

-- Create states for memory optimization
local autoCleanerEnabled = false
local cleanupInterval = 60
local cleanerActive = false

memorySection:toggle{
    Name = "Auto Memory Cleaner",
    Description = "Periodically cleans memory to reduce lag spikes",
    Default = false,
    Callback = function(value)
        autoCleanerEnabled = value
        
        if value and not cleanerActive then
            cleanerActive = true
            -- Start memory cleaning loop
            task.spawn(function()
                while autoCleanerEnabled and task.wait(cleanupInterval) do
                    print("[OPTIMIZE] Running memory cleanup...")
                    
                    -- Force garbage collection
                    for i = 1, 10 do
                        game:GetService("Debris"):AddItem(Instance.new("Frame"), 0)
                    end
                    
                    -- Wait for next collection phase
                    task.wait(0.5)
                    
                    -- Try to free unused assets
                    if game:GetService("ContentProvider").RequestQueueSize > 0 then
                        game:GetService("ContentProvider"):PreloadAsync({})
                    end
                    
                    -- Update status
                    local currentMemory = math.floor(game:GetService("Stats"):GetTotalMemoryUsageMb())
                    print("[OPTIMIZE] Memory usage: " .. currentMemory .. "MB")
                    gui:set_status("Memory cleaned: " .. currentMemory .. "MB in use")
                end
                cleanerActive = false
            end)
        end
    end
}

memorySection:slider{
    Name = "Cleanup Interval (seconds)",
    Description = "How often to run memory cleanup",
    Default = 60,
    Min = 10,
    Max = 300,
    Callback = function(value)
        cleanupInterval = value
    end
}

-- Add a button to force immediate cleanup
memorySection:button{
    Name = "CLEAN MEMORY NOW",
    Description = "Force an immediate memory cleanup",
    Callback = function()
        print("[OPTIMIZE] Forcing memory cleanup...")
        gui:set_status("Cleaning memory...")
        
        -- Remove textures from memory
        for _, v in pairs(game:GetDescendants()) do
            if v:IsA("BasePart") or v:IsA("Decal") or v:IsA("Texture") then
                task.spawn(function()
                    pcall(function()
                        v.Transparency = v.Transparency
                    end)
                end)
            end
        end
        
        -- Force garbage collection
        for i = 1, 10 do
            game:GetService("Debris"):AddItem(Instance.new("Frame"), 0)
        end
        
        -- Try to force content streaming
        if game:GetService("ContentProvider").RequestQueueSize > 0 then
            game:GetService("ContentProvider"):PreloadAsync({})
        end
        
        -- Show current memory usage
        task.wait(1)
        local currentMemory = math.floor(game:GetService("Stats"):GetTotalMemoryUsageMb())
        print("[OPTIMIZE] Memory cleaned. Current usage: " .. currentMemory .. "MB")
        gui:set_status("Memory cleaned: " .. currentMemory .. "MB in use")
    end
}

-- Add FPS monitoring
local showFpsEnabled = false
local fpsLabel = nil

memorySection:toggle{
    Name = "Show FPS Counter",
    Description = "Display current FPS in the corner",
    Default = false,
    Callback = function(value)
        showFpsEnabled = value
        
        if value and not fpsLabel then
            -- Create FPS counter
            local screenGui = Instance.new("ScreenGui")
            screenGui.Name = "FPSCounter"
            screenGui.ResetOnSpawn = false
            screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
            
            fpsLabel = Instance.new("TextLabel")
            fpsLabel.Name = "FPSLabel"
            fpsLabel.Size = UDim2.new(0, 100, 0, 30)
            fpsLabel.Position = UDim2.new(1, -110, 0, 10)
            fpsLabel.BackgroundTransparency = 0.5
            fpsLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
            fpsLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            fpsLabel.TextSize = 16
            fpsLabel.Font = Enum.Font.Code
            fpsLabel.Text = "FPS: --"
            fpsLabel.Parent = screenGui
            
            -- Set parent based on context
            pcall(function()
                screenGui.Parent = game:GetService("CoreGui")
            end)
            
            if not screenGui.Parent then
                screenGui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
            end
            
            -- Start FPS counter update loop
            local lastTime = tick()
            local frameCount = 0
            local fpsValue = 60
            
            game:GetService("RunService").RenderStepped:Connect(function()
                frameCount = frameCount + 1
                
                local currentTime = tick()
                local deltaTime = currentTime - lastTime
                
                if deltaTime >= 0.5 then
                    fpsValue = math.floor(frameCount / deltaTime)
                    frameCount = 0
                    lastTime = currentTime
                    
                    if fpsLabel then
                        local color
                        if fpsValue >= 45 then
                            color = Color3.fromRGB(0, 255, 0)  -- Green
                        elseif fpsValue >= 30 then
                            color = Color3.fromRGB(255, 255, 0)  -- Yellow
                        else
                            color = Color3.fromRGB(255, 0, 0)  -- Red
                        end
                        
                        fpsLabel.TextColor3 = color
                        fpsLabel.Text = "FPS: " .. tostring(fpsValue)
                    end
                end
            end)
        elseif not value and fpsLabel then
            -- Remove FPS counter
            local screenGui = fpsLabel.Parent
            fpsLabel:Destroy()
            fpsLabel = nil
            
            if screenGui then
                screenGui:Destroy()
            end
        end
    end
}

-- Make OptimizeGraphics function global for easy access
getgenv().OptimizeGraphics = function()
    -- Run the optimization with default settings
    print("[OPTIMIZE] Running quick optimization with default settings...")
    
    -- Graphics
    if settings then
        local RenderSettings = settings():GetService("RenderSettings")
        local UserGameSettings = UserSettings():GetService("UserGameSettings")
        
        RenderSettings.QualityLevel = Enum.QualityLevel.Level01
        RenderSettings.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level01
        UserGameSettings.SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1
    end
    
    -- Lighting
    local Lighting = game:GetService("Lighting")
    Lighting.GlobalShadows = false
    Lighting.FogEnd = 100000
    
    -- Terrain
    local Terrain = workspace.Terrain
    Terrain.WaterWaveSize = 0
    Terrain.WaterWaveSpeed = 0
    Terrain.WaterReflectance = 0
    Terrain.WaterTransparency = 0
    
    print("[OPTIMIZE] Quick optimization complete!")
    return "Optimization complete"
end

-- Expose this function globally
_G.OptimizeGraphics = getgenv().OptimizeGraphics

-- Script created by /LAWSUIT
getgenv().ScriptCreator = "/LAWSUIT"
print("Script created by /LAWSUIT - All rights reserved")

-- Add creator name to GUI title
gui:set_title("Mercury | Created by /LAWSUIT")

-- Optimize visible attribution - Create on demand rather than always
local creatorLabel = nil
local function setupCreatorLabel()
    if not creatorLabel then
        creatorLabel = Drawing.new("Text")
        creatorLabel.Text = "Script by /LAWSUIT"
        creatorLabel.Size = 16
        creatorLabel.Color = Color3.fromRGB(255, 255, 0)
        creatorLabel.Center = false
        creatorLabel.Outline = true
        creatorLabel.OutlineColor = Color3.new(0, 0, 0)
        creatorLabel.Position = Vector2.new(10, 10)
        creatorLabel.Visible = true
    end
end

-- Call setup function when needed
setupCreatorLabel()

-- Add script cleanup handler
game:GetService("Players").LocalPlayer.CharacterRemoving:Connect(function()
    if creatorLabel then
        creatorLabel.Visible = false
    end
end)

-- Create a notification that requires acknowledgment
gui:prompt{
    Title = "SCRIPT CREATOR",
    Text = "This script was created by /LAWSUIT\nAll rights reserved.",
    Buttons = {"OK"},
    Callback = function()
        print("User acknowledged /LAWSUIT as creator")
    end
}

-- Debug Mode Implementation
local debugMode = {
    Enabled = false,
    DisableVisualEffects = true,
    DisableBackgroundProcessing = true,
    DisableLogging = false,
    LowMemoryMode = false
}

-- Function to toggle debug features
local function ApplyDebugMode()
    if debugMode.Enabled then
        print("[DEBUG] Debug mode enabled - optimizing performance")
        
        -- Disable visual effects if selected
        if debugMode.DisableVisualEffects then
            -- Hide non-essential visual elements
            if creatorLabel then creatorLabel.Visible = false end
            
            -- Reduce ESP features if ESP is present
            if ESP then
                ESP.ShowTracers = false
                ESP.ShowNames = false
                if ESP.Box2D then ESP.Box2D.Enabled = false end
                if ESP.SkeleESP then ESP.SkeleESP.Enabled = false end
            end
            
            -- Reduce FOV visual elements
            setrenderproperty(aimbot.FOVCircleOutline, "Visible", false)
            setrenderproperty(aimbot.TracerLine, "Visible", false)
        end
        
        -- Disable background processing
        if debugMode.DisableBackgroundProcessing then
            -- Reduce update frequency for non-critical features
            cleanupInterval = 120 -- Increase memory cleanup interval
        end
        
        -- Enable low memory mode
        if debugMode.LowMemoryMode then
            -- Force memory cleanup
            for i = 1, 10 do
                game:GetService("Debris"):AddItem(Instance.new("Frame"), 0)
            end
            
            -- Clear textures from memory
            for _, v in pairs(game:GetDescendants()) do
                if v:IsA("BasePart") or v:IsA("Decal") or v:IsA("Texture") then
                    task.spawn(function()
                        pcall(function() v.Transparency = v.Transparency end)
                    end)
                end
            end
        end
        
        gui:set_status("Debug Mode: Enabled - Performance Optimized")
    else
        print("[DEBUG] Debug mode disabled - restoring features")
        
        -- Restore visual elements
        if creatorLabel then creatorLabel.Visible = true end
        
        -- Restore original cleanup interval
        cleanupInterval = 60
        
        gui:set_status("Debug Mode: Disabled - All Features Restored")
    end
end

-- Add a Debug section to the Optimized tab
local debugSection = optimizedTab:section{
    Name = "Debug Mode",
    Side = "right" 
}

-- Add toggle for main debug mode
debugSection:toggle{
    Name = "Enable Debug Mode",
    Description = "Disable non-essential features for better performance",
    Default = false,
    Callback = function(value)
        debugMode.Enabled = value
        ApplyDebugMode()
    end
}

-- Add toggles for specific debug features
debugSection:toggle{
    Name = "Disable Visual Effects",
    Description = "Turn off non-essential visual elements",
    Default = true,
    Callback = function(value)
        debugMode.DisableVisualEffects = value
        if debugMode.Enabled then ApplyDebugMode() end
    end
}

debugSection:toggle{
    Name = "Background Processing",
    Description = "Reduce frequency of background tasks",
    Default = true,
    Callback = function(value)
        debugMode.DisableBackgroundProcessing = value
        if debugMode.Enabled then ApplyDebugMode() end
    end
}

debugSection:toggle{
    Name = "Low Memory Mode",
    Description = "Aggressively reduce memory usage",
    Default = false,
    Callback = function(value)
        debugMode.LowMemoryMode = value
        if debugMode.Enabled then ApplyDebugMode() end
    end
}

debugSection:button{
    Name = "FORCE FULL OPTIMIZATION",
    Description = "Immediately apply all optimization techniques",
    Callback = function()
        -- Enable all debug options
        debugMode.Enabled = true
        debugMode.DisableVisualEffects = true
        debugMode.DisableBackgroundProcessing = true
        debugMode.LowMemoryMode = true
        
        -- Apply optimizations
        ApplyDebugMode()
        
        -- Run graphics optimization
        if getgenv().OptimizeGraphics then
            getgenv().OptimizeGraphics()
        end
        
        gui:set_status("Maximum optimization applied")
    end
}
