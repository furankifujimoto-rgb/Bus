-- [[ 0. PERSISTENCE (QUEUE ON TELEPORT) ]]

-- try to get a queue_on_teleport function from common executors
local queue_on_teleport = queue_on_teleport
    or queueteleport
    or (syn and syn.queue_on_teleport)
    or (fluxus and fluxus.queue_on_teleport)
    or (KRNL_LOADED and queue_on_teleport)
    or nil

-- if supported, queue this same script to run in the next server
if queue_on_teleport then
    -- IMPORTANT: replace the loadstring(...) below with however you normally load this script
    -- Example: if you execute it from a URL, put that same loadstring(game:HttpGet(...)) here.
    queue_on_teleport([[
        loadstring(game:HttpGet("https://raw.githubusercontent.com/furankifujimoto-rgb/Bus/refs/heads/main/SHINOBI%20HUNTER.lua"))()
    ]])
end

-- If you paste this whole file directly into your executor,
-- then instead of HttpGet, you can just paste the full script
-- again in the queued chunk (not recommended because very long).

----------------------------------------------------------------
-- [[ 1. CONFIGURATION & SERVICES ]] --
----------------------------------------------------------------

local bossName = "StrongestShinobiBoss"
local targetCFrame = CFrame.new(-2112.1355, 29.5027905, -596.019653) 
local travelSpeed = 75 
local backDistance = 7 
local swordSlot = Enum.KeyCode.Two
local skills = {Enum.KeyCode.X, Enum.KeyCode.C} 

local stopHoppingAt = 60 
local targetMaxPlayers = 6 
local HistoryFile = "ShinobiHunter_History.json"

local player = game.Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local root = char:WaitForChild("HumanoidRootPart")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local VIM = game:GetService("VirtualInputManager")
local HttpService = game:GetService("HttpService")

local isFarming = false
local isTraveling = false
local isTeleporting = false

----------------------------------------------------------------
-- [[ 2. UTILITIES & HOPPER ENGINE ]] --
----------------------------------------------------------------

local function getHistory()
    local success, content = pcall(readfile, HistoryFile)
    if success and content then 
        local s, data = pcall(function() return HttpService:JSONDecode(content) end)
        if s then return data end
    end
    return {os.date("!*t").hour}
end

local function saveToHistory(id)
    local hist = getHistory()
    table.insert(hist, tostring(id))
    pcall(writefile, HistoryFile, HttpService:JSONEncode(hist))
end

local function serverHop()
    if isTeleporting then return end
    print("Searching for fresh servers...")
    local url = 'https://games.roblox.com/v1/games/'..game.PlaceId..'/servers/Public?sortOrder=Asc&limit=100'
    local success, result = pcall(function() return game:HttpGet(url) end)
    if not success or not result then return end
    
    local decoded = HttpService:JSONDecode(result)
    local history = getHistory()
    local servers = decoded.data
    table.sort(servers, function(a, b) return a.playing < b.playing end)

    for _, server in pairs(servers) do
        local id = tostring(server.id)
        if server.playing < targetMaxPlayers and id ~= game.JobId then
            local seen = false
            for _, vId in pairs(history) do
                if id == vId then
                    seen = true
                    break
                end
            end
            if not seen then
                isTeleporting = true
                saveToHistory(id)
                game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, server.id)
                task.wait(5)
                isTeleporting = false 
                return 
            end
        end
    end
end

----------------------------------------------------------------
-- [[ 3. PHYSICS & COMBAT CONTROLLERS ]] --
----------------------------------------------------------------

local bp = Instance.new("BodyPosition", root)
bp.MaxForce = Vector3.new(0, 0, 0)
bp.P, bp.D = 20000, 1500

local bg = Instance.new("BodyGyro", root)
bg.MaxTorque = Vector3.new(0, 0, 0)
bg.P = 5000

RunService.Stepped:Connect(function()
    if isFarming or isTraveling then
        if char then
            for _, v in pairs(char:GetDescendants()) do
                if v:IsA("BasePart") then
                    v.CanCollide = false
                end
            end
        end
    end
end)

local function travelToIsland()
    if (root.Position - targetCFrame.Position).Magnitude < 50 then return end
    isTraveling = true
    local dist = (root.Position - targetCFrame.Position).Magnitude
    local info = TweenInfo.new(dist/travelSpeed, Enum.EasingStyle.Linear)
    local tween = TweenService:Create(root, info, {CFrame = targetCFrame})
    tween:Play()
    tween.Completed:Wait()
    isTraveling = false
end

----------------------------------------------------------------
-- [[ 4. THE MAIN COMBAT LOOP ]] --
----------------------------------------------------------------

RunService.Heartbeat:Connect(function()
    if not isFarming then 
        bp.MaxForce = Vector3.new(0, 0, 0)
        bg.MaxTorque = Vector3.new(0, 0, 0)
        return 
    end
    
    local boss = workspace.NPCs:FindFirstChild(bossName)
    if boss and boss:FindFirstChild("HumanoidRootPart") then
        local bossRoot = boss.HumanoidRootPart
        local humanoid = boss:FindFirstChildOfClass("Humanoid")
        
        if humanoid and humanoid.Health > 0 then
            bp.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
            bp.Position = (bossRoot.CFrame * CFrame.new(0, 2, backDistance)).Position
            bg.CFrame = CFrame.new(root.Position, bossRoot.Position)
            root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)

            if not char:FindFirstChildOfClass("Tool") then
                VIM:SendKeyEvent(true, swordSlot, false, game)
            end

            for _, key in pairs(skills) do
                VIM:SendKeyEvent(true, key, false, game)
                VIM:SendKeyEvent(false, key, false, game)
            end
            
            game:GetService("ReplicatedStorage").Events.TryAttack:FireServer({
                ["Victim"] = boss,
                ["Type"] = "Light",
                ["VictimPosition"] = bossRoot.Position,
                ["CurrentHeavy"] = 1,
                ["CurrentLight"] = 1,
                ["CurrentLightCombo"] = 1,
                ["LocalInfo"] = {["Flying"] = false},
                ["AnimSet"] = "Generic"
            })
        else
            isFarming = false 
        end
    end
end)

----------------------------------------------------------------
-- [[ 5. MASTER CONTROLLER ]] --
----------------------------------------------------------------

task.spawn(function()
    while true do
        local boss = workspace.NPCs:FindFirstChild(bossName)
        local alive = boss and (boss:FindFirstChildOfClass("Humanoid")
            and boss:FindFirstChildOfClass("Humanoid").Health > 0)
        
        if alive then
            travelToIsland()
            isFarming = true
            repeat
                task.wait(2)
            until not boss or not (boss:FindFirstChildOfClass("Humanoid")
                and boss:FindFirstChildOfClass("Humanoid").Health > 0)
            task.wait(5)
            serverHop()
        else
            local timerContainer = workspace:FindFirstChild("TimedBossSpawn_"..bossName.."_Container", true)
            local canWait = false
            
            if timerContainer then
                local label = timerContainer:FindFirstChild("Timer", true)
                if label then
                    local min, sec = label.Text:match("(%d+):(%d+)")
                    local totalSec = (tonumber(min) or 0) * 60 + (tonumber(sec) or 0)
                    if totalSec <= stopHoppingAt then
                        travelToIsland()
                        canWait = true
                    end
                end
            end
            
            if not canWait then
                serverHop()
            end
        end
        task.wait(5)
    end
end)
