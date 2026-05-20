-- Rise of Nations - Auto Justify All

local Players = game:GetService("Players")
local CountryData = workspace:WaitForChild("CountryData")
local JustifyWar = workspace:WaitForChild("GameManager"):WaitForChild("JustifyWar")

local LocalPlayer = Players.LocalPlayer
local JUSTIFY_DELAY = 1
local RESCAN_DELAY = 5
local REQUEST_RETRY_DELAY = 60

local requested = {}

local function getMyCountry()
    for _, country in ipairs(CountryData:GetChildren()) do
        local leader = country:FindFirstChild("Leader")
        if leader and tostring(leader.Value) == LocalPlayer.Name then
            return country
        end
    end
end

local function hasConquestCB(myCountry, targetName)
    if not myCountry then
        return false
    end

    local diplomacy = myCountry:FindFirstChild("Diplomacy")
    local casusBelli = diplomacy and diplomacy:FindFirstChild("CasusBelli")
    local conquest = casusBelli and casusBelli:FindFirstChild("Conquest")
    return conquest and conquest:FindFirstChild(targetName) ~= nil
end

local function cleanRemovedCountries(currentCountries)
    for countryName in pairs(requested) do
        if not currentCountries[countryName] then
            requested[countryName] = nil
        end
    end
end

while true do
    local myCountry = getMyCountry()
    local currentCountries = {}
    local retryReadyAt = os.clock()

    for _, country in ipairs(CountryData:GetChildren()) do
        local countryName = country.Name
        currentCountries[countryName] = true

        local shouldSkipOwnCountry = myCountry and country == myCountry
        local alreadyHasCB = hasConquestCB(myCountry, countryName)

        if shouldSkipOwnCountry or alreadyHasCB then
            requested[countryName] = nil
        elseif not requested[countryName] or requested[countryName] <= retryReadyAt then
            requested[countryName] = retryReadyAt + REQUEST_RETRY_DELAY
            pcall(function()
                JustifyWar:FireServer(countryName, "Conquest")
            end)
        end

        task.wait(JUSTIFY_DELAY)
    end

    cleanRemovedCountries(currentCountries)
    task.wait(RESCAN_DELAY)
end
