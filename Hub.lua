--[[
    MATHIS HUB — Admin/Dev Hub pour Roblox
    ------------------------------------------------------------
    INSTALLATION :
    1. Roblox Studio → Explorer.
    2. Place ce script dans StarterPlayer > StarterPlayerScripts
       en tant que LocalScript.
    3. Lance le jeu (Play).

    CATÉGORIES :
    - Joueur  : vitesse, saut, saut infini, invisible, freeze, reset
    - Combat  : mode dieu, soigner, se tuer
    - Voiture : turbo, redresser, sortir (nécessite un VehicleSeat)
    - Op      : vol + noclip + vitesse, téléportation vers un joueur
    - Visuel  : ESP, fullbright, champ de vision (FOV)
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

--============================================================
-- CONFIGURATION
--============================================================
local CONFIG = {
    MinSpeed = 10, MaxSpeed = 300, DefaultSpeed = 60,
    MinFrameSize = Vector2.new(460, 380),
    MaxFrameSize = Vector2.new(920, 760),
}

local COLORS = {
    Panel = Color3.fromRGB(24, 24, 28),
    Border = Color3.fromRGB(60, 60, 68),
    Accent = Color3.fromRGB(10, 132, 255),
    Green = Color3.fromRGB(52, 199, 89),
    Red = Color3.fromRGB(220, 60, 60),
    Text = Color3.fromRGB(245, 245, 245),
    SubText = Color3.fromRGB(160, 160, 170),
    Track = Color3.fromRGB(70, 70, 78),
}

--============================================================
-- OUTILS
--============================================================
local function create(class, props, children)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do inst[k] = v end
    for _, child in ipairs(children or {}) do child.Parent = inst end
    return inst
end

local function addPressFeedback(button)
    local scale = Instance.new("UIScale")
    scale.Parent = button
    button.MouseButton1Down:Connect(function()
        TweenService:Create(scale, TweenInfo.new(0.08, Enum.EasingStyle.Quad), { Scale = 0.94 }):Play()
    end)
    local function release()
        TweenService:Create(scale, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
    end
    button.MouseButton1Up:Connect(release)
    button.MouseLeave:Connect(release)
end

--============================================================
-- ÉTAT
--============================================================
local flying = false
local flySpeed = CONFIG.DefaultSpeed
local currentWalkSpeed = 16
local currentJumpPower = 50
local godMode = false
local isInvisible = false
local isFrozen = false
local infiniteJumpEnabled = false
local espEnabled = false

local character, humanoid, rootPart
local originalCollide = {}
local originalTransparency = {}
local originalLighting = nil
local espHighlights = {}
local noclipConn
local inputState = { W = false, A = false, S = false, D = false, Up = false, Down = false }

local setFlying -- assigné plus bas (dépend de l'UI)

local function applyNoclip(state)
    if not character then return end
    if state then
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                originalCollide[part] = part.CanCollide
                part.CanCollide = false
            end
        end
        noclipConn = character.DescendantAdded:Connect(function(desc)
            if desc:IsA("BasePart") then
                originalCollide[desc] = desc.CanCollide
                desc.CanCollide = false
            end
        end)
    else
        if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
        for part, wasCollide in pairs(originalCollide) do
            if part and part.Parent then part.CanCollide = wasCollide end
        end
        originalCollide = {}
    end
end

local function applyInvisible(state)
    if not character then return end
    if state then
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") or part:IsA("Decal") then
                originalTransparency[part] = part.Transparency
                part.Transparency = 1
            end
        end
    else
        for inst, t in pairs(originalTransparency) do
            if inst and inst.Parent then inst.Transparency = t end
        end
        originalTransparency = {}
    end
end

local function getSeat()
    if humanoid and humanoid.SeatPart and humanoid.SeatPart:IsA("VehicleSeat") then
        return humanoid.SeatPart
    end
    return nil
end

local function addESPToCharacter(char)
    if char:FindFirstChild("ESP_Highlight") then return end
    local hl = create("Highlight", {
        Name = "ESP_Highlight",
        FillColor = COLORS.Accent,
        FillTransparency = 0.5,
        OutlineColor = Color3.fromRGB(255, 255, 255),
        DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
        Parent = char,
    })
    table.insert(espHighlights, hl)
end

local function removeAllESP()
    for _, hl in ipairs(espHighlights) do
        if hl and hl.Parent then hl:Destroy() end
    end
    espHighlights = {}
end

local function setESP(state)
    espEnabled = state
    if state then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= player and plr.Character then
                addESPToCharacter(plr.Character)
            end
        end
    else
        removeAllESP()
    end
end

local function setFullbright(state)
    if state then
        originalLighting = {
            Brightness = Lighting.Brightness,
            ClockTime = Lighting.ClockTime,
            GlobalShadows = Lighting.GlobalShadows,
            FogEnd = Lighting.FogEnd,
        }
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 100000
    elseif originalLighting then
        Lighting.Brightness = originalLighting.Brightness
        Lighting.ClockTime = originalLighting.ClockTime
        Lighting.GlobalShadows = originalLighting.GlobalShadows
        Lighting.FogEnd = originalLighting.FogEnd
        originalLighting = nil
    end
end

Players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Connect(function(char)
        if espEnabled and plr ~= player then addESPToCharacter(char) end
    end)
end)
for _, plr in ipairs(Players:GetPlayers()) do
    if plr ~= player then
        plr.CharacterAdded:Connect(function(char)
            if espEnabled then addESPToCharacter(char) end
        end)
    end
end

--============================================================
-- INTERFACE — FENÊTRE PRINCIPALE
--============================================================
local screenGui = create("ScreenGui", { Name = "MathisHub", ResetOnSpawn = false, DisplayOrder = 50 })

local fabButton = create("TextButton", {
    Name = "FAB", Size = UDim2.fromOffset(56, 56),
    AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -24, 1, -24),
    BackgroundColor3 = COLORS.Accent, Text = "M", TextColor3 = COLORS.Text, TextSize = 24,
    Font = Enum.Font.GothamBold, AutoButtonColor = false, Parent = screenGui,
}, {
    create("UICorner", { CornerRadius = UDim.new(1, 0) }),
    create("UIStroke", { Color = COLORS.Border, Thickness = 1 }),
})
addPressFeedback(fabButton)

local mainFrame = create("Frame", {
    Name = "MainFrame", Size = UDim2.fromOffset(640, 460),
    Position = UDim2.new(0.5, -320, 0.5, -230),
    BackgroundColor3 = COLORS.Panel, BackgroundTransparency = 0,
    Visible = false, Parent = screenGui,
}, {
    create("UICorner", { CornerRadius = UDim.new(0, 16) }),
    create("UIStroke", { Color = COLORS.Border, Thickness = 1 }),
})
local mainScale = create("UIScale", { Scale = 0.001, Parent = mainFrame })

local topBar = create("Frame", {
    Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, Active = true, Parent = mainFrame,
})
create("TextLabel", {
    Text = "Mathis Hub", Font = Enum.Font.GothamBold, TextSize = 18, TextColor3 = COLORS.Text,
    TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1,
    Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -60, 1, 0), Parent = topBar,
})
local closeButton = create("TextButton", {
    Text = "×", Font = Enum.Font.GothamBold, TextSize = 20, TextColor3 = COLORS.Text,
    BackgroundColor3 = COLORS.Track, AutoButtonColor = false, AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(26, 26), Parent = topBar,
}, { create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
addPressFeedback(closeButton)

-- ===== BARRE D'ONGLETS =====
local tabBar = create("Frame", {
    Size = UDim2.new(1, 0, 0, 36), Position = UDim2.new(0, 0, 0, 44),
    BackgroundTransparency = 1, Parent = mainFrame,
})
create("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), Parent = tabBar })
create("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4),
    SortOrder = Enum.SortOrder.LayoutOrder, Parent = tabBar,
})

local paneContainer = create("Frame", {
    Position = UDim2.new(0, 0, 0, 80), Size = UDim2.new(1, 0, 1, -80),
    BackgroundTransparency = 1, Parent = mainFrame,
})

local resizeHandle = create("Frame", {
    Size = UDim2.fromOffset(20, 20), AnchorPoint = Vector2.new(1, 1),
    Position = UDim2.new(1, -4, 1, -4), BackgroundTransparency = 1,
    Active = true, ZIndex = 5, Parent = mainFrame,
})
create("Frame", { BackgroundColor3 = COLORS.SubText, Size = UDim2.fromOffset(12, 2), Position = UDim2.fromOffset(4, 13), Rotation = -45, ZIndex = 5, Parent = resizeHandle })
create("Frame", { BackgroundColor3 = COLORS.SubText, Size = UDim2.fromOffset(8, 2), Position = UDim2.fromOffset(9, 17), Rotation = -45, ZIndex = 5, Parent = resizeHandle })

screenGui.Parent = playerGui

--============================================================
-- FACTORIES (onglets, toggles, sliders, boutons)
--============================================================
local tabsOrder = { "Joueur", "Combat", "Voiture", "Op", "Visuel" }
local panes, tabButtons = {}, {}

for i, tabName in ipairs(tabsOrder) do
    local tabBtn = create("TextButton", {
        Text = tabName, Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = COLORS.Text,
        AutoButtonColor = false, BackgroundColor3 = (i == 1) and COLORS.Accent or COLORS.Track,
        Size = UDim2.new(1 / #tabsOrder, -4, 1, 0), LayoutOrder = i, Parent = tabBar,
    }, { create("UICorner", { CornerRadius = UDim.new(0, 8) }) })
    addPressFeedback(tabBtn)
    tabButtons[tabName] = tabBtn

    local pane = create("ScrollingFrame", {
        Name = tabName .. "Pane", Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 4, ScrollBarImageColor3 = COLORS.SubText,
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = (i == 1), Parent = paneContainer,
    })
    create("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16), PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 16), Parent = pane })
    create("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder, Parent = pane })

    tabBtn.MouseButton1Click:Connect(function()
        for n, p in pairs(panes) do p.Visible = (n == tabName) end
        for n, b in pairs(tabButtons) do b.BackgroundColor3 = (n == tabName) and COLORS.Accent or COLORS.Track end
    end)

    panes[tabName] = pane
end

local joueurPane, combatPane, voiturePane, opPane, visuelPane =
    panes["Joueur"], panes["Combat"], panes["Voiture"], panes["Op"], panes["Visuel"]

local function createToggleRow(parent, order, labelText, onToggle)
    local row = create("Frame", { Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, LayoutOrder = order, Parent = parent })
    create("TextLabel", {
        Text = labelText, Font = Enum.Font.Gotham, TextSize = 14, TextColor3 = COLORS.Text,
        TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1,
        Size = UDim2.new(0.6, 0, 1, 0), Parent = row,
    })
    local track = create("TextButton", {
        Text = "", AutoButtonColor = false, BackgroundColor3 = COLORS.Track,
        Size = UDim2.fromOffset(46, 26), AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0), Parent = row,
    }, { create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
    local knob = create("Frame", {
        BackgroundColor3 = Color3.fromRGB(255, 255, 255), Size = UDim2.fromOffset(22, 22),
        Position = UDim2.new(0, 2, 0.5, -11), Parent = track,
    }, { create("UICorner", { CornerRadius = UDim.new(1, 0) }) })

    local state = false
    local function applyVisual(s)
        TweenService:Create(knob, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = s and UDim2.new(0, 22, 0.5, -11) or UDim2.new(0, 2, 0.5, -11),
        }):Play()
        TweenService:Create(track, TweenInfo.new(0.18), { BackgroundColor3 = s and COLORS.Green or COLORS.Track }):Play()
    end
    track.MouseButton1Click:Connect(function()
        state = not state
        applyVisual(state)
        if onToggle then onToggle(state) end
    end)
    return { Get = function() return state end }
end

local function createSliderRow(parent, order, labelPrefix, min, max, default, suffix, onChange)
    local section = create("Frame", { Size = UDim2.new(1, 0, 0, 50), BackgroundTransparency = 1, LayoutOrder = order, Parent = parent })
    local label = create("TextLabel", {
        Text = labelPrefix .. " : " .. default .. suffix, Font = Enum.Font.Gotham, TextSize = 13,
        TextColor3 = COLORS.SubText, TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), Parent = section,
    })
    local track = create("Frame", {
        BackgroundColor3 = COLORS.Track, Active = true,
        Position = UDim2.new(0, 0, 0, 28), Size = UDim2.new(1, 0, 0, 6), Parent = section,
    }, { create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
    local fill = create("Frame", { BackgroundColor3 = COLORS.Accent, Size = UDim2.new(0, 0, 1, 0), Parent = track }, { create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
    local knob = create("Frame", {
        BackgroundColor3 = Color3.fromRGB(255, 255, 255), Size = UDim2.fromOffset(16, 16),
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0), ZIndex = 2, Parent = track,
    }, { create("UICorner", { CornerRadius = UDim.new(1, 0) }), create("UIStroke", { Color = COLORS.Accent, Thickness = 2 }) })

    local currentValue = default
    local function setValue(v)
        currentValue = math.clamp(math.floor(v + 0.5), min, max)
        label.Text = labelPrefix .. " : " .. currentValue .. suffix
        local pct = (currentValue - min) / (max - min)
        fill.Size = UDim2.new(pct, 0, 1, 0)
        knob.Position = UDim2.new(pct, 0, 0.5, 0)
        if onChange then onChange(currentValue) end
    end

    local dragging = false
    local function updateFromX(x)
        local pos, size = track.AbsolutePosition.X, track.AbsoluteSize.X
        if size <= 0 then return end
        setValue(min + math.clamp((x - pos) / size, 0, 1) * (max - min))
    end
    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            updateFromX(input.Position.X)
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateFromX(input.Position.X)
        end
    end)

    setValue(default)
    return { Set = setValue, Get = function() return currentValue end }
end

local function createActionButton(parent, order, text, color, callback)
    local btn = create("TextButton", {
        Text = text, Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = COLORS.Text,
        BackgroundColor3 = color, AutoButtonColor = false,
        Size = UDim2.new(1, 0, 0, 36), LayoutOrder = order, Parent = parent,
    }, { create("UICorner", { CornerRadius = UDim.new(0, 10) }) })
    addPressFeedback(btn)
    btn.MouseButton1Click:Connect(callback)
    return btn
end

--============================================================
-- ONGLET JOUEUR
--============================================================
createSliderRow(joueurPane, 1, "Vitesse de marche", 16, 300, 16, " studs/s", function(v)
    currentWalkSpeed = v
    if humanoid then humanoid.WalkSpeed = v end
end)
createSliderRow(joueurPane, 2, "Puissance de saut", 50, 300, 50, "", function(v)
    currentJumpPower = v
    if humanoid then humanoid.UseJumpPower = true; humanoid.JumpPower = v end
end)
createToggleRow(joueurPane, 3, "Saut infini", function(state) infiniteJumpEnabled = state end)
createToggleRow(joueurPane, 4, "Invisible", function(state) isInvisible = state; applyInvisible(state) end)
createToggleRow(joueurPane, 5, "Freeze (immobile)", function(state)
    isFrozen = state
    if rootPart then rootPart.Anchored = state end
end)
createActionButton(joueurPane, 6, "Réinitialiser le personnage", COLORS.Red, function()
    player:LoadCharacter()
end)

--============================================================
-- ONGLET COMBAT
--============================================================
createToggleRow(combatPane, 1, "Mode Dieu (santé infinie)", function(state)
    godMode = state
    if state and humanoid then humanoid.Health = humanoid.MaxHealth end
end)
createActionButton(combatPane, 2, "Soigner", COLORS.Accent, function()
    if humanoid then humanoid.Health = humanoid.MaxHealth end
end)
createActionButton(combatPane, 3, "Se tuer", COLORS.Red, function()
    if humanoid then humanoid.Health = 0 end
end)

--============================================================
-- ONGLET VOITURE
--============================================================
create("TextLabel", {
    Text = "Ces actions nécessitent d'être assis dans un véhicule (VehicleSeat).",
    Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = COLORS.SubText, TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 0, 32), LayoutOrder = 1, Parent = voiturePane,
})
createActionButton(voiturePane, 2, "Turbo", COLORS.Accent, function()
    local seat = getSeat()
    if not seat then return end
    seat.MaxSpeed = math.max(seat.MaxSpeed or 0, 200)
    seat.Torque = math.max(seat.Torque or 0, 100)
    local model = seat.Parent
    local primary = (model and model.PrimaryPart) or seat
    primary.AssemblyLinearVelocity = primary.CFrame.LookVector * 150 + Vector3.new(0, 20, 0)
end)
createActionButton(voiturePane, 3, "Redresser le véhicule", COLORS.Accent, function()
    local seat = getSeat()
    if not seat then return end
    local model = seat.Parent
    local primary = (model and model.PrimaryPart) or seat
    local look = primary.CFrame.LookVector
    local flatLook = Vector3.new(look.X, 0, look.Z)
    if flatLook.Magnitude < 0.05 then flatLook = Vector3.new(0, 0, -1) end
    local newCFrame = CFrame.new(primary.Position + Vector3.new(0, 4, 0), primary.Position + Vector3.new(0, 4, 0) + flatLook.Unit)
    if model and model.PrimaryPart then
        model:SetPrimaryPartCFrame(newCFrame)
    else
        primary.CFrame = newCFrame
    end
    primary.AssemblyLinearVelocity = Vector3.zero
    primary.AssemblyAngularVelocity = Vector3.zero
end)
createActionButton(voiturePane, 4, "Sortir du véhicule", COLORS.Red, function()
    if humanoid then humanoid.Sit = false end
end)

--============================================================
-- ONGLET OP (vol + téléportation)
--============================================================
local flyRow = create("Frame", { Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, LayoutOrder = 1, Parent = opPane })
create("TextLabel", {
    Text = "Vol (Fly + Noclip)", Font = Enum.Font.Gotham, TextSize = 14, TextColor3 = COLORS.Text,
    TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1,
    Size = UDim2.new(0.6, 0, 1, 0), Parent = flyRow,
})
local flyTrack = create("TextButton", {
    Text = "", AutoButtonColor = false, BackgroundColor3 = COLORS.Track,
    Size = UDim2.fromOffset(46, 26), AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, 0, 0.5, 0), Parent = flyRow,
}, { create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
local flyKnob = create("Frame", {
    BackgroundColor3 = Color3.fromRGB(255, 255, 255), Size = UDim2.fromOffset(22, 22),
    Position = UDim2.new(0, 2, 0.5, -11), Parent = flyTrack,
}, { create("UICorner", { CornerRadius = UDim.new(1, 0) }) })

setFlying = function(state)
    if state == flying then return end
    flying = state
    TweenService:Create(flyKnob, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = state and UDim2.new(0, 22, 0.5, -11) or UDim2.new(0, 2, 0.5, -11),
    }):Play()
    TweenService:Create(flyTrack, TweenInfo.new(0.18), { BackgroundColor3 = state and COLORS.Green or COLORS.Track }):Play()
    if state then
        if humanoid and rootPart then
            humanoid.PlatformStand = true
            humanoid.AutoRotate = false
            applyNoclip(true)
        end
    else
        if humanoid then
            humanoid.PlatformStand = false
            humanoid.AutoRotate = true
        end
        applyNoclip(false)
        for k in pairs(inputState) do inputState[k] = false end
    end
end
flyTrack.MouseButton1Click:Connect(function() setFlying(not flying) end)

local flySliderApi = createSliderRow(opPane, 2, "Vitesse de vol", CONFIG.MinSpeed, CONFIG.MaxSpeed, CONFIG.DefaultSpeed, " studs/s", function(v)
    flySpeed = v
end)

local presetRow = create("Frame", { Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, LayoutOrder = 3, Parent = opPane })
create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = presetRow })
for i, preset in ipairs({ { "Lent", 20 }, { "Normal", 60 }, { "Rapide", 120 }, { "Turbo", 250 } }) do
    local btn = create("TextButton", {
        Text = preset[1], Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = COLORS.Text,
        BackgroundColor3 = COLORS.Track, AutoButtonColor = false,
        Size = UDim2.new(0.25, -5, 1, 0), LayoutOrder = i, Parent = presetRow,
    }, { create("UICorner", { CornerRadius = UDim.new(0, 8) }) })
    addPressFeedback(btn)
    btn.MouseButton1Click:Connect(function() flySliderApi.Set(preset[2]) end)
end

create("TextLabel", {
    Text = "F : vol on/off  •  Espace : monter  •  Maj : descendre",
    Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = COLORS.SubText, TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 0, 24), LayoutOrder = 4, Parent = opPane,
})

create("TextLabel", {
    Text = "Téléportation vers un joueur", Font = Enum.Font.GothamBold, TextSize = 13,
    TextColor3 = COLORS.Accent, TextXAlignment = Enum.TextXAlignment.Left,
    BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 5, Parent = opPane,
})

local selectRow = create("Frame", { Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, LayoutOrder = 6, Parent = opPane })
local selectButton = create("TextButton", {
    Text = "Sélectionner un joueur", Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = COLORS.Text,
    BackgroundColor3 = COLORS.Track, AutoButtonColor = false, Size = UDim2.new(1, -42, 1, 0), Parent = selectRow,
}, { create("UICorner", { CornerRadius = UDim.new(0, 8) }) })
local refreshButton = create("TextButton", {
    Text = "⟳", Font = Enum.Font.GothamBold, TextSize = 18, TextColor3 = COLORS.Text,
    BackgroundColor3 = COLORS.Track, AutoButtonColor = false, AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(36, 36), Parent = selectRow,
}, { create("UICorner", { CornerRadius = UDim.new(0, 8) }) })
addPressFeedback(selectButton)
addPressFeedback(refreshButton)

local listFrame = create("Frame", {
    Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
    BackgroundColor3 = COLORS.Panel, Visible = false, LayoutOrder = 7, Parent = opPane,
}, { create("UICorner", { CornerRadius = UDim.new(0, 8) }), create("UIStroke", { Color = COLORS.Border, Thickness = 1 }) })
create("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, SortOrder = Enum.SortOrder.LayoutOrder, Parent = listFrame })
create("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4), Parent = listFrame })

local selectedPlayer = nil

local function refreshPlayerList()
    for _, child in ipairs(listFrame:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    local others = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player then table.insert(others, plr) end
    end
    if #others == 0 then
        create("TextLabel", {
            Text = "Aucun autre joueur", Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = COLORS.SubText,
            BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24), Parent = listFrame,
        })
        return
    end
    for i, plr in ipairs(others) do
        local btn = create("TextButton", {
            Text = plr.Name, Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = COLORS.Text,
            BackgroundColor3 = COLORS.Track, AutoButtonColor = false,
            Size = UDim2.new(1, 0, 0, 30), LayoutOrder = i, Parent = listFrame,
        }, { create("UICorner", { CornerRadius = UDim.new(0, 6) }) })
        btn.MouseButton1Click:Connect(function()
            selectedPlayer = plr
            selectButton.Text = plr.Name
            listFrame.Visible = false
        end)
    end
end

selectButton.MouseButton1Click:Connect(function() listFrame.Visible = not listFrame.Visible end)
refreshButton.MouseButton1Click:Connect(refreshPlayerList)
Players.PlayerRemoving:Connect(function(plr)
    if selectedPlayer == plr then
        selectedPlayer = nil
        selectButton.Text = "Sélectionner un joueur"
    end
end)
refreshPlayerList()

createActionButton(opPane, 8, "Se téléporter", COLORS.Accent, function()
    if selectedPlayer and selectedPlayer.Parent and selectedPlayer.Character then
        local targetRoot = selectedPlayer.Character:FindFirstChild("HumanoidRootPart")
        if targetRoot and rootPart then
            rootPart.CFrame = targetRoot.CFrame * CFrame.new(3, 0, 0)
        end
    end
end)

--============================================================
-- ONGLET VISUEL
--============================================================
createToggleRow(visuelPane, 1, "ESP (voir les joueurs à travers les murs)", function(state) setESP(state) end)
createToggleRow(visuelPane, 2, "Fullbright (lumière maximale)", function(state) setFullbright(state) end)
createSliderRow(visuelPane, 3, "Champ de vision (FOV)", 30, 120, 70, "", function(v)
    workspace.CurrentCamera.FieldOfView = v
end)

--============================================================
-- OUVERTURE / FERMETURE DU MENU
--============================================================
local menuOpen = false
local function openMenu()
    if menuOpen then return end
    menuOpen = true
    mainFrame.Visible = true
    TweenService:Create(mainScale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end
local function closeMenu()
    if not menuOpen then return end
    menuOpen = false
    local t = TweenService:Create(mainScale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.001 })
    t:Play()
    t.Completed:Connect(function()
        if not menuOpen then mainFrame.Visible = false end
    end)
end
local function toggleMenu()
    if menuOpen then closeMenu() else openMenu() end
end
closeButton.MouseButton1Click:Connect(closeMenu)

--============================================================
-- DÉPLACEMENT DU BOUTON FLOTTANT
--============================================================
local fabDragging, fabDragInput, fabDragStart, fabStartPos, fabMoved = false, nil, nil, nil, false
fabButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        fabDragging = true
        fabMoved = false
        fabDragStart = input.Position
        fabStartPos = fabButton.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                fabDragging = false
                if not fabMoved then toggleMenu() end
            end
        end)
    end
end)
fabButton.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        fabDragInput = input
    end
end)
UIS.InputChanged:Connect(function(input)
    if fabDragging and input == fabDragInput then
        local delta = input.Position - fabDragStart
        if delta.Magnitude > 4 then fabMoved = true end
        fabButton.Position = UDim2.new(fabStartPos.X.Scale, fabStartPos.X.Offset + delta.X, fabStartPos.Y.Scale, fabStartPos.Y.Offset + delta.Y)
    end
end)

--============================================================
-- DÉPLACEMENT DU MENU
--============================================================
local dragging, dragInput, dragStart, startPos = false, nil, nil, nil
topBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = mainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
topBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)
UIS.InputChanged:Connect(function(input)
    if dragging and input == dragInput then
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

--============================================================
-- REDIMENSIONNEMENT DU MENU
--============================================================
local resizing, resizeStart, startSize = false, nil, nil
resizeHandle.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        resizing = true
        resizeStart = input.Position
        startSize = mainFrame.Size
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then resizing = false end
        end)
    end
end)
UIS.InputChanged:Connect(function(input)
    if resizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - resizeStart
        local newX = math.clamp(startSize.X.Offset + delta.X, CONFIG.MinFrameSize.X, CONFIG.MaxFrameSize.X)
        local newY = math.clamp(startSize.Y.Offset + delta.Y, CONFIG.MinFrameSize.Y, CONFIG.MaxFrameSize.Y)
        mainFrame.Size = UDim2.new(0, newX, 0, newY)
    end
end)

--============================================================
-- PERSONNAGE / CYCLE DE VIE
--============================================================
local function onCharacterAdded(char)
    character = char
    humanoid = char:WaitForChild("Humanoid")
    rootPart = char:WaitForChild("HumanoidRootPart")

    humanoid.UseJumpPower = true
    humanoid.WalkSpeed = currentWalkSpeed
    humanoid.JumpPower = currentJumpPower

    if flying then setFlying(false) end
    if isFrozen then rootPart.Anchored = true end
    if isInvisible then applyInvisible(true) end

    humanoid.Died:Connect(function()
        if flying then setFlying(false) end
    end)
end
player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then onCharacterAdded(player.Character) end

--============================================================
-- BOUCLE PRINCIPALE (vol corrigé + mode dieu)
--============================================================
RunService.Heartbeat:Connect(function(dt)
    if flying and rootPart and rootPart.Parent then
        local cam = workspace.CurrentCamera
        if cam then
            local moveDir = Vector3.zero
            local camCF = cam.CFrame
            if inputState.W then moveDir += camCF.LookVector end
            if inputState.S then moveDir -= camCF.LookVector end
            if inputState.D then moveDir += camCF.RightVector end
            if inputState.A then moveDir -= camCF.RightVector end
            if inputState.Up then moveDir += Vector3.new(0, 1, 0) end
            if inputState.Down then moveDir -= Vector3.new(0, 1, 0) end
            if moveDir.Magnitude > 0 then
                moveDir = moveDir.Unit * flySpeed * dt
            end
            -- Toujours réappliquer la position (même sans input) pour annuler la gravité
            local newPos = rootPart.Position + moveDir
            rootPart.CFrame = CFrame.new(newPos, newPos + camCF.LookVector)
            rootPart.AssemblyLinearVelocity = Vector3.zero
            rootPart.AssemblyAngularVelocity = Vector3.zero
        end
    end
    if godMode and humanoid and humanoid.Health < humanoid.MaxHealth then
        humanoid.Health = humanoid.MaxHealth
    end
end)

--============================================================
-- ENTRÉES CLAVIER
--============================================================
UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    local kc = input.KeyCode
    if kc == Enum.KeyCode.W then inputState.W = true
    elseif kc == Enum.KeyCode.A then inputState.A = true
    elseif kc == Enum.KeyCode.S then inputState.S = true
    elseif kc == Enum.KeyCode.D then inputState.D = true
    elseif kc == Enum.KeyCode.Space then inputState.Up = true
    elseif kc == Enum.KeyCode.LeftShift or kc == Enum.KeyCode.RightShift then inputState.Down = true
    elseif kc == Enum.KeyCode.F then setFlying(not flying)
    end
    if kc == Enum.KeyCode.Space and infiniteJumpEnabled and not flying and humanoid then
        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end)
UIS.InputEnded:Connect(function(input)
    local kc = input.KeyCode
    if kc == Enum.KeyCode.W then inputState.W = false
    elseif kc == Enum.KeyCode.A then inputState.A = false
    elseif kc == Enum.KeyCode.S then inputState.S = false
    elseif kc == Enum.KeyCode.D then inputState.D = false
    elseif kc == Enum.KeyCode.Space then inputState.Up = false
    elseif kc == Enum.KeyCode.LeftShift or kc == Enum.KeyCode.RightShift then inputState.Down = false
    end
end)
