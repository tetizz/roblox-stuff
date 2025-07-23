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
    print("Searching for country with leader:", leaderName)
    for _, countryData in pairs(workspaceData:GetChildren()) do
        local leader = countryData:FindFirstChild("Leader")
        if leader then
            print("Found leader in:", countryData.Name, "=", leader.Value)
            if leader.Value == leaderName then
                print("Matched leader to country:", countryData.Name)
                return countryData.Name
            end
        end
    end
    return nil
end

-- Get player country
local country = getCountryByLeader(player.Name)
if not country then
    warn("Could not determine player’s country.")
    return
else
    print("Player country determined:", country)
end

-- Get current political power safely
local function getPoliticalPower()
    local countryData = workspaceData:FindFirstChild(country)
    if not countryData then print("No country data") return 0 end

    local power = countryData:FindFirstChild("Power")
    if not power then print("No power data") return 0 end

    local political = power:FindFirstChild("Political")
    if not political then print("No political value") return 0 end

    local success, value = pcall(function() return political.Value end)
    if success and type(value) == "number" then
        print("Political power:", value)
        return value
    end

    return 0
end

-- Get active policies
local function getActivePolicies()
    local active = {}
    local countryData = workspaceData:FindFirstChild(country)
    if not countryData then print("No country data for active policies") return active end

    local laws = countryData:FindFirstChild("Laws")
    if not laws then print("No laws data") return active end

    local policies = laws:FindFirstChild("Policies")
    if not policies then print("No policies folder") return active end

    for _, policy in ipairs(policies:GetChildren()) do
        active[policy.Name] = true
    end
    print("Active policies:", active)
    return active
end

-- Enact a policy
local recentlyEnacted = {}
local function enactPolicy(policyName)
    print("Attempting to enact:", policyName)
    if recentlyEnacted[policyName] then
        print("Already enacted recently:", policyName)
        return
    end

    local args = {
        "Policy",
        policyName
    }

    local success, err = pcall(function()
        GameManager:WaitForChild("ChangeLaw"):FireServer(unpack(args))
    end)

    if success then
        print("Successfully enacted:", policyName)
        recentlyEnacted[policyName] = true
    else
        warn("Failed to enact:", policyName, err)
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

    if not policiesFolder then print("No policies folder") return end

    for _, policy in ipairs(policiesFolder:GetChildren()) do
        local policyName = policy.Name
        local costValue = policy:FindFirstChild("PPCost")
        local toggle = Toggles[sanitizeKey(policyName)]

        local cost = 0
        if costValue and costValue:IsA("Vector3Value") then
            cost = costValue.Value.X -- use only the X component
        else
            print("PPCost missing or invalid for:", policyName)
        end

        print("Checking:", policyName, "Toggle:", toggle and toggle.Value, "Cost:", cost, "Power:", power)

        if toggle and toggle.Value and type(cost) == "number" then
            if not activePolicies[policyName] and power >= cost then
                print("Conditions met for:", policyName)
                enactPolicy(policyName)
            else
                print("Conditions NOT met for:", policyName, "Active:", activePolicies[policyName], "Power:", power)
            end
        end
    end
end

-- Use Heartbeat instead of while true loop
RunService.Heartbeat:Connect(function()
    pcall(checkAndEnactPolicies)
end)
