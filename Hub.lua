local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

-- Suppression d'une ancienne instance si elle existe
if CoreGui:FindFirstChild("SlaydixHub") then
    CoreGui.SlaydixHub:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SlaydixHub"
ScreenGui.Parent = CoreGui

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 520, 0, 360)
MainFrame.Position = UDim2.new(0.5, -260, 0.5, -180)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 23, 42)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner", MainFrame)
UICorner.CornerRadius = UDim.new(0, 10)

-- Titre
local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 50)
Title.BackgroundColor3 = Color3.fromRGB(30, 41, 59)
Title.Text = "  ⚡ SLAYDIX HUB"
Title.TextColor3 = Color3.fromRGB(56, 189, 248)
Title.Font = Enum.Font.SourceSansBold
Title.TextSize = 20
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = MainFrame

local TitleCorner = Instance.new("UICorner", Title)
TitleCorner.CornerRadius = UDim.new(0, 10)

-- Onglets (Boutons)
local TabPlayerBtn = Instance.new("TextButton")
TabPlayerBtn.Size = UDim2.new(0, 120, 0, 35)
TabPlayerBtn.Position = UDim2.new(0, 15, 0, 60)
TabPlayerBtn.BackgroundColor3 = Color3.fromRGB(3, 105, 161)
TabPlayerBtn.Text = "Player"
TabPlayerBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
TabPlayerBtn.Font = Enum.Font.SourceSansBold
TabPlayerBtn.TextSize = 16
TabPlayerBtn.Parent = MainFrame
Instance.new("UICorner", TabPlayerBtn).CornerRadius = UDim.new(0, 6)

local TabMoveBtn = Instance.new("TextButton")
TabMoveBtn.Size = UDim2.new(0, 120, 0, 35)
TabMoveBtn.Position = UDim2.new(0, 145, 0, 60)
TabMoveBtn.BackgroundColor3 = Color3.fromRGB(51, 65, 85)
TabMoveBtn.Text = "Mouvement"
TabMoveBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
TabMoveBtn.Font = Enum.Font.SourceSansBold
TabMoveBtn.TextSize = 16
TabMoveBtn.Parent = MainFrame
Instance.new("UICorner", TabMoveBtn).CornerRadius = UDim.new(0, 6)

-- Conteneur Player
local PlayerContainer = Instance.new("ScrollingFrame")
PlayerContainer.Size = UDim2.new(1, -30, 1, -120)
PlayerContainer.Position = UDim2.new(0, 15, 0, 105)
PlayerContainer.BackgroundTransparency = 1
PlayerContainer.Visible = true
PlayerContainer.Parent = MainFrame

-- Conteneur Mouvement
local MoveContainer = Instance.new("Frame")
MoveContainer.Size = UDim2.new(1, -30, 1, -120)
MoveContainer.Position = UDim2.new(0, 15, 0, 105)
MoveContainer.BackgroundTransparency = 1
MoveContainer.Visible = false
MoveContainer.Parent = MainFrame

-- Liste dynamique des joueurs
local selectedPlayer = nil
local playerListLayout = Instance.new("UIListLayout", PlayerContainer)
playerListLayout.SortOrder = Enum.SortOrder.LayoutOrder
playerListLayout.Padding = UDim.new(0, 8)

local function refreshPlayerList()
    for _, child in pairs(PlayerContainer:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local pBtn = Instance.new("TextButton")
            pBtn.Size = UDim2.new(1, 0, 0, 36)
            pBtn.BackgroundColor3 = Color3.fromRGB(30, 41, 59)
            pBtn.Text = "  👤 " .. p.Name
            pBtn.TextColor3 = Color3.fromRGB(241, 245, 249)
            pBtn.Font = Enum.Font.SourceSans
            pBtn.TextSize = 16
            pBtn.TextXAlignment = Enum.TextXAlignment.Left
            pBtn.Parent = PlayerContainer
            Instance.new("UICorner", pBtn).CornerRadius = UDim.new(0, 6)
            
            pBtn.MouseButton1Click:Connect(function()
                selectedPlayer = p
                for _, b in pairs(PlayerContainer:GetChildren()) do
                    if b:IsA("TextButton") then b.BackgroundColor3 = Color3.fromRGB(30, 41, 59) end
                end
                pBtn.BackgroundColor3 = Color3.fromRGB(3, 105, 161)
            end)
        end
    end
end
refreshPlayerList()
Players.PlayerAdded:Connect(refreshPlayerList)
Players.PlayerRemoving:Connect(refreshPlayerList)

-- Bouton Teleport
local TpBtn = Instance.new("TextButton")
TpBtn.Size = UDim2.new(0, 200, 0, 40)
TpBtn.Position = UDim2.new(0.5, -100, 1, -50)
TpBtn.BackgroundColor3 = Color3.fromRGB(16, 185, 129)
TpBtn.Text = "Se Téléporter sur le joueur"
TpBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
TpBtn.Font = Enum.Font.SourceSansBold
TpBtn.TextSize = 15
TpBtn.Parent = PlayerContainer
Instance.new("UICorner", TpBtn).CornerRadius = UDim.new(0, 6)

TpBtn.MouseButton1Click:Connect(function()
    if selectedPlayer and selectedPlayer.Character and selectedPlayer.Character:FindFirstChild("HumanoidRootPart") then
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            LocalPlayer.Character.HumanoidRootPart.CFrame = selectedPlayer.Character.HumanoidRootPart.CFrame + Vector3.new(0, 3, 0)
        end
    end
end)

-- --- ONGLET MOUVEMENT ---
local speedLabel = Instance.new("TextLabel")
speedLabel.Size = UDim2.new(1, 0, 0, 30)
speedLabel.Position = UDim2.new(0, 0, 0, 10)
speedLabel.Text = "WalkSpeed : 16"
speedLabel.TextColor3 = Color3.fromRGB(241, 245, 249)
speedLabel.Font = Enum.Font.SourceSansBold
speedLabel.TextSize = 16
speedLabel.TextXAlignment = Enum.TextXAlignment.Left
speedLabel.BackgroundTransparency = 1
speedLabel.Parent = MoveContainer

local speedBox = Instance.new("TextBox")
speedBox.Size = UDim2.new(1, 0, 0, 35)
speedBox.Position = UDim2.new(0, 0, 0, 45)
speedBox.BackgroundColor3 = Color3.fromRGB(30, 41, 59)
speedBox.Text = "16"
speedBox.TextColor3 = Color3.fromRGB(255, 255, 255)
speedBox.Font = Enum.Font.SourceSans
speedBox.TextSize = 16
speedBox.Parent = MoveContainer
Instance.new("UICorner", speedBox).CornerRadius = UDim.new(0, 6)

speedBox.FocusLost:Connect(function(enterPressed)
    local val = tonumber(speedBox.Text)
    if val and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        LocalPlayer.Character.Humanoid.WalkSpeed = val
        speedLabel.Text = "WalkSpeed : " .. tostring(val)
    end
end)

local flyLabel = Instance.new("TextLabel")
flyLabel.Size = UDim2.new(1, 0, 0, 30)
flyLabel.Position = UDim2.new(0, 0, 0, 100)
flyLabel.Text = "Fly Speed : 50"
flyLabel.TextColor3 = Color3.fromRGB(241, 245, 249)
flyLabel.Font = Enum.Font.SourceSansBold
flyLabel.TextSize = 16
flyLabel.TextXAlignment = Enum.TextXAlignment.Left
flyLabel.BackgroundTransparency = 1
flyLabel.Parent = MoveContainer

local flyBox = Instance.new("TextBox")
flyBox.Size = UDim2.new(1, 0, 0, 35)
flyBox.Position = UDim2.new(0, 0, 0, 135)
flyBox.BackgroundColor3 = Color3.fromRGB(30, 41, 59)
flyBox.Text = "50"
flyBox.TextColor3 = Color3.fromRGB(255, 255, 255)
flyBox.Font = Enum.Font.SourceSans
flyBox.TextSize = 16
flyBox.Parent = MoveContainer
Instance.new("UICorner", flyBox).CornerRadius = UDim.new(0, 6)

local flyBtn = Instance.new("TextButton")
flyBtn.Size = UDim2.new(1, 0, 0, 40)
flyBtn.Position = UDim2.new(0, 0, 0, 185)
flyBtn.BackgroundColor3 = Color3.fromRGB(225, 29, 72)
flyBtn.Text = "Activer / Désactiver Fly (Vol)"
flyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
flyBtn.Font = Enum.Font.SourceSansBold
flyBtn.TextSize = 15
flyBtn.Parent = MoveContainer
Instance.new("UICorner", flyBtn).CornerRadius = UDim.new(0, 6)

local flying = false
local bg, bv
flyBtn.MouseButton1Click:Connect(function()
    flying = not flying
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    
    if flying then
        flyBtn.BackgroundColor3 = Color3.fromRGB(16, 185, 129)
        local hrp = char.HumanoidRootPart
        bg = Instance.new("BodyGyro", hrp)
        bg.P = 9e4
        bg.maxTorque = Vector3.new(9e4, 9e4, 9e4)
        bg.cframe = hrp.CFrame
        
        bv = Instance.new("BodyVelocity", hrp)
        bv.velocity = Vector3.new(0,0,0)
        bv.maxForce = Vector3.new(9e4, 9e4, 9e4)
        
        RunService.RenderStepped:Connect(function()
            if not flying then return end
            local speed = tonumber(flyBox.Text) or 50
            local cam = workspace.CurrentCamera
            local moveDir = Vector3.new(0,0,0)
            
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + cam.CoordinateFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - cam.CoordinateFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - cam.CoordinateFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + cam.CoordinateFrame.RightVector end
            
            bv.velocity = moveDir * speed
            bg.cframe = cam.CoordinateFrame
        end)
    else
        flyBtn.BackgroundColor3 = Color3.fromRGB(225, 29, 72)
        if bg then bg:Destroy() end
        if bv then bv:Destroy() end
    end
end)

-- Gestion bascule des onglets
TabPlayerBtn.MouseButton1Click:Connect(function()
    PlayerContainer.Visible = true
    MoveContainer.Visible = false
    TabPlayerBtn.BackgroundColor3 = Color3.fromRGB(3, 105, 161)
    TabMoveBtn.BackgroundColor3 = Color3.fromRGB(51, 65, 85)
end)

TabMoveBtn.MouseButton1Click:Context(function() end)
TabMoveBtn.MouseButton1Click:Connect(function()
    PlayerContainer.Visible = false
    MoveContainer.Visible = true
    TabMoveBtn.BackgroundColor3 = Color3.fromRGB(3, 105, 161)
    TabPlayerBtn.BackgroundColor3 = Color3.fromRGB(51, 65, 85)
end
