-- Load Obsidian UI Library
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/deividcomsono/Obsidian/refs/heads/main/Library.lua"))()

local Window = Library:CreateWindow({
    Title = "Auto Policy Enact",
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
local policiesFolder = replicatedStorage:FindFirstChild("Assets") 
    and replicatedStorage.Assets:FindFirstChild("Laws") 
    and replicatedStorage.Assets.Laws:FindFirstChild("Policies")
local GameManager = workspace:FindFirstChild("GameManager")
local RunService = game:GetService("RunService")

if not policiesFolder or not GameManager or not workspaceData then
    return
end

-- Get current country by leader
local function getCountryByLeader(leaderName)
    for _, countryData in pairs(workspaceData:GetChildren()) do
        local leader = countryData:FindFirstChild("Leader")
        if leader and leader.Value == leaderName then
            return countryData.Name
        end
    end
    return nil
end

-- Get player country
local country = getCountryByLeader(player.Name)
if not country then
    return
end

-- Get current political power safely
local function getPoliticalPower()
    local countryData = workspaceData:FindFirstChild(country)
    if not countryData then return 0 end

    local power = countryData:FindFirstChild("Power")
    if not power then return 0 end

    local political = power:FindFirstChild("Political")
    if not political then return 0 end

    local success, value = pcall(function() return political.Value end)
    if success and type(value) == "number" then
        return value
    end

    return 0
end

-- Get active policies
local function getActivePolicies()
    local active = {}
    local countryData = workspaceData:FindFirstChild(country)
    if not countryData then return active end

    local laws = countryData:FindFirstChild("Laws")
    if not laws then return active end

    local policies = laws:FindFirstChild("Policies")
    if not policies then return active end

    for _, policy in ipairs(policies:GetChildren()) do
        active[policy.Name] = true
    end
    return active
end

-- Enact a policy
local recentlyEnacted = {}
local function enactPolicy(policyName)
    local activePolicies = getActivePolicies()
    if activePolicies[policyName] then
        return
    end
    if recentlyEnacted[policyName] then
        return
    end

    local args = {
        "Policy",
        policyName
    }

    local success = pcall(function()
        GameManager:WaitForChild("ChangeLaw"):FireServer(unpack(args))
    end)

    if success then
        recentlyEnacted[policyName] = true
    end
end

-- Sanitize toggle key for Obsidian compatibility
local function sanitizeKey(name)
    return name:gsub("[^%w]", "_")
end

-- Create toggle for each policy and store toggle references
local Toggles = {}
if policiesFolder then
    for _, policy in ipairs(policiesFolder:GetChildren()) do
        local policyName = policy.Name
        local key = sanitizeKey(policyName)
        Toggles[key] = Groupbox:AddToggle("Toggle_" .. key, {
            Text = policyName,
            Default = false,
            Callback = function(val)
            end
        })
    end
end

-- Auto-check policies and enact if affordable and not already active
local function checkAndEnactPolicies()
    local activePolicies = getActivePolicies()
    local power = getPoliticalPower()

    if not policiesFolder then return end

    for _, policy in ipairs(policiesFolder:GetChildren()) do
        local policyName = policy.Name
        local costValue = policy:FindFirstChild("PPCost")
        local toggle = Toggles[sanitizeKey(policyName)]

        local cost = 0
        if costValue and costValue:IsA("Vector3Value") then
            cost = costValue.Value.X
        end

        local isActive = activePolicies[policyName] == true
        local isToggled = toggle and toggle.Value

        if isToggled and not isActive and type(cost) == "number" and power >= cost then
            enactPolicy(policyName)
        elseif isToggled and isActive then
            recentlyEnacted[policyName] = true
        elseif not isActive then
            recentlyEnacted[policyName] = nil
        end
    end
end

-- Use Heartbeat instead of while true loop
RunService.Heartbeat:Connect(function()
    pcall(checkAndEnactPolicies)
end)

