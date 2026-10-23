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
-- УМНАЯ ЛОГИКА СМЕНЫ СЕРВЕРА (АНТИ-БАН)
-- ==========================================
local function hopToRandomServer()
    if isHopping then return end
    isHopping = true
    
    local placeId = game.PlaceId
    local currentJobId = game.JobId
    local url = "https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Asc&limit=100"
    
    if statusLabel then statusLabel.Text = "Статус: Поиск сервера..." end
    
    local response = nil
    local req = request or http_request or syn.request
    
    -- Делаем до 3 попыток получить список серверов
    for i = 1, 3 do
        if req then
            local ok, res = pcall(req, {Url = url, Method = "GET"})
            if ok and res and res.Success then
                local s, r = pcall(function() return HttpService:JSONDecode(res.Body) end)
                if s then response = r; break end
            end
        end
        if not response then
            local ok, res = pcall(function() return game:HttpGet(url) end)
            if ok then
                local s, r = pcall(function() return HttpService:JSONDecode(res) end)
                if s then response = r; break end
            end
        end
        task.wait(2) -- Ждем 2 секунды перед повторной попыткой
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
    
    -- Если Roblox заблокировал API (Rate Limit), ждем и пробуем снова
    if not randomServerId then
        if statusLabel then statusLabel.Text = "Статус: Блок API. Ждем 5с..." end
        task.wait(5)
        isHopping = false
        return hopToRandomServer()
    end
    
    if statusLabel then statusLabel.Text = "Статус: Переход..." end
    
    -- ==========================================
    -- СОХРАНЕНИЕ СКРИПТА (С ОЖИДАНИЕМ ЗАГРУЗКИ)
    -- ==========================================
    if QueueFunction and SCRIPT_URL ~= "" then
        -- Ждем, пока игра прогрузится (IsLoaded), и только потом запускаем
        local execString = string.format(
            'if not game:IsLoaded() then game.Loaded:Wait() end ' ..
            'task.wait(1) ' ..
            'local s, e = pcall(function() loadstring(game:HttpGet("%s", true))() end) ' ..
            'if not s then warn("[AutoFarmLoadErr] " .. tostring(e)) end', 
            SCRIPT_URL
        )
        QueueFunction(execString)
    end
    
    task.wait(1) -- Важно: ждем 1 сек, чтобы экзекьютор точно сохранил команду
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
            if statusLabel then statusLabel.Text = "Статус: Таймаут. Ливаю..." end
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
-- АВТО-СТАРТ
-- ==========================================
task.spawn(function()
    if statusLabel then statusLabel.Text = "Статус: Ждем загрузку карты..." end
    local waitTime = 0
    while not Workspace:FindFirstChild("CandyCorns") and waitTime < 20 do
        task.wait(0.5)
        waitTime = waitTime + 0.5
    end
    
    if statusLabel then statusLabel.Text = "Статус: Ждем персонажа..." end
    while not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") do
        task.wait(0.5)
    end
    
    if statusLabel then statusLabel.Text = "Статус: Авто-старт!" end
    task.wait(0.5)
    startFarm()
end)
