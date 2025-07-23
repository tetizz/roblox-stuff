local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local GameManager = workspace:WaitForChild("GameManager")
local policiesFolder = ReplicatedStorage.Assets.Laws.Policies
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/deividcomsono/Obsidian/refs/heads/main/Library.lua"))()

local Window = Library:CreateWindow({
    Title = "Auto Policy Enactor",
    Footer = "v1.0",
    ToggleKeybind = Enum.KeyCode.RightControl,
    Center = true,
    AutoShow = true
})

local Tab = Window:AddTab("Policies", "shield")
local Group = Tab:AddLeftGroupbox("Auto Policies", "list")

-- Get country name by finding the player as leader
local function getCountryByLeader(leaderName)
    for _, countryData in pairs(workspace.CountryData:GetChildren()) do
        local leader = countryData:FindFirstChild("Leader")
        if leader and leader.Value == leaderName then
            return countryData.Name
        end
    end
    return nil
end

local country = getCountryByLeader(player.Name)
if not country then
    warn("Could not determine player’s country.")
    return
end

-- Stores policy toggles
local policyToggles = {}

-- Get active policies
local function getActivePolicies()
    local activeFolder = workspace.CountryData[country].Laws:FindFirstChild("Policies")
    local active = {}
    if activeFolder then
        for _, policy in ipairs(activeFolder:GetChildren()) do
            active[policy.Name] = true
        end
    end
    return active
end

-- Get political power (make sure it’s a number)
local function getPoliticalPower()
    local powerObj = workspace.CountryData[country].Power:FindFirstChild("Political")
    return powerObj and powerObj.Value or 0
end

-- Enact a policy
local function enactPolicy(policyName)
    local args = {
        "Policy",
        policyName
    }
    GameManager:WaitForChild("ChangeLaw"):FireServer(unpack(args))
    print("✅ Enacted policy:", policyName)
end

-- Go through toggled policies and try to enact
local function checkAndEnactPolicies()
    local activePolicies = getActivePolicies()
    local currentPower = getPoliticalPower()

    for policyName, toggle in pairs(policyToggles) do
        local isEnabled = toggle:GetState()
        local policy = policiesFolder:FindFirstChild(policyName)

        if isEnabled and not activePolicies[policyName] and policy then
            local costVal = policy:FindFirstChild("PPCost")
            if costVal and typeof(costVal.Value) == "number" then
                local cost = costVal.Value
                if currentPower >= cost then
                    enactPolicy(policyName)
                end
            end
        end
    end
end

-- UI: Add toggle for every policy
for _, policy in ipairs(policiesFolder:GetChildren()) do
    local policyName = policy.Name
    policyToggles[policyName] = Group:AddToggle(policyName, {
        Text = policyName,
        Default = false,
        Callback = function(val)
            print(policyName, "toggle set to", val)
        end
    })
end

-- Use Heartbeat instead of while true
RunService.Heartbeat:Connect(function()
    checkAndEnactPolicies()
end)
