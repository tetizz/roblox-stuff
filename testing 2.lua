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
    warn("Essential game elements missing (Policies, GameManager, or CountryData).")
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
    warn("Could not determine player’s country.")
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
local function enactPolicy(policyName)
    local activePolicies = getActivePolicies()
    if activePolicies[policyName] then return end -- Prevent firing if already active

    local args = {
        "Policy",
        policyName
    }

    local success, err = pcall(function()
        workspace:WaitForChild("GameManager"):WaitForChild("ChangeLaw"):FireServer(unpack(args))
    end)

    if success then
        print("Enacted policy:", policyName)
    else
        warn("Failed to enact policy:", policyName, err)
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
                print(policyName .. " toggled to " .. tostring(val))
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

        local costSuccess, cost = pcall(function()
            return costValue and costValue.Value
        end)

        if costSuccess and toggle and toggle.Value and type(cost) == "number" then
            if not activePolicies[policyName] and power >= cost then
                enactPolicy(policyName)
            end
        end
    end
end

-- Use Heartbeat instead of while true loop
RunService.Heartbeat:Connect(function()
    pcall(checkAndEnactPolicies)
end)
