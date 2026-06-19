-- Rise of Nations - Auto Trade (separate) + Automations (Build/Resupply/Watcher/Justify/Tags/Promote)
-- Preferred formatting: one space around =

--============================================================
-- RoN Nation Brain UI
--============================================================

--============================================================
-- Services / Refs
--============================================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

local CountryData = workspace:WaitForChild("CountryData")
local GameManager = workspace:WaitForChild("GameManager")
local ManageAlliance = GameManager:WaitForChild("ManageAlliance")
local CreateBuilding = GameManager:WaitForChild("CreateBuilding")
local JustifyWar = GameManager:WaitForChild("JustifyWar")
local CountryWorker = GameManager:WaitForChild("CountryWorker")
local ChangeLaw = GameManager:WaitForChild("ChangeLaw")

local Assets = ReplicatedStorage:WaitForChild("Assets")
local Resources = Assets:WaitForChild("Resources")
local BuildingsFolder = Assets:WaitForChild("Buildings")
local LawsFolder = Assets:FindFirstChild("Laws")
local PoliciesFolder = LawsFolder and LawsFolder:FindFirstChild("Policies")

local Baseplate = workspace:WaitForChild("Baseplate")
local CitiesRoot = Baseplate:WaitForChild("Cities")

local Units = workspace:WaitForChild("Units")

-- Fast refs like your old scripts
local GetChildren = game.GetChildren
local FirstChild = game.FindFirstChild

--============================================================
-- CONFIG
--============================================================
local CONFIG = {
	Debug = true,

	-- Auto Trade (separate tab)
	TradeEnabled = false,
	TradeResource = "Consumer Goods",
	TradeTargetPercent = 0.79, -- slider 0..80 default 79
	TradeMultiplier = 1, -- fixed
	TradeDelaySeconds = 0.8,
	TradeMinUnits = 0.1,
	TradeSkipIfTargetSlotOccupied = true,
	TradeAttemptCheckDelay = 1.5,
	TradeCooldownSeconds = 120,
	TradeBypassFlowSafety = false, -- if false: block if flow negative OR units > flow
	TradeOnlyAI = true, -- you asked to detect non-player / AI; keep it AI-only

	-- Automations toggles
	AutoBuildEnabled = false,
	AutoBuildSelected = {},
	AutoBuildPriority = "Selected Order",
	AutoBuildSkipQueued = true,
	AutoResupplyEnabled = false, -- AI-only always
	AutoResupplyOnlyNegativeFlow = true,
	UnitTagsEnabled = false,
	AutoPolicyEnabled = false,

	WatcherEnabled = false, -- rebel funding watcher
	JustifyWatchEnabled = false, -- justification progress watcher
	LeaderWatchEnabled = false, -- corrupt leader watcher
	AutoJustifyEnabled = false,
	AutoJustifyAIOnly = true,
	AutoJustifySkipAllies = true,
	AutoJustifySkipWars = true,
	AutoJustifyRequireCities = true,
	AutoJustifyRetrySeconds = 60,
	AutoDeclareEnabled = false,
	AutoPeaceEnabled = false,

	AutoPromoteEnabled = false, -- corrupt leader promote

	BrainDashboardEnabled = true,
	BrainStrategyMode = "Economic Power",

	NotificationsEnabled = true
}

local function now()
	return os.clock()
end

local function debugPrint(tag, ...)
	if CONFIG.Debug then
		print(tag, ...)
	end
end

local function safeNotify(title, text, duration)
	if not CONFIG.NotificationsEnabled then
		return
	end
	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = title,
			Text = text,
			Duration = duration or 4
		})
	end)
end

--============================================================
-- Simple scheduler (streamlines loops)
--============================================================
local Scheduler = {
	Last = {}
}

local function runEvery(key, interval, fn)
	local t = now()
	local last = Scheduler.Last[key]
	if last and (t - last) < interval then
		return
	end
	Scheduler.Last[key] = t
	fn()
end

--============================================================
-- Leader detection (robust) + AI detection
--============================================================
local PlayerIdentityCache = {
	Dirty = true,
	Set = {}
}

local CountryCache = {
	CheckedAt = 0,
	Folder = nil
}

local function markPlayerIdentityDirty()
	PlayerIdentityCache.Dirty = true
end

Players.PlayerAdded:Connect(markPlayerIdentityDirty)
Players.PlayerRemoving:Connect(markPlayerIdentityDirty)

local function getMyCountryFolder()
	local t = now()
	if CountryCache.Folder and CountryCache.Folder.Parent and (t - CountryCache.CheckedAt) < 0.5 then
		return CountryCache.Folder
	end

	local name = LocalPlayer.Name
	local display = LocalPlayer.DisplayName
	local userId = tostring(LocalPlayer.UserId)

	for _, country in ipairs(CountryData:GetChildren()) do
		local leader = country:FindFirstChild("Leader")
		if leader then
			local v = tostring(leader.Value)
			if v == name or v == display or v == userId then
				CountryCache.CheckedAt = t
				CountryCache.Folder = country
				return country
			end
		end
	end

	CountryCache.CheckedAt = t
	CountryCache.Folder = nil
end

local function assertStillLeader()
	local c = getMyCountryFolder()
	if not c then
		return false
	end
	return true, c
end

local function buildPlayerIdentitySet()
	if not PlayerIdentityCache.Dirty then
		return PlayerIdentityCache.Set
	end

	local set = {}
	for _, p in ipairs(Players:GetPlayers()) do
		set[p.Name] = true
		set[p.DisplayName] = true
		set[tostring(p.UserId)] = true
	end
	PlayerIdentityCache.Set = set
	PlayerIdentityCache.Dirty = false
	return set
end

local function isCountryAI(country, playerSet)
	-- Your rule request:
	-- 1) "check if a country is not a player"
	-- 2) "include the country's name into the name of leader to see if it's ai"
	-- Practical detection:
	-- - Leader.Value NOT equal to any player identity => AI
	-- - OR leader string contains "AI"
	-- - OR leader string contains the country name (common AI labeling)
	local leader = country:FindFirstChild("Leader")
	if not leader then
		return true
	end

	local s = tostring(leader.Value or "")
	if s:find("AI") then
		return true
	end
	if s ~= "" and country.Name and s:lower():find(country.Name:lower(), 1, true) then
		return true
	end

	if playerSet and playerSet[s] then
		return false
	end

	-- If it isn't any current player identity, treat as AI
	return true
end

--============================================================
-- Cities helpers
--============================================================
local CitiesCache = {
	CountryName = nil,
	Folder = nil,
	List = {},
	CheckedAt = 0
}

local function getAllMyCitiesSorted(forceRefresh)
	local ok, myCountry = assertStillLeader()
	if not ok then
		return {}, nil, nil
	end

	local folder = CitiesRoot:FindFirstChild(myCountry.Name)
	if not folder then
		CitiesCache.CountryName = nil
		CitiesCache.Folder = nil
		CitiesCache.List = {}
		CitiesCache.CheckedAt = now()
		return {}, nil, myCountry
	end

	local t = now()
	if not forceRefresh
		and CitiesCache.CountryName == myCountry.Name
		and CitiesCache.Folder == folder
		and (t - CitiesCache.CheckedAt) < 1 then
		return CitiesCache.List, folder, myCountry
	end

	local list = folder:GetChildren()
	table.sort(list, function(a, b)
		return a.Name < b.Name
	end)

	CitiesCache.CountryName = myCountry.Name
	CitiesCache.Folder = folder
	CitiesCache.List = list
	CitiesCache.CheckedAt = t

	return list, folder, myCountry
end

local function countryHasAtLeastOneCity(countryName)
	local folder = CitiesRoot:FindFirstChild(countryName)
	if not folder then
		return false
	end
	return #folder:GetChildren() >= 1
end

--============================================================
-- Shared helpers
--============================================================
local function getNumberAttrOrValueObject(inst, name)
	if not inst then return end

	local a = inst:GetAttribute(name)
	if type(a) == "number" then
		return a
	end

	local obj = inst:FindFirstChild(name)
	if obj and obj.Value ~= nil and type(obj.Value) == "number" then
		return obj.Value
	end
end

--============================================================
-- Trade helpers
--============================================================
local function getTradeFolder(country, resource)
	local resourcesFolder = country:FindFirstChild("Resources")
	if not resourcesFolder then return end
	local res = resourcesFolder:FindFirstChild(resource)
	if not res then return end
	return res:FindFirstChild("Trade")
end

local function getTradeCount(country, resource)
	local trade = getTradeFolder(country, resource)
	return trade and #trade:GetChildren() or 0
end

local function hasTradeWith(country, resource, partner)
	local trade = getTradeFolder(country, resource)
	return trade and trade:FindFirstChild(partner) ~= nil
end

local function targetSlotsOccupied(country, resource)
	return getTradeCount(country, resource) > 0
end

local function shouldSkipTargetSlot(country, resource)
	if resource == "Consumer Goods" then
		return false
	end
	return CONFIG.TradeSkipIfTargetSlotOccupied and targetSlotsOccupied(country, resource)
end

local function getCountryResourceFlow(country, resource)
	local resourcesFolder = country:FindFirstChild("Resources")
	if not resourcesFolder then return end
	local res = resourcesFolder:FindFirstChild(resource)
	if not res then return end
	local flow = res:FindFirstChild("Flow")
	if flow and type(flow.Value) == "number" then
		return flow.Value
	end
end

local function isTradeAllowedByFlow(myCountry, resource, units)
	if CONFIG.TradeBypassFlowSafety then
		return true, nil
	end

	local flow = getCountryResourceFlow(myCountry, resource)
	if type(flow) == "number" then
		if flow < 0 then
			return false, "flow negative"
		end
		if type(units) == "number" and units > flow then
			return false, "units exceed flow"
		end
	end

	return true, nil
end

local function getUnitSellPrice(resource)
	local v = Resources:FindFirstChild(resource)
	if not v then return end
	return v.Value * 0.8
end

-- Net income rule: Revenue total − Expenses total
local function getRevenueTotalValue(country)
	local econ = country:FindFirstChild("Economy")
	if not econ then return end
	local revenue = econ:FindFirstChild("Revenue")
	if not revenue then return end

	local total = revenue:FindFirstChild("Total")
	if total and type(total.Value) == "number" then
		return total.Value
	end

	local a = revenue:GetAttribute("Total")
	if type(a) == "number" then
		return a
	end
end

local function getExpensesTotalValue(country)
	local econ = country:FindFirstChild("Economy")
	if not econ then return end
	local expenses = econ:FindFirstChild("Expenses")
	if not expenses then return end

	local total = expenses:FindFirstChild("Total")
	if total and type(total.Value) == "number" then
		return total.Value
	end

	local a = expenses:GetAttribute("Total")
	if type(a) == "number" then
		return a
	end
end

local function getNetIncome(country)
	local rev = getRevenueTotalValue(country)
	local exp = getExpensesTotalValue(country)
	if type(rev) ~= "number" or type(exp) ~= "number" then
		return
	end
	return rev - exp
end

local function computeUnitsFromNet(netIncome, unitSellPrice)
	if type(netIncome) ~= "number" or netIncome <= 0 then
		return 0
	end

	local targetMoney = netIncome * CONFIG.TradeTargetPercent
	local units = targetMoney / (unitSellPrice * CONFIG.TradeMultiplier)

	if units < CONFIG.TradeMinUnits then
		return 0
	end

	-- cap non-consumer goods at 5
	if CONFIG.TradeResource ~= "Consumer Goods" and units > 5 then
		units = 5
	end

	return units
end

local function sendTrade(target, resource, units, mode)
	ManageAlliance:FireServer(
		target,
		"ResourceTrade",
		{ resource, mode or "Sell", units, 1, "Trade" }
	)
end

local function tradeExists(myCountry, resource, targetName)
	local trade = getTradeFolder(myCountry, resource)
	if not trade then return false end
	return trade:FindFirstChild(targetName) ~= nil
end

local function getTradeIncomeFallback(myCountry)
	local econ = myCountry:FindFirstChild("Economy")
	if not econ then return end
	local revenue = econ:FindFirstChild("Revenue")
	if not revenue then return end
	local tradeExport = revenue:FindFirstChild("TradeExport")
	if not tradeExport then return end
	return tradeExport.Value
end

-- Cooldowns for retrying trade attempts
local TradeCooldowns = {}
local PendingAttempts = {}

local function cooldownKey(targetName, resourceName)
	return tostring(targetName) .. "|" .. tostring(resourceName)
end

local function isOnCooldown(targetName, resourceName)
	local key = cooldownKey(targetName, resourceName)
	local t = TradeCooldowns[key]
	return t and t > now()
end

local function setCooldown(targetName, resourceName)
	local key = cooldownKey(targetName, resourceName)
	TradeCooldowns[key] = now() + CONFIG.TradeCooldownSeconds
end

local function clearCooldown(targetName, resourceName)
	local key = cooldownKey(targetName, resourceName)
	TradeCooldowns[key] = nil
end

--============================================================
-- Auto Build (helpers)
--============================================================
local function cityTier(city)
	return getNumberAttrOrValueObject(city, "Tier")
end

local function cityInfrastructure(city)
	return getNumberAttrOrValueObject(city, "Infrastructure")
end

local function cityHasBuilding(city, buildingName)
	local buildings = city:FindFirstChild("Buildings")
	if not buildings then return false end
	return buildings:FindFirstChild(buildingName) ~= nil
end

local function getQueueUnitValue(city)
	local queue = city:FindFirstChild("Queue")
	if not queue then return end
	local unitOrder = queue:FindFirstChild("UnitOrder")
	if not unitOrder then return end
	local unit = unitOrder:FindFirstChild("Unit")
	if not unit then return end
	return unit.Value
end

local function getBuildingCost(buildingName)
	local b = BuildingsFolder:FindFirstChild(buildingName)
	if not b then return end
	local cost = b:FindFirstChild("Cost")
	return cost and cost.Value
end

local function getMyFunds()
	local ok, myCountry = assertStillLeader()
	if not ok then
		return nil, "not leader"
	end

	local econ = myCountry:FindFirstChild("Economy")
	if econ then
		for _, key in ipairs({ "Balance", "Money", "Stockpile" }) do
			local obj = econ:FindFirstChild(key)
			if obj and type(obj.Value) == "number" then
				return obj.Value, key
			end
			local attr = econ:GetAttribute(key)
			if type(attr) == "number" then
				return attr, key
			end
		end
	end

	return nil, "unknown"
end

local function canAffordBuilding(buildingName)
	local cost = getBuildingCost(buildingName)
	local funds = getMyFunds()

	if type(cost) ~= "number" then
		return false, cost, funds
	end

	if type(funds) ~= "number" then
		return true, cost, funds
	end

	return cost <= funds, cost, funds
end

local function fireCreateBuilding(city, buildingName)
	CreateBuilding:FireServer({ city }, buildingName)
end

--============================================================
-- Auto Resupply (AI-only, no spam, cooldown-aware, runs alongside autotrade)
--============================================================
local Resupply = {
	-- Per supplier/resource retry cooldowns
	Paused = {}, -- key = supplier|resource -> time
	CheckDelay = 1.25,
	CooldownSeconds = 30,
	IntervalSeconds = 0.5,
	MaxTradesPerScan = 6
}

local function resKey(supplier, resource)
	return tostring(supplier) .. "|" .. tostring(resource)
end

local function isResupplySupplierOnCooldown(supplier, resource)
	local k = resKey(supplier, resource)
	local t = Resupply.Paused[k]
	return t and t > now()
end

local function setResupplySupplierCooldown(supplier, resource)
	local k = resKey(supplier, resource)
	Resupply.Paused[k] = now() + Resupply.CooldownSeconds
end

local function parseOperationalReason(reason)
	if type(reason) ~= "string" then return end
	local res, needStr = reason:match("([%a%s%-%_]+)%s*%[Need:%s*([%d%.]+)%s*%]")
	if not res or not needStr then return end
	res = res:gsub("^%s+", ""):gsub("%s+$", "")
	local need = tonumber(needStr)
	if res == "" or type(need) ~= "number" or need <= 0 then
		return
	end
	return res, need
end

local function isBuildingOperational(buildingInstance)
	local a = buildingInstance:GetAttribute("Operational")
	if type(a) == "boolean" then
		return a
	end
	local obj = buildingInstance:FindFirstChild("Operational")
	if obj and typeof(obj.Value) == "boolean" then
		return obj.Value
	end
	return nil
end

local function getBuildingOperationalReason(buildingInstance)
	local a = buildingInstance:GetAttribute("Operational_Reason")
	if type(a) == "string" and a ~= "" then
		return a
	end
	local obj = buildingInstance:FindFirstChild("Operational_Reason")
	if obj and typeof(obj.Value) == "string" then
		return obj.Value
	end
end

local function getMyResourceFolder(myCountry, resourceName)
	local rf = myCountry:FindFirstChild("Resources")
	if not rf then return end
	return rf:FindFirstChild(resourceName)
end

local function getTradeFolderForMyResource(myCountry, resourceName)
	local res = getMyResourceFolder(myCountry, resourceName)
	if not res then return end
	return res:FindFirstChild("Trade")
end

local function getTradeXFromEntry(entry)
	-- Trade entry often Vector3Value where X = amount
	if entry:IsA("Vector3Value") and typeof(entry.Value) == "Vector3" then
		return tonumber(entry.Value.X) or 0
	end
	if entry.Value ~= nil and type(entry.Value) == "number" then
		return entry.Value
	end
	return 0
end

local function getMyCurrentTotalTradeX(myCountry, resourceName)
	local trade = getTradeFolderForMyResource(myCountry, resourceName)
	if not trade then
		return 0
	end

	local total = 0
	for _, entry in ipairs(trade:GetChildren()) do
		total = total + getTradeXFromEntry(entry)
	end
	return total
end

local function hasTradePartner(myCountry, resourceName, partner)
	local trade = getTradeFolderForMyResource(myCountry, resourceName)
	if not trade then return false end
	return trade:FindFirstChild(partner) ~= nil
end

local function buildAISuppliers(myCountry, resourceName, playerSet)
	-- AI-only suppliers with Flow > 0 for resource, excluding us.
	-- Prefer existing trade partners first; then higher flow.
	local suppliers = {}

	for _, c in ipairs(CountryData:GetChildren()) do
		if c ~= myCountry then
			if isCountryAI(c, playerSet) then
				local flow = getCountryResourceFlow(c, resourceName)
				if type(flow) == "number" and flow > 0 then
					suppliers[#suppliers + 1] = {
						name = c.Name,
						flow = flow,
						hasTrade = hasTradePartner(myCountry, resourceName, c.Name),
						onCd = isResupplySupplierOnCooldown(c.Name, resourceName)
					}
				end
			end
		end
	end

	table.sort(suppliers, function(a, b)
		if a.onCd ~= b.onCd then
			return a.onCd == false
		end
		if a.hasTrade ~= b.hasTrade then
			return a.hasTrade == true
		end
		return a.flow > b.flow
	end)

	return suppliers
end

local function sendBuy(targetCountry, resourceName, amount)
	ManageAlliance:FireServer(
		targetCountry,
		"ResourceTrade",
		{ resourceName, "Buy", amount, 1, "Trade" }
	)
end

local function attemptResupplyResource(myCountry, resourceName, delta, playerSet, statusOut)
	local remaining = delta
	local suppliers = buildAISuppliers(myCountry, resourceName, playerSet)
	local tradesSent = 0

	for i = 1, #suppliers do
		if remaining <= 0 then break end
		if tradesSent >= Resupply.MaxTradesPerScan then break end

		local s = suppliers[i]
		if not s.onCd then
			local amt = math.min(remaining, s.flow)
			if amt > 0 then
				local supplierName = s.name
				sendBuy(supplierName, resourceName, amt)
				tradesSent = tradesSent + 1

				-- After a delay, if trade entry is not present, pause that supplier/resource briefly.
				task.delay(Resupply.CheckDelay, function()
					local ok2, myCountry2 = assertStillLeader()
					if not ok2 then return end
					if not hasTradePartner(myCountry2, resourceName, supplierName) then
						setResupplySupplierCooldown(supplierName, resourceName)
					end
				end)

				remaining = remaining - amt
			end
		end
	end

	if statusOut then
		statusOut[#statusOut + 1] = resourceName .. " delta=" .. tostring(delta) .. " sent=" .. tostring(delta - remaining) .. " trades=" .. tostring(tradesSent)
	end

	return delta - remaining
end

local function computeTotalNeedByResource(cities)
	local needByRes = {}

	for _, city in ipairs(cities) do
		local buildingsFolder = city:FindFirstChild("Buildings")
		if buildingsFolder then
			for _, b in ipairs(buildingsFolder:GetChildren()) do
				local op = isBuildingOperational(b)
				if op == false then
					local reason = getBuildingOperationalReason(b)
					local resName, need = parseOperationalReason(reason)
					if resName and need then
						needByRes[resName] = (needByRes[resName] or 0) + need
					end
				end
			end
		end
	end

	return needByRes
end

local function scanAndResupplyOnce()
	local statuses = {}
	local ok, myCountry = assertStillLeader()
	if not ok then
		return statuses, 0
	end

	local citiesList = getAllMyCitiesSorted()
	if #citiesList == 0 then
		return statuses, 0
	end

	local playerSet = buildPlayerIdentitySet()
	local needByRes = computeTotalNeedByResource(citiesList)

	local totalTradesBudget = Resupply.MaxTradesPerScan
	for resName, needTotal in pairs(needByRes) do
		if totalTradesBudget <= 0 then
			break
		end

		needTotal = tonumber(needTotal) or 0
		if needTotal > 0 then
			local flow = getCountryResourceFlow(myCountry, resName)
			if CONFIG.AutoResupplyOnlyNegativeFlow and (type(flow) ~= "number" or flow >= 0) then
				statuses[#statuses + 1] = resName .. " skipped flow=" .. tostring(flow)
			else
				local currentTotalX = getMyCurrentTotalTradeX(myCountry, resName)
				local delta = needTotal - currentTotalX

				if delta > 0 then
					local before = #statuses
					local bought = attemptResupplyResource(myCountry, resName, delta, playerSet, statuses)
					local usedTrades = #statuses - before
					totalTradesBudget = totalTradesBudget - usedTrades

					if bought > 0 then
						debugPrint("[Resupply]", "Need", resName, "need=", needTotal, "tradingX=", currentTotalX, "delta=", delta, "bought=", bought)
					end
				end
			end
		end
	end

	return statuses, #citiesList
end

--============================================================
-- Unit Tags (auto force enabled while toggle)
--============================================================
local function ForceTags()
	for _, v in next, GetChildren(Units) do
		local Tag = FirstChild(v, "Tag")
		if Tag then
			Tag.Enabled = true
		end
	end
end

--============================================================
-- Rebel funding watcher (constant while toggle)
--============================================================
local Watcher = {
	Notified = {}, -- [countryName][funder] = true
	LastStatus = "Idle"
}

local function doRebelWatch()
	local ok, myCountry = assertStillLeader()
	local myCountryName = ok and myCountry.Name or nil
	local hits = 0
	local ownHits = 0

	for _, country in ipairs(CountryData:GetChildren()) do
		local countryName = country.Name
		local rebelFolder = country:FindFirstChild("Rebel")

		Watcher.Notified[countryName] = Watcher.Notified[countryName] or {}

		if rebelFolder then
			local current = {}
			for _, funder in ipairs(rebelFolder:GetChildren()) do
				local funderName = funder.Name
				current[funderName] = true

				if not Watcher.Notified[countryName][funderName] then
					hits = hits + 1
					local isOwnCountry = countryName == myCountryName
					if isOwnCountry then
						ownHits = ownHits + 1
						safeNotify("Rebels Funded In Your Country", funderName .. " is funding rebels in " .. countryName, 5)
					else
						safeNotify("Rebel Funding", funderName .. " funding rebels in " .. countryName, 4)
					end
					debugPrint("[Watcher]", funderName, "funding", countryName)
					Watcher.Notified[countryName][funderName] = true
				end
			end

			for prev, _ in pairs(Watcher.Notified[countryName]) do
				if not current[prev] then
					Watcher.Notified[countryName][prev] = nil
				end
			end
		else
			Watcher.Notified[countryName] = {}
		end
	end

	Watcher.LastStatus = "Hits: " .. tostring(hits) .. " | Own: " .. tostring(ownHits)
	return hits
end

--============================================================
-- Justification progress watch (constant while toggle)
-- remaining = Z - X
--============================================================
local JustWatch = {
	NotifiedDone = {}, -- key = myCountry|target
	NotifiedStarted = {}, -- [countryName][target] = true
	NotifiedThreats = {}, -- [countryName] = true when targeting you
	LastStatus = "Idle"
}

local function getRemainingFromAction(action)
	-- action is typically Vector3Value: X elapsed, Z completed
	if action:IsA("Vector3Value") and typeof(action.Value) == "Vector3" then
		local x = tonumber(action.Value.X) or 0
		local z = tonumber(action.Value.Z) or 0
		return z - x, x, z
	end
	return nil
end

local function doJustificationWatch()
	local ok, myCountry = assertStillLeader()
	if not ok then
		JustWatch.LastStatus = "Not leader"
		return
	end

	local dip = myCountry:FindFirstChild("Diplomacy")
	if not dip then
		JustWatch.LastStatus = "No diplomacy"
		return
	end

	local actions = dip:FindFirstChild("Actions")

	local doneCount = 0
	local tracking = 0
	local startedCount = 0
	local threatCount = 0

	if actions then
		for _, action in ipairs(actions:GetChildren()) do
			tracking = tracking + 1
			local rem = getRemainingFromAction(action)
			if rem ~= nil then
				local key = myCountry.Name .. "|" .. action.Name

				if rem <= 0 then
					doneCount = doneCount + 1
					if not JustWatch.NotifiedDone[key] then
						JustWatch.NotifiedDone[key] = true
						safeNotify("CB Completed", "Conquest CB ready on: " .. action.Name, 4)
					end
				else
					-- If it becomes active again later, allow re-notify on completion
					JustWatch.NotifiedDone[key] = nil
				end
			end
		end
	end

	for _, country in ipairs(CountryData:GetChildren()) do
		local countryName = country.Name
		local countryDip = country:FindFirstChild("Diplomacy")
		local countryActions = countryDip and countryDip:FindFirstChild("Actions")

		JustWatch.NotifiedStarted[countryName] = JustWatch.NotifiedStarted[countryName] or {}

		if countryActions then
			local currentTargets = {}
			for _, action in ipairs(countryActions:GetChildren()) do
				local targetName = action.Name
				currentTargets[targetName] = true

				if country ~= myCountry and not JustWatch.NotifiedStarted[countryName][targetName] then
					JustWatch.NotifiedStarted[countryName][targetName] = true
					startedCount = startedCount + 1
					safeNotify("Justification Started", countryName .. " started justifying on " .. targetName, 4)
				end

				if country ~= myCountry and targetName == myCountry.Name and not JustWatch.NotifiedThreats[countryName] then
					JustWatch.NotifiedThreats[countryName] = true
					threatCount = threatCount + 1
					safeNotify("Justification Alert", countryName .. " is justifying on your country", 5)
				end
			end

			for oldTarget in pairs(JustWatch.NotifiedStarted[countryName]) do
				if not currentTargets[oldTarget] then
					JustWatch.NotifiedStarted[countryName][oldTarget] = nil
					if oldTarget == myCountry.Name then
						JustWatch.NotifiedThreats[countryName] = nil
					end
				end
			end
		else
			JustWatch.NotifiedStarted[countryName] = {}
			JustWatch.NotifiedThreats[countryName] = nil
		end
	end

	JustWatch.LastStatus = "Mine: " .. tostring(tracking) .. " | Done: " .. tostring(doneCount) .. " | New: " .. tostring(startedCount) .. " | Threats: " .. tostring(threatCount)
end

--============================================================
-- Auto War: Justify / Declare / Peace (AI-only)
--============================================================
local War = {
	Justified = {},
	Declared = {},
	ProcessedWars = {},
	LastStatus = "Idle"
}

local function hasConquestCB(myCountryFolder, targetName)
	local dip = myCountryFolder:FindFirstChild("Diplomacy")
	if not dip then return false end
	local cb = dip:FindFirstChild("CasusBelli")
	if not cb then return false end
	local conquest = cb:FindFirstChild("Conquest")
	if not conquest then return false end
	return conquest:FindFirstChild(targetName) ~= nil
end

local function hasNestedChildNamed(root, wantedName)
	if not root then
		return false
	end
	if root:FindFirstChild(wantedName) then
		return true
	end
	for _, child in ipairs(root:GetChildren()) do
		if child.Name == wantedName then
			return true
		end
		if #child:GetChildren() > 0 and hasNestedChildNamed(child, wantedName) then
			return true
		end
	end
	return false
end

local function isAlliedWith(myCountryFolder, targetName)
	local dip = myCountryFolder:FindFirstChild("Diplomacy")
	if not dip then return false end
	local allies = dip:FindFirstChild("Allies") or dip:FindFirstChild("Alliances") or dip:FindFirstChild("Alliance")
	return hasNestedChildNamed(allies, targetName)
end

local function isCountryInWar(countryName)
	local warsFolder = workspace:FindFirstChild("Wars")
	if not warsFolder then return false end
	for _, war in ipairs(warsFolder:GetChildren()) do
		local attacker = war:FindFirstChild("Attacker")
		local defender = war:FindFirstChild("Defender")
		if (attacker and attacker:FindFirstChild(countryName)) or (defender and defender:FindFirstChild(countryName)) then
			return true
		end
	end
	return false
end

local function isWarTargetAllowed(myCountry, target, playerSet)
	if target == myCountry then
		return false, "self"
	end
	if CONFIG.AutoJustifyAIOnly and not isCountryAI(target, playerSet) then
		return false, "player"
	end
	if CONFIG.AutoJustifyRequireCities and not countryHasAtLeastOneCity(target.Name) then
		return false, "no cities"
	end
	if CONFIG.AutoJustifySkipAllies and isAlliedWith(myCountry, target.Name) then
		return false, "ally"
	end
	if CONFIG.AutoJustifySkipWars and isCountryInWar(target.Name) then
		return false, "war"
	end
	return true
end

local function doAutoJustify()
	local ok, myCountry = assertStillLeader()
	if not ok then
		War.LastStatus = "Not leader"
		return
	end

	local playerSet = buildPlayerIdentitySet()
	local t = now()
	local attempted = 0
	local skipped = 0
	local filtered = 0

	for _, c in ipairs(CountryData:GetChildren()) do
		local name = c.Name
		local targetAllowed = isWarTargetAllowed(myCountry, c, playerSet)

		if targetAllowed then
			if hasConquestCB(myCountry, name) then
				War.Justified[name] = nil
				skipped = skipped + 1
			elseif (not War.Justified[name]) or War.Justified[name] <= t then
				JustifyWar:FireServer(name, "Conquest")
				War.Justified[name] = t + CONFIG.AutoJustifyRetrySeconds
				attempted = attempted + 1
				debugPrint("[War]", "Justified on", name)
			end
		else
			filtered = filtered + 1
			War.Justified[name] = nil
		end
	end

	War.LastStatus = "Justify sent: " .. tostring(attempted) .. " | Existing CB: " .. tostring(skipped) .. " | Filtered: " .. tostring(filtered)
end

local function doAutoDeclare()
	local ok, myCountry = assertStillLeader()
	if not ok then
		War.LastStatus = "Not leader"
		return
	end

	local playerSet = buildPlayerIdentitySet()

	for _, c in ipairs(CountryData:GetChildren()) do
		local name = c.Name
		if isWarTargetAllowed(myCountry, c, playerSet) then
			if not War.Declared[name] and hasConquestCB(myCountry, name) then
				ManageAlliance:FireServer(name, "WarDeclare", "Conquest")
				War.Declared[name] = true
				debugPrint("[War]", "Declared on", name)
			end
		end
	end

	War.LastStatus = "AutoDeclare running"
end

local function doAutoPeace()
	local ok, myCountry = assertStillLeader()
	if not ok then
		War.LastStatus = "Not leader"
		return
	end

	local warsFolder = workspace:FindFirstChild("Wars")
	if not warsFolder then
		War.LastStatus = "No wars folder"
		return
	end

	-- Clean up missing wars
	for warName in pairs(War.ProcessedWars) do
		if not warsFolder:FindFirstChild(warName) then
			War.ProcessedWars[warName] = nil
		end
	end

	for _, war in ipairs(warsFolder:GetChildren()) do
		local warName = war.Name
		if not War.ProcessedWars[warName] then
			local attacker = war:FindFirstChild("Attacker")
			if attacker and attacker:FindFirstChild(myCountry.Name) then
				local defender = war:FindFirstChild("Defender")
				if defender then
					for _, def in ipairs(defender:GetChildren()) do
						local defName = def.Name
						local args = {
							defName,
							"PeaceOut",
							{
								warName,
								"Demand",
								{
									AnnexSome = {},
									Money = { Percentage = 75 },
									Resource = { Percentage = 75 }
								}
							}
						}
						ManageAlliance:FireServer(unpack(args))
						debugPrint("[War]", ("PeaceOut to %s for '%s'"):format(defName, warName))
					end
				end
				War.ProcessedWars[warName] = true
			end
		end
	end

	War.LastStatus = "AutoPeace running"
end

--============================================================
-- Auto Promote (dynamic leaders in Leaders.Current, your country auto-detected)
-- Promotes any leader with attribute Corrupt == true if:
-- my Political X > 2 * strongest opponent Political X
--============================================================
local Promote = {
	LastRun = 0,
	Cooldown = 1.5,
	LastStatus = "Idle"
}

local function getPoliticalX(countryFolder)
	local power = countryFolder:FindFirstChild("Power")
	if not power then return end

	local pol = power:FindFirstChild("Political")
	if not pol then return end

	if pol:IsA("Vector3Value") and typeof(pol.Value) == "Vector3" then
		return tonumber(pol.Value.X)
	end

	if pol.Value ~= nil and type(pol.Value) == "number" then
		return pol.Value
	end
end

local function getStrongestOpponentX(myCountryFolder)
	local highest = 0
	for _, c in ipairs(CountryData:GetChildren()) do
		if c ~= myCountryFolder then
			local x = getPoliticalX(c)
			if type(x) == "number" and x > highest then
				highest = x
			end
		end
	end
	return highest
end

local LeaderWatch = {
	Notified = {}, -- [leaderName] = true
	LastStatus = "Idle"
}

local function doLeaderWatch()
	local ok, myCountry = assertStillLeader()
	if not ok then
		LeaderWatch.LastStatus = "Not leader"
		return
	end

	local leaders = myCountry:FindFirstChild("Leaders")
	local current = leaders and leaders:FindFirstChild("Current")
	if not current then
		LeaderWatch.Notified = {}
		LeaderWatch.LastStatus = "No leaders"
		return
	end

	local currentCorrupt = {}
	local corruptCount = 0
	for _, leaderObj in ipairs(current:GetChildren()) do
		if leaderObj:GetAttribute("Corrupt") == true then
			local leaderName = leaderObj.Name
			currentCorrupt[leaderName] = true
			corruptCount = corruptCount + 1

			if not LeaderWatch.Notified[leaderName] then
				LeaderWatch.Notified[leaderName] = true
				safeNotify("Corrupt Leader Found", leaderName .. " is corrupt in " .. myCountry.Name, 5)
			end
		end
	end

	for leaderName in pairs(LeaderWatch.Notified) do
		if not currentCorrupt[leaderName] then
			LeaderWatch.Notified[leaderName] = nil
		end
	end

	LeaderWatch.LastStatus = "Corrupt leaders: " .. tostring(corruptCount)
end

local function doAutoPromote()
	local t = now()
	if (t - Promote.LastRun) < Promote.Cooldown then
		return
	end
	Promote.LastRun = t

	local ok, myCountry = assertStillLeader()
	if not ok then
		Promote.LastStatus = "Not leader"
		return
	end

	local myX = getPoliticalX(myCountry)
	if type(myX) ~= "number" then
		Promote.LastStatus = "My political X missing"
		return
	end

	local oppX = getStrongestOpponentX(myCountry)
	if oppX <= 0 then
		Promote.LastStatus = "No opponents"
		return
	end

	if myX <= (oppX * 2) then
		Promote.LastStatus = "Power too low"
		return
	end

	local leaders = myCountry:FindFirstChild("Leaders")
	local current = leaders and leaders:FindFirstChild("Current")
	if not current then
		Promote.LastStatus = "No leaders"
		return
	end

	for _, leaderObj in ipairs(current:GetChildren()) do
		if leaderObj:GetAttribute("Corrupt") == true then
			CountryWorker:FireServer("CountryLeader", { leaderObj.Name, "Promote" })
			Promote.LastStatus = "Promoted: " .. leaderObj.Name
			safeNotify("Auto Promote", "Promoted: " .. leaderObj.Name, 3)
			return
		end
	end

	Promote.LastStatus = "No corrupt leaders"
end

--============================================================
-- Auto Policy
--============================================================
local Policy = {
	Info = {},
	Selected = {},
	RecentlyEnacted = {},
	LastStatus = "Idle"
}

local function sanitizePolicyKey(name)
	return tostring(name):gsub("[^%w]", "_")
end

local function getPolicyPower(myCountry)
	local power = myCountry and myCountry:FindFirstChild("Power")
	local political = power and power:FindFirstChild("Political")
	if not political then
		return 0
	end
	if political:IsA("Vector3Value") and typeof(political.Value) == "Vector3" then
		return tonumber(political.Value.X) or 0
	end
	return (typeof(political.Value) == "number" and political.Value) or 0
end

local function getActivePolicies(myCountry)
	local active = {}
	local laws = myCountry and myCountry:FindFirstChild("Laws")
	local policies = laws and laws:FindFirstChild("Policies")
	if policies then
		for _, policy in ipairs(policies:GetChildren()) do
			active[policy.Name] = true
		end
	end
	return active
end

local function getPolicyCost(policy)
	local costObj = policy:FindFirstChild("PPCost")
	if costObj and costObj:IsA("Vector3Value") then
		return tonumber(costObj.Value.X) or 0
	end
	if costObj and typeof(costObj.Value) == "number" then
		return costObj.Value
	end
	return 0
end

local function buildPolicyInfo()
	Policy.Info = {}
	if not PoliciesFolder then
		return
	end

	local policies = PoliciesFolder:GetChildren()
	table.sort(policies, function(a, b)
		return a.Name < b.Name
	end)

	for _, policy in ipairs(policies) do
		Policy.Info[#Policy.Info + 1] = {
			name = policy.Name,
			key = "Policy_" .. sanitizePolicyKey(policy.Name),
			cost = getPolicyCost(policy)
		}
	end
end

local function cleanupPolicyMemory(active)
	for name in pairs(Policy.RecentlyEnacted) do
		if not active[name] then
			Policy.RecentlyEnacted[name] = nil
		end
	end
end

local function doAutoPolicy()
	if not PoliciesFolder then
		Policy.LastStatus = "No policies folder"
		return
	end

	local ok, myCountry = assertStillLeader()
	if not ok then
		Policy.LastStatus = "Not leader"
		return
	end

	local active = getActivePolicies(myCountry)
	cleanupPolicyMemory(active)

	local power = getPolicyPower(myCountry)
	local enacted = 0
	local selected = 0

	for _, policy in ipairs(Policy.Info) do
		if Policy.Selected[policy.name] then
			selected = selected + 1
			if not active[policy.name] and not Policy.RecentlyEnacted[policy.name] and power >= policy.cost then
				ChangeLaw:FireServer("Policy", policy.name)
				Policy.RecentlyEnacted[policy.name] = true
				enacted = enacted + 1
			end
		end
	end

	Policy.LastStatus = "Selected: " .. tostring(selected) .. " | Enacted: " .. tostring(enacted) .. " | Power: " .. tostring(power)
end

--============================================================
-- Auto Trade core (AI-only, updates list, skips flow-exceed candidates)
--============================================================
local function getValidCandidates(myCountry, resource, unitSellPrice)
	local valid = {}
	local playerSet = buildPlayerIdentitySet()

	for _, target in ipairs(CountryData:GetChildren()) do
		if target ~= myCountry and countryHasAtLeastOneCity(target.Name) then
			if (not CONFIG.TradeOnlyAI) or isCountryAI(target, playerSet) then
				if not hasTradeWith(myCountry, resource, target.Name) then
					if not shouldSkipTargetSlot(target, resource) then
						if not isOnCooldown(target.Name, resource) then
							local pendingKey = cooldownKey(target.Name, resource)
							if not PendingAttempts[pendingKey] then
								local net = getNetIncome(target)
								if net and net > 0 then
									local units = computeUnitsFromNet(net, unitSellPrice)
									if units > 0 then
										valid[#valid + 1] = { name = target.Name, net = net, units = units }
									end
								end
							end
						end
					end
				end
			end
		end
	end

	table.sort(valid, function(a, b)
		return a.net > b.net
	end)

	return valid
end

local function attemptOneTrade(TradeStatusLabel, TradeAttemptingLabel, setTradeValidList, TradeFlowSafetyLabel)
	local ok, myCountry = assertStillLeader()
	if not ok then
		if TradeAttemptingLabel then
			TradeAttemptingLabel:SetText("Attempting to trade: (not leader)")
		end
		if setTradeValidList then
			setTradeValidList({})
		end
		return
	end

	local price = getUnitSellPrice(CONFIG.TradeResource)
	if not price then
		if TradeAttemptingLabel then
			TradeAttemptingLabel:SetText("Attempting to trade: (no price)")
		end
		if setTradeValidList then
			setTradeValidList({})
		end
		return
	end

	local candidates = getValidCandidates(myCountry, CONFIG.TradeResource, price)

	local namesOnly = {}
	for i = 1, #candidates do
		namesOnly[i] = candidates[i].name
	end
	if setTradeValidList then
		setTradeValidList(namesOnly)
	end

	-- Find first candidate that passes flow safety; if blocked because units exceed flow, SKIP and try next
	local pick = nil
	local blockedReason = nil

	for i = 1, #candidates do
		local c = candidates[i]
		local allowed, reason = isTradeAllowedByFlow(myCountry, CONFIG.TradeResource, c.units)
		if allowed then
			pick = c
			break
		end
		-- your rule: if exceeds flow limit skip and move on to next
		blockedReason = reason
	end

	if not pick then
		if TradeAttemptingLabel then
			TradeAttemptingLabel:SetText("Attempting to trade: (none" .. (blockedReason and (", last blocked: " .. tostring(blockedReason)) or "") .. ")")
		end
		return
	end

	if TradeAttemptingLabel then
		TradeAttemptingLabel:SetText("Attempting to trade " .. tostring(pick.units) .. " " .. tostring(CONFIG.TradeResource) .. " to " .. tostring(pick.name))
	end

	local pendingKey = cooldownKey(pick.name, CONFIG.TradeResource)
	PendingAttempts[pendingKey] = true

	sendTrade(pick.name, CONFIG.TradeResource, pick.units, "Sell")
	debugPrint("[AutoTrade]", "Attempted", pick.units, CONFIG.TradeResource, "to", pick.name, "(net:", pick.net .. ")")

	task.delay(CONFIG.TradeAttemptCheckDelay, function()
		local ok2, myCountry2 = assertStillLeader()
		if not ok2 then
			PendingAttempts[pendingKey] = nil
			return
		end

		local accepted = tradeExists(myCountry2, CONFIG.TradeResource, pick.name)
		if accepted then
			clearCooldown(pick.name, CONFIG.TradeResource)
		else
			setCooldown(pick.name, CONFIG.TradeResource)
		end

		PendingAttempts[pendingKey] = nil
	end)
end

--============================================================
-- Auto Build core (runs on scheduler)
-- Rules:
-- - Infrastructure max 10
-- - Develop City max tier 10
--============================================================
local AutoBuild = {
	CityIndex = 1,
	LastStatus = "Idle"
}

local function isFactoryOrResourceBuilding(buildingName)
	local n = tostring(buildingName):lower()
	return n:find("factory", 1, true)
		or n:find("mine", 1, true)
		or n:find("oil", 1, true)
		or n:find("steel", 1, true)
		or n:find("motor", 1, true)
		or n:find("fertilizer", 1, true)
		or n:find("electronics", 1, true)
		or n:find("consumer", 1, true)
end

local function pushUnique(list, seen, name)
	if name and not seen[name] then
		list[#list + 1] = name
		seen[name] = true
	end
end

local function getAutoBuildOrder(selected)
	if CONFIG.AutoBuildPriority == "Selected Order" then
		return selected
	end

	local ordered = {}
	local seen = {}

	if CONFIG.AutoBuildPriority == "Infrastructure First" then
		pushUnique(ordered, seen, "Infrastructure")
	elseif CONFIG.AutoBuildPriority == "Develop First" then
		pushUnique(ordered, seen, "Develop City")
	elseif CONFIG.AutoBuildPriority == "Factories First" then
		for _, name in ipairs(selected) do
			if isFactoryOrResourceBuilding(name) then
				pushUnique(ordered, seen, name)
			end
		end
	end

	for _, name in ipairs(selected) do
		pushUnique(ordered, seen, name)
	end

	return ordered
end

local function attemptAutoBuildOnce(BuildAttemptLabel, BuildCityLabel, BuildTierLabel, BuildInfraLabel, BuildFundsLabel, BuildQueueLabel, BuildCitiesCountLabel, BuildCitiesFolderLabel)
	local ok, myCountry = assertStillLeader()
	if not ok then
		if BuildAttemptLabel then
			BuildAttemptLabel:SetText("Attempt: (not leader)")
		end
		return
	end

	local cities, folder = getAllMyCitiesSorted()
	if BuildCitiesFolderLabel then
		BuildCitiesFolderLabel:SetText("Cities Folder: " .. (folder and folder.Name or "(none)"))
	end
	if BuildCitiesCountLabel then
		BuildCitiesCountLabel:SetText("Cities Found: " .. tostring(#cities))
	end

	if #cities == 0 then
		if BuildAttemptLabel then
			BuildAttemptLabel:SetText("Attempt: (no cities found)")
		end
		return
	end

	local list = CONFIG.AutoBuildSelected
	if type(list) ~= "table" or #list == 0 then
		if BuildAttemptLabel then
			BuildAttemptLabel:SetText("Attempt: (no buildings selected)")
		end
		return
	end

	if AutoBuild.CityIndex > #cities then
		AutoBuild.CityIndex = 1
	end

	local city = cities[AutoBuild.CityIndex]
	AutoBuild.CityIndex = AutoBuild.CityIndex + 1
	if AutoBuild.CityIndex > #cities then
		AutoBuild.CityIndex = 1
	end

	local tier = cityTier(city)
	local infra = cityInfrastructure(city)
	local funds, source = getMyFunds()
	local qUnit = getQueueUnitValue(city)

	if BuildCityLabel then BuildCityLabel:SetText("City: " .. city.Name) end
	if BuildTierLabel then BuildTierLabel:SetText("Tier: " .. tostring(tier)) end
	if BuildInfraLabel then BuildInfraLabel:SetText("Infrastructure: " .. tostring(infra)) end
	if BuildFundsLabel then BuildFundsLabel:SetText("Funds: " .. tostring(funds) .. " (" .. tostring(source) .. ")") end
	if BuildQueueLabel then BuildQueueLabel:SetText("Queue Unit: " .. tostring(qUnit)) end

	if CONFIG.AutoBuildSkipQueued and qUnit ~= nil and tostring(qUnit) ~= "" then
		if BuildAttemptLabel then
			BuildAttemptLabel:SetText("Attempt: (queued city skipped)")
		end
		return
	end

	list = getAutoBuildOrder(list)
	for i = 1, #list do
		local buildingName = list[i]

		if buildingName == "Infrastructure" then
			if type(infra) ~= "number" or infra < 10 then
				local okAfford, cost = canAffordBuilding("Infrastructure")
				if not okAfford then
					if BuildAttemptLabel then
						BuildAttemptLabel:SetText("Attempt: (can't afford Infrastructure) cost=" .. tostring(cost))
					end
					return
				end
				if BuildAttemptLabel then
					BuildAttemptLabel:SetText("Attempt: Infrastructure in " .. city.Name)
				end
				fireCreateBuilding(city, "Infrastructure")
				return
			end
		elseif buildingName == "Develop City" then
			if type(tier) ~= "number" or tier < 10 then
				local okAfford, cost = canAffordBuilding("Develop City")
				if not okAfford then
					if BuildAttemptLabel then
						BuildAttemptLabel:SetText("Attempt: (can't afford Develop City) cost=" .. tostring(cost))
					end
					return
				end
				if BuildAttemptLabel then
					BuildAttemptLabel:SetText("Attempt: Develop City in " .. city.Name)
				end
				fireCreateBuilding(city, "Develop City")
				return
			end
		elseif not cityHasBuilding(city, buildingName) then
			local okAfford, cost = canAffordBuilding(buildingName)
			if not okAfford then
				if BuildAttemptLabel then
					BuildAttemptLabel:SetText("Attempt: (can't afford " .. buildingName .. ") cost=" .. tostring(cost))
				end
				return
			end

			if BuildAttemptLabel then
				BuildAttemptLabel:SetText("Attempt: " .. buildingName .. " in " .. city.Name)
			end
			fireCreateBuilding(city, buildingName)
			return
		end
	end

	if BuildAttemptLabel then
		BuildAttemptLabel:SetText("Attempt: (nothing to do)")
	end
end

--============================================================
-- Nation Brain UI Library
--============================================================
local BrainUILibrary = loadstring(game:HttpGet("https://raw.githubusercontent.com/tetizz/roblox-stuff/main/ron_brain_ui.lua"))()
local BrainUI = BrainUILibrary.new({
	CONFIG = CONFIG,
	CoreGui = CoreGui,
	UserInputService = UserInputService,
	workspace = workspace,
	Resources = Resources,
	BuildingsFolder = BuildingsFolder,
	CountryData = CountryData,
	Policy = Policy,
	assertStillLeader = assertStillLeader,
	getAllMyCitiesSorted = getAllMyCitiesSorted,
	getMyFunds = getMyFunds,
	getPolicyPower = getPolicyPower,
	getCountryResourceFlow = getCountryResourceFlow,
	getTradeCount = getTradeCount,
	getNetIncome = getNetIncome,
	computeTotalNeedByResource = computeTotalNeedByResource,
	scanAndResupplyOnce = scanAndResupplyOnce,
	attemptAutoBuildOnce = attemptAutoBuildOnce,
	doAutoPolicy = doAutoPolicy,
	safeNotify = safeNotify,
	buildPolicyInfo = buildPolicyInfo
})

local DashCountryLabel = BrainUI.Status.DashCountryLabel
local DashFundsLabel = BrainUI.Status.DashFundsLabel
local DashPoliticalLabel = BrainUI.Status.DashPoliticalLabel
local DashCitiesLabel = BrainUI.Status.DashCitiesLabel
local DashTradeLabel = BrainUI.Status.DashTradeLabel
local DashFlowLabel = BrainUI.Status.DashFlowLabel
local DashWarsLabel = BrainUI.Status.DashWarsLabel
local DashAutoLabel = BrainUI.Status.DashAutoLabel
local DashWarLabel = BrainUI.Status.DashWarLabel
local DashBuildLabel = BrainUI.Status.DashBuildLabel
local DashResourceLabel = BrainUI.Status.DashResourceLabel
local DashWatcherLabel = BrainUI.Status.DashWatcherLabel
local DashPolicyLabel = BrainUI.Status.DashPolicyLabel

local TradeStatusLabel = BrainUI.Status.TradeStatusLabel
local TradeCountryLabel = BrainUI.Status.TradeCountryLabel
local TradePartnerLabel = BrainUI.Status.TradePartnerLabel
local TradeFlowLabel = BrainUI.Status.TradeFlowLabel
local TradeIncomeLabel = BrainUI.Status.TradeIncomeLabel
local TradePercentLabel = BrainUI.Status.TradePercentLabel
local TradeAttemptingLabel = BrainUI.Status.TradeAttemptingLabel
local TradeValidLabel = BrainUI.Status.TradeValidLabel
local TradeValidListLabel = BrainUI.Status.TradeValidListLabel
local TradeFlowSafetyLabel = BrainUI.Status.TradeFlowSafetyLabel

local WarStatusLabel = BrainUI.Status.WarStatusLabel
local PromoteStatusLabel = BrainUI.Status.PromoteStatusLabel
local AutoResupplyStatusLabel = BrainUI.Status.AutoResupplyStatusLabel
local AutoResupplyDetailsLabel = BrainUI.Status.AutoResupplyDetailsLabel
local UnitTagsStatusLabel = BrainUI.Status.UnitTagsStatusLabel
local PolicyStatusLabel = BrainUI.Status.PolicyStatusLabel
local PolicyCountLabel = BrainUI.Status.PolicyCountLabel
local WatcherStatusLabel = BrainUI.Status.WatcherStatusLabel
local JustWatchStatusLabel = BrainUI.Status.JustWatchStatusLabel
local LeaderWatchStatusLabel = BrainUI.Status.LeaderWatchStatusLabel

local AutoBuildStatusLabel = BrainUI.Status.AutoBuildStatusLabel
local BuildCitiesFolderLabel = BrainUI.Status.BuildCitiesFolderLabel
local BuildCitiesCountLabel = BrainUI.Status.BuildCitiesCountLabel
local BuildCityLabel = BrainUI.Status.BuildCityLabel
local BuildTierLabel = BrainUI.Status.BuildTierLabel
local BuildInfraLabel = BrainUI.Status.BuildInfraLabel
local BuildFundsLabel = BrainUI.Status.BuildFundsLabel
local BuildQueueLabel = BrainUI.Status.BuildQueueLabel
local BuildAttemptLabel = BrainUI.Status.BuildAttemptLabel

local setTradeValidList = BrainUI.setTradeValidList
local updateDashboard = BrainUI.updateDashboard

--============================================================
-- MAIN SCHEDULER LOOP (single loop, everything runs alongside)
--============================================================
task.spawn(function()
	while true do
		runEvery("dashboard", 0.75, function()
			updateDashboard()
		end)

		-- Common status refresh for trade
		runEvery("ui_trade_status", 0.5, function()
			local ok, myCountry = assertStillLeader()
			if ok then
				TradeCountryLabel:SetText("Country: " .. myCountry.Name)
				TradePartnerLabel:SetText("Partners: " .. tostring(getTradeCount(myCountry, CONFIG.TradeResource)))
				TradeFlowLabel:SetText("Flow: " .. tostring(getCountryResourceFlow(myCountry, CONFIG.TradeResource)))
				TradeIncomeLabel:SetText("Trade Export: " .. tostring(getTradeIncomeFallback(myCountry)))
				TradePercentLabel:SetText("Trade Percent: " .. tostring(math.floor(CONFIG.TradeTargetPercent * 100 + 0.5)) .. "%")
			else
				TradeCountryLabel:SetText("Country: (not leader)")
				TradePartnerLabel:SetText("Partners: ?")
				TradeFlowLabel:SetText("Flow: ?")
				TradeIncomeLabel:SetText("Trade Export: ?")
				TradePercentLabel:SetText("Trade Percent: ?")
			end
		end)

		-- Auto Trade (separate tab) - uses its own delay slider
		if CONFIG.TradeEnabled then
			runEvery("auto_trade", CONFIG.TradeDelaySeconds, function()
				TradeStatusLabel:SetText("Status: Running")
				attemptOneTrade(TradeStatusLabel, TradeAttemptingLabel, setTradeValidList, TradeFlowSafetyLabel)
			end)
		else
			runEvery("auto_trade_idle", 0.5, function()
				TradeStatusLabel:SetText("Status: Idle")
			end)
		end

		-- Unit Tags (force each frame? no, keep it light but constant)
		if CONFIG.UnitTagsEnabled then
			runEvery("unit_tags", 0.25, function()
				ForceTags()
			end)
		end

		-- Auto Policy
		if CONFIG.AutoPolicyEnabled then
			runEvery("auto_policy", 1.0, function()
				doAutoPolicy()
				PolicyStatusLabel:SetText("Auto Policy: " .. Policy.LastStatus)
			end)
		else
			runEvery("auto_policy_idle", 0.5, function()
				PolicyStatusLabel:SetText("Auto Policy: Idle")
			end)
		end

		-- Rebel watch constant (no user timer setting; internal throttle)
		if CONFIG.WatcherEnabled then
			runEvery("rebel_watch", 1.0, function()
				doRebelWatch()
				WatcherStatusLabel:SetText("Rebel Watch: " .. Watcher.LastStatus)
			end)
		end

		-- Justification watch constant
		if CONFIG.JustifyWatchEnabled then
			runEvery("justify_watch", 0.75, function()
				doJustificationWatch()
				JustWatchStatusLabel:SetText("Justify Watch: " .. JustWatch.LastStatus)
			end)
		end

		-- Leader watch constant
		if CONFIG.LeaderWatchEnabled then
			runEvery("leader_watch", 1.0, function()
				doLeaderWatch()
				LeaderWatchStatusLabel:SetText("Leader Watch: " .. LeaderWatch.LastStatus)
			end)
		end

		-- Auto wars (internal throttle, constant style)
		if CONFIG.AutoJustifyEnabled then
			runEvery("auto_justify", 1.0, function()
				doAutoJustify()
				WarStatusLabel:SetText("Auto Wars: " .. War.LastStatus)
			end)
		end
		if CONFIG.AutoDeclareEnabled then
			runEvery("auto_declare", 1.0, function()
				doAutoDeclare()
				WarStatusLabel:SetText("Auto Wars: " .. War.LastStatus)
			end)
		end
		if CONFIG.AutoPeaceEnabled then
			runEvery("auto_peace", 1.0, function()
				doAutoPeace()
				WarStatusLabel:SetText("Auto Wars: " .. War.LastStatus)
			end)
		end

		-- Auto Build (don’t hog)
		if CONFIG.AutoBuildEnabled then
			runEvery("auto_build", 0.45, function()
				AutoBuildStatusLabel:SetText("Auto Build: Running")
				attemptAutoBuildOnce(
					BuildAttemptLabel,
					BuildCityLabel, BuildTierLabel, BuildInfraLabel,
					BuildFundsLabel, BuildQueueLabel,
					BuildCitiesCountLabel, BuildCitiesFolderLabel
				)
			end)
		else
			runEvery("auto_build_idle", 0.5, function()
				AutoBuildStatusLabel:SetText("Auto Build: Idle")
			end)
		end

		-- Auto Resupply (fast but not spam/hog; AI-only)
		if CONFIG.AutoResupplyEnabled then
			runEvery("auto_resupply", Resupply.IntervalSeconds, function()
				AutoResupplyStatusLabel:SetText("Auto Resupply: Running")
				local statuses, cityCount = scanAndResupplyOnce()
				if statuses and #statuses > 0 then
					AutoResupplyDetailsLabel:SetText("Resupply Details: " .. table.concat(statuses, " | "))
				else
					AutoResupplyDetailsLabel:SetText("Resupply Details: (none)")
				end
			end)
		else
			runEvery("auto_resupply_idle", 0.5, function()
				AutoResupplyStatusLabel:SetText("Auto Resupply: Idle")
			end)
		end

		-- Auto Promote
		if CONFIG.AutoPromoteEnabled then
			runEvery("auto_promote", 1.0, function()
				doAutoPromote()
				PromoteStatusLabel:SetText("Auto Promote: " .. Promote.LastStatus)
			end)
		end

		task.wait(0.05)
	end
end)

safeNotify("RoN Nation Brain", "Loaded. RightShift toggles the dashboard.", 4)
