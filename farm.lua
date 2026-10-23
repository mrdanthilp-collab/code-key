-- СЮДА Я УЖЕ ВСТАВИЛ ТВОЮ ССЫЛКУ
local SCRIPT_URL = "https://raw.githubusercontent.com/mrdanthilp-collab/code-key/515def41164b2c4ffc2831f3cccbf415170a98b6/farm.lua"

local collectInterval = 1.0
local hopDelay = 15.0
local VISITED_FILE = "CandyFarm_VisitedServers.txt"

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local autoFarm = false
local visitedServers = {}

local function loadVisitedServers()
    visitedServers = {}
    if isfile and isfile(VISITED_FILE) then
        local content = readfile(VISITED_FILE)
        for jobId in string.gmatch(content, "[^\n]+") do
            visitedServers[jobId] = true
        end
    end
end

local function markCurrentServerVisited()
    visitedServers[game.JobId] = true
    if writefile then
        local text = ""
        for jobId in pairs(visitedServers) do
            text = text .. jobId .. "\n"
        end
        writefile(VISITED_FILE, text)
    end
end

loadVisitedServers()

local function collectCandies()
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local folder = Workspace:FindFirstChild("CandyCorns")
    if not folder then return end
    for _, candy in ipairs(folder:GetChildren()) do
        pcall(function()
            if candy:IsA("BasePart") then
                candy.CFrame = hrp.CFrame
            elseif candy:IsA("Model") then
                candy:PivotTo(hrp.CFrame)
            end
        end)
    end
end

local function hopToRandomServer()
    local placeId = game.PlaceId
    local currentJobId = game.JobId
    local url = "https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Asc&limit=100"
    
    local success, response = pcall(function()
        return HttpService:JSONDecode(game:HttpGet(url))
    end)
    
    if not success or not response or not response.data then
        print("[AutoHop] Не удалось получить список серверов.")
        return
    end
    
    local availableServers = {}
    for _, server in ipairs(response.data) do
        if server.id ~= currentJobId 
           and server.playing < server.maxPlayers 
           and not visitedServers[server.id] then
            table.insert(availableServers, server.id)
        end
    end
    
    if #availableServers == 0 then
        print("[AutoHop] Все сервера посещены. Очищаем историю.")
        if writefile then writefile(VISITED_FILE, "") end
        visitedServers = {}
        task.wait(2)
        hopToRandomServer()
        return
    end
    
    local randomServerId = availableServers[math.random(1, #availableServers)]
    print("[AutoHop] Переход на новый сервер: " .. randomServerId)
    markCurrentServerVisited()
    
    -- Сохраняем скрипт для перезапуска
    local executeCode = 'loadstring(game:HttpGet("' .. SCRIPT_URL .. '"))()'
    if type(syn) == "table" and syn.queue_on_teleport then
        syn.queue_on_teleport(executeCode)
    elseif type(queue_on_teleport) == "function" then
        queue_on_teleport(executeCode)
    elseif type(fluxus) == "table" and fluxus.queue_on_teleport then
        fluxus.queue_on_teleport(executeCode)
    else
        print("[AutoHop] ВНИМАНИЕ: Экзекьютор не поддерживает queue_on_teleport!")
    end
    
    TeleportService:TeleportToPlaceInstance(placeId, randomServerId, player)
end

local function autoFarmLoop()
    local lastCollect = 0
    local startTime = tick()
    while autoFarm do
        if tick() - lastCollect >= collectInterval then
            collectCandies()
            lastCollect = tick()
        end
        if tick() - startTime >= hopDelay then
            print("[AutoHop] Меняем сервер...")
            autoFarm = false 
            hopToRandomServer()
            break
        end
        task.wait(0.1)
    end
end

local gui = Instance.new("ScreenGui")
gui.Name = "AutoCandyServerHop"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 240, 0, 140)
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
title.Text = "Smart Server Hop"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 13
title.Parent = frame

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -20, 0, 20)
statusLabel.Position = UDim2.new(0, 10, 0, 35)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Статус: ожидание"
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

btnToggle.MouseButton1Click:Connect(function()
    autoFarm = not autoFarm
    btnToggle.Text = "Auto Farm: " .. (autoFarm and "ON" or "OFF")
    btnToggle.BackgroundColor3 = autoFarm and Color3.fromRGB(100, 200, 100) or Color3.fromRGB(80, 80, 100)
    statusLabel.Text = "Статус: " .. (autoFarm and "Сбор идёт..." or "Остановлено")
    if autoFarm then
        task.spawn(autoFarmLoop)
    end
end)

print("✅ Скрипт готов.")
