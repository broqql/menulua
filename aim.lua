-- 🎯 Улучшенный Aimbot — красивый, перетаскиваемый, стабильный
-- Не интегрирован в меню • Готов для loadstring

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local localPlayer = Players.LocalPlayer

-- === НАСТРОЙКИ ===
local MAX_DISTANCE = 750
local SMOOTHING = 0.2
local CHAMS_COLOR_ENEMY = Color3.fromRGB(255, 50, 50)
local CHAMS_COLOR_TEAM = Color3.fromRGB(50, 150, 255)
local STRETCH_INTENSITY = 1.2

-- === СОСТОЯНИЕ ===
local aimbotEnabled = true
local highlights = {}

-- === УДАЛЕНИЕ СТАРОГО UI ===
if localPlayer.PlayerGui:FindFirstChild("AimbotUI") then
    localPlayer.PlayerGui.AimbotUI:Destroy()
end

-- === СОЗДАНИЕ КРАСИВОГО UI ===
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AimbotUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = localPlayer.PlayerGui

-- Кнопка переключения
local toggleButton = Instance.new("TextButton")
toggleButton.Size = UDim2.new(0, 140, 0, 44)
toggleButton.Position = UDim2.new(0.02, 0, 0.05, 0) -- 2% от ширины, 5% от высоты
toggleButton.AnchorPoint = Vector2.new(0, 0)
toggleButton.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
toggleButton.BackgroundTransparency = 0.25
toggleButton.BorderSizePixel = 0
toggleButton.Text = "AIMBOT: ON"
toggleButton.TextColor3 = Color3.fromRGB(0, 255, 100)
toggleButton.Font = Enum.Font.GothamBold
toggleButton.TextSize = 16
toggleButton.ZIndex = 10
toggleButton.Parent = screenGui

-- Скругление
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = toggleButton

-- Внутренняя подсветка
local glow = Instance.new("UIStroke")
glow.Color = Color3.fromRGB(0, 200, 100)
glow.Thickness = 1.5
glow.Transparency = 0.7
glow.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
glow.Parent = toggleButton

-- Градиент (для глубины)
local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 30, 45)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 20, 30))
}
gradient.Rotation = 90
gradient.Parent = toggleButton

-- === ПЕРЕТАСКИВАНИЕ КНОПКИ ===
local dragging = false
local dragInput = nil
local dragStart = nil
local startPos = nil

local function updateToggleText()
    if aimbotEnabled then
        toggleButton.Text = "AIMBOT: ON"
        toggleButton.TextColor3 = Color3.fromRGB(0, 255, 100)
        glow.Color = Color3.fromRGB(0, 200, 100)
    else
        toggleButton.Text = "AIMBOT: OFF"
        toggleButton.TextColor3 = Color3.fromRGB(255, 80, 80)
        glow.Color = Color3.fromRGB(200, 60, 60)
    end
end

toggleButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = toggleButton.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

toggleButton.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        toggleButton.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end)

-- Переключение аимбота по клику (но не при перетаскивании)
toggleButton.MouseButton1Click:Connect(function()
    -- Чтобы не срабатывало при перетаскивании
    if (UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)) then
        wait() -- дадим время отпустить
    end
    aimbotEnabled = not aimbotEnabled
    updateToggleText()
end)

-- === ЭФФЕКТ РАСТЯГА ===
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
    viewport.CurrentCamera = workspace.CurrentCamera or workspace:WaitForChild("CurrentCamera")
    viewport.Parent = stretchFrame

    return stretchGui
end

local stretchEffect = createStretchEffect()

-- === ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ===
local function isTeammate(player)
    if player == localPlayer then return true end
    if not localPlayer.Team or not player.Team then return false end
    return localPlayer.Team == player.Team
end

local function isAlive(player)
    local char = player.Character
    if not char then return false end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    return humanoid and humanoid.Health > 0
end

local function isVisible(target)
    local char = localPlayer.Character
    local targetChar = target.Character
    if not char or not char:FindFirstChild("Head") or not targetChar or not targetChar:FindFirstChild("Head") then
        return false
    end

    local origin = char.Head.Position
    local targetPos = targetChar.Head.Position
    local direction = targetPos - origin
    local distance = direction.Magnitude
    if distance == 0 then return false end

    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = {char}

    local result = workspace:Raycast(origin, direction, raycastParams)
    if result then
        local hitModel = result.Instance:FindFirstAncestorOfClass("Model")
        return hitModel == targetChar
    end
    return true
end

-- === CHAMS ===
local function createHighlight(player)
    if highlights[player] then
        highlights[player]:Destroy()
        highlights[player] = nil
    end

    local char = player.Character
    if not char then return end

    local highlight = Instance.new("Highlight")
    highlight.Adornee = char
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillTransparency = 0.75
    highlight.OutlineTransparency = 0.1
    highlight.FillColor = isTeammate(player) and CHAMS_COLOR_TEAM or CHAMS_COLOR_ENEMY
    highlight.OutlineColor = highlight.FillColor
    highlight.Parent = char
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
            if player.Character and not highlights[player] then
                createHighlight(player)
            elseif not player.Character and highlights[player] then
                removeHighlight(player)
            elseif player.Character and highlights[player] and highlights[player].Adornee ~= player.Character then
                removeHighlight(player)
                createHighlight(player)
            end
        end
    end
end

-- === АИМБОТ ===
local function findClosestTarget()
    if not aimbotEnabled then return nil end
    if not localPlayer.Character or not localPlayer.Character:FindFirstChild("HumanoidRootPart") then
        return nil
    end

    local localRoot = localPlayer.Character.HumanoidRootPart.Position
    local closestTarget = nil
    local closestDist = MAX_DISTANCE

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer and
           not isTeammate(player) and
           isAlive(player) and
           player.Character and
           player.Character:FindFirstChild("HumanoidRootPart") and
           isVisible(player) then

            local targetPos = player.Character.HumanoidRootPart.Position
            local dist = (targetPos - localRoot).Magnitude
            if dist < closestDist then
                closestDist = dist
                closestTarget = player
            end
        end
    end
    return closestTarget
end

local function smoothAim(target)
    if not target or not target.Character or not target.Character:FindFirstChild("Head") then
        return
    end

    local camera = workspace.CurrentCamera
    if not camera then return end

    local targetPos = target.Character.Head.Position + Vector3.new(0, -1.2, 0)
    local currentCF = camera.CFrame
    local targetCF = CFrame.lookAt(currentCF.Position, targetPos)
    camera.CFrame = currentCF:Lerp(targetCF, SMOOTHING)
end

-- === ИНИЦИАЛИЗАЦИЯ ===
for _, player in ipairs(Players:GetPlayers()) do
    if player ~= localPlayer then
        createHighlight(player)
    end
end

Players.PlayerAdded:Connect(createHighlight)
Players.PlayerRemoving:Connect(removeHighlight)

localPlayer.CharacterAdded:Connect(function()
    task.delay(1, function()
        if not screenGui.Parent then
            screenGui.Parent = localPlayer.PlayerGui
        end
        if not stretchEffect.Parent then
            stretchEffect = createStretchEffect()
        end
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= localPlayer then
                removeHighlight(p)
                task.delay(0.1, function()
                    createHighlight(p)
                end)
            end
        end
    end)
end)

RunService.RenderStepped:Connect(function()
    local target = findClosestTarget()
    if target then
        smoothAim(target)
    end
end)

-- Обновление Chams
task.spawn(function()
    while task.wait(1.5) do
        updateAllChams()
    end
end)

-- Смена команды
if localPlayer.Team then
    localPlayer:GetPropertyChangedSignal("Team"):Connect(function()
        task.delay(0.3, function()
            for player, highlight in pairs(highlights) do
                if player ~= localPlayer and highlight and highlight.Parent then
                    local color = isTeammate(player) and CHAMS_COLOR_TEAM or CHAMS_COLOR_ENEMY
                    highlight.FillColor = color
                    highlight.OutlineColor = color
                end
            end
        end)
    end)
end

print("✅ Улучшенный аимбот запущен!")
print("• Перетаскивайте кнопку мышкой/пальцем")
print("• AIMBOT: " .. (aimbotEnabled and "ON" or "OFF"))
