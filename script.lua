--[[
    ================================================================
    [ SCRIPT INFORMATION ]
    Project: Universal script
    Author: Limplik
    YouTube:
    
    [ TERMS AND CONDITIONS ]
    - You ARE allowed to use and modify this script for your own games.
    - You ARE NOT allowed to re-upload, redistribute, or claim 
      ownership of this script.
    - Removing or altering these credits is strictly prohibited.
    
    Copyright (c) 2026 OYB. All rights reserved.
    ================================================================
]]

-- ⚠️ IMPORTANT: Put this code at the VERY TOP of your Main Script (before obfuscating) ⚠️

local ProtectionConfig = {
    -- 🔴 CRITICAL: This MUST exactly match the 'Secret' value in your Key System's Config!
    -- If your Key System has: Secret = "Test"
    -- Then this must also be: SecretKey = "Test"
    SecretKey = "LimplikUniversalScript",
    
    -- The name of your Hub (shown in the kick message if they try to bypass)
    HubName = "Limplik Universal"
}

-- Anti-Bypass Logic: Checks if the Key System successfully set the global variable
if not _G[ProtectionConfig.SecretKey] then
    local player = game:GetService("Players").LocalPlayer
    if player then
        player:Kick("\n🛡️ Unauthorized Execution 🛡️\n\nPlease use the official Key System to run " .. ProtectionConfig.HubName)
    end
    return -- Stops the rest of the script from loading!
end

-------------------------------------------------------------------------------
-- 👇 YOUR MAIN SCRIPT CODE STARTS HERE 👇
-------------------------------------------------------------------------------
-- LocalScript: StarterPlayer > StarterPlayerScripts

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local flying = false
local noclip = false
local freecam = false
local espEnabled = false
local spectating = false
local spectateTarget = nil

local flySpeed = 60
local freecamSpeed = 60
local FLY_MIN, FLY_MAX = 20, 500
local CAM_MIN, CAM_MAX = 10, 400

local flightConnection
local noclipConnection
local freecamConnection
local espConnection

local savedCameraType
local savedCameraSubject
local savedMouseBehavior
local savedWalkSpeed
local savedJumpPower
local freecamPart

local savedSpecCameraType
local savedSpecCameraSubject

local camYaw = 0
local camPitch = 0

local espHighlights = {}
local espBillboards = {}

local ESP_FILL_COLOR = Color3.fromRGB(120, 190, 255)
local ESP_OUTLINE_COLOR = Color3.fromRGB(200, 230, 255)
local ESP_FILL_TRANSPARENCY = 0.75
local ESP_OUTLINE_TRANSPARENCY = 0.15

-- ===== Touch Fling =====

local touchFlingEnabled = false
local flingRunning = false
local flingTarget = nil
local flingConnections = {}
local touchFlingButton

local function getPlayerFromPart(part)
    local model = part and part:FindFirstAncestorOfClass("Model")
    if not model then
        return nil
    end
    return Players:GetPlayerFromCharacter(model)
end

local function onFlingTouch(hit)
    if not touchFlingEnabled then
        return
    end

    local otherPlayer = getPlayerFromPart(hit)
    if not otherPlayer or otherPlayer == player then
        return
    end

    local otherChar = otherPlayer.Character
    if otherChar and otherChar:FindFirstChild("HumanoidRootPart") then
        flingTarget = otherChar
    end
end

local function connectFlingTouched(character)
    if not character then
        return
    end

    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            table.insert(flingConnections, part.Touched:Connect(onFlingTouch))
        end
    end
end

local function clearFlingConnections()
    for _, conn in ipairs(flingConnections) do
        conn:Disconnect()
    end
    flingConnections = {}
end

local function setTouchFlingButton(enabled)
    touchFlingEnabled = enabled
    if touchFlingButton then
        touchFlingButton.Text = enabled and "Touch Fling: ON" or "Touch Fling: OFF"
        touchFlingButton.BackgroundColor3 = enabled and Color3.fromRGB(55, 150, 90) or Color3.fromRGB(65, 65, 80)
    end
end

local function startTouchFling()
    flingRunning = true
    local movel = 0.1

    while touchFlingEnabled do
        RunService.Heartbeat:Wait()
        if not touchFlingEnabled then
            break
        end

        local character = player.Character
        local hrp = character and character:FindFirstChild("HumanoidRootPart")

        if hrp and hrp.Parent and flingTarget then
            local targetHrp = flingTarget:FindFirstChild("HumanoidRootPart")
            local vel = hrp.AssemblyLinearVelocity

            hrp.AssemblyLinearVelocity = vel * 10000 + Vector3.new(0, 10000, 0)
            RunService.RenderStepped:Wait()

            if hrp and hrp.Parent then
                hrp.AssemblyLinearVelocity = vel
            end

            RunService.Stepped:Wait()

            if hrp and hrp.Parent then
                hrp.AssemblyLinearVelocity = vel + Vector3.new(0, movel, 0)
                movel = movel * -1
            end

            if targetHrp and targetHrp.Parent then
                local dir = targetHrp.Position - hrp.Position
                if dir.Magnitude < 0.1 then
                    dir = Vector3.new(0, 1, 0)
                else
                    dir = dir.Unit
                end

                targetHrp.AssemblyLinearVelocity = dir * 400 + Vector3.new(0, 350, 0)
                targetHrp.AssemblyAngularVelocity = Vector3.new(
                    math.random(-60, 60),
                    math.random(-60, 60),
                    math.random(-60, 60)
                )
            end

            flingTarget = nil
        end
    end

    flingRunning = false
end

function toggleTouchFling()
    local enabled = not touchFlingEnabled
    setTouchFlingButton(enabled)

    if enabled then
        connectFlingTouched(player.Character)
        if not flingRunning then
            task.spawn(startTouchFling)
        end
    else
        clearFlingConnections()
    end
end

-- ===== Base GUI =====

local gui = Instance.new("ScreenGui")
gui.Name = "FlightMenu"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(220, 470)
frame.Position = UDim2.new(0, 18, 0.5, -235)
frame.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

-- ===== Make the panel draggable =====

local dragToggle = nil
local dragStart = nil
local startPos = nil

local function updateDrag(input)
    local delta = input.Position - dragStart
    frame.Position = UDim2.new(
        startPos.X.Scale, startPos.X.Offset + delta.X,
        startPos.Y.Scale, startPos.Y.Offset + delta.Y
    )
end

frame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragToggle = true
        dragStart = input.Position
        startPos = frame.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragToggle = false
            end
        end)
    end
end)

frame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
        if dragToggle then
            updateDrag(input)
        end
    end
end)

-- ===== Toggle buttons =====

local button = Instance.new("TextButton")
button.Size = UDim2.new(1, -20, 0, 42)
button.Position = UDim2.fromOffset(10, 10)
button.BackgroundColor3 = Color3.fromRGB(65, 65, 80)
button.TextColor3 = Color3.new(1, 1, 1)
button.TextSize = 18
button.Font = Enum.Font.GothamBold
button.Text = "Flight: OFF"
button.Parent = frame
Instance.new("UICorner", button).CornerRadius = UDim.new(0, 7)

local noclipButton = Instance.new("TextButton")
noclipButton.Size = UDim2.new(1, -20, 0, 42)
noclipButton.Position = UDim2.fromOffset(10, 58)
noclipButton.BackgroundColor3 = Color3.fromRGB(65, 65, 80)
noclipButton.TextColor3 = Color3.new(1, 1, 1)
noclipButton.TextSize = 18
noclipButton.Font = Enum.Font.GothamBold
noclipButton.Text = "Noclip: OFF"
noclipButton.Parent = frame
Instance.new("UICorner", noclipButton).CornerRadius = UDim.new(0, 7)

local freecamButton = Instance.new("TextButton")
freecamButton.Size = UDim2.new(1, -20, 0, 42)
freecamButton.Position = UDim2.fromOffset(10, 106)
freecamButton.BackgroundColor3 = Color3.fromRGB(65, 65, 80)
freecamButton.TextColor3 = Color3.new(1, 1, 1)
freecamButton.TextSize = 18
freecamButton.Font = Enum.Font.GothamBold
freecamButton.Text = "Freecam: OFF"
freecamButton.Parent = frame
Instance.new("UICorner", freecamButton).CornerRadius = UDim.new(0, 7)

local espButton = Instance.new("TextButton")
espButton.Size = UDim2.new(1, -20, 0, 42)
espButton.Position = UDim2.fromOffset(10, 154)
espButton.BackgroundColor3 = Color3.fromRGB(65, 65, 80)
espButton.TextColor3 = Color3.new(1, 1, 1)
espButton.TextSize = 18
espButton.Font = Enum.Font.GothamBold
espButton.Text = "ESP: OFF"
espButton.Parent = frame
Instance.new("UICorner", espButton).CornerRadius = UDim.new(0, 7)

local spectateToggleButton = Instance.new("TextButton")
spectateToggleButton.Size = UDim2.new(1, -20, 0, 42)
spectateToggleButton.Position = UDim2.fromOffset(10, 202)
spectateToggleButton.BackgroundColor3 = Color3.fromRGB(65, 65, 80)
spectateToggleButton.TextColor3 = Color3.new(1, 1, 1)
spectateToggleButton.TextSize = 18
spectateToggleButton.Font = Enum.Font.GothamBold
spectateToggleButton.Text = "Spectate"
spectateToggleButton.Parent = frame
Instance.new("UICorner", spectateToggleButton).CornerRadius = UDim.new(0, 7)

touchFlingButton = Instance.new("TextButton")
touchFlingButton.Size = UDim2.new(1, -20, 0, 42)
touchFlingButton.Position = UDim2.fromOffset(10, 250)
touchFlingButton.BackgroundColor3 = Color3.fromRGB(65, 65, 80)
touchFlingButton.TextColor3 = Color3.new(1, 1, 1)
touchFlingButton.TextSize = 18
touchFlingButton.Font = Enum.Font.GothamBold
touchFlingButton.Text = "Touch Fling: OFF"
touchFlingButton.Parent = frame
Instance.new("UICorner", touchFlingButton).CornerRadius = UDim.new(0, 7)

-- ===== Slider factory (used for fly speed + freecam speed) =====

local function createSlider(yPos, minVal, maxVal, initialVal, labelPrefix, onChange)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -20, 0, 24)
    label.Position = UDim2.fromOffset(10, yPos)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextSize = 15
    label.Font = Enum.Font.Gotham
    label.Parent = frame

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, -30, 0, 8)
    bar.Position = UDim2.fromOffset(15, yPos + 40)
    bar.BackgroundColor3 = Color3.fromRGB(75, 75, 90)
    bar.Parent = frame
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)

    local fill = Instance.new("Frame")
    fill.BackgroundColor3 = Color3.fromRGB(65, 170, 255)
    fill.Parent = bar
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("TextButton")
    knob.Size = UDim2.fromOffset(18, 18)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.Text = ""
    knob.Parent = bar
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local function setValue(newVal)
        local rounded = math.round(math.clamp(newVal, minVal, maxVal))
        local percent = (rounded - minVal) / (maxVal - minVal)

        label.Text = labelPrefix .. ": " .. rounded
        fill.Size = UDim2.fromScale(percent, 1)
        knob.Position = UDim2.new(percent, 0, 0.5, 0)

        onChange(rounded)
    end

    local dragging = false

    local function updateFromX(x)
        local percent = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        setValue(minVal + (maxVal - minVal) * percent)
    end

    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            updateFromX(input.Position.X)
        end
    end)

    knob.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            updateFromX(input.Position.X)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    setValue(initialVal)
end

createSlider(298, FLY_MIN, FLY_MAX, flySpeed, "Fly speed", function(val)
    flySpeed = val
end)

createSlider(354, CAM_MIN, CAM_MAX, freecamSpeed, "Cam speed", function(val)
    freecamSpeed = val
end)

-- ===== Controls legend =====

local controlsToggle = Instance.new("TextButton")
controlsToggle.Size = UDim2.fromOffset(24, 24)
controlsToggle.Position = UDim2.new(1, -32, 0, 8)
controlsToggle.BackgroundColor3 = Color3.fromRGB(65, 65, 80)
controlsToggle.TextColor3 = Color3.new(1, 1, 1)
controlsToggle.TextSize = 14
controlsToggle.Font = Enum.Font.GothamBold
controlsToggle.Text = "?"
controlsToggle.Parent = frame
Instance.new("UICorner", controlsToggle).CornerRadius = UDim.new(1, 0)

local controlsFrame = Instance.new("Frame")
controlsFrame.Size = UDim2.fromOffset(200, 182)
controlsFrame.Position = UDim2.fromOffset(10, 410)
controlsFrame.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
controlsFrame.Visible = false
controlsFrame.Parent = frame
Instance.new("UICorner", controlsFrame).CornerRadius = UDim.new(0, 8)

local controlsTitle = Instance.new("TextLabel")
controlsTitle.Size = UDim2.new(1, -16, 0, 20)
controlsTitle.Position = UDim2.fromOffset(8, 6)
controlsTitle.BackgroundTransparency = 1
controlsTitle.TextColor3 = Color3.new(1, 1, 1)
controlsTitle.TextSize = 14
controlsTitle.Font = Enum.Font.GothamBold
controlsTitle.TextXAlignment = Enum.TextXAlignment.Left
controlsTitle.Text = "Controls"
controlsTitle.Parent = controlsFrame

local controlsList = Instance.new("TextLabel")
controlsList.Size = UDim2.new(1, -16, 0, 148)
controlsList.Position = UDim2.fromOffset(8, 28)
controlsList.BackgroundTransparency = 1
controlsList.TextColor3 = Color3.fromRGB(210, 210, 220)
controlsList.TextSize = 13
controlsList.Font = Enum.Font.Gotham
controlsList.TextXAlignment = Enum.TextXAlignment.Left
controlsList.TextYAlignment = Enum.TextYAlignment.Top
controlsList.TextWrapped = true
controlsList.Text =
    "F — Toggle flight\n" ..
    "N — Toggle noclip\n" ..
    "C — Toggle freecam\n" ..
    "V — Toggle ESP\n" ..
    "Space/Ctrl — Fly up/down\n" ..
    "WASD/Q/E — Move in freecam\n" ..
    "Mouse — Look around in freecam\n" ..
    "Touch Fling — fling others on touch\n" ..
    "Spectate — pick a player, then\n" ..
    "teleport to them or stop\n" ..
    "Drag bars — Adjust speeds\n" ..
    "Drag panel — Move this window"
controlsList.Parent = controlsFrame

controlsToggle.MouseButton1Click:Connect(function()
    controlsFrame.Visible = not controlsFrame.Visible
end)

-- ===== Flight =====

local function stopFlying()
    flying = false
    button.Text = "Flight: OFF"
    button.BackgroundColor3 = Color3.fromRGB(65, 65, 80)

    if flightConnection then
        flightConnection:Disconnect()
        flightConnection = nil
    end

    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.AutoRotate = true
    end
end

local function startFlying()
    local character = player.Character or player.CharacterAdded:Wait()
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not root then
        return
    end

    flying = true
    button.Text = "Flight: ON"
    button.BackgroundColor3 = Color3.fromRGB(55, 150, 90)
    humanoid.AutoRotate = false

    flightConnection = RunService.Heartbeat:Connect(function()
        if not flying or not root.Parent then
            return
        end

        local vertical = 0
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            vertical += 1
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            vertical -= 1
        end

        root.AssemblyLinearVelocity =
            (humanoid.MoveDirection * flySpeed) + Vector3.new(0, vertical * flySpeed, 0)
    end)
end

local function toggleFlight()
    if flying then
        stopFlying()
    else
        startFlying()
    end
end

-- ===== Noclip =====

local function setCharacterCollisions(character, collidable)
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = collidable
        end
    end
end

local function stopNoclip()
    noclip = false
    noclipButton.Text = "Noclip: OFF"
    noclipButton.BackgroundColor3 = Color3.fromRGB(65, 65, 80)

    if noclipConnection then
        noclipConnection:Disconnect()
        noclipConnection = nil
    end

    local character = player.Character
    if character then
        setCharacterCollisions(character, true)
    end
end

local function startNoclip()
    local character = player.Character or player.CharacterAdded:Wait()
    noclip = true
    noclipButton.Text = "Noclip: ON"
    noclipButton.BackgroundColor3 = Color3.fromRGB(55, 150, 90)

    noclipConnection = RunService.Stepped:Connect(function()
        if not noclip or not character.Parent then
            return
        end
        setCharacterCollisions(character, false)
    end)
end

local function toggleNoclip()
    if noclip then
        stopNoclip()
    else
        startNoclip()
    end
end

-- ===== Freecam =====

local function freezeCharacter(character)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        savedWalkSpeed = humanoid.WalkSpeed
        savedJumpPower = humanoid.JumpPower
        humanoid.WalkSpeed = 0
        humanoid.JumpPower = 0
    end
end

local function unfreezeCharacter(character)
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.WalkSpeed = savedWalkSpeed or 16
        humanoid.JumpPower = savedJumpPower or 50
    end
end

local function stopFreecam()
    freecam = false
    freecamButton.Text = "Freecam: OFF"
    freecamButton.BackgroundColor3 = Color3.fromRGB(65, 65, 80)

    if freecamConnection then
        freecamConnection:Disconnect()
        freecamConnection = nil
    end

    local camera = Workspace.CurrentCamera
    if camera then
        camera.CameraType = savedCameraType or Enum.CameraType.Custom
        if savedCameraSubject then
            camera.CameraSubject = savedCameraSubject
        end
    end

    if freecamPart then
        freecamPart:Destroy()
        freecamPart = nil
    end

    UserInputService.MouseBehavior = savedMouseBehavior or Enum.MouseBehavior.Default
    UserInputService.MouseIconEnabled = true

    local character = player.Character
    if character then
        unfreezeCharacter(character)
    end
end

local function startFreecam()
    local camera = Workspace.CurrentCamera
    if not camera then
        return
    end

    local character = player.Character
    if character then
        freezeCharacter(character)
    end

    freecam = true
    freecamButton.Text = "Freecam: ON"
    freecamButton.BackgroundColor3 = Color3.fromRGB(55, 150, 90)

    savedCameraType = camera.CameraType
    savedCameraSubject = camera.CameraSubject
    savedMouseBehavior = UserInputService.MouseBehavior

    freecamPart = Instance.new("Part")
    freecamPart.Name = "FreecamAnchor"
    freecamPart.Size = Vector3.new(1, 1, 1)
    freecamPart.Transparency = 1
    freecamPart.CanCollide = false
    freecamPart.Anchored = true
    freecamPart.CFrame = camera.CFrame
    freecamPart.Parent = Workspace

    camera.CameraType = Enum.CameraType.Scriptable
    camera.CFrame = freecamPart.CFrame

    local lookVector = camera.CFrame.LookVector
    camYaw = math.atan2(-lookVector.X, -lookVector.Z)
    camPitch = math.asin(math.clamp(lookVector.Y, -1, 1))

    UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
    UserInputService.MouseIconEnabled = false

    local mouseSensitivity = 0.0025

    freecamConnection = RunService.Heartbeat:Connect(function(dt)
        if not freecam then
            return
        end

        local delta = UserInputService:GetMouseDelta()
        camYaw -= delta.X * mouseSensitivity
        camPitch = math.clamp(camPitch - delta.Y * mouseSensitivity, math.rad(-89), math.rad(89))

        local rotationCFrame = CFrame.Angles(0, camYaw, 0) * CFrame.Angles(camPitch, 0, 0)

        local moveVector = Vector3.new(0, 0, 0)
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then
            moveVector += rotationCFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then
            moveVector -= rotationCFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then
            moveVector -= rotationCFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then
            moveVector += rotationCFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.E) then
            moveVector += Vector3.new(0, 1, 0)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Q) then
            moveVector -= Vector3.new(0, 1, 0)
        end

        if moveVector.Magnitude > 0 then
            moveVector = moveVector.Unit * freecamSpeed * dt
        end

        local newPosition = camera.CFrame.Position + moveVector
        camera.CFrame = CFrame.new(newPosition) * rotationCFrame
    end)
end

local function toggleFreecam()
    if freecam then
        stopFreecam()
    else
        startFreecam()
    end
end

-- ===== ESP =====

local function createEspForPlayer(targetPlayer)
    local character = targetPlayer.Character
    if not character then
        return
    end

    local highlight = Instance.new("Highlight")
    highlight.Name = "ComfyESP"
    highlight.FillColor = ESP_FILL_COLOR
    highlight.FillTransparency = ESP_FILL_TRANSPARENCY
    highlight.OutlineColor = ESP_OUTLINE_COLOR
    highlight.OutlineTransparency = ESP_OUTLINE_TRANSPARENCY
    highlight.DepthMode = Enum.HighlightDepthMode.Occluded
    highlight.Adornee = character
    highlight.Parent = character

    local head = character:FindFirstChild("Head")
    local billboard, distLabel
    if head then
        billboard = Instance.new("BillboardGui")
        billboard.Name = "ComfyESPLabel"
        billboard.Size = UDim2.fromOffset(140, 36)
        billboard.StudsOffset = Vector3.new(0, 1.6, 0)
        billboard.AlwaysOnTop = true
        billboard.Adornee = head
        billboard.Parent = head

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1, 0, 0, 18)
        nameLabel.BackgroundTransparency = 1
        nameLabel.TextColor3 = Color3.fromRGB(225, 240, 255)
        nameLabel.TextStrokeTransparency = 0.6
        nameLabel.Font = Enum.Font.GothamMedium
        nameLabel.TextSize = 14
        nameLabel.Text = targetPlayer.DisplayName
        nameLabel.Parent = billboard

        distLabel = Instance.new("TextLabel")
        distLabel.Name = "DistLabel"
        distLabel.Size = UDim2.new(1, 0, 0, 16)
        distLabel.Position = UDim2.fromOffset(0, 18)
        distLabel.BackgroundTransparency = 1
        distLabel.TextColor3 = Color3.fromRGB(170, 200, 220)
        distLabel.TextStrokeTransparency = 0.7
        distLabel.Font = Enum.Font.Gotham
        distLabel.TextSize = 12
        distLabel.Text = ""
        distLabel.Parent = billboard
    end

    espHighlights[targetPlayer] = highlight
    espBillboards[targetPlayer] = billboard
end

local function removeEspForPlayer(targetPlayer)
    local highlight = espHighlights[targetPlayer]
    if highlight then
        highlight:Destroy()
        espHighlights[targetPlayer] = nil
    end

    local billboard = espBillboards[targetPlayer]
    if billboard then
        billboard:Destroy()
        espBillboards[targetPlayer] = nil
    end
end

local function refreshAllEsp()
    for _, targetPlayer in ipairs(Players:GetPlayers()) do
        if targetPlayer ~= player and not espHighlights[targetPlayer] then
            createEspForPlayer(targetPlayer)
        end
    end
end

local function stopEsp()
    espEnabled = false
    espButton.Text = "ESP: OFF"
    espButton.BackgroundColor3 = Color3.fromRGB(65, 65, 80)

    if espConnection then
        espConnection:Disconnect()
        espConnection = nil
    end

    for targetPlayer in pairs(espHighlights) do
        removeEspForPlayer(targetPlayer)
    end
end

local function startEsp()
    espEnabled = true
    espButton.Text = "ESP: ON"
    espButton.BackgroundColor3 = Color3.fromRGB(55, 150, 90)

    refreshAllEsp()

    espConnection = RunService.Heartbeat:Connect(function()
        if not espEnabled then
            return
        end

        local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")

        for targetPlayer, billboard in pairs(espBillboards) do
            if billboard and billboard.Parent then
                local targetChar = targetPlayer.Character
                local targetRoot = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
                local distLabel = billboard:FindFirstChild("DistLabel")

                if myRoot and targetRoot and distLabel then
                    local distance = math.floor((myRoot.Position - targetRoot.Position).Magnitude)
                    distLabel.Text = distance .. "m"

                    local fade = math.clamp(distance / 250, 0, 0.6)
                    local highlight = espHighlights[targetPlayer]
                    if highlight then
                        highlight.FillTransparency = ESP_FILL_TRANSPARENCY + fade * 0.2
                        highlight.OutlineTransparency = ESP_OUTLINE_TRANSPARENCY + fade * 0.5
                    end
                end
            end
        end
    end)
end

local function toggleEsp()
    if espEnabled then
        stopEsp()
    else
        startEsp()
    end
end

-- ===== Spectate =====

local spectatePanel = Instance.new("Frame")
spectatePanel.Size = UDim2.fromOffset(200, 220)
spectatePanel.Position = UDim2.fromOffset(230, 10)
spectatePanel.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
spectatePanel.Visible = false
spectatePanel.Parent = frame
Instance.new("UICorner", spectatePanel).CornerRadius = UDim.new(0, 8)

local spectateTitle = Instance.new("TextLabel")
spectateTitle.Size = UDim2.new(1, -16, 0, 20)
spectateTitle.Position = UDim2.fromOffset(8, 6)
spectateTitle.BackgroundTransparency = 1
spectateTitle.TextColor3 = Color3.new(1, 1, 1)
spectateTitle.TextSize = 14
spectateTitle.Font = Enum.Font.GothamBold
spectateTitle.TextXAlignment = Enum.TextXAlignment.Left
spectateTitle.Text = "Spectate a player"
spectateTitle.Parent = spectatePanel

local spectateListFrame = Instance.new("ScrollingFrame")
spectateListFrame.Size = UDim2.new(1, -16, 1, -40)
spectateListFrame.Position = UDim2.fromOffset(8, 32)
spectateListFrame.BackgroundTransparency = 1
spectateListFrame.ScrollBarThickness = 4
spectateListFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
spectateListFrame.Parent = spectatePanel

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 6)
listLayout.Parent = spectateListFrame

local spectatingFrame = Instance.new("Frame")
spectatingFrame.Size = UDim2.new(1, -16, 1, -40)
spectatingFrame.Position = UDim2.fromOffset(8, 32)
spectatingFrame.BackgroundTransparency = 1
spectatingFrame.Visible = false
spectatingFrame.Parent = spectatePanel

local spectatingLabel = Instance.new("TextLabel")
spectatingLabel.Size = UDim2.new(1, 0, 0, 24)
spectatingLabel.BackgroundTransparency = 1
spectatingLabel.TextColor3 = Color3.new(1, 1, 1)
spectatingLabel.TextSize = 15
spectatingLabel.Font = Enum.Font.GothamBold
spectatingLabel.TextXAlignment = Enum.TextXAlignment.Left
spectatingLabel.TextWrapped = true
spectatingLabel.Text = ""
spectatingLabel.Parent = spectatingFrame

local teleportButton = Instance.new("TextButton")
teleportButton.Size = UDim2.new(1, 0, 0, 36)
teleportButton.Position = UDim2.fromOffset(0, 36)
teleportButton.BackgroundColor3 = Color3.fromRGB(65, 130, 200)
teleportButton.TextColor3 = Color3.new(1, 1, 1)
teleportButton.TextSize = 14
teleportButton.Font = Enum.Font.GothamBold
teleportButton.TextWrapped = true
teleportButton.Text = "Teleport"
teleportButton.Parent = spectatingFrame
Instance.new("UICorner", teleportButton).CornerRadius = UDim.new(0, 7)

local stopSpectateButton = Instance.new("TextButton")
stopSpectateButton.Size = UDim2.new(1, 0, 0, 36)
stopSpectateButton.Position = UDim2.fromOffset(0, 80)
stopSpectateButton.BackgroundColor3 = Color3.fromRGB(150, 60, 60)
stopSpectateButton.TextColor3 = Color3.new(1, 1, 1)
stopSpectateButton.TextSize = 14
stopSpectateButton.Font = Enum.Font.GothamBold
stopSpectateButton.Text = "Stop Spectating"
stopSpectateButton.Parent = spectatingFrame
Instance.new("UICorner", stopSpectateButton).CornerRadius = UDim.new(0, 7)

local spectateEntryButtons = {}

local function clearSpectateList()
    for _, btn in ipairs(spectateEntryButtons) do
        btn:Destroy()
    end
    spectateEntryButtons = {}
end

local function stopSpectate()
    spectating = false
    spectateTarget = nil

    local camera = Workspace.CurrentCamera
    local myHumanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")

    if camera then
        camera.CameraType = savedSpecCameraType or Enum.CameraType.Custom
        camera.CameraSubject = savedSpecCameraSubject or myHumanoid
    end

    spectatingFrame.Visible = false
    spectateListFrame.Visible = true
end

local function startSpectate(targetPlayer)
    local character = targetPlayer.Character
    if not character then
        return
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        return
    end

    local camera = Workspace.CurrentCamera
    if not spectating then
        savedSpecCameraType = camera.CameraType
        savedSpecCameraSubject = camera.CameraSubject
    end

    spectating = true
    spectateTarget = targetPlayer
    camera.CameraType = Enum.CameraType.Custom
    camera.CameraSubject = humanoid

    spectateListFrame.Visible = false
    spectatingFrame.Visible = true
    spectatingLabel.Text = "Spectating: " .. targetPlayer.DisplayName
    teleportButton.Text = "Teleport to " .. targetPlayer.DisplayName
end

local function teleportToSpectateTarget()
    if not spectateTarget then
        return
    end

    local targetChar = spectateTarget.Character
    local myChar = player.Character
    if not targetChar or not myChar then
        return
    end

    local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    if targetRoot and myRoot then
        myRoot.CFrame = targetRoot.CFrame * CFrame.new(3, 0, 3)
    end
end

local function refreshSpectateList()
    clearSpectateList()

    for _, targetPlayer in ipairs(Players:GetPlayers()) do
        if targetPlayer ~= player then
            local entry = Instance.new("TextButton")
            entry.Size = UDim2.new(1, 0, 0, 32)
            entry.BackgroundColor3 = Color3.fromRGB(50, 50, 62)
            entry.TextColor3 = Color3.new(1, 1, 1)
            entry.TextSize = 14
            entry.Font = Enum.Font.Gotham
            entry.Text = targetPlayer.DisplayName
            entry.LayoutOrder = #spectateEntryButtons
            entry.Parent = spectateListFrame
            Instance.new("UICorner", entry).CornerRadius = UDim.new(0, 6)

            entry.MouseButton1Click:Connect(function()
                startSpectate(targetPlayer)
            end)

            table.insert(spectateEntryButtons, entry)
        end
    end

    spectateListFrame.CanvasSize = UDim2.new(0, 0, 0, #spectateEntryButtons * 38)
end

teleportButton.MouseButton1Click:Connect(teleportToSpectateTarget)
stopSpectateButton.MouseButton1Click:Connect(stopSpectate)

spectateToggleButton.MouseButton1Click:Connect(function()
    spectatePanel.Visible = not spectatePanel.Visible
    if spectatePanel.Visible and not spectating then
        refreshSpectateList()
    end
end)

-- ===== Roster-change handling (shared by ESP + Spectate) =====

Players.PlayerAdded:Connect(function(newPlayer)
    if spectatePanel.Visible and not spectating then
        refreshSpectateList()
    end

    newPlayer.CharacterAdded:Connect(function(newChar)
        if espEnabled then
            task.wait(0.5)
            removeEspForPlayer(newPlayer)
            createEspForPlayer(newPlayer)
        end

        if spectating and spectateTarget == newPlayer then
            task.wait(0.5)
            local humanoid = newChar:FindFirstChildOfClass("Humanoid")
            if humanoid then
                Workspace.CurrentCamera.CameraSubject = humanoid
            end
        end
    end)
end)

Players.PlayerRemoving:Connect(function(leavingPlayer)
    removeEspForPlayer(leavingPlayer)

    if spectateTarget == leavingPlayer then
        stopSpectate()
    end
    if spectatePanel.Visible then
        refreshSpectateList()
    end
end)

for _, existingPlayer in ipairs(Players:GetPlayers()) do
    if existingPlayer ~= player then
        existingPlayer.CharacterAdded:Connect(function(newChar)
            if espEnabled then
                task.wait(0.5)
                removeEspForPlayer(existingPlayer)
                createEspForPlayer(existingPlayer)
            end

            if spectating and spectateTarget == existingPlayer then
                task.wait(0.5)
                local humanoid = newChar:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    Workspace.CurrentCamera.CameraSubject = humanoid
                end
            end
        end)
    end
end

-- ===== Input bindings =====

button.MouseButton1Click:Connect(toggleFlight)
noclipButton.MouseButton1Click:Connect(toggleNoclip)
freecamButton.MouseButton1Click:Connect(toggleFreecam)
espButton.MouseButton1Click:Connect(toggleEsp)
touchFlingButton.Activated:Connect(toggleTouchFling)

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then
        return
    end

    if input.KeyCode == Enum.KeyCode.F then
        toggleFlight()
    elseif input.KeyCode == Enum.KeyCode.N then
        toggleNoclip()
    elseif input.KeyCode == Enum.KeyCode.C then
        toggleFreecam()
    elseif input.KeyCode == Enum.KeyCode.V then
        toggleEsp()
    end
end)

player.CharacterAdded:Connect(function(character)
    clearFlingConnections()
    if touchFlingEnabled then
        connectFlingTouched(character)
    end

    stopFlying()
    stopNoclip()
    stopFreecam()
    stopSpectate()
end)
print(ProtectionConfig.HubName .. " Loaded Successfully!")
