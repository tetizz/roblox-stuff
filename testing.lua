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
local policiesFolder = replicatedStorage.Assets.Laws.Policies
local GameManager = workspace.GameManager
local RunService = game:GetService("RunService")

local function getCountryByLeader(leaderName)
    for _, countryData in pairs(workspaceData:GetChildren()) do
        local leader = countryData:FindFirstChild("Leader")
        if leader and leader.Value == leaderName then
            return countryData.Name
        end
    end
    return nil
end

local country = getCountryByLeader(player.Name)

local function getPoliticalPower()
    return workspaceData[country].Power.Political.Value
end

local function getActivePolicies()
    local active = {}
    for _, policy in ipairs(workspaceData[country].Laws.Policies:GetChildren()) do
        active[policy.Name] = true
    end
    return active
end

local function enactPolicy(policyName)
    local args = {
        "Policy",
        policyName
    }
    GameManager:WaitForChild("ChangeLaw"):FireServer(unpack(args))
end

local function sanitizeKey(name)
    return name:gsub("[^%w]", "_")
end

local Toggles = {}
for _, policy in ipairs(policiesFolder:GetChildren()) do
    local policyName = policy.Name
    local key = sanitizeKey(policyName)
    Toggles[key] = Groupbox:AddToggle("Toggle_" .. key, {
        Text = policyName,
        Default = false,
        Callback = function() end
    })
end

local recentlyEnacted = {}

local function checkAndEnactPolicies()
    local activePolicies = getActivePolicies()
    local power = getPoliticalPower()

    for _, policy in ipairs(policiesFolder:GetChildren()) do
        local policyName = policy.Name
        local costValue = policy:FindFirstChild("PPCost")
        local cost = costValue and costValue.Value or 0
        local toggle = Toggles[sanitizeKey(policyName)]

        if toggle and toggle.Value and power >= cost then
            if not activePolicies[policyName] and not recentlyEnacted[policyName] then
                enactPolicy(policyName)
                recentlyEnacted[policyName] = true
            elseif activePolicies[policyName] then
                recentlyEnacted[policyName] = nil
            end
        end
    end
end

RunService.Heartbeat:Connect(function()
    checkAndEnactPolicies()
end)

