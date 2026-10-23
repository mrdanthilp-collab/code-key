local SCRIPT_URL = "https://raw.githubusercontent.com/mrdanthilp-collab/code-key/refs/heads/main/farm.lua"

local collectInterval = 0.1
local maxTimeOnServer = 15.0

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local autoFarm = false
local isHopping = false

-- Проверка экзекьютора
local QueueFunction = nil
if type(syn) == "table" and syn.queue_on_teleport then
    QueueFunction = syn.queue_on_teleport
elseif type(queue_on_teleport) == "function" then
    QueueFunction = queue_on_teleport
elseif type(fluxus) == "table" and fluxus.queue_on_teleport then
    QueueFunction = fluxus.queue_on_teleport
end

-- ==========================================
-- ЛОГИКА СБОРА
-- ==========================================
local function getCandyCount()
    local folder = Workspace:FindFirstChild("CandyCorns")
    if folder then return #folder:GetChildren() end
    return 0
end

local function collectCandies()
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return 0 end
    
    local folder = Workspace:FindFirstChild("CandyCorns")
    if not folder then return 0 end
    
    local count = 0
    for _, candy in ipairs(folder:GetChildren()) do
        pcall(function()
            if candy:IsA("BasePart") then
                candy.CFrame = hrp.CFrame
                count = count + 1
            elseif candy:IsA("Model") then
                candy:PivotTo(hrp.CFrame)
                count = count + 1
            end
        end)
    end
    return count
end

-- ==========================================
-- ЛОГИКА СМЕНЫ СЕРВЕРА
-- ==========================================
local function hopToRandomServer()
    if isHopping then return end
    isHopping = true
    
    local placeId = game.PlaceId
    local currentJobId = game.JobId
    local url = "https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Asc&limit=100"
    
    print("[AutoHop] Ищу новый сервер...")
    local response = nil
    local req = request or http_request or syn.request
    
    if req then
        local ok, res = pcall(req, {Url = url, Method = "GET"})
        if ok and res and res.Success then
            local s, r = pcall(function() return HttpService:JSONDecode(res.Body) end)
            if s then response = r end
        end
    end
    
    if not response then
        local ok, res = pcall(function() return game:HttpGet(url) end)
        if ok then
            local s, r = pcall(function() return HttpService:JSONDecode(res) end)
            if s then response = r end
        end
    end
    
    local randomServerId = nil
    if response and response.data then
        local availableServers = {}
        for _, server in ipairs(response.data) do
            if server.id ~= currentJobId and server.playing < server.maxPlayers then
                table.insert(availableServers, server.id)
            end
        end
        if #availableServers > 0 then
            randomServerId = availableServers[math.random(1, #availableServers)]
        end
    end
    
    -- Если не нашли ID, используем стандартный телепорт (закинет куда-нибудь)
    if not randomServerId then
        print("[AutoHop] Ошибка API, стандартный телепорт.")
        TeleportService:Teleport(placeId, player)
        return
    end
    
    print("[AutoHop] Переход на: " .. randomServerId)
    
    -- ==========================================
    -- ОБНОВЛЕННЫЙ QUEUE (С ЗАДЕРЖКОЙ И PCALL)
    -- ==========================================
    if QueueFunction and SCRIPT_URL ~= "" then
        -- Ждем 3 секунды на новом сервере перед запуском, чтобы прогрузился PlayerGui
        local execString = string.format(
            'task.wait(3) local s, e = pcall(function() loadstring(game:HttpGet("%s"))() end) if not s then warn("[AutoFarmLoadErr] " .. tostring(e)) end', 
            SCRIPT_URL
        )
        QueueFunction(execString)
    end
    
    TeleportService:TeleportToPlaceInstance(placeId, randomServerId, player)
end

-- ==========================================
-- ОСНОВНОЙ ЦИКЛ (СБОР ДО ПУСТОТЫ)
-- ==========================================
local function autoFarmLoop()
    local startTime = tick()
    local emptyTicks = 0
    
    while autoFarm do
        collectCandies()
        local currentCount = getCandyCount()
        
        if statusLabel then 
            statusLabel.Text = "Статус: Сбор... Осталось: " .. currentCount
        end
        
        if currentCount == 0 then
            emptyTicks = emptyTicks + 1
            if emptyTicks > 5 then 
                if statusLabel then statusLabel.Text = "Статус: Все собрано! Ливаю..." end
                autoFarm = false 
                hopToRandomServer()
                break
            end
        else
            emptyTicks = 0
        end
        
        if tick() - startTime > maxTimeOnServer then
            if statusLabel then statusLabel.Text = "Статус: Таймаут 15с. Ливаю..." end
            autoFarm = false 
            hopToRandomServer()
            break
        end
        
        task.wait(0.1)
    end
end

-- ==========================================
-- GUI
-- ==========================================
local gui = Instance.new("ScreenGui")
gui.Name = "AutoCandyServerHop"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 250, 0, 160)
frame.Position = UDim2.new(0, 20, 0, 100)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
frame.BorderSizePixel = 2
frame.BorderColor3 = Color3.fromRGB(200, 200, 200)
frame.Active = true
frame.Draggable = true
frame.Parent = gui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
title.BorderSizePixel = 0
title.Text = "Fast Server Hop"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 13
title.Parent = frame

statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -20, 0, 20)
statusLabel.Position = UDim2.new(0, 10, 0, 35)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Статус: Инициализация..."
statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 11
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = frame

local btnToggle = Instance.new("TextButton")
btnToggle.Size = UDim2.new(1, -20, 0, 35)
btnToggle.Position = UDim2.new(0, 10, 0, 60)
btnToggle.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
btnToggle.BorderSizePixel = 0
btnToggle.Text = "Auto Farm: OFF"
btnToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
btnToggle.Font = Enum.Font.GothamBold
btnToggle.TextSize = 12
btnToggle.Parent = frame

local btnForceHop = Instance.new("TextButton")
btnForceHop.Size = UDim2.new(1, -20, 0, 30)
btnForceHop.Position = UDim2.new(0, 10, 0, 105)
btnForceHop.BackgroundColor3 = Color3.fromRGB(150, 100, 50)
btnForceHop.BorderSizePixel = 0
btnForceHop.Text = "Сменить сервер сейчас"
btnForceHop.TextColor3 = Color3.fromRGB(255, 255, 255)
btnForceHop.Font = Enum.Font.GothamBold
btnForceHop.TextSize = 11
btnForceHop.Parent = frame

local function startFarm()
    if autoFarm then return end
    autoFarm = true
    btnToggle.Text = "Auto Farm: ON"
    btnToggle.BackgroundColor3 = Color3.fromRGB(100, 200, 100)
    statusLabel.Text = "Статус: Старт сбора..."
    task.spawn(autoFarmLoop)
end

btnToggle.MouseButton1Click:Connect(function()
    autoFarm = not autoFarm
    if autoFarm then startFarm()
    else
        btnToggle.Text = "Auto Farm: OFF"
        btnToggle.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
        statusLabel.Text = "Статус: Остановлено"
    end
end)

btnForceHop.MouseButton1Click:Connect(function()
    autoFarm = false
    btnToggle.Text = "Auto Farm: OFF"
    btnToggle.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
    statusLabel.Text = "Статус: Принудительный переход..."
    hopToRandomServer()
end)

-- ==========================================
-- ЖЕЛЕЗОБЕТОННЫЙ АВТО-СТАРТ
-- ==========================================
task.spawn(function()
    statusLabel.Text = "Статус: Ждем загрузку карты..."
    local waitTime = 0
    while not Workspace:FindFirstChild("CandyCorns") and waitTime < 20 do
        task.wait(0.5)
        waitTime = waitTime + 0.5
    end
    
    statusLabel.Text = "Статус: Ждем персонажа..."
    while not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") do
        task.wait(0.5)
    end
    
    statusLabel.Text = "Статус: Авто-старт!"
    task.wait(0.5)
    startFarm()
end)
