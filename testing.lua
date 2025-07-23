-- Load Library
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/deividcomsono/Obsidian/refs/heads/main/Library.lua"))()

local Window = Library:CreateWindow({
    Title = "Auto Policy",
    Footer = "v1.0.0",
    Center = true,
    AutoShow = true,
    ToggleKeybind = Enum.KeyCode.RightControl
})

local MainTab = Window:AddTab("Policies", "sliders")
local Groupbox = MainTab:AddLeftGroupbox("Toggle Policies")

local player = game.Players.LocalPlayer
local replicatedStorage = game:GetService("ReplicatedStorage")
local workspaceData = workspace:FindFirstChild("CountryData")
local GameManager = workspace:FindFirstChild("GameManager")
local RunService = game:GetService("RunService")

local policiesFolder = replicatedStorage:FindFirstChild("Assets") 
    and replicatedStorage.Assets:FindFirstChild("Laws")
    and replicatedStorage.Assets.Laws:FindFirstChild("Policies")

if not (policiesFolder and GameManager and workspaceData) then return end

-- Get country
local function getCountry()
    for _, country in pairs(workspaceData:GetChildren()) do
        local leader = country:FindFirstChild("Leader")
        if leader and leader.Value == player.Name then
            return country.Name
        end
    end
end

local country = getCountry()
if not country then return end

local function getPower()
    local political = workspaceData[country]:FindFirstChild("Power") and workspaceData[country].Power:FindFirstChild("Political")
    return (political and typeof(political.Value) == "number") and political.Value or 0
end

local function getActivePolicies()
    local active = {}
    local policyFolder = workspaceData[country]:FindFirstChild("Laws") and workspaceData[country].Laws:FindFirstChild("Policies")
    if policyFolder then
        for _, p in ipairs(policyFolder:GetChildren()) do
            active[p.Name] = true
        end
    end
    return active
end

local recentlyEnacted = {}
local function enactPolicy(name)
    GameManager:WaitForChild("ChangeLaw"):FireServer("Policy", name)
    recentlyEnacted[name] = true
end

local function sanitize(name)
    return name:gsub("[^%w]", "_")
end

local Toggles = {}
local sortedPolicies = policiesFolder:GetChildren()
table.sort(sortedPolicies, function(a, b) return a.Name < b.Name end)

for _, policy in ipairs(sortedPolicies) do
    local key = sanitize(policy.Name)
    Toggles[key] = Groupbox:AddToggle("Toggle_" .. key, {
        Text = policy.Name,
        Default = false,
        Callback = function() end
    })
end

task.spawn(function()
    while true do
        local active = getActivePolicies()
        for name in pairs(recentlyEnacted) do
            if not active[name] then
                recentlyEnacted[name] = nil
            end
        end
        task.wait(5)
    end
end)

local function processPolicies()
    local active = getActivePolicies()
    local power = getPower()

    for _, policy in ipairs(policiesFolder:GetChildren()) do
        local name = policy.Name
        local toggle = Toggles[sanitize(name)]
        local costObj = policy:FindFirstChild("PPCost")
        local cost = (costObj and costObj:IsA("Vector3Value")) and costObj.Value.X or 0

        if toggle and toggle.Value and not active[name] and not recentlyEnacted[name] and power >= cost then
            enactPolicy(name)
        end
    end
end

RunService.Heartbeat:Connect(function()
    pcall(processPolicies)
end)
