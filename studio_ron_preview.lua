-- RoN Automation Studio preview
-- Requires ReplicatedStorage.RoNPreviewModules with:
--   ObsidianLibrary, LucideIcons, and RoNBrainUI ModuleScripts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
if not player then
	return
end

if _G and type(_G.RoNStudioPreviewCleanup) == "function" then
	pcall(_G.RoNStudioPreviewCleanup)
end

local modules = ReplicatedStorage:WaitForChild("RoNPreviewModules", 10)
assert(modules, "[RoN Preview] ReplicatedStorage.RoNPreviewModules is missing")

local function requireFresh(sourceModule)
	local clone = sourceModule:Clone()
	clone.Name = sourceModule.Name .. "_Runtime"
	clone.Parent = modules
	local ok, result = pcall(require, clone)
	clone:Destroy()
	if not ok then
		error(result, 2)
	end
	return result
end

local previousGlobals = {}
for _, key in ipairs({ "gethui", "protectgui" }) do
	previousGlobals[key] = _G[key]
end
_G.gethui = function()
	return player:WaitForChild("PlayerGui")
end
_G.protectgui = function() end

local Library = requireFresh(modules:WaitForChild("ObsidianLibrary"))
local LucideIcons = require(modules:WaitForChild("LucideIcons"))
local BrainUI = requireFresh(modules:WaitForChild("RoNBrainUI"))

for key, value in pairs(previousGlobals) do
	_G[key] = value
end

assert(
	type(BrainUI) == "table" and BrainUI.Version == "2026-07-23.1",
	"[RoN Preview] production UI module version mismatch"
)

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, item in pairs(value) do
		result[deepCopy(key)] = deepCopy(item)
	end
	return result
end

local StudioSaveManager = {
	Library = nil,
	Folder = "RoN_Automation"
}

function StudioSaveManager:SetLibrary(library)
	self.Library = library
end

function StudioSaveManager:SetFolder(folder)
	self.Folder = folder
end

function StudioSaveManager:IgnoreThemeSettings() end

function StudioSaveManager:_capture()
	local data = {
		Toggles = {},
		Options = {}
	}
	for id, control in pairs(self.Library.Toggles or {}) do
		if control.Type == "Toggle" then
			data.Toggles[id] = control.Value == true
		end
	end
	for id, control in pairs(self.Library.Options or {}) do
		if control.Type == "Slider" or control.Type == "Dropdown" then
			data.Options[id] = deepCopy(control.Value)
		end
	end
	return data
end

function StudioSaveManager:_apply(data)
	if type(data) ~= "table" then
		return false
	end
	for id, value in pairs(data.Toggles or {}) do
		local control = self.Library.Toggles[id]
		if control and control.SetValue then
			control:SetValue(value)
		end
	end
	for id, value in pairs(data.Options or {}) do
		local control = self.Library.Options[id]
		if control and control.SetValue then
			control:SetValue(deepCopy(value))
		end
	end
	return true
end

function StudioSaveManager:BuildConfigSection(tab)
	local group = tab:AddLeftGroupbox("Configuration", "save")
	group:AddLabel({
		Text = "Studio session profile",
		DoesWrap = true
	})
	group:AddButton({
		Text = "Save current session",
		Func = function()
			shared.RoNPreviewConfig = self:_capture()
			self.Library:Notify({
				Title = "Configuration saved",
				Description = "The preview profile is stored for this Studio session.",
				Time = 4,
				Icon = "save"
			})
		end
	})
	group:AddButton({
		Text = "Load saved session",
		Func = function()
			if self:_apply(shared.RoNPreviewConfig) then
				self.Library:Notify({
					Title = "Configuration loaded",
					Description = "Saved preview controls were applied.",
					Time = 4,
					Icon = "folder-open"
				})
			else
				self.Library:Notify({
					Title = "No saved configuration",
					Description = "Save the current session before loading it.",
					Time = 4,
					Icon = "circle-alert"
				})
			end
		end
	})
	group:AddButton({
		Text = "Clear saved session",
		Risky = true,
		Func = function()
			shared.RoNPreviewConfig = nil
			self.Library:Notify({
				Title = "Configuration cleared",
				Description = "The Studio session profile was removed.",
				Time = 4,
				Icon = "trash-2"
			})
		end
	})
end

function StudioSaveManager:LoadAutoloadConfig()
	if shared.RoNPreviewConfig then
		self:_apply(shared.RoNPreviewConfig)
	end
end

local StudioThemeManager = {
	Library = nil,
	DefaultThemeName = "Obsidian"
}

local themes = {
	Obsidian = {
		BackgroundColor = Color3.fromRGB(15, 15, 15),
		MainColor = Color3.fromRGB(25, 25, 25),
		AccentColor = Color3.fromRGB(125, 85, 255),
		OutlineColor = Color3.fromRGB(40, 40, 40),
		FontColor = Color3.fromRGB(255, 255, 255)
	},
	Graphite = {
		BackgroundColor = Color3.fromRGB(17, 19, 22),
		MainColor = Color3.fromRGB(27, 30, 34),
		AccentColor = Color3.fromRGB(52, 152, 219),
		OutlineColor = Color3.fromRGB(55, 61, 69),
		FontColor = Color3.fromRGB(241, 244, 248)
	},
	Forest = {
		BackgroundColor = Color3.fromRGB(14, 19, 17),
		MainColor = Color3.fromRGB(24, 32, 28),
		AccentColor = Color3.fromRGB(74, 222, 128),
		OutlineColor = Color3.fromRGB(47, 63, 54),
		FontColor = Color3.fromRGB(241, 247, 243)
	}
}

function StudioThemeManager:SetLibrary(library)
	self.Library = library
end

function StudioThemeManager:SetFolder() end

function StudioThemeManager:_apply(themeName)
	local theme = themes[themeName]
	if not theme then
		return
	end
	for key, value in pairs(theme) do
		self.Library.Scheme[key] = value
	end
	self.Library:UpdateColorsUsingRegistry()
end

function StudioThemeManager:ApplyToTab(tab)
	local group = tab:AddRightGroupbox("Theme", "palette")
	group:AddDropdown("StudioTheme", {
		Text = "Preset",
		Values = { "Obsidian", "Graphite", "Forest" },
		Default = self.DefaultThemeName
	}):OnChanged(function(value)
		self.DefaultThemeName = value
		self:_apply(value)
	end)
	group:AddSlider("StudioScale", {
		Text = "Interface scale",
		Default = 100,
		Min = 75,
		Max = 125,
		Rounding = 0,
		Suffix = "%"
	}):OnChanged(function(value)
		self.Library:SetDPIScale(value / 100)
	end)
end

function StudioThemeManager:LoadDefault()
	self:_apply(self.DefaultThemeName)
end

local CONFIG = {
	Debug = false,
	TradeEnabled = false,
	TradeResource = "Consumer Goods",
	TradeTargetPercent = 0.79,
	TradeMultiplier = 1,
	TradeDelaySeconds = 0.8,
	TradeMinUnits = 0.1,
	TradeSkipIfTargetSlotOccupied = true,
	TradeAttemptCheckDelay = 1.5,
	TradeCooldownSeconds = 120,
	TradeBypassFlowSafety = false,
	TradeOnlyAI = true,

	AutoBuildEnabled = false,
	AutoBuildSelected = {},
	AutoBuildPriority = "Selected Order",
	AutoBuildSkipQueued = true,
	AutoResupplyEnabled = false,
	AutoResupplyOnlyNegativeFlow = true,
	UnitTagsEnabled = false,
	AutoPolicyEnabled = false,

	WatcherEnabled = false,
	JustifyWatchEnabled = false,
	LeaderWatchEnabled = false,
	AutoJustifyEnabled = false,
	AutoJustifyAIOnly = true,
	AutoJustifySkipAllies = true,
	AutoJustifySkipWars = true,
	AutoJustifyRequireCities = true,
	AutoJustifyRetrySeconds = 60,
	AutoDeclareEnabled = false,
	AutoPeaceEnabled = false,
	AutoAnnexEnabled = false,
	AutoAnnexExtractionPercent = 100,
	DebtGuardEnabled = false,
	DebtGuardFloor = 500000,
	AutoPromoteEnabled = false,

	BrainDashboardEnabled = true,
	BrainStrategyMode = "Economic Power",
	NotificationsEnabled = true
}

local resources = Instance.new("Folder")
resources.Name = "PreviewResources"
for _, definition in ipairs({
	{ "Consumer Goods", 118 },
	{ "Electronics", 91 },
	{ "Fertilizer", 54 },
	{ "Motor Parts", 87 },
	{ "Oil", 34 },
	{ "Steel", 72 }
}) do
	local resource = Instance.new("NumberValue")
	resource.Name = definition[1]
	resource.Value = definition[2]
	resource.Parent = resources
end

local buildings = Instance.new("Folder")
buildings.Name = "PreviewBuildings"
for _, name in ipairs({
	"Airport",
	"Develop City",
	"Electronics Factory",
	"Fertilizer Factory",
	"Infrastructure",
	"Motor Factory",
	"Recruitment Center",
	"Steel Manufactory"
}) do
	local building = Instance.new("Folder")
	building.Name = name
	building.Parent = buildings
end

local country = Instance.new("Folder")
country.Name = "United States"

local mock = {
	funds = 2340000000000,
	political = 184,
	net = 18600000000,
	partners = {
		["Consumer Goods"] = 3,
		Electronics = 1,
		Fertilizer = 0,
		["Motor Parts"] = 1,
		Oil = 2,
		Steel = 2
	},
	flow = {
		["Consumer Goods"] = 42,
		Electronics = 18,
		Fertilizer = -4,
		["Motor Parts"] = 8,
		Oil = -12,
		Steel = 26
	},
	shortages = {
		Oil = 12,
		Fertilizer = 4
	},
	cityQueue = "",
	buildCount = 0
}

local cities = {}
for index = 1, 12 do
	local city = Instance.new("Folder")
	city.Name = "Preview City " .. tostring(index)
	cities[index] = city
end

local Policy = {
	Info = {
		{ name = "Agricultural Subsidies", key = "Policy_Agricultural_Subsidies", cost = 75 },
		{ name = "Consumer Protections", key = "Policy_Consumer_Protections", cost = 100 },
		{ name = "Factory Subsidies", key = "Policy_Factory_Subsidies", cost = 125 },
		{ name = "Military Spending", key = "Policy_Military_Spending", cost = 150 }
	},
	Selected = {},
	LastStatus = "Idle"
}

local War = { LastStatus = "Idle" }
local Resupply = { MaxTradesPerScan = 6 }
local AutoBuild = { LastStatus = "Idle" }
local DebtRecovery = { LastStatus = "Idle" }
local Promote = { LastStatus = "Idle" }
local Watcher = { LastStatus = "Idle" }
local JustWatch = { LastStatus = "Idle" }
local LeaderWatch = { LastStatus = "Idle" }

local currentUI

local function attemptOneTrade(_, attemptingLabel, setValidList, flowSafetyLabel)
	local valid = { "Canada", "Mexico", "Brazil", "Argentina" }
	setValidList(valid)
	if CONFIG.TradeBypassFlowSafety then
		flowSafetyLabel:SetText("Flow safety: BYPASSED")
	else
		flowSafetyLabel:SetText("Flow safety: ON")
	end

	local resource = CONFIG.TradeResource
	local flow = mock.flow[resource]
	if not CONFIG.TradeBypassFlowSafety and (type(flow) ~= "number" or flow <= 0) then
		attemptingLabel:SetText("Attempt blocked: selected resource has no safe export flow")
		return false, "The preview flow guard blocked this trade."
	end

	mock.partners[resource] = (mock.partners[resource] or 0) + 1
	attemptingLabel:SetText("Request simulated: " .. resource .. " to Canada")
	return true, "A validated preview trade request was recorded."
end

local function attemptAutoBuildOnce(
	attemptLabel,
	cityLabel,
	tierLabel,
	infraLabel,
	fundsLabel,
	queueLabel,
	countLabel,
	folderLabel
)
	if #CONFIG.AutoBuildSelected == 0 then
		attemptLabel:SetText("Build blocked: no buildings selected")
		return false, "Select at least one building."
	end

	mock.buildCount = mock.buildCount + 1
	local selected = CONFIG.AutoBuildSelected[1]
	local city = cities[((mock.buildCount - 1) % #cities) + 1]
	mock.cityQueue = selected
	AutoBuild.LastStatus = "Requested " .. selected .. " in " .. city.Name
	attemptLabel:SetText("Request simulated: " .. selected .. " in " .. city.Name)
	cityLabel:SetText("City: " .. city.Name)
	tierLabel:SetText("Tier: 6")
	infraLabel:SetText("Infrastructure: 7")
	fundsLabel:SetText("Funds: $" .. tostring(mock.funds))
	queueLabel:SetText("Queue: " .. selected)
	countLabel:SetText("Cities found: " .. tostring(#cities))
	folderLabel:SetText("Cities folder: PreviewCities")

	task.delay(1.5, function()
		mock.cityQueue = ""
		queueLabel:SetText("Queue: clear")
	end)
	return true, AutoBuild.LastStatus
end

local function scanAndResupplyOnce()
	local details = {}
	for resource, amount in pairs(mock.shortages) do
		if amount > 0 then
			details[#details + 1] = resource .. " +" .. tostring(amount)
			mock.flow[resource] = (mock.flow[resource] or 0) + amount
			mock.shortages[resource] = 0
		end
	end
	table.sort(details)
	if #details == 0 then
		return {}
	end
	return details
end

local function doDebtGuardOnce()
	if mock.funds >= CONFIG.DebtGuardFloor then
		DebtRecovery.LastStatus = "Healthy"
		return true, "Balance is above the configured guard floor."
	end
	mock.funds = mock.funds + 500000
	DebtRecovery.LastStatus = "Preview surplus sale requested"
	return true, DebtRecovery.LastStatus
end

local function doAutoPolicy()
	local selected = 0
	for _ in pairs(Policy.Selected) do
		selected = selected + 1
	end
	Policy.LastStatus = "Selected: " .. tostring(selected) .. " | Power: " .. tostring(mock.political)
	return true, Policy.LastStatus
end

local function setWarStatus(message)
	War.LastStatus = message
	return true, message
end

local context = {
	CONFIG = CONFIG,
	workspace = workspace,
	Resources = resources,
	BuildingsFolder = buildings,
	Policy = Policy,
	War = War,
	Resupply = Resupply,
	AutoBuild = AutoBuild,
	DebtRecovery = DebtRecovery,
	Promote = Promote,
	Watcher = Watcher,
	JustWatch = JustWatch,
	LeaderWatch = LeaderWatch,

	ObsidianLibrary = Library,
	ObsidianSaveManager = StudioSaveManager,
	ObsidianThemeManager = StudioThemeManager,
	ObsidianIconModule = LucideIcons,

	assertStillLeader = function()
		return true, country
	end,
	getAllMyCitiesSorted = function()
		return cities, "PreviewCities"
	end,
	getMyFunds = function()
		return mock.funds, "Preview"
	end,
	getPolicyPower = function()
		return mock.political
	end,
	getCountryResourceFlow = function(_, resource)
		return mock.flow[resource]
	end,
	getTradeCount = function(_, resource)
		return mock.partners[resource] or 0
	end,
	getNetIncome = function()
		return mock.net
	end,
	computeTotalNeedByResource = function()
		return deepCopy(mock.shortages)
	end,

	scanAndResupplyOnce = scanAndResupplyOnce,
	attemptAutoBuildOnce = attemptAutoBuildOnce,
	attemptOneTrade = attemptOneTrade,
	doAutoPolicy = doAutoPolicy,
	doAutoJustify = function()
		return setWarStatus("Justification scan simulated")
	end,
	doAutoDeclare = function()
		return setWarStatus("AI declaration scan simulated")
	end,
	doAutoPeace = function()
		return setWarStatus("Partial peace scan simulated")
	end,
	doAutoAnnex = function()
		return setWarStatus("Full annex scan simulated")
	end,
	doAutoPromote = function()
		Promote.LastStatus = "No corrupt leaders"
		return true, Promote.LastStatus
	end,
	doDebtGuardOnce = doDebtGuardOnce,
	buildPolicyInfo = function() end
}

currentUI = BrainUI.new(context)

local alive = true
currentUI.UI:OnUnload(function()
	alive = false
end)

local function cleanup()
	if not alive then
		return
	end
	alive = false
	if currentUI and currentUI.Destroy then
		currentUI.Destroy()
	end
	resources:Destroy()
	buildings:Destroy()
	country:Destroy()
	for _, city in ipairs(cities) do
		city:Destroy()
	end
	if _G and _G.RoNStudioPreviewCleanup == cleanup then
		_G.RoNStudioPreviewCleanup = nil
	end
end

if _G then
	_G.RoNStudioPreviewCleanup = cleanup
end

task.spawn(function()
	while alive do
		currentUI.updateDashboard()
		task.wait(0.75)
	end
end)
