-- 🎯 Aimbot — безопасная версия для loadstring
-- GitHub: broqql/menulua

local success, err = pcall(function()
    if not game:IsLoaded() then
        game.Loaded:Wait()
    end

    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local TweenService = game:GetService("TweenService")

    local localPlayer = Players.LocalPlayer

    -- Настройки
    local MAX_DISTANCE = 750
    local SMOOTHING = 0.2
    local CHAMS_COLOR_ENEMY = Color3.fromRGB(255, 0, 0)
    local CHAMS_COLOR_TEAM = Color3.fromRGB(0, 0, 255)
    local STRETCH_INTENSITY = 1.2

    -- Состояние
    local aimbotEnabled = true
    local highlights = {}

    -- Удаляем старый UI
    local function cleanup()
        if localPlayer.PlayerGui:FindFirstChild("AimbotUI") then
            localPlayer.PlayerGui.AimbotUI:Destroy()
        end
        if localPlayer.PlayerGui:FindFirstChild("StretchEffect") then
            localPlayer.PlayerGui.StretchEffect:Destroy()
        end
    end
    cleanup()

    -- UI
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AimbotUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = localPlayer.PlayerGui

    local toggleButton = Instance.new("TextButton")
    toggleButton.Size = UDim2.new(0, 120, 0, 40)
    toggleButton.Position = UDim2.new(0, 20, 0, 20)
    toggleButton.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    toggleButton.BorderSizePixel = 0
    toggleButton.Text = "AIMBOT: ON"
    toggleButton.TextColor3 = Color3.fromRGB(0, 255, 0)
    toggleButton.TextScaled = true
    toggleButton.ZIndex = 10
    toggleButton.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = toggleButton

    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, 5)
    padding.PaddingRight = UDim.new(0, 5)
    padding.PaddingTop = UDim.new(0, 5)
    padding.PaddingBottom = UDim.new(0, 5)
    padding.Parent = toggleButton

    toggleButton.MouseButton1Click:Connect(function()
        aimbotEnabled = not aimbotEnabled
        if aimbotEnabled then
            toggleButton.Text = "AIMBOT: ON"
            toggleButton.TextColor3 = Color3.fromRGB(0, 255, 0)
        else
            toggleButton.Text = "AIMBOT: OFF"
            toggleButton.TextColor3 = Color3.fromRGB(255, 0, 0)
        end
    end)

    -- Stretch Effect
    local function createStretchEffect()
        if localPlayer.PlayerGui:FindFirstChild("StretchEffect") then
            localPlayer.PlayerGui.StretchEffect:Destroy()
        end

        local stretchGui = Instance.new("ScreenGui")
        stretchGui.Name = "StretchEffect"
        stretchGui.ResetOnSpawn = false
        stretchGui.DisplayOrder = 1
        stretchGui.Parent = localPlayer.PlayerGui

        local stretchFrame = Instance.new("Frame")
        stretchFrame.Size = UDim2.new(STRETCH_INTENSITY, 0, 1, 0)
        stretchFrame.Position = UDim2.new(-(STRETCH_INTENSITY - 1) / 2, 0, 0, 0)
        stretchFrame.BackgroundTransparency = 1
        stretchFrame.ClipsDescendants = true
        stretchFrame.Parent = stretchGui

        local viewport = Instance.new("ViewportFrame")
        viewport.Size = UDim2.new(1 / STRETCH_INTENSITY, 0, 1, 0)
        viewport.Position = UDim2.new((STRETCH_INTENSITY - 1) / (2 * STRETCH_INTENSITY), 0, 0, 0)
        viewport.BackgroundTransparency = 1
        viewport.CurrentCamera = workspace.CurrentCamera
        viewport.Parent = stretchFrame

        return stretchGui
    end

    local stretchEffect = createStretchEffect()

    -- Логика
    local function isTeammate(player)
        if player == localPlayer then return true end
        if not localPlayer.Team or not player.Team then return false end
        return localPlayer.Team == player.Team
    end

    local function isAlive(player)
        local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        return humanoid and humanoid.Health > 0
    end

    local function isVisible(target)
        if not localPlayer.Character or not localPlayer.Character:FindFirstChild("Head") then
            return false
        end

        local origin = localPlayer.Character.Head.Position
        local targetPos = target.Character.Head.Position
        local direction = (targetPos - origin).Unit
        local distance = (targetPos - origin).Magnitude

        local raycastParams = RaycastParams.new()
        raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
        raycastParams.FilterDescendantsInstances = {localPlayer.Character}

        local result = workspace:Raycast(origin, direction * distance, raycastParams)

        if result then
            local hitParent = result.Instance:FindFirstAncestorOfClass("Model")
            return hitParent == target.Character
        end

        return true
    end

    local function createHighlight(player)
        if highlights[player] then
            highlights[player]:Destroy()
        end

        if not player.Character then return end

        local highlight = Instance.new("Highlight")
        highlight.Name = "AimbotChams"
        highlight.Adornee = player.Character
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.FillTransparency = 0.7
        highlight.OutlineTransparency = 0

        if isTeammate(player) then
            highlight.FillColor = CHAMS_COLOR_TEAM
            highlight.OutlineColor = CHAMS_COLOR_TEAM
        else
            highlight.FillColor = CHAMS_COLOR_ENEMY
            highlight.OutlineColor = CHAMS_COLOR_ENEMY
        end

        highlight.Parent = player.Character
        highlights[player] = highlight
    end

    local function removeHighlight(player)
        if highlights[player] then
            highlights[player]:Destroy()
            highlights[player] = nil
        end
    end

    local function updateAllChams()
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= localPlayer then
                if not highlights[player] and player.Character then
                    createHighlight(player)
                elseif highlights[player] and not player.Character then
                    removeHighlight(player)
                elseif highlights[player] and player.Character and highlights[player].Adornee ~= player.Character then
                    removeHighlight(player)
                    createHighlight(player)
                end
            end
        end
    end

    local function findClosestTarget()
        if not aimbotEnabled then return nil end

        local closestTarget = nil
        local closestDistance = MAX_DISTANCE

        if not localPlayer.Character or not localPlayer.Character:FindFirstChild("HumanoidRootPart") then
            return nil
        end

        local localRoot = localPlayer.Character.HumanoidRootPart

        for _, player in ipairs(Players:GetPlayers()) do
            if 
                player ~= localPlayer and
                not isTeammate(player) and
                isAlive(player) and
                player.Character and
                player.Character:FindFirstChild("HumanoidRootPart") and
                isAlive(localPlayer)
            then
                local targetRoot = player.Character.HumanoidRootPart
                local distance = (targetRoot.Position - localRoot.Position).Magnitude

                if distance <= MAX_DISTANCE and distance < closestDistance and isVisible(player) then
                    closestTarget = player
                    closestDistance = distance
                end
            end
        end

        return closestTarget
    end

    local function smoothAim(target)
        if not target or not target.Character or not target.Character.Head then
            return
        end

        local camera = workspace.CurrentCamera
        local targetPos = target.Character.Head.Position
        local offset = Vector3.new(0, -1.5, 0)
        targetPos = targetPos + offset

        local currentCF = camera.CFrame
        local targetCF = CFrame.lookAt(currentCF.Position, targetPos)
        camera.CFrame = currentCF:Lerp(targetCF, SMOOTHING)
    end

    -- Инициализация
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            createHighlight(player)
        end
    end

    Players.PlayerAdded:Connect(createHighlight)
    Players.PlayerRemoving:Connect(removeHighlight)

    localPlayer.CharacterAdded:Connect(function()
        wait(1)
        cleanup()
        screenGui = Instance.new("ScreenGui")
        screenGui.Name = "AimbotUI"
        screenGui.ResetOnSpawn = false
        screenGui.Parent = localPlayer.PlayerGui

        toggleButton = Instance.new("TextButton")
        toggleButton.Size = UDim2.new(0, 120, 0, 40)
        toggleButton.Position = UDim2.new(0, 20, 0, 20)
        toggleButton.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        toggleButton.BorderSizePixel = 0
        toggleButton.Text = aimbotEnabled and "AIMBOT: ON" or "AIMBOT: OFF"
        toggleButton.TextColor3 = aimbotEnabled and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
        toggleButton.TextScaled = true
        toggleButton.ZIndex = 10
        toggleButton.Parent = screenGui

        corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = toggleButton

        padding = Instance.new("UIPadding")
        padding.PaddingLeft = UDim.new(0, 5)
        padding.PaddingRight = UDim.new(0, 5)
        padding.PaddingTop = UDim.new(0, 5)
        padding.PaddingBottom = UDim.new(0, 5)
        padding.Parent = toggleButton

        toggleButton.MouseButton1Click:Connect(function()
            aimbotEnabled = not aimbotEnabled
            toggleButton.Text = aimbotEnabled and "AIMBOT: ON" or "AIMBOT: OFF"
            toggleButton.TextColor3 = aimbotEnabled and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
        end)

        stretchEffect = createStretchEffect()

        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= localPlayer then
                removeHighlight(p)
                wait()
                createHighlight(p)
            end
        end
    end)

    RunService.RenderStepped:Connect(function()
        local target = findClosestTarget()
        if target then
            smoothAim(target)
        end
    end)

    spawn(function()
        while wait(1) do
            updateAllChams()
        end
    end)

    if localPlayer.Team then
        localPlayer:GetPropertyChangedSignal("Team"):Connect(function()
            wait(0.5)
            for player, highlight in pairs(highlights) do
                if player ~= localPlayer then
                    if isTeammate(player) then
                        highlight.FillColor = CHAMS_COLOR_TEAM
                        highlight.OutlineColor = CHAMS_COLOR_TEAM
                    else
                        highlight.FillColor = CHAMS_COLOR_ENEMY
                        highlight.OutlineColor = CHAMS_COLOR_ENEMY
                    end
                end
            end
        end)
    end

    print("Aimbot loaded via loadstring!")
end)

if not success then
    warn("Aimbot error:", err)
end
