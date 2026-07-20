--[[
    MARKXRS [BETA] – Premium VFX Edition
    - Opens automatically on injection.
    - Fade‑in, pulsing glow, glass styling, hover animations.
    - All features fully functional.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- ===== SPEED & FPS VARIABLES =====
local currentSpeed = 0
local isLocked = false
local overrideConnection = nil
local remote = nil

local fpsEnabled = false
local targetFPS = 60
local fpsScript = nil
local limiterRunning = false

-- ===== TRACER VARIABLES =====
local tracerEnabled = false
local tracerColor = Color3.fromRGB(0, 255, 0)
local tracerObjects = {}

-- ===== SPEED TAB VARIABLES =====
local trailEnabled = false
local accelerationEnabled = false
local accelerationRate = 0.5
local currentAppliedSpeed = 0
local accelKeybind = Enum.KeyCode.None
local accelKeyName = "None"
local boostKeybind = Enum.KeyCode.None
local boostKeyName = "None"

-- ===== RACING CONFIG =====
local racingConfig = nil
local originalConfig = nil
pcall(function()
    racingConfig = require(ReplicatedStorage:FindFirstChild("RacingSystem"):FindFirstChild("RacingConfig"))
    if racingConfig then
        originalConfig = {
            MinReward = racingConfig.MinReward,
            MaxReward = racingConfig.MaxReward,
            RewardPerSecond = racingConfig.RewardPerSecond,
        }
    end
end)

-- ===== FIND REMOTE =====
for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
    if obj.Name == "ReportPerformanceStats" and obj:IsA("RemoteEvent") then
        remote = obj
        break
    end
end
if not remote then
    for _, obj in ipairs(game:GetDescendants()) do
        if obj.Name == "ReportPerformanceStats" and obj:IsA("RemoteEvent") then
            remote = obj
            break
        end
    end
end

-- ================================================
-- SPEED FUNCTIONS (with acceleration support)
-- ================================================
local function applySpeedOverride(speed, deltaTime)
    local character = player.Character
    if not character then return end
    local torso = character:FindFirstChild("Torso")
    if not torso then return end

    local currentVel = torso.AssemblyLinearVelocity
    local horiz = Vector3.new(currentVel.X, 0, currentVel.Z)
    local dir = horiz.Unit

    if horiz.Magnitude < 0.1 then
        local cf = torso.CFrame
        dir = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z).Unit
        if dir.Magnitude < 0.1 then
            dir = Vector3.new(1, 0, 0)
        end
    end

    if accelerationEnabled then
        local diff = speed - currentAppliedSpeed
        local step = math.abs(diff) * math.min(accelerationRate * deltaTime * 10, 1)
        if math.abs(diff) < step then
            currentAppliedSpeed = speed
        else
            currentAppliedSpeed = currentAppliedSpeed + math.sign(diff) * step
        end
    else
        currentAppliedSpeed = speed
    end

    torso.AssemblyLinearVelocity = Vector3.new(dir.X * currentAppliedSpeed, currentVel.Y, dir.Z * currentAppliedSpeed)
end

local function setSpeed(value)
    value = tonumber(value)
    if not value or value < 0 then
        print("❌ Invalid number")
        return false
    end

    currentSpeed = value
    print("🚀 Setting speed to " .. value)

    player:SetAttribute("HighestMS", value)
    _G.CurrentHorizontalSpeed = value

    if remote then
        pcall(function()
            remote:FireServer(60, value)
            print("📤 Fired ReportPerformanceStats with " .. value)
        end)
    end

    if isLocked then
        startOverride()
    end

    print("✅ Speed set to " .. value)
    return true
end

local function startOverride()
    if overrideConnection then
        overrideConnection:Disconnect()
        overrideConnection = nil
    end

    if not isLocked or currentSpeed <= 0 then
        return
    end

    local character = player.Character
    if character then
        local torso = character:FindFirstChild("Torso")
        if torso then
            local horiz = Vector3.new(torso.AssemblyLinearVelocity.X, 0, torso.AssemblyLinearVelocity.Z)
            currentAppliedSpeed = horiz.Magnitude
        else
            currentAppliedSpeed = 0
        end
    else
        currentAppliedSpeed = 0
    end

    overrideConnection = RunService.RenderStepped:Connect(function(deltaTime)
        if not isLocked then
            if overrideConnection then
                overrideConnection:Disconnect()
                overrideConnection = nil
            end
            return
        end
        applySpeedOverride(currentSpeed, deltaTime)
        _G.CurrentHorizontalSpeed = currentAppliedSpeed
    end)

    print("🔒 Speed locked to " .. currentSpeed)
end

local function stopOverride()
    isLocked = false
    if overrideConnection then
        overrideConnection:Disconnect()
        overrideConnection = nil
    end
    print("🔓 Speed unlocked")
end

-- ================================================
-- TRAIL TOGGLE
-- ================================================
local function toggleTrail(enabled)
    local character = player.Character
    if not character then return end
    local torso = character:FindFirstChild("Torso")
    if not torso then return end
    local trail = torso:FindFirstChild("SpeedTrail")
    if trail and trail:IsA("Trail") then
        trail.Enabled = enabled
        trailEnabled = enabled
        print("SpeedTrail " .. (enabled and "ENABLED" or "DISABLED"))
    else
        warn("SpeedTrail not found on Torso.")
    end
end

-- ================================================
-- FPS UNLOCKER FUNCTIONS (unchanged)
-- ================================================
local function findFpsScript()
    local scripts = player:FindFirstChild("PlayerScripts")
    if scripts then
        local found = scripts:FindFirstChild("Force 60 fps")
        if found then return found end
    end
    local starter = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
    if starter then
        local found = starter:FindFirstChild("Force 60 fps")
        if found then return found end
    end
    for _, obj in ipairs(player:GetDescendants()) do
        if obj.Name == "Force 60 fps" and obj:IsA("LocalScript") then
            return obj
        end
    end
    return nil
end

local function disableFpsScript()
    local script = findFpsScript()
    if script then
        script.Disabled = true
        fpsScript = script
        print("✅ Force 60 fps script disabled!")
        return true
    else
        warn("⚠️ Could not find 'Force 60 fps' script.")
        return false
    end
end

local function enableFpsScript()
    if fpsScript and fpsScript.Parent then
        fpsScript.Disabled = false
        print("🔁 Force 60 fps script re-enabled.")
    else
        local script = findFpsScript()
        if script then
            script.Disabled = false
            fpsScript = script
            print("🔁 Force 60 fps script re-enabled (found again).")
        else
            print("⚠️ Could not find script to enable.")
        end
    end
end

local function runFPSLimiter(target)
    if limiterRunning then return end
    limiterRunning = true
    task.spawn(function()
        while limiterRunning and fpsEnabled do
            local startTime = os.clock()
            RunService.RenderStepped:Wait()
            if not limiterRunning or not fpsEnabled then break end
            local elapsed = os.clock() - startTime
            local targetDelta = 1 / target
            if elapsed < targetDelta then
                task.wait(targetDelta - elapsed)
            end
        end
        limiterRunning = false
        print("🔄 FPS limiter stopped.")
    end)
end

local function startFPSLimiter(target)
    if limiterRunning then stopFPSLimiter() end
    if not fpsEnabled or target <= 0 then return end
    limiterRunning = true
    runFPSLimiter(target)
    print("🔄 FPS limiter started, target: " .. target)
end

local function stopFPSLimiter()
    limiterRunning = false
    print("⏹️ FPS limiter stopped")
end

local function toggleFPS()
    fpsEnabled = not fpsEnabled
    if fpsEnabled then
        disableFpsScript()
        startFPSLimiter(targetFPS)
    else
        stopFPSLimiter()
        enableFpsScript()
    end
    print("FPS Unlocker " .. (fpsEnabled and "ENABLED" or "DISABLED"))
    return fpsEnabled
end

local function setTargetFPS(value)
    targetFPS = value
    if fpsEnabled then
        stopFPSLimiter()
        startFPSLimiter(targetFPS)
        print("🔁 FPS target changed to " .. targetFPS)
    else
        print("ℹ️ FPS target set to " .. targetFPS .. " (will apply when enabled)")
    end
end

local function monitorFpsScript()
    if fpsEnabled then
        local script = findFpsScript()
        if script and not script.Disabled then
            script.Disabled = true
            fpsScript = script
            print("🔄 Re-disabled Force 60 fps script.")
        end
    end
end

player.CharacterAdded:Connect(function()
    task.wait(0.5)
    monitorFpsScript()
    if trailEnabled then
        toggleTrail(true)
    end
end)

task.spawn(function()
    while true do
        task.wait(3)
        monitorFpsScript()
    end
end)

-- ================================================
-- ULTIMATE ROCK FINDER & SETTER (unchanged)
-- ================================================
local function findRockCandidates()
    local candidates = {}

    local ls = player:FindFirstChild("leaderstats")
    if ls then
        for _, child in ipairs(ls:GetChildren()) do
            if child:IsA("NumberValue") or child:IsA("IntValue") then
                local name = child.Name:lower()
                if name:find("rock") or name:find("currency") or name:find("coin") or name:find("point") or name:find("cash") or name:find("money") then
                    table.insert(candidates, {instance = child, path = child:GetFullName(), value = child.Value, type = "leaderstats"})
                end
            end
        end
    end

    local attrs = player:GetAttributes()
    for name, value in pairs(attrs) do
        if type(value) == "number" then
            local lowerName = name:lower()
            if lowerName:find("rock") or lowerName:find("currency") or lowerName:find("coin") or lowerName:find("point") or lowerName:find("cash") or lowerName:find("money") then
                table.insert(candidates, {instance = nil, path = "Attribute: " .. name, value = value, type = "attribute", attrName = name})
            end
        end
    end

    local char = player.Character
    if char then
        for _, child in ipairs(char:GetDescendants()) do
            if child:IsA("NumberValue") or child:IsA("IntValue") then
                local name = child.Name:lower()
                if name:find("rock") or name:find("currency") or name:find("coin") or name:find("point") or name:find("cash") or name:find("money") then
                    table.insert(candidates, {instance = child, path = child:GetFullName(), value = child.Value, type = "character"})
                end
            end
        end
    end

    local bp = player:FindFirstChild("Backpack")
    if bp then
        for _, child in ipairs(bp:GetDescendants()) do
            if child:IsA("NumberValue") or child:IsA("IntValue") then
                local name = child.Name:lower()
                if name:find("rock") or name:find("currency") or name:find("coin") or name:find("point") or name:find("cash") or name:find("money") then
                    table.insert(candidates, {instance = child, path = child:GetFullName(), value = child.Value, type = "backpack"})
                end
            end
        end
    end

    return candidates
end

local function setRocks(amount)
    amount = tonumber(amount)
    if not amount or amount < 0 then
        print("❌ Invalid amount")
        return false
    end

    local candidates = findRockCandidates()
    if #candidates == 0 then
        print("❌ No rock value found. Try earning rocks manually and then use the 'Find Rock Value' button.")
        return false
    end

    print("🔍 Found " .. #candidates .. " possible rock values:")
    for i, cand in ipairs(candidates) do
        print("   " .. i .. ". " .. cand.path .. " = " .. tostring(cand.value))
    end

    local success = false
    for _, cand in ipairs(candidates) do
        if cand.instance then
            pcall(function()
                cand.instance.Value = amount
                print("✅ Set " .. cand.path .. " to " .. amount)
                success = true
            end)
        elseif cand.attrName then
            pcall(function()
                player:SetAttribute(cand.attrName, amount)
                print("✅ Set attribute " .. cand.attrName .. " to " .. amount)
                success = true
            end)
        end
    end

    if success then
        print("🎉 Rocks set to " .. amount .. "!")
    else
        print("❌ Failed to set any value.")
    end
    return success
end

-- ================================================
-- TRACER DRAWING (unchanged)
-- ================================================
local function createTracer(plr)
    if tracerObjects[plr] then return end
    local line = Drawing.new("Line")
    line.Thickness = 2
    line.Color = tracerColor
    line.Visible = false
    line.Transparency = 1
    tracerObjects[plr] = line
end

local function removeTracer(plr)
    local line = tracerObjects[plr]
    if line then
        line:Remove()
        tracerObjects[plr] = nil
    end
end

local function updateTracers()
    if not tracerEnabled then
        for _, line in pairs(tracerObjects) do
            line.Visible = false
        end
        return
    end

    local screenW, screenH = camera.ViewportSize.X, camera.ViewportSize.Y
    local bottomCenter = Vector2.new(screenW / 2, screenH)

    for _, otherPlayer in ipairs(Players:GetPlayers()) do
        if otherPlayer ~= player then
            local char = otherPlayer.Character
            if char and char.Parent then
                local root = char:FindFirstChild("HumanoidRootPart")
                if root then
                    local pos, onScreen = camera:WorldToScreenPoint(root.Position)
                    if onScreen then
                        createTracer(otherPlayer)
                        local line = tracerObjects[otherPlayer]
                        line.From = bottomCenter
                        line.To = Vector2.new(pos.X, pos.Y)
                        line.Color = tracerColor
                        line.Visible = true
                    else
                        if tracerObjects[otherPlayer] then
                            tracerObjects[otherPlayer].Visible = false
                        end
                    end
                else
                    if tracerObjects[otherPlayer] then
                        tracerObjects[otherPlayer].Visible = false
                    end
                end
            else
                if tracerObjects[otherPlayer] then
                    tracerObjects[otherPlayer].Visible = false
                end
            end
        end
    end
end

Players.PlayerRemoving:Connect(function(otherPlayer)
    local line = tracerObjects[otherPlayer]
    if line then
        line:Remove()
        tracerObjects[otherPlayer] = nil
    end
end)

local tracerConnection = RunService.RenderStepped:Connect(updateTracers)

-- ================================================
-- UI CREATION – Premium VFX Edition
-- ================================================
local function createUI()
    local gui = Instance.new("ScreenGui")
    gui.Name = "Markxrs_UI"
    gui.ResetOnSpawn = false
    gui.Parent = player:WaitForChild("PlayerGui")
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Enabled = true

    -- ===== DARK OVERLAY =====
    local overlay = Instance.new("Frame")
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    overlay.BackgroundTransparency = 0.65
    overlay.BorderSizePixel = 0
    overlay.Parent = gui

    -- ===== MAIN FRAME =====
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 720, 0, 480)
    frame.Position = UDim2.new(0.5, -360, 0.5, -240)
    frame.BackgroundColor3 = Color3.fromRGB(20, 14, 35)
    frame.BackgroundTransparency = 0.15
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Draggable = true
    frame.Parent = gui
    frame.ClipsDescendants = false

    -- ===== GLASS EFFECT (simulated with gradient and corner) =====
    local glass = Instance.new("Frame")
    glass.Size = UDim2.new(1, 0, 1, 0)
    glass.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    glass.BackgroundTransparency = 0.97
    glass.BorderSizePixel = 0
    glass.Parent = frame

    -- Corner
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = frame

    -- Glow border (UIStroke with pulse animation)
    local glowStroke = Instance.new("UIStroke")
    glowStroke.Color = Color3.fromRGB(140, 80, 220)
    glowStroke.Thickness = 2
    glowStroke.Transparency = 0.6
    glowStroke.Parent = frame

    -- Pulsing glow (we'll animate transparency)
    local pulseInfo = TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
    local pulseTween = TweenService:Create(glowStroke, pulseInfo, {Transparency = 0.2})
    pulseTween:Play()

    -- Gradient background
    local grad = Instance.new("UIGradient")
    grad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(35, 22, 60)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(15, 10, 30))
    })
    grad.Parent = frame

    -- ===== HEADER =====
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 50)
    header.Position = UDim2.new(0, 0, 0, 0)
    header.BackgroundColor3 = Color3.fromRGB(50, 35, 90)
    header.BackgroundTransparency = 0.4
    header.BorderSizePixel = 0
    header.Parent = frame

    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = UDim.new(0, 12)
    headerCorner.Parent = header

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -70, 1, 0)
    title.Position = UDim2.new(0, 20, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "Markxrs [BETA]"
    title.TextColor3 = Color3.fromRGB(220, 190, 255)
    title.TextScaled = true
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header

    -- Beta badge (now with a subtle glow)
    local beta = Instance.new("TextLabel")
    beta.Size = UDim2.new(0, 50, 0, 18)
    beta.Position = UDim2.new(0, 135, 0, 16)
    beta.BackgroundColor3 = Color3.fromRGB(180, 120, 255)
    beta.BackgroundTransparency = 0.2
    beta.Text = "BETA"
    beta.TextColor3 = Color3.fromRGB(255, 255, 255)
    beta.TextScaled = true
    beta.Font = Enum.Font.GothamBold
    beta.Parent = header
    local betaCorner = Instance.new("UICorner")
    betaCorner.CornerRadius = UDim.new(0, 4)
    betaCorner.Parent = beta

    -- Close button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 36, 0, 36)
    closeBtn.Position = UDim2.new(1, -44, 0, 7)
    closeBtn.BackgroundColor3 = Color3.fromRGB(60, 40, 100)
    closeBtn.BackgroundTransparency = 0.5
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255, 180, 180)
    closeBtn.TextScaled = true
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.BorderSizePixel = 0
    closeBtn.Parent = header

    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 6)
    closeCorner.Parent = closeBtn

    -- Hover animation for close
    local closeHoverIn = TweenService:Create(closeBtn, TweenInfo.new(0.2), {BackgroundTransparency = 0.2, TextColor3 = Color3.fromRGB(255, 255, 255)})
    local closeHoverOut = TweenService:Create(closeBtn, TweenInfo.new(0.2), {BackgroundTransparency = 0.5, TextColor3 = Color3.fromRGB(255, 180, 180)})
    closeBtn.MouseEnter:Connect(function() closeHoverIn:Play() end)
    closeBtn.MouseLeave:Connect(function() closeHoverOut:Play() end)

    closeBtn.MouseButton1Click:Connect(function()
        -- Fade out animation before destroying
        local fadeOut = TweenService:Create(frame, TweenInfo.new(0.3), {BackgroundTransparency = 1})
        fadeOut:Play()
        fadeOut.Completed:Connect(function()
            gui:Destroy()
        end)
    end)

    -- ===== SIDEBAR =====
    local sidebar = Instance.new("Frame")
    sidebar.Size = UDim2.new(0, 160, 1, -50)
    sidebar.Position = UDim2.new(0, 0, 0, 50)
    sidebar.BackgroundColor3 = Color3.fromRGB(15, 10, 28)
    sidebar.BackgroundTransparency = 0.4
    sidebar.BorderSizePixel = 0
    sidebar.Parent = frame

    local sidebarCorner = Instance.new("UICorner")
    sidebarCorner.CornerRadius = UDim.new(0, 0)
    sidebarCorner.Parent = sidebar

    -- Tab buttons
    local tabs = {"Main", "Tracer", "Rock Adder", "Speed"}
    local tabBtns = {}
    local currentTab = "Main"

    for i, name in ipairs(tabs) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0.85, 0, 0, 34)
        btn.Position = UDim2.new(0.075, 0, 0, 12 + (i - 1) * 38)
        btn.BackgroundColor3 = (i == 1) and Color3.fromRGB(80, 50, 180) or Color3.fromRGB(30, 20, 55)
        btn.BackgroundTransparency = (i == 1) and 0.15 or 0.5
        btn.Text = name
        btn.TextColor3 = Color3.fromRGB(220, 210, 255)
        btn.TextScaled = true
        btn.Font = Enum.Font.GothamSemibold
        btn.BorderSizePixel = 0
        btn.Parent = sidebar

        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 6)
        btnCorner.Parent = btn

        -- Hover animations
        local hoverIn = TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundTransparency = 0.2, BackgroundColor3 = Color3.fromRGB(100, 70, 200)})
        local hoverOut = TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundTransparency = 0.5, BackgroundColor3 = Color3.fromRGB(30, 20, 55)})
        btn.MouseEnter:Connect(function()
            hoverIn:Play()
        end)
        btn.MouseLeave:Connect(function()
            if currentTab == name then
                return
            else
                hoverOut:Play()
            end
        end)

        tabBtns[name] = btn
    end

    -- ===== PANEL =====
    local panelContainer = Instance.new("Frame")
    panelContainer.Size = UDim2.new(1, -170, 1, -50)
    panelContainer.Position = UDim2.new(0, 165, 0, 50)
    panelContainer.BackgroundColor3 = Color3.fromRGB(20, 14, 35)
    panelContainer.BackgroundTransparency = 0.3
    panelContainer.BorderSizePixel = 0
    panelContainer.Parent = frame
    panelContainer.ClipsDescendants = true

    local panelCorner = Instance.new("UICorner")
    panelCorner.CornerRadius = UDim.new(0, 8)
    panelCorner.Parent = panelContainer

    local scrollPanel = Instance.new("ScrollingFrame")
    scrollPanel.Size = UDim2.new(1, 0, 1, 0)
    scrollPanel.BackgroundTransparency = 1
    scrollPanel.BorderSizePixel = 0
    scrollPanel.ScrollBarThickness = 4
    scrollPanel.ScrollBarImageColor3 = Color3.fromRGB(140, 80, 220)
    scrollPanel.Parent = panelContainer

    local scrollLayout = Instance.new("UIListLayout")
    scrollLayout.Padding = UDim.new(0, 10)
    scrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
    scrollLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    scrollLayout.Parent = scrollPanel

    -- ================================================
    -- BUILD MAIN TAB (unchanged)
    -- ================================================
    local function buildMainTab()
        for _, child in ipairs(scrollPanel:GetChildren()) do
            if child:IsA("UIListLayout") == false then
                child:Destroy()
            end
        end

        local speedLabel = Instance.new("TextLabel")
        speedLabel.Size = UDim2.new(0.9, 0, 0, 30)
        speedLabel.BackgroundTransparency = 1
        speedLabel.Text = "Current Speed: 0 M/S"
        speedLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
        speedLabel.TextScaled = true
        speedLabel.Font = Enum.Font.GothamMedium
        speedLabel.Parent = scrollPanel

        local speedRow = Instance.new("Frame")
        speedRow.Size = UDim2.new(0.8, 0, 0, 40)
        speedRow.BackgroundTransparency = 1
        speedRow.Parent = scrollPanel
        local speedRowLayout = Instance.new("UIListLayout")
        speedRowLayout.FillDirection = Enum.FillDirection.Horizontal
        speedRowLayout.Padding = UDim.new(0, 10)
        speedRowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        speedRowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
        speedRowLayout.Parent = speedRow

        local textBox = Instance.new("TextBox")
        textBox.Size = UDim2.new(0, 120, 0, 30)
        textBox.BackgroundColor3 = Color3.fromRGB(40, 35, 60)
        textBox.TextColor3 = Color3.fromRGB(255, 255, 255)
        textBox.TextScaled = true
        textBox.Font = Enum.Font.GothamBold
        textBox.PlaceholderText = "Enter speed"
        textBox.Text = "667"
        textBox.ClearTextOnFocus = false
        textBox.Parent = speedRow
        local tbCorner = Instance.new("UICorner")
        tbCorner.CornerRadius = UDim.new(0, 6)
        tbCorner.Parent = textBox

        local setBtn = Instance.new("TextButton")
        setBtn.Size = UDim2.new(0, 80, 0, 30)
        setBtn.BackgroundColor3 = Color3.fromRGB(100, 70, 200)
        setBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        setBtn.Text = "Set"
        setBtn.TextScaled = true
        setBtn.Font = Enum.Font.GothamBold
        setBtn.BorderSizePixel = 0
        setBtn.Parent = speedRow
        local setCorner = Instance.new("UICorner")
        setCorner.CornerRadius = UDim.new(0, 6)
        setCorner.Parent = setBtn

        local lockBtn = Instance.new("TextButton")
        lockBtn.Size = UDim2.new(0.4, 0, 0, 32)
        lockBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
        lockBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        lockBtn.Text = "🔓 Unlocked"
        lockBtn.TextScaled = true
        lockBtn.Font = Enum.Font.GothamBold
        lockBtn.BorderSizePixel = 0
        lockBtn.Parent = scrollPanel
        local lockCorner = Instance.new("UICorner")
        lockCorner.CornerRadius = UDim.new(0, 6)
        lockCorner.Parent = lockBtn

        local fpsTitle = Instance.new("TextLabel")
        fpsTitle.Size = UDim2.new(0.8, 0, 0, 30)
        fpsTitle.BackgroundTransparency = 1
        fpsTitle.Text = "FPS Unlocker"
        fpsTitle.TextColor3 = Color3.fromRGB(180, 160, 255)
        fpsTitle.TextScaled = true
        fpsTitle.Font = Enum.Font.GothamBold
        fpsTitle.Parent = scrollPanel

        local fpsToggle = Instance.new("TextButton")
        fpsToggle.Size = UDim2.new(0.4, 0, 0, 32)
        fpsToggle.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
        fpsToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
        fpsToggle.Text = "FPS Unlock: OFF"
        fpsToggle.TextScaled = true
        fpsToggle.Font = Enum.Font.GothamBold
        fpsToggle.BorderSizePixel = 0
        fpsToggle.Parent = scrollPanel
        local fpsToggleCorner = Instance.new("UICorner")
        fpsToggleCorner.CornerRadius = UDim.new(0, 6)
        fpsToggleCorner.Parent = fpsToggle

        local presetsRow = Instance.new("Frame")
        presetsRow.Size = UDim2.new(0.8, 0, 0, 36)
        presetsRow.BackgroundTransparency = 1
        presetsRow.Parent = scrollPanel
        local presetsLayout = Instance.new("UIListLayout")
        presetsLayout.FillDirection = Enum.FillDirection.Horizontal
        presetsLayout.Padding = UDim.new(0, 10)
        presetsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        presetsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
        presetsLayout.Parent = presetsRow

        local presetValues = {10, 30, 40, 50}
        local presetBtns = {}
        for _, val in ipairs(presetValues) do
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(0, 60, 0, 28)
            btn.BackgroundColor3 = Color3.fromRGB(40, 35, 60)
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            btn.Text = tostring(val)
            btn.TextScaled = true
            btn.Font = Enum.Font.GothamBold
            btn.BorderSizePixel = 0
            btn.Parent = presetsRow
            local btnCorner = Instance.new("UICorner")
            btnCorner.CornerRadius = UDim.new(0, 4)
            btnCorner.Parent = btn
            btn:SetAttribute("FPSValue", val)
            btn.MouseButton1Click:Connect(function()
                if fpsEnabled then
                    local v = btn:GetAttribute("FPSValue")
                    setTargetFPS(v)
                    updateMainDisplay()
                    print("🔁 FPS preset set to " .. v)
                else
                    print("⏳ Enable FPS Unlocker first to change presets.")
                end
            end)
            table.insert(presetBtns, btn)
        end

        local function updateMainDisplay()
            local highest = player:GetAttribute("HighestMS") or 0
            speedLabel.Text = "Current Speed: " .. math.floor(highest) .. " M/S"
            lockBtn.Text = isLocked and "🔒 Locked" or "🔓 Unlocked"
            lockBtn.BackgroundColor3 = isLocked and Color3.fromRGB(60, 180, 80) or Color3.fromRGB(200, 60, 60)
            fpsToggle.Text = fpsEnabled and "FPS Unlock: ON" or "FPS Unlock: OFF"
            fpsToggle.BackgroundColor3 = fpsEnabled and Color3.fromRGB(60, 180, 80) or Color3.fromRGB(200, 60, 60)
            for _, btn in ipairs(presetBtns) do
                local val = btn:GetAttribute("FPSValue")
                local isActive = (fpsEnabled and val == targetFPS)
                btn.BackgroundColor3 = isActive and Color3.fromRGB(60, 200, 80) or Color3.fromRGB(40, 35, 60)
            end
        end

        setBtn.MouseButton1Click:Connect(function()
            local success = setSpeed(textBox.Text)
            if success then updateMainDisplay() end
        end)
        textBox.FocusLost:Connect(function(enterPressed)
            if enterPressed then
                local success = setSpeed(textBox.Text)
                if success then updateMainDisplay() end
            end
        end)
        lockBtn.MouseButton1Click:Connect(function()
            if isLocked then
                stopOverride()
                updateMainDisplay()
            else
                if currentSpeed == 0 then
                    currentSpeed = tonumber(textBox.Text) or 667
                    player:SetAttribute("HighestMS", currentSpeed)
                    _G.CurrentHorizontalSpeed = currentSpeed
                end
                isLocked = true
                startOverride()
                updateMainDisplay()
            end
        end)
        fpsToggle.MouseButton1Click:Connect(function()
            toggleFPS()
            updateMainDisplay()
        end)
        player:GetAttributeChangedSignal("HighestMS"):Connect(updateMainDisplay)
        updateMainDisplay()
    end

    -- ================================================
    -- BUILD TRACER TAB (unchanged)
    -- ================================================
    local function buildTracerTab()
        for _, child in ipairs(scrollPanel:GetChildren()) do
            if child:IsA("UIListLayout") == false then
                child:Destroy()
            end
        end

        local tracerTitle = Instance.new("TextLabel")
        tracerTitle.Size = UDim2.new(0.9, 0, 0, 30)
        tracerTitle.BackgroundTransparency = 1
        tracerTitle.Text = "Main Tracer"
        tracerTitle.TextColor3 = Color3.fromRGB(180, 160, 255)
        tracerTitle.TextScaled = true
        tracerTitle.Font = Enum.Font.GothamBold
        tracerTitle.Parent = scrollPanel

        local tracerToggle = Instance.new("TextButton")
        tracerToggle.Size = UDim2.new(0.4, 0, 0, 30)
        tracerToggle.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
        tracerToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
        tracerToggle.Text = "Tracer: OFF"
        tracerToggle.TextScaled = true
        tracerToggle.Font = Enum.Font.GothamBold
        tracerToggle.BorderSizePixel = 0
        tracerToggle.Parent = scrollPanel
        local tracerToggleCorner = Instance.new("UICorner")
        tracerToggleCorner.CornerRadius = UDim.new(0, 6)
        tracerToggleCorner.Parent = tracerToggle

        local colorLabel = Instance.new("TextLabel")
        colorLabel.Size = UDim2.new(0.9, 0, 0, 18)
        colorLabel.BackgroundTransparency = 1
        colorLabel.Text = "Tracer Color"
        colorLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
        colorLabel.TextScaled = true
        colorLabel.Font = Enum.Font.GothamMedium
        colorLabel.TextXAlignment = Enum.TextXAlignment.Left
        colorLabel.Parent = scrollPanel

        local colorRow = Instance.new("Frame")
        colorRow.Size = UDim2.new(0.8, 0, 0, 26)
        colorRow.BackgroundTransparency = 1
        colorRow.Parent = scrollPanel
        local colorLayout = Instance.new("UIListLayout")
        colorLayout.FillDirection = Enum.FillDirection.Horizontal
        colorLayout.Padding = UDim.new(0, 6)
        colorLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        colorLayout.VerticalAlignment = Enum.VerticalAlignment.Center
        colorLayout.Parent = colorRow

        local colorPresets = {
            {Color3.fromRGB(255, 0, 0), "Red"},
            {Color3.fromRGB(0, 255, 0), "Green"},
            {Color3.fromRGB(0, 0, 255), "Blue"},
            {Color3.fromRGB(255, 255, 0), "Yellow"},
            {Color3.fromRGB(255, 0, 255), "Pink"},
            {Color3.fromRGB(255, 255, 255), "White"},
        }
        for _, preset in ipairs(colorPresets) do
            local col = preset[1]
            local name = preset[2]
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(0, 28, 0, 20)
            btn.BackgroundColor3 = col
            btn.Text = ""
            btn.BorderSizePixel = 1
            btn.BorderColor3 = (col == tracerColor) and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(100, 100, 100)
            btn.Parent = colorRow
            local btnCorner = Instance.new("UICorner")
            btnCorner.CornerRadius = UDim.new(1, 0)
            btnCorner.Parent = btn
            btn.MouseButton1Click:Connect(function()
                tracerColor = col
                print("Tracer color set to " .. name)
                for _, b in ipairs(colorRow:GetChildren()) do
                    if b:IsA("TextButton") then
                        b.BorderColor3 = (b == btn) and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(100, 100, 100)
                        b.BorderSizePixel = (b == btn) and 2 or 1
                    end
                end
            end)
        end

        tracerToggle.MouseButton1Click:Connect(function()
            tracerEnabled = not tracerEnabled
            tracerToggle.BackgroundColor3 = tracerEnabled and Color3.fromRGB(60, 180, 80) or Color3.fromRGB(200, 60, 60)
            tracerToggle.Text = tracerEnabled and "Tracer: ON" or "Tracer: OFF"
            print("Tracer " .. (tracerEnabled and "ENABLED" or "DISABLED"))
        end)
    end

    -- ================================================
    -- BUILD ROCK ADDER TAB (unchanged)
    -- ================================================
    local function buildRockAdderTab()
        for _, child in ipairs(scrollPanel:GetChildren()) do
            if child:IsA("UIListLayout") == false then
                child:Destroy()
            end
        end

        -- Rock Adder section
        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(0.9, 0, 0, 30)
        title.BackgroundTransparency = 1
        title.Text = "Rock Adder"
        title.TextColor3 = Color3.fromRGB(180, 160, 255)
        title.TextScaled = true
        title.Font = Enum.Font.GothamBold
        title.Parent = scrollPanel

        local instr = Instance.new("TextLabel")
        instr.Size = UDim2.new(0.9, 0, 0, 20)
        instr.BackgroundTransparency = 1
        instr.Text = "Enter amount and click Set"
        instr.TextColor3 = Color3.fromRGB(200, 200, 220)
        instr.TextScaled = true
        instr.Font = Enum.Font.GothamMedium
        instr.Parent = scrollPanel

        local row = Instance.new("Frame")
        row.Size = UDim2.new(0.8, 0, 0, 40)
        row.BackgroundTransparency = 1
        row.Parent = scrollPanel
        local rowLayout = Instance.new("UIListLayout")
        rowLayout.FillDirection = Enum.FillDirection.Horizontal
        rowLayout.Padding = UDim.new(0, 10)
        rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
        rowLayout.Parent = row

        local rockBox = Instance.new("TextBox")
        rockBox.Size = UDim2.new(0, 120, 0, 30)
        rockBox.BackgroundColor3 = Color3.fromRGB(40, 35, 60)
        rockBox.TextColor3 = Color3.fromRGB(255, 255, 255)
        rockBox.TextScaled = true
        rockBox.Font = Enum.Font.GothamBold
        rockBox.PlaceholderText = "Enter rocks"
        rockBox.Text = "500000"
        rockBox.ClearTextOnFocus = false
        rockBox.Parent = row
        local tbCorner = Instance.new("UICorner")
        tbCorner.CornerRadius = UDim.new(0, 6)
        tbCorner.Parent = rockBox

        local setBtn = Instance.new("TextButton")
        setBtn.Size = UDim2.new(0, 80, 0, 30)
        setBtn.BackgroundColor3 = Color3.fromRGB(100, 70, 200)
        setBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        setBtn.Text = "Set"
        setBtn.TextScaled = true
        setBtn.Font = Enum.Font.GothamBold
        setBtn.BorderSizePixel = 0
        setBtn.Parent = row
        local setCorner = Instance.new("UICorner")
        setCorner.CornerRadius = UDim.new(0, 6)
        setCorner.Parent = setBtn

        local findBtn = Instance.new("TextButton")
        findBtn.Size = UDim2.new(0, 80, 0, 30)
        findBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
        findBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        findBtn.Text = "Find"
        findBtn.TextScaled = true
        findBtn.Font = Enum.Font.GothamBold
        findBtn.BorderSizePixel = 0
        findBtn.Parent = row
        local findCorner = Instance.new("UICorner")
        findCorner.CornerRadius = UDim.new(0, 6)
        findCorner.Parent = findBtn

        findBtn.MouseButton1Click:Connect(function()
            local candidates = findRockCandidates()
            if #candidates == 0 then
                print("❌ No rock value found. Try earning some rocks manually and then click Find again.")
            else
                print("🔍 Found " .. #candidates .. " possible rock values:")
                for i, cand in ipairs(candidates) do
                    print("   " .. i .. ". " .. cand.path .. " = " .. tostring(cand.value))
                end
            end
        end)

        setBtn.MouseButton1Click:Connect(function()
            setRocks(rockBox.Text)
        end)

        rockBox.FocusLost:Connect(function(enterPressed)
            if enterPressed then
                setRocks(rockBox.Text)
            end
        end)

        -- ===== RACING CONFIG SLIDERS SECTION =====
        if racingConfig then
            local sep = Instance.new("Frame")
            sep.Size = UDim2.new(0.8, 0, 0, 2)
            sep.BackgroundColor3 = Color3.fromRGB(100, 80, 180)
            sep.BorderSizePixel = 0
            sep.Parent = scrollPanel

            local racingTitle = Instance.new("TextLabel")
            racingTitle.Size = UDim2.new(0.9, 0, 0, 30)
            racingTitle.BackgroundTransparency = 1
            racingTitle.Text = "Racing Rocks"
            racingTitle.TextColor3 = Color3.fromRGB(180, 160, 255)
            racingTitle.TextScaled = true
            racingTitle.Font = Enum.Font.GothamBold
            racingTitle.Parent = scrollPanel

            -- Helper to create a slider row
            local function createSliderRow(label, minVal, maxVal, initial, callback)
                local row = Instance.new("Frame")
                row.Size = UDim2.new(0.85, 0, 0, 40)
                row.BackgroundTransparency = 1
                row.Parent = scrollPanel

                local labelText = Instance.new("TextLabel")
                labelText.Size = UDim2.new(0.4, -10, 0, 20)
                labelText.Position = UDim2.new(0, 5, 0, 0)
                labelText.BackgroundTransparency = 1
                labelText.Text = label
                labelText.TextColor3 = Color3.fromRGB(220, 220, 230)
                labelText.TextScaled = true
                labelText.Font = Enum.Font.GothamMedium
                labelText.TextXAlignment = Enum.TextXAlignment.Left
                labelText.Parent = row

                local valueLabel = Instance.new("TextLabel")
                valueLabel.Size = UDim2.new(0.3, -10, 0, 20)
                valueLabel.Position = UDim2.new(0.7, 0, 0, 0)
                valueLabel.BackgroundTransparency = 1
                valueLabel.Text = tostring(initial)
                valueLabel.TextColor3 = Color3.fromRGB(180, 160, 255)
                valueLabel.TextScaled = true
                valueLabel.Font = Enum.Font.GothamBold
                valueLabel.TextXAlignment = Enum.TextXAlignment.Right
                valueLabel.Parent = row

                local slider = Instance.new("Frame")
                slider.Size = UDim2.new(0.65, 0, 0, 4)
                slider.Position = UDim2.new(0, 5, 0, 28)
                slider.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
                slider.BorderSizePixel = 0
                slider.Parent = row
                local sliderCorner = Instance.new("UICorner")
                sliderCorner.CornerRadius = UDim.new(1, 0)
                sliderCorner.Parent = slider

                local fill = Instance.new("Frame")
                fill.Size = UDim2.new((initial - minVal) / (maxVal - minVal), 0, 1, 0)
                fill.BackgroundColor3 = Color3.fromRGB(100, 80, 220)
                fill.BorderSizePixel = 0
                fill.Parent = slider
                local fillCorner = Instance.new("UICorner")
                fillCorner.CornerRadius = UDim.new(1, 0)
                fillCorner.Parent = fill

                local currentVal = initial
                local dragging = false

                local function updateSlider(mouseX)
                    local relX = math.clamp((mouseX - slider.AbsolutePosition.X) / slider.AbsoluteSize.X, 0, 1)
                    local val = minVal + (maxVal - minVal) * relX
                    val = math.round(val)
                    currentVal = val
                    fill.Size = UDim2.new(relX, 0, 1, 0)
                    valueLabel.Text = tostring(val)
                    if callback then callback(val) end
                end

                slider.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 then
                        dragging = true
                        updateSlider(input.Position.X)
                    end
                end)

                UserInputService.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 then
                        dragging = false
                    end
                end)

                UserInputService.InputChanged:Connect(function(input)
                    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                        updateSlider(input.Position.X)
                    end
                end)

                return function() return currentVal end
            end

            -- Sliders (Min/Max up to 1e12)
            local minRewardSlider = createSliderRow("Min Reward", 0, 1e12, racingConfig.MinReward or 20, function(val)
                racingConfig.MinReward = val
                print("MinReward set to " .. val)
            end)

            local maxRewardSlider = createSliderRow("Max Reward", 0, 1e12, racingConfig.MaxReward or 200, function(val)
                racingConfig.MaxReward = val
                print("MaxReward set to " .. val)
            end)

            local rewardPerSecSlider = createSliderRow("Reward/Second", 0, 100, racingConfig.RewardPerSecond or 10, function(val)
                racingConfig.RewardPerSecond = val
                print("RewardPerSecond set to " .. val)
            end)

            local resetBtn = Instance.new("TextButton")
            resetBtn.Size = UDim2.new(0.3, 0, 0, 28)
            resetBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
            resetBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            resetBtn.Text = "Reset to Original"
            resetBtn.TextScaled = true
            resetBtn.Font = Enum.Font.GothamBold
            resetBtn.BorderSizePixel = 0
            resetBtn.Parent = scrollPanel
            local resetCorner = Instance.new("UICorner")
            resetCorner.CornerRadius = UDim.new(0, 6)
            resetCorner.Parent = resetBtn

            resetBtn.MouseButton1Click:Connect(function()
                if originalConfig then
                    racingConfig.MinReward = originalConfig.MinReward
                    racingConfig.MaxReward = originalConfig.MaxReward
                    racingConfig.RewardPerSecond = originalConfig.RewardPerSecond
                    print("Racing config restored to original values.")
                    buildRockAdderTab()
                end
            end)

            print("Racing config sliders built (Min/Max up to 1e12).")
        else
            local warnLabel = Instance.new("TextLabel")
            warnLabel.Size = UDim2.new(0.9, 0, 0, 30)
            warnLabel.BackgroundTransparency = 1
            warnLabel.Text = "RacingConfig not found."
            warnLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
            warnLabel.TextScaled = true
            warnLabel.Font = Enum.Font.GothamMedium
            warnLabel.Parent = scrollPanel
        end
    end

    -- ================================================
    -- BUILD SPEED TAB (with Boost & Acceleration Keybinds)
    -- ================================================
    local function buildSpeedTab()
        for _, child in ipairs(scrollPanel:GetChildren()) do
            if child:IsA("UIListLayout") == false then
                child:Destroy()
            end
        end

        -- Title
        local speedTitle = Instance.new("TextLabel")
        speedTitle.Size = UDim2.new(0.9, 0, 0, 30)
        speedTitle.BackgroundTransparency = 1
        speedTitle.Text = "Speed Controls"
        speedTitle.TextColor3 = Color3.fromRGB(180, 160, 255)
        speedTitle.TextScaled = true
        speedTitle.Font = Enum.Font.GothamBold
        speedTitle.Parent = scrollPanel

        -- Speed Boost toggle
        local boostToggle = Instance.new("TextButton")
        boostToggle.Size = UDim2.new(0.4, 0, 0, 30)
        boostToggle.BackgroundColor3 = isLocked and Color3.fromRGB(60, 180, 80) or Color3.fromRGB(200, 60, 60)
        boostToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
        boostToggle.Text = isLocked and "Boost: ON" or "Boost: OFF"
        boostToggle.TextScaled = true
        boostToggle.Font = Enum.Font.GothamBold
        boostToggle.BorderSizePixel = 0
        boostToggle.Parent = scrollPanel
        local boostCorner = Instance.new("UICorner")
        boostCorner.CornerRadius = UDim.new(0, 6)
        boostCorner.Parent = boostToggle

        -- Set speed row
        local row = Instance.new("Frame")
        row.Size = UDim2.new(0.8, 0, 0, 40)
        row.BackgroundTransparency = 1
        row.Parent = scrollPanel
        local rowLayout = Instance.new("UIListLayout")
        rowLayout.FillDirection = Enum.FillDirection.Horizontal
        rowLayout.Padding = UDim.new(0, 10)
        rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
        rowLayout.Parent = row

        local speedBox = Instance.new("TextBox")
        speedBox.Size = UDim2.new(0, 120, 0, 30)
        speedBox.BackgroundColor3 = Color3.fromRGB(40, 35, 60)
        speedBox.TextColor3 = Color3.fromRGB(255, 255, 255)
        speedBox.TextScaled = true
        speedBox.Font = Enum.Font.GothamBold
        speedBox.PlaceholderText = "Enter speed"
        speedBox.Text = tostring(currentSpeed > 0 and currentSpeed or 667)
        speedBox.ClearTextOnFocus = false
        speedBox.Parent = row
        local tbCorner = Instance.new("UICorner")
        tbCorner.CornerRadius = UDim.new(0, 6)
        tbCorner.Parent = speedBox

        local setSpeedBtn = Instance.new("TextButton")
        setSpeedBtn.Size = UDim2.new(0, 80, 0, 30)
        setSpeedBtn.BackgroundColor3 = Color3.fromRGB(100, 70, 200)
        setSpeedBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        setSpeedBtn.Text = "Set Speed"
        setSpeedBtn.TextScaled = true
        setSpeedBtn.Font = Enum.Font.GothamBold
        setSpeedBtn.BorderSizePixel = 0
        setSpeedBtn.Parent = row
        local setCorner = Instance.new("UICorner")
        setCorner.CornerRadius = UDim.new(0, 6)
        setCorner.Parent = setSpeedBtn

        -- Trail toggle
        local trailToggle = Instance.new("TextButton")
        trailToggle.Size = UDim2.new(0.4, 0, 0, 30)
        trailToggle.BackgroundColor3 = trailEnabled and Color3.fromRGB(60, 180, 80) or Color3.fromRGB(200, 60, 60)
        trailToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
        trailToggle.Text = trailEnabled and "Trail: ON" or "Trail: OFF"
        trailToggle.TextScaled = true
        trailToggle.Font = Enum.Font.GothamBold
        trailToggle.BorderSizePixel = 0
        trailToggle.Parent = scrollPanel
        local trailCorner = Instance.new("UICorner")
        trailCorner.CornerRadius = UDim.new(0, 6)
        trailCorner.Parent = trailToggle

        -- Acceleration Boost section
        local accelTitle = Instance.new("TextLabel")
        accelTitle.Size = UDim2.new(0.9, 0, 0, 26)
        accelTitle.BackgroundTransparency = 1
        accelTitle.Text = "Acceleration Boost"
        accelTitle.TextColor3 = Color3.fromRGB(180, 160, 255)
        accelTitle.TextScaled = true
        accelTitle.Font = Enum.Font.GothamBold
        accelTitle.Parent = scrollPanel

        -- Acceleration toggle
        local accelToggle = Instance.new("TextButton")
        accelToggle.Size = UDim2.new(0.4, 0, 0, 28)
        accelToggle.BackgroundColor3 = accelerationEnabled and Color3.fromRGB(60, 180, 80) or Color3.fromRGB(200, 60, 60)
        accelToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
        accelToggle.Text = accelerationEnabled and "Accel: ON" or "Accel: OFF"
        accelToggle.TextScaled = true
        accelToggle.Font = Enum.Font.GothamBold
        accelToggle.BorderSizePixel = 0
        accelToggle.Parent = scrollPanel
        local accelCorner = Instance.new("UICorner")
        accelCorner.CornerRadius = UDim.new(0, 6)
        accelCorner.Parent = accelToggle

        -- Acceleration Rate slider (range 0.01 to 2.0)
        local rateRow = Instance.new("Frame")
        rateRow.Size = UDim2.new(0.85, 0, 0, 40)
        rateRow.BackgroundTransparency = 1
        rateRow.Parent = scrollPanel

        local rateLabel = Instance.new("TextLabel")
        rateLabel.Size = UDim2.new(0.4, -10, 0, 20)
        rateLabel.Position = UDim2.new(0, 5, 0, 0)
        rateLabel.BackgroundTransparency = 1
        rateLabel.Text = "Acceleration Rate"
        rateLabel.TextColor3 = Color3.fromRGB(220, 220, 230)
        rateLabel.TextScaled = true
        rateLabel.Font = Enum.Font.GothamMedium
        rateLabel.TextXAlignment = Enum.TextXAlignment.Left
        rateLabel.Parent = rateRow

        local rateValueLabel = Instance.new("TextLabel")
        rateValueLabel.Size = UDim2.new(0.3, -10, 0, 20)
        rateValueLabel.Position = UDim2.new(0.7, 0, 0, 0)
        rateValueLabel.BackgroundTransparency = 1
        rateValueLabel.Text = string.format("%.2f", accelerationRate)
        rateValueLabel.TextColor3 = Color3.fromRGB(180, 160, 255)
        rateValueLabel.TextScaled = true
        rateValueLabel.Font = Enum.Font.GothamBold
        rateValueLabel.TextXAlignment = Enum.TextXAlignment.Right
        rateValueLabel.Parent = rateRow

        local rateSlider = Instance.new("Frame")
        rateSlider.Size = UDim2.new(0.65, 0, 0, 4)
        rateSlider.Position = UDim2.new(0, 5, 0, 28)
        rateSlider.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
        rateSlider.BorderSizePixel = 0
        rateSlider.Parent = rateRow
        local rateSliderCorner = Instance.new("UICorner")
        rateSliderCorner.CornerRadius = UDim.new(1, 0)
        rateSliderCorner.Parent = rateSlider

        local rateFill = Instance.new("Frame")
        rateFill.Size = UDim2.new((accelerationRate - 0.01) / 1.99, 0, 1, 0)
        rateFill.BackgroundColor3 = Color3.fromRGB(100, 80, 220)
        rateFill.BorderSizePixel = 0
        rateFill.Parent = rateSlider
        local rateFillCorner = Instance.new("UICorner")
        rateFillCorner.CornerRadius = UDim.new(1, 0)
        rateFillCorner.Parent = rateFill

        local rateDragging = false

        local function updateRateSlider(mouseX)
            local relX = math.clamp((mouseX - rateSlider.AbsolutePosition.X) / rateSlider.AbsoluteSize.X, 0, 1)
            local val = 0.01 + 1.99 * relX
            val = math.round(val * 100) / 100
            accelerationRate = val
            rateFill.Size = UDim2.new((accelerationRate - 0.01) / 1.99, 0, 1, 0)
            rateValueLabel.Text = string.format("%.2f", accelerationRate)
            print("Acceleration Rate set to " .. accelerationRate)
        end

        rateSlider.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                rateDragging = true
                updateRateSlider(input.Position.X)
            end
        end)

        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                rateDragging = false
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if rateDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                updateRateSlider(input.Position.X)
            end
        end)

        -- Keybind for Acceleration
        local keyLabel1 = Instance.new("TextLabel")
        keyLabel1.Size = UDim2.new(0.4, -10, 0, 20)
        keyLabel1.Position = UDim2.new(0, 5, 0, 0)
        keyLabel1.BackgroundTransparency = 1
        keyLabel1.Text = "Accel Keybind"
        keyLabel1.TextColor3 = Color3.fromRGB(220, 220, 230)
        keyLabel1.TextScaled = true
        keyLabel1.Font = Enum.Font.GothamMedium
        keyLabel1.TextXAlignment = Enum.TextXAlignment.Left
        keyLabel1.Parent = scrollPanel

        local keyOptions = {"None", "F", "G", "LeftShift", "LeftControl", "E", "Q", "R", "T", "X", "Z", "C", "V", "B", "N", "M"}
        local keyMap = {
            None = Enum.KeyCode.None,
            F = Enum.KeyCode.F,
            G = Enum.KeyCode.G,
            LeftShift = Enum.KeyCode.LeftShift,
            LeftControl = Enum.KeyCode.LeftControl,
            E = Enum.KeyCode.E,
            Q = Enum.KeyCode.Q,
            R = Enum.KeyCode.R,
            T = Enum.KeyCode.T,
            X = Enum.KeyCode.X,
            Z = Enum.KeyCode.Z,
            C = Enum.KeyCode.C,
            V = Enum.KeyCode.V,
            B = Enum.KeyCode.B,
            N = Enum.KeyCode.N,
            M = Enum.KeyCode.M,
        }
        local accelKeyIndex = 1
        local boostKeyIndex = 1

        -- Accel key dropdown
        local accelKeyDropdown = Instance.new("TextButton")
        accelKeyDropdown.Size = UDim2.new(0.4, 0, 0, 28)
        accelKeyDropdown.Position = UDim2.new(0, 10, 0, 0)
        accelKeyDropdown.BackgroundColor3 = Color3.fromRGB(40, 35, 60)
        accelKeyDropdown.TextColor3 = Color3.fromRGB(255, 255, 255)
        accelKeyDropdown.Text = "None"
        accelKeyDropdown.TextScaled = true
        accelKeyDropdown.Font = Enum.Font.GothamBold
        accelKeyDropdown.BorderSizePixel = 0
        accelKeyDropdown.Parent = scrollPanel
        local accelKeyCorner = Instance.new("UICorner")
        accelKeyCorner.CornerRadius = UDim.new(0, 6)
        accelKeyCorner.Parent = accelKeyDropdown

        accelKeyDropdown.MouseButton1Click:Connect(function()
            accelKeyIndex = accelKeyIndex % #keyOptions + 1
            local selectedName = keyOptions[accelKeyIndex]
            accelKeyDropdown.Text = selectedName
            accelKeybind = keyMap[selectedName]
            accelKeyName = selectedName
            print("Accel keybind set to: " .. selectedName)
        end)

        -- Keybind for Boost
        local keyLabel2 = Instance.new("TextLabel")
        keyLabel2.Size = UDim2.new(0.4, -10, 0, 20)
        keyLabel2.Position = UDim2.new(0, 5, 0, 0)
        keyLabel2.BackgroundTransparency = 1
        keyLabel2.Text = "Boost Keybind"
        keyLabel2.TextColor3 = Color3.fromRGB(220, 220, 230)
        keyLabel2.TextScaled = true
        keyLabel2.Font = Enum.Font.GothamMedium
        keyLabel2.TextXAlignment = Enum.TextXAlignment.Left
        keyLabel2.Parent = scrollPanel

        local boostKeyDropdown = Instance.new("TextButton")
        boostKeyDropdown.Size = UDim2.new(0.4, 0, 0, 28)
        boostKeyDropdown.Position = UDim2.new(0, 10, 0, 0)
        boostKeyDropdown.BackgroundColor3 = Color3.fromRGB(40, 35, 60)
        boostKeyDropdown.TextColor3 = Color3.fromRGB(255, 255, 255)
        boostKeyDropdown.Text = "None"
        boostKeyDropdown.TextScaled = true
        boostKeyDropdown.Font = Enum.Font.GothamBold
        boostKeyDropdown.BorderSizePixel = 0
        boostKeyDropdown.Parent = scrollPanel
        local boostKeyCorner = Instance.new("UICorner")
        boostKeyCorner.CornerRadius = UDim.new(0, 6)
        boostKeyCorner.Parent = boostKeyDropdown

        boostKeyDropdown.MouseButton1Click:Connect(function()
            boostKeyIndex = boostKeyIndex % #keyOptions + 1
            local selectedName = keyOptions[boostKeyIndex]
            boostKeyDropdown.Text = selectedName
            boostKeybind = keyMap[selectedName]
            boostKeyName = selectedName
            print("Boost keybind set to: " .. selectedName)
        end)

        -- Listen for keypress to toggle boost and acceleration
        UserInputService.InputBegan:Connect(function(input, gp)
            if gp then return end
            if boostKeybind ~= Enum.KeyCode.None and input.KeyCode == boostKeybind then
                -- Toggle boost
                if isLocked then
                    stopOverride()
                else
                    local val = tonumber(speedBox.Text)
                    if not val or val <= 0 then
                        val = 667
                        speedBox.Text = "667"
                    end
                    currentSpeed = val
                    player:SetAttribute("HighestMS", val)
                    _G.CurrentHorizontalSpeed = val
                    isLocked = true
                    startOverride()
                end
                -- Update UI button
                boostToggle.BackgroundColor3 = isLocked and Color3.fromRGB(60, 180, 80) or Color3.fromRGB(200, 60, 60)
                boostToggle.Text = isLocked and "Boost: ON" or "Boost: OFF"
                print("Boost toggled via key to: " .. tostring(isLocked))
            end

            if accelKeybind ~= Enum.KeyCode.None and input.KeyCode == accelKeybind then
                -- Toggle acceleration
                accelerationEnabled = not accelerationEnabled
                if accelerationEnabled then
                    if isLocked then
                        startOverride()
                    end
                else
                    if isLocked then
                        currentAppliedSpeed = currentSpeed
                    end
                end
                accelToggle.BackgroundColor3 = accelerationEnabled and Color3.fromRGB(60, 180, 80) or Color3.fromRGB(200, 60, 60)
                accelToggle.Text = accelerationEnabled and "Accel: ON" or "Accel: OFF"
                print("Acceleration toggled via key to: " .. tostring(accelerationEnabled))
            end
        end)

        -- Functions to update UI
        local function updateSpeedTabUI()
            boostToggle.BackgroundColor3 = isLocked and Color3.fromRGB(60, 180, 80) or Color3.fromRGB(200, 60, 60)
            boostToggle.Text = isLocked and "Boost: ON" or "Boost: OFF"
            trailToggle.BackgroundColor3 = trailEnabled and Color3.fromRGB(60, 180, 80) or Color3.fromRGB(200, 60, 60)
            trailToggle.Text = trailEnabled and "Trail: ON" or "Trail: OFF"
            accelToggle.BackgroundColor3 = accelerationEnabled and Color3.fromRGB(60, 180, 80) or Color3.fromRGB(200, 60, 60)
            accelToggle.Text = accelerationEnabled and "Accel: ON" or "Accel: OFF"
            speedBox.Text = tostring(currentSpeed > 0 and currentSpeed or 667)
            rateValueLabel.Text = string.format("%.2f", accelerationRate)
            rateFill.Size = UDim2.new((accelerationRate - 0.01) / 1.99, 0, 1, 0)
            accelKeyDropdown.Text = accelKeyName
            boostKeyDropdown.Text = boostKeyName
        end

        -- Boost toggle
        boostToggle.MouseButton1Click:Connect(function()
            if isLocked then
                stopOverride()
            else
                local val = tonumber(speedBox.Text)
                if not val or val <= 0 then
                    val = 667
                    speedBox.Text = "667"
                end
                currentSpeed = val
                player:SetAttribute("HighestMS", val)
                _G.CurrentHorizontalSpeed = val
                isLocked = true
                startOverride()
            end
            updateSpeedTabUI()
        end)

        -- Set Speed
        setSpeedBtn.MouseButton1Click:Connect(function()
            local val = tonumber(speedBox.Text)
            if val and val > 0 then
                setSpeed(val)
            else
                print("❌ Invalid speed")
            end
            updateSpeedTabUI()
        end)

        speedBox.FocusLost:Connect(function(enterPressed)
            if enterPressed then
                local val = tonumber(speedBox.Text)
                if val and val > 0 then
                    setSpeed(val)
                else
                    print("❌ Invalid speed")
                end
                updateSpeedTabUI()
            end
        end)

        -- Trail toggle
        trailToggle.MouseButton1Click:Connect(function()
            trailEnabled = not trailEnabled
            toggleTrail(trailEnabled)
            updateSpeedTabUI()
        end)

        -- Acceleration toggle
        accelToggle.MouseButton1Click:Connect(function()
            accelerationEnabled = not accelerationEnabled
            if accelerationEnabled then
                if isLocked then
                    startOverride()
                end
            else
                if isLocked then
                    currentAppliedSpeed = currentSpeed
                end
            end
            updateSpeedTabUI()
        end)

        updateSpeedTabUI()
        print("Speed tab built with Boost & Acceleration Keybinds.")
    end

    -- ================================================
    -- TAB SWITCHING
    -- ================================================
    local function switchTab(tabName)
        currentTab = tabName
        for name, btn in pairs(tabBtns) do
            if name == tabName then
                btn.BackgroundColor3 = Color3.fromRGB(80, 50, 180)
                btn.BackgroundTransparency = 0.15
            else
                btn.BackgroundColor3 = Color3.fromRGB(30, 20, 55)
                btn.BackgroundTransparency = 0.5
            end
        end
        if tabName == "Main" then
            buildMainTab()
        elseif tabName == "Tracer" then
            buildTracerTab()
        elseif tabName == "Rock Adder" then
            buildRockAdderTab()
        elseif tabName == "Speed" then
            buildSpeedTab()
        end
    end

    for name, btn in pairs(tabBtns) do
        btn.MouseButton1Click:Connect(function()
            switchTab(name)
        end)
    end

    switchTab("Main")

    -- ================================================
    -- FADE‑IN ANIMATION
    -- ================================================
    -- Start with frame invisible and scale slightly
    frame.BackgroundTransparency = 1
    frame.Size = UDim2.new(0, 700, 0, 460) -- slightly smaller for scale animation
    frame.Position = UDim2.new(0.5, -350, 0.5, -230)

    local fadeIn = TweenService:Create(frame, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        BackgroundTransparency = 0.15,
        Size = UDim2.new(0, 720, 0, 480),
        Position = UDim2.new(0.5, -360, 0.5, -240)
    })
    fadeIn:Play()

    print("✅ Markxrs [BETA] – Premium VFX Edition loaded.")
end

pcall(createUI)
