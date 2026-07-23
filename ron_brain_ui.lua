-- RoN Nation Brain UI
-- Production UI built on the same Obsidian library used by the original script.

local BrainUI = {
	Version = "2026-07-23.1"
}

local OBSIDIAN_COMMIT = "69804de55a1af0c5d2da97d15b49445d5a670c02"
local LUCIDE_COMMIT = "d27200e7eb834f7a69591e18f7a30461569b8318"
local OBSIDIAN_BASE = "https://raw.githubusercontent.com/deividcomsono/Obsidian/" .. OBSIDIAN_COMMIT .. "/"
local LUCIDE_URL = "https://raw.githubusercontent.com/deividcomsono/lucide-roblox-direct/" .. LUCIDE_COMMIT .. "/source.lua"

local STATUS_DEFAULTS = {
	DashCountryLabel = "Country: unavailable",
	DashFundsLabel = "Balance: unavailable",
	DashPoliticalLabel = "Political power: unavailable",
	DashCitiesLabel = "Cities: unavailable",
	DashTradeLabel = "Trade partners: unavailable",
	DashFlowLabel = "Selected flow: unavailable",
	DashWarsLabel = "Active wars: unavailable",
	DashAutoLabel = "Enabled automations: none",
	DashWarLabel = "War: idle",
	DashBuildLabel = "Build: idle",
	DashResourceLabel = "Resources: idle",
	DashWatcherLabel = "Watchers: idle",
	DashPolicyLabel = "Policy: idle",

	TradeStatusLabel = "Status: Idle",
	TradeCountryLabel = "Country: unavailable",
	TradePartnerLabel = "Partners: unavailable",
	TradeFlowLabel = "Flow: unavailable",
	TradeIncomeLabel = "Trade export: unavailable",
	TradePercentLabel = "Trade percent: unavailable",
	TradeAttemptingLabel = "Attempt: none",
	TradeValidLabel = "Valid countries: 0",
	TradeValidListLabel = "Valid list: none",
	TradeFlowSafetyLabel = "Flow safety: ON",
	TradeTargetFilterLabel = "Target filter: AI only",

	WarStatusLabel = "War automation: Idle",
	PromoteStatusLabel = "Auto promote: Idle",
	DebtStatusLabel = "Debt guard: Idle",
	AutoResupplyStatusLabel = "Auto resupply: Idle",
	AutoResupplyDetailsLabel = "Resupply details: none",
	UnitTagsStatusLabel = "Unit tags: Idle",
	PolicyStatusLabel = "Auto policy: Idle",
	PolicyCountLabel = "Policies loaded: 0",
	WatcherStatusLabel = "Rebel watch: Idle",
	JustWatchStatusLabel = "Justification watch: Idle",
	LeaderWatchStatusLabel = "Leader watch: Idle",

	AutoBuildStatusLabel = "Auto build: Idle",
	BuildCitiesFolderLabel = "Cities folder: unavailable",
	BuildCitiesCountLabel = "Cities found: 0",
	BuildCityLabel = "City: unavailable",
	BuildTierLabel = "Tier: unavailable",
	BuildInfraLabel = "Infrastructure: unavailable",
	BuildFundsLabel = "Funds: unavailable",
	BuildQueueLabel = "Queue: unavailable",
	BuildAttemptLabel = "Build attempt: none",
	SettingsConfigLabel = "Config: RoN_Automation"
}

local BOOLEAN_KEYS = {
	"Debug",
	"TradeEnabled",
	"TradeSkipIfTargetSlotOccupied",
	"TradeBypassFlowSafety",
	"TradeOnlyAI",
	"AutoBuildEnabled",
	"AutoBuildSkipQueued",
	"AutoResupplyEnabled",
	"AutoResupplyOnlyNegativeFlow",
	"UnitTagsEnabled",
	"AutoPolicyEnabled",
	"WatcherEnabled",
	"JustifyWatchEnabled",
	"LeaderWatchEnabled",
	"AutoJustifyEnabled",
	"AutoJustifyAIOnly",
	"AutoJustifySkipAllies",
	"AutoJustifySkipWars",
	"AutoJustifyRequireCities",
	"AutoDeclareEnabled",
	"AutoPeaceEnabled",
	"AutoAnnexEnabled",
	"DebtGuardEnabled",
	"AutoPromoteEnabled",
	"BrainDashboardEnabled",
	"NotificationsEnabled"
}

local function loadRemote(url, name)
	local source = game:HttpGet(url)
	local chunk, loadError = loadstring(source)
	if not chunk then
		error(("[RoN UI] failed to compile %s: %s"):format(name, tostring(loadError)), 2)
	end

	local result = chunk()
	if result == nil then
		error("[RoN UI] " .. name .. " returned nil", 2)
	end
	return result
end

local function clampNumber(value, fallback, minimum, maximum)
	value = tonumber(value)
	if not value or value ~= value or value == math.huge or value == -math.huge then
		value = fallback
	end
	return math.clamp(value, minimum, maximum)
end

local function normalizeConfig(config)
	for _, key in ipairs(BOOLEAN_KEYS) do
		config[key] = config[key] == true
	end

	config.TradeTargetPercent = clampNumber(config.TradeTargetPercent, 0.79, 0, 0.8)
	config.TradeMultiplier = clampNumber(config.TradeMultiplier, 1, 0.01, 100)
	config.TradeDelaySeconds = clampNumber(config.TradeDelaySeconds, 0.8, 0.1, 10)
	config.TradeMinUnits = clampNumber(config.TradeMinUnits, 0.1, 0.1, 100)
	config.TradeAttemptCheckDelay = clampNumber(config.TradeAttemptCheckDelay, 1.5, 0.2, 10)
	config.TradeCooldownSeconds = clampNumber(config.TradeCooldownSeconds, 120, 10, 600)
	config.AutoJustifyRetrySeconds = clampNumber(config.AutoJustifyRetrySeconds, 60, 10, 300)
	config.AutoAnnexExtractionPercent = clampNumber(config.AutoAnnexExtractionPercent, 100, 0, 100)
	config.DebtGuardFloor = clampNumber(config.DebtGuardFloor, 500000, 0, 10000000)

	local priorities = {
		["Selected Order"] = true,
		["Infrastructure First"] = true,
		["Develop First"] = true,
		["Factories First"] = true
	}
	if not priorities[config.AutoBuildPriority] then
		config.AutoBuildPriority = "Selected Order"
	end

	local modes = {
		["Economic Power"] = true,
		["Military Readiness"] = true,
		["Balanced"] = true
	}
	if not modes[config.BrainStrategyMode] then
		config.BrainStrategyMode = "Economic Power"
	end
	if config.AutoAnnexEnabled then
		config.AutoPeaceEnabled = false
	end

	if type(config.AutoBuildSelected) ~= "table" then
		config.AutoBuildSelected = {}
	end
end

local function sortedChildNames(folder, className, excludedName)
	local names = {}
	if not folder or type(folder.GetChildren) ~= "function" then
		return names
	end

	for _, child in ipairs(folder:GetChildren()) do
		if (not className or child:IsA(className)) and child.Name ~= excludedName then
			names[#names + 1] = child.Name
		end
	end
	table.sort(names)
	return names
end

local function listToSelectionMap(list, allowed)
	local allowedMap = {}
	for _, value in ipairs(allowed) do
		allowedMap[value] = true
	end

	local selected = {}
	for _, value in ipairs(list or {}) do
		if allowedMap[value] then
			selected[value] = true
		end
	end
	return selected
end

local function selectionMapToList(selected, order)
	local list = {}
	for _, value in ipairs(order) do
		if selected and selected[value] then
			list[#list + 1] = value
		end
	end
	return list
end

local function formatNumber(value)
	if type(value) ~= "number" then
		return "unavailable"
	end

	local absolute = math.abs(value)
	local suffix = ""
	local divisor = 1
	if absolute >= 1000000000000 then
		suffix, divisor = "T", 1000000000000
	elseif absolute >= 1000000000 then
		suffix, divisor = "B", 1000000000
	elseif absolute >= 1000000 then
		suffix, divisor = "M", 1000000
	elseif absolute >= 1000 then
		suffix, divisor = "K", 1000
	end

	if divisor == 1 then
		return tostring(math.floor(value * 100 + 0.5) / 100)
	end
	return ("%.2f%s"):format(value / divisor, suffix)
end

local function safeCall(fn, ...)
	if type(fn) ~= "function" then
		return false, "callback unavailable"
	end
	local ok, a, b, c = pcall(fn, ...)
	if not ok then
		return false, tostring(a)
	end
	return true, a, b, c
end

local function getActiveAutomationNames(config)
	local definitions = {
		{ "Trade", "TradeEnabled" },
		{ "Build", "AutoBuildEnabled" },
		{ "Resupply", "AutoResupplyEnabled" },
		{ "Debt guard", "DebtGuardEnabled" },
		{ "Policy", "AutoPolicyEnabled" },
		{ "Unit tags", "UnitTagsEnabled" },
		{ "Rebel watch", "WatcherEnabled" },
		{ "Justify watch", "JustifyWatchEnabled" },
		{ "Leader watch", "LeaderWatchEnabled" },
		{ "Auto justify", "AutoJustifyEnabled" },
		{ "Auto declare", "AutoDeclareEnabled" },
		{ "Auto peace", "AutoPeaceEnabled" },
		{ "Auto annex", "AutoAnnexEnabled" },
		{ "Auto promote", "AutoPromoteEnabled" }
	}

	local active = {}
	for _, definition in ipairs(definitions) do
		if config[definition[2]] then
			active[#active + 1] = definition[1]
		end
	end
	return active
end

local function countCountryWars(workspaceRef, countryName)
	local warsFolder = workspaceRef and workspaceRef:FindFirstChild("Wars")
	if not warsFolder or not countryName then
		return 0
	end

	local count = 0
	for _, war in ipairs(warsFolder:GetChildren()) do
		local attacker = war:FindFirstChild("Attacker")
		local defender = war:FindFirstChild("Defender")
		if (attacker and attacker:FindFirstChild(countryName))
			or (defender and defender:FindFirstChild(countryName)) then
			count = count + 1
		end
	end
	return count
end

local function summarizeNeeds(needs)
	local sorted = {}
	for resource, amount in pairs(needs or {}) do
		amount = tonumber(amount) or 0
		if amount > 0 then
			sorted[#sorted + 1] = {
				resource = resource,
				amount = amount
			}
		end
	end
	table.sort(sorted, function(a, b)
		if a.amount == b.amount then
			return a.resource < b.resource
		end
		return a.amount > b.amount
	end)

	if #sorted == 0 then
		return "No detected production shortages", nil
	end
	local first = sorted[1]
	return ("%s needs %s"):format(first.resource, formatNumber(first.amount)), first
end

local function createNotificationHost(Library, config)
	local TweenService = game:GetService("TweenService")
	local host = Instance.new("Frame")
	host.Name = "RoNNotificationHost"
	host.AnchorPoint = Vector2.new(1, 1)
	host.BackgroundTransparency = 1
	host.Position = UDim2.new(1, -12, 1, -12)
	host.Size = UDim2.new(1, -24, 0, 278)
	host.ZIndex = 1000
	host.Parent = Library.ScreenGui

	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize = Vector2.new(360, 278)
	constraint.MinSize = Vector2.zero
	constraint.Parent = host

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Padding = UDim.new(0, 8)
	layout.Parent = host

	local active = {}
	local destroyed = false

	local function removeToast(toast)
		for index, current in ipairs(active) do
			if current == toast then
				table.remove(active, index)
				break
			end
		end
		if toast and toast.Parent then
			toast:Destroy()
		end
	end

	local function getIcon(iconName)
		local ok, icon = pcall(function()
			return Library:GetCustomIcon(iconName)
		end)
		if ok then
			return icon
		end
		return nil
	end

	local function show(title, description, duration, iconName)
		if destroyed or config.NotificationsEnabled ~= true then
			return false
		end

		title = tostring(title or "RoN Automation")
		description = tostring(description or "")
		duration = clampNumber(duration, 4, 1, 15)

		while #active >= 4 do
			removeToast(active[1])
		end

		local toast = Instance.new("CanvasGroup")
		toast.Name = "Notification"
		toast.BackgroundColor3 = Color3.fromRGB(20, 22, 27)
		toast.GroupTransparency = 1
		toast.Size = UDim2.new(1, 0, 0, 60)
		toast.ZIndex = 1001
		toast.Parent = host

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 4)
		corner.Parent = toast

		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(67, 71, 82)
		stroke.Thickness = 1
		stroke.Parent = toast

		local accent = Instance.new("Frame")
		accent.BackgroundColor3 = Color3.fromRGB(99, 102, 241)
		accent.BorderSizePixel = 0
		accent.Size = UDim2.new(0, 3, 1, 0)
		accent.ZIndex = 1002
		accent.Parent = toast

		local iconData = getIcon(iconName or "bell")
		local icon = Instance.new("ImageLabel")
		icon.BackgroundTransparency = 1
		icon.Image = iconData and iconData.Url or ""
		icon.ImageColor3 = Color3.fromRGB(180, 183, 255)
		icon.ImageRectOffset = iconData and iconData.ImageRectOffset or Vector2.zero
		icon.ImageRectSize = iconData and iconData.ImageRectSize or Vector2.zero
		icon.Position = UDim2.fromOffset(16, 12)
		icon.Size = UDim2.fromOffset(20, 20)
		icon.ZIndex = 1002
		icon.Parent = toast

		local titleLabel = Instance.new("TextLabel")
		titleLabel.BackgroundTransparency = 1
		titleLabel.Font = Enum.Font.GothamSemibold
		titleLabel.Position = UDim2.fromOffset(48, 8)
		titleLabel.Size = UDim2.new(1, -60, 0, 20)
		titleLabel.Text = title
		titleLabel.TextColor3 = Color3.fromRGB(242, 243, 247)
		titleLabel.TextSize = 14
		titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
		titleLabel.TextXAlignment = Enum.TextXAlignment.Left
		titleLabel.ZIndex = 1002
		titleLabel.Parent = toast

		local bodyLabel = Instance.new("TextLabel")
		bodyLabel.BackgroundTransparency = 1
		bodyLabel.Font = Enum.Font.Gotham
		bodyLabel.Position = UDim2.fromOffset(48, 29)
		bodyLabel.Size = UDim2.new(1, -60, 0, 20)
		bodyLabel.Text = description
		bodyLabel.TextColor3 = Color3.fromRGB(174, 178, 189)
		bodyLabel.TextSize = 12
		bodyLabel.TextTruncate = Enum.TextTruncate.AtEnd
		bodyLabel.TextXAlignment = Enum.TextXAlignment.Left
		bodyLabel.ZIndex = 1002
		bodyLabel.Parent = toast

		local progress = Instance.new("Frame")
		progress.AnchorPoint = Vector2.new(0, 1)
		progress.BackgroundColor3 = Color3.fromRGB(99, 102, 241)
		progress.BorderSizePixel = 0
		progress.Position = UDim2.new(0, 3, 1, 0)
		progress.Size = UDim2.new(1, -3, 0, 2)
		progress.ZIndex = 1002
		progress.Parent = toast

		active[#active + 1] = toast
		TweenService:Create(
			toast,
			TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ GroupTransparency = 0 }
		):Play()
		TweenService:Create(
			progress,
			TweenInfo.new(duration, Enum.EasingStyle.Linear),
			{ Size = UDim2.new(0, 0, 0, 2) }
		):Play()

		task.delay(duration, function()
			if destroyed or not toast.Parent then
				return
			end
			local fade = TweenService:Create(
				toast,
				TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ GroupTransparency = 1 }
			)
			fade:Play()
			fade.Completed:Wait()
			removeToast(toast)
		end)
		return true
	end

	local function destroy()
		destroyed = true
		active = {}
		if host then
			host:Destroy()
			host = nil
		end
	end

	return show, destroy
end

function BrainUI.new(ctx)
	assert(type(ctx) == "table", "[RoN UI] context table is required")
	assert(type(ctx.CONFIG) == "table", "[RoN UI] CONFIG is required")

	local config = ctx.CONFIG
	normalizeConfig(config)

	local Library = ctx.ObsidianLibrary or loadRemote(OBSIDIAN_BASE .. "Library.lua", "Obsidian Library")
	local SaveManager = ctx.ObsidianSaveManager
		or loadRemote(OBSIDIAN_BASE .. "addons/SaveManager.lua", "Obsidian SaveManager")
	local ThemeManager = ctx.ObsidianThemeManager
		or loadRemote(OBSIDIAN_BASE .. "addons/ThemeManager.lua", "Obsidian ThemeManager")

	local iconOk = ctx.ObsidianIconModule ~= nil
	local iconModule = ctx.ObsidianIconModule
	if not iconOk then
		iconOk, iconModule = pcall(loadRemote, LUCIDE_URL, "Lucide icons")
	end
	if iconOk and type(Library.SetIconModule) == "function" then
		pcall(function()
			Library:SetIconModule(iconModule)
		end)
	end

	local Window = Library:CreateWindow({
		Title = "RoN Automation",
		Footer = "Nation Brain",
		Icon = "brain-circuit",
		Size = UDim2.fromOffset(920, 640),
		NotifySide = "Right",
		Resizable = true,
		EnableSidebarResize = true,
		EnableCompacting = true,
		GlobalSearch = true,
		ToggleKeybind = Enum.KeyCode.RightControl,
		CornerRadius = 4,
		Font = Enum.Font.Gotham,
		Animations = {
			ToggleWindow = true,
			TabSwitch = true,
			Groupbox = true,
			Dropdown = true,
			KeyPicker = false
		},
		TabTransitionTime = 0.16,
		TabSwipeOffset = 16,
		TabSwipeFrom = "right"
	})

	local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
	if type(Window.SetCompact) == "function"
		and (Library.IsMobile == true or (viewport and viewport.X < 900)) then
		Window:SetCompact(true)
	end

	local Tabs = {
		Dashboard = Window:AddTab("Dashboard", "layout-dashboard"),
		Trade = Window:AddTab("Trade", "repeat-2"),
		Strategy = Window:AddTab("Strategy", "landmark"),
		Build = Window:AddTab("Build", "hammer"),
		Resources = Window:AddTab("Resources", "package-open"),
		War = Window:AddTab("War", "swords"),
		Watchers = Window:AddTab("Watchers", "bell-ring"),
		Settings = Window:AddTab("Settings", "settings")
	}

	local Groups = {
		Thought = Tabs.Dashboard:AddLeftGroupbox("Thought Process", "brain-circuit"),
		Feed = Tabs.Dashboard:AddLeftGroupbox("Live Feed", "activity"),
		Snapshot = Tabs.Dashboard:AddRightGroupbox("Nation Snapshot", "chart-no-axes-combined"),
		Action = Tabs.Dashboard:AddRightGroupbox("Next Action", "target"),

		TradeControls = Tabs.Trade:AddLeftGroupbox("Trade Controls", "repeat-2"),
		TradeRules = Tabs.Trade:AddLeftGroupbox("Safety Rules", "shield-check"),
		TradeStatus = Tabs.Trade:AddRightGroupbox("Trade Status", "activity"),

		StrategyControls = Tabs.Strategy:AddLeftGroupbox("Strategy", "landmark"),
		PolicyControls = Tabs.Strategy:AddRightGroupbox("Policy Selection", "scroll-text"),
		PolicyStatus = Tabs.Strategy:AddLeftGroupbox("Policy Status", "activity"),

		BuildControls = Tabs.Build:AddLeftGroupbox("Build Controls", "hammer"),
		BuildStatus = Tabs.Build:AddRightGroupbox("Build Status", "building-2"),

		ResourceControls = Tabs.Resources:AddLeftGroupbox("Resource Controls", "package-open"),
		ResourceStatus = Tabs.Resources:AddRightGroupbox("Resource Status", "activity"),

		WarControls = Tabs.War:AddLeftGroupbox("War Controls", "swords"),
		WarFilters = Tabs.War:AddLeftGroupbox("Target Filters", "shield-check"),
		WarStatus = Tabs.War:AddRightGroupbox("War Status", "activity"),

		WatcherControls = Tabs.Watchers:AddLeftGroupbox("Watchers", "eye"),
		WatcherStatus = Tabs.Watchers:AddRightGroupbox("Watcher Status", "activity"),

		SettingsControls = Tabs.Settings:AddLeftGroupbox("Interface", "settings"),
		SettingsStatus = Tabs.Settings:AddRightGroupbox("Runtime", "wrench")
	}

	local originalGroupParents = {}

	local function applyResponsiveTabLayout(tab)
		local sides = tab and tab.Sides
		if type(sides) ~= "table" or not sides[1] or not sides[2] then
			return
		end

		local camera = workspace.CurrentCamera
		local viewportSize = camera and camera.ViewportSize
		local singleColumn = viewportSize and viewportSize.X < 540
		local leftSide = sides[1]
		local rightSide = sides[2]

		for _, group in pairs(tab.Groupboxes or {}) do
			local holder = group.BoxHolder
			if holder then
				if not originalGroupParents[holder] then
					originalGroupParents[holder] = holder.Parent
				end
				if singleColumn then
					holder.Parent = leftSide
				else
					holder.Parent = originalGroupParents[holder]
				end
			end
		end

		if singleColumn then
			leftSide.Size = UDim2.new(1, 0, 1, leftSide.Size.Y.Offset)
			rightSide.Visible = false
		else
			rightSide.Visible = true
		end
	end

	local function refreshResponsiveLayout()
		for _, tab in pairs(Tabs) do
			tab:RefreshSides()
		end
	end

	local function installResponsiveLayout()
		for _, tab in pairs(Tabs) do
			for _, group in pairs(tab.Groupboxes or {}) do
				if group.BoxHolder then
					originalGroupParents[group.BoxHolder] = group.BoxHolder.Parent
				end
			end

			local originalRefresh = tab.RefreshSides
			tab.RefreshSides = function(self, ...)
				originalRefresh(self, ...)
				applyResponsiveTabLayout(self)
			end
		end

		refreshResponsiveLayout()

		local camera = workspace.CurrentCamera
		if camera and type(Library.GiveSignal) == "function" then
			Library:GiveSignal(camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
				task.defer(refreshResponsiveLayout)
			end))
		end
	end

	local status = {}
	local function addStatus(group, key)
		local label = group:AddLabel({
			Text = STATUS_DEFAULTS[key] or key,
			DoesWrap = true
		})
		status[key] = label
		return label
	end

	addStatus(Groups.Snapshot, "DashCountryLabel")
	addStatus(Groups.Snapshot, "DashFundsLabel")
	addStatus(Groups.Snapshot, "DashPoliticalLabel")
	addStatus(Groups.Snapshot, "DashCitiesLabel")
	addStatus(Groups.Snapshot, "DashTradeLabel")
	addStatus(Groups.Snapshot, "DashFlowLabel")
	addStatus(Groups.Snapshot, "DashWarsLabel")
	addStatus(Groups.Snapshot, "DashAutoLabel")

	addStatus(Groups.Action, "DashWarLabel")
	addStatus(Groups.Action, "DashBuildLabel")
	addStatus(Groups.Action, "DashResourceLabel")
	addStatus(Groups.Action, "DashWatcherLabel")
	addStatus(Groups.Action, "DashPolicyLabel")

	addStatus(Groups.TradeStatus, "TradeStatusLabel")
	addStatus(Groups.TradeStatus, "TradeCountryLabel")
	addStatus(Groups.TradeStatus, "TradePartnerLabel")
	addStatus(Groups.TradeStatus, "TradeFlowLabel")
	addStatus(Groups.TradeStatus, "TradeIncomeLabel")
	addStatus(Groups.TradeStatus, "TradePercentLabel")
	addStatus(Groups.TradeStatus, "TradeAttemptingLabel")
	addStatus(Groups.TradeStatus, "TradeValidLabel")
	addStatus(Groups.TradeStatus, "TradeValidListLabel")
	addStatus(Groups.TradeStatus, "TradeFlowSafetyLabel")
	addStatus(Groups.TradeStatus, "TradeTargetFilterLabel")

	addStatus(Groups.WarStatus, "WarStatusLabel")
	addStatus(Groups.WarStatus, "PromoteStatusLabel")
	addStatus(Groups.ResourceStatus, "DebtStatusLabel")
	addStatus(Groups.ResourceStatus, "AutoResupplyStatusLabel")
	addStatus(Groups.ResourceStatus, "AutoResupplyDetailsLabel")
	addStatus(Groups.ResourceStatus, "UnitTagsStatusLabel")
	addStatus(Groups.PolicyStatus, "PolicyStatusLabel")
	addStatus(Groups.PolicyStatus, "PolicyCountLabel")
	addStatus(Groups.WatcherStatus, "WatcherStatusLabel")
	addStatus(Groups.WatcherStatus, "JustWatchStatusLabel")
	addStatus(Groups.WatcherStatus, "LeaderWatchStatusLabel")

	addStatus(Groups.BuildStatus, "AutoBuildStatusLabel")
	addStatus(Groups.BuildStatus, "BuildCitiesFolderLabel")
	addStatus(Groups.BuildStatus, "BuildCitiesCountLabel")
	addStatus(Groups.BuildStatus, "BuildCityLabel")
	addStatus(Groups.BuildStatus, "BuildTierLabel")
	addStatus(Groups.BuildStatus, "BuildInfraLabel")
	addStatus(Groups.BuildStatus, "BuildFundsLabel")
	addStatus(Groups.BuildStatus, "BuildQueueLabel")
	addStatus(Groups.BuildStatus, "BuildAttemptLabel")
	addStatus(Groups.SettingsStatus, "SettingsConfigLabel")

	local decisionLabel = Groups.Thought:AddLabel({
		Text = "Waiting for the first nation snapshot.",
		DoesWrap = true,
		Size = 15
	})
	local evidenceLabel = Groups.Thought:AddLabel({
		Text = "No nation evidence is available yet.",
		DoesWrap = true
	})
	local shortageLabel = Groups.Thought:AddLabel({
		Text = "Resource check pending.",
		DoesWrap = true
	})

	local feedTrade = Groups.Feed:AddLabel({ Text = "Trade: idle", DoesWrap = true })
	local feedBuild = Groups.Feed:AddLabel({ Text = "Build: idle", DoesWrap = true })
	local feedResources = Groups.Feed:AddLabel({ Text = "Resources: idle", DoesWrap = true })
	local feedWar = Groups.Feed:AddLabel({ Text = "War: idle", DoesWrap = true })
	local feedWatchers = Groups.Feed:AddLabel({ Text = "Watchers: idle", DoesWrap = true })

	local showToast, destroyToastHost = createNotificationHost(Library, config)
	Library.Notify = function(first, second, third)
		local info
		local duration
		if first == Library then
			info = second
			duration = third
		else
			info = first
			duration = second
		end

		if type(info) == "table" then
			return showToast(
				info.Title or "RoN Automation",
				info.Description or info.Text or "",
				info.Time or info.Duration or duration,
				info.Icon or "bell"
			)
		end
		return showToast("RoN Automation", tostring(info or ""), duration, "bell")
	end

	local updateDashboard
	local setTradeValidList
	local nextAction = {
		name = "Refresh dashboard",
		callback = function()
			if updateDashboard then
				updateDashboard()
			end
		end,
		status = function()
			return "Nation snapshot refreshed"
		end
	}

	local function notifyAction(title, callback, statusGetter)
		local ok, result, message = safeCall(callback)
		if not ok then
			showToast(title .. " failed", tostring(result), 6, "triangle-alert")
			return false
		end
		if result == false then
			showToast(title .. " blocked", tostring(message or "The cycle declined the request."), 5, "circle-alert")
			return false
		end

		local detail = type(message) == "string" and message or nil
		if not detail and type(statusGetter) == "function" then
			local statusOk, statusText = pcall(statusGetter)
			if statusOk and type(statusText) == "string" and statusText ~= "" then
				detail = statusText
			end
		end
		showToast(title, detail or "Cycle requested; status will update after replication.", 4, "circle-check")
		if updateDashboard then
			updateDashboard()
		end
		return true
	end

	Groups.Action:AddButton({
		Text = "Execute next action",
		Tooltip = "Runs the action selected from current nation state and enabled automations.",
		Func = function()
			notifyAction(nextAction.name, nextAction.callback, nextAction.status)
		end
	})
	Groups.Action:AddButton({
		Text = "Refresh nation snapshot",
		Func = function()
			if updateDashboard then
				updateDashboard()
				showToast("Dashboard refreshed", "Nation data and automation status were read again.", 3, "refresh-cw")
			end
		end
	})

	local resources = sortedChildNames(ctx.Resources, "NumberValue")
	if #resources == 0 then
		resources = { config.TradeResource or "Consumer Goods" }
	end
	local resourceExists = false
	for _, name in ipairs(resources) do
		if name == config.TradeResource then
			resourceExists = true
			break
		end
	end
	if not resourceExists then
		config.TradeResource = resources[1]
	end

	local buildings = sortedChildNames(ctx.BuildingsFolder, nil, "Expand Canal")
	config.AutoBuildSelected = selectionMapToList(
		listToSelectionMap(config.AutoBuildSelected, buildings),
		buildings
	)

	local function syncToggleStatus(label, prefix, value)
		label:SetText(prefix .. ": " .. (value and "Running" or "Idle"))
	end

	local function bindToggle(group, id, text, configKey, tooltip, statusLabel, statusPrefix)
		local toggle = group:AddToggle(id, {
			Text = text,
			Default = config[configKey] == true,
			Tooltip = tooltip
		})
		toggle:OnChanged(function(value)
			config[configKey] = value == true
			if statusLabel then
				syncToggleStatus(statusLabel, statusPrefix or text, config[configKey])
			end
			if updateDashboard then
				updateDashboard()
			end
		end)
		return toggle
	end

	bindToggle(
		Groups.TradeControls,
		"TradeEnabled",
		"Enable auto trading",
		"TradeEnabled",
		"Scans eligible countries and submits one validated sell request per cycle.",
		status.TradeStatusLabel,
		"Status"
	)
	bindToggle(
		Groups.TradeControls,
		"TradeOnlyAI",
		"AI countries only",
		"TradeOnlyAI",
		"Prevents the trade scanner from selecting player-led countries."
	)
	Groups.TradeControls:AddDropdown("TradeResource", {
		Text = "Resource",
		Values = resources,
		Default = config.TradeResource,
		Searchable = true,
		Tooltip = "Resource sold by the auto-trade cycle."
	}):OnChanged(function(value)
		config.TradeResource = value
		if updateDashboard then updateDashboard() end
	end)
	Groups.TradeControls:AddSlider("TradeTargetPercent", {
		Text = "Buyer income allocation",
		Default = math.floor(config.TradeTargetPercent * 100 + 0.5),
		Min = 0,
		Max = 80,
		Rounding = 0,
		Suffix = "%",
		Tooltip = "Share of the target country's net income used to size a trade."
	}):OnChanged(function(value)
		config.TradeTargetPercent = value / 100
	end)
	Groups.TradeControls:AddSlider("TradeDelay", {
		Text = "Scan interval",
		Default = config.TradeDelaySeconds,
		Min = 0.1,
		Max = 10,
		Rounding = 1,
		Suffix = "s"
	}):OnChanged(function(value)
		config.TradeDelaySeconds = value
	end)
	Groups.TradeControls:AddSlider("TradeCooldown", {
		Text = "Rejected trade cooldown",
		Default = config.TradeCooldownSeconds,
		Min = 10,
		Max = 600,
		Rounding = 0,
		Suffix = "s"
	}):OnChanged(function(value)
		config.TradeCooldownSeconds = value
	end)
	Groups.TradeControls:AddButton({
		Text = "Run trade scan now",
		Func = function()
			notifyAction("Trade scan", function()
				return ctx.attemptOneTrade(
					status.TradeStatusLabel,
					status.TradeAttemptingLabel,
					setTradeValidList,
					status.TradeFlowSafetyLabel
				)
			end, function()
				return status.TradeAttemptingLabel.Text
			end)
		end
	})

	bindToggle(
		Groups.TradeRules,
		"TradeSkipOccupied",
		"Skip occupied target slots",
		"TradeSkipIfTargetSlotOccupied",
		"Skips non-consumer-goods targets that already have a resource trade."
	)
	bindToggle(
		Groups.TradeRules,
		"TradeBypassFlowSafety",
		"Bypass flow safety",
		"TradeBypassFlowSafety",
		"Allows exports with missing, negative, or insufficient flow. This can damage production."
	)
	Groups.TradeRules:AddSlider("TradeMinUnits", {
		Text = "Minimum trade size",
		Default = config.TradeMinUnits,
		Min = 0.1,
		Max = 100,
		Rounding = 1
	}):OnChanged(function(value)
		config.TradeMinUnits = value
	end)
	Groups.TradeRules:AddSlider("TradeCheckDelay", {
		Text = "Acceptance check delay",
		Default = config.TradeAttemptCheckDelay,
		Min = 0.2,
		Max = 10,
		Rounding = 1,
		Suffix = "s"
	}):OnChanged(function(value)
		config.TradeAttemptCheckDelay = value
	end)

	Groups.StrategyControls:AddDropdown("BrainStrategyMode", {
		Text = "Dashboard decision focus",
		Values = { "Economic Power", "Military Readiness", "Balanced" },
		Default = config.BrainStrategyMode,
		Tooltip = "Changes which enabled automation is prioritized by Execute next action."
	}):OnChanged(function(value)
		config.BrainStrategyMode = value
		if updateDashboard then updateDashboard() end
	end)
	bindToggle(
		Groups.StrategyControls,
		"AutoPolicyEnabled",
		"Enable auto policy",
		"AutoPolicyEnabled",
		"Enacts only selected policies when enough political power is available.",
		status.PolicyStatusLabel,
		"Auto policy"
	)
	Groups.StrategyControls:AddButton({
		Text = "Run policy cycle now",
		Func = function()
			notifyAction("Policy cycle", ctx.doAutoPolicy, function()
				return ctx.Policy and ctx.Policy.LastStatus
			end)
		end
	})

	if type(ctx.buildPolicyInfo) == "function" then
		safeCall(ctx.buildPolicyInfo)
	end
	local policyInfo = ctx.Policy and ctx.Policy.Info or {}
	status.PolicyCountLabel:SetText("Policies loaded: " .. tostring(#policyInfo))
	if #policyInfo == 0 then
		Groups.PolicyControls:AddLabel({
			Text = "No policy definitions were found in Assets.Laws.Policies.",
			DoesWrap = true
		})
	else
		for _, policy in ipairs(policyInfo) do
			local policyName = policy.name
			local policyKey = policy.key
			local policyCost = tonumber(policy.cost) or 0
			Groups.PolicyControls:AddToggle(policyKey, {
				Text = ("%s (%s PP)"):format(policyName, formatNumber(policyCost)),
				Default = ctx.Policy.Selected[policyName] == true,
				Tooltip = "Allows the auto-policy cycle to enact this policy."
			}):OnChanged(function(value)
				ctx.Policy.Selected[policyName] = value == true
			end)
		end
	end

	bindToggle(
		Groups.BuildControls,
		"AutoBuildEnabled",
		"Enable auto build",
		"AutoBuildEnabled",
		"Cycles through owned cities and attempts one affordable selected building.",
		status.AutoBuildStatusLabel,
		"Auto build"
	)
	Groups.BuildControls:AddDropdown("AutoBuildPriority", {
		Text = "Priority mode",
		Values = { "Selected Order", "Infrastructure First", "Develop First", "Factories First" },
		Default = config.AutoBuildPriority,
		Tooltip = "Reorders selected buildings without adding unselected buildings."
	}):OnChanged(function(value)
		config.AutoBuildPriority = value
	end)
	bindToggle(
		Groups.BuildControls,
		"AutoBuildSkipQueued",
		"Skip cities with active queues",
		"AutoBuildSkipQueued",
		"Prevents a build request when the city queue is already occupied."
	)
	Groups.BuildControls:AddDropdown("AutoBuildBuildings", {
		Text = "Buildings",
		Values = buildings,
		Default = listToSelectionMap(config.AutoBuildSelected, buildings),
		Searchable = true,
		Multi = true,
		Tooltip = "Only selected buildings are eligible for auto build."
	}):OnChanged(function(value)
		config.AutoBuildSelected = selectionMapToList(value, buildings)
	end)
	Groups.BuildControls:AddButton({
		Text = "Run build cycle now",
		Func = function()
			notifyAction("Build cycle", function()
				return ctx.attemptAutoBuildOnce(
					status.BuildAttemptLabel,
					status.BuildCityLabel,
					status.BuildTierLabel,
					status.BuildInfraLabel,
					status.BuildFundsLabel,
					status.BuildQueueLabel,
					status.BuildCitiesCountLabel,
					status.BuildCitiesFolderLabel
				)
			end, function()
				return status.BuildAttemptLabel.Text
			end)
		end
	})

	bindToggle(
		Groups.ResourceControls,
		"AutoResupplyEnabled",
		"Enable auto resupply (AI only)",
		"AutoResupplyEnabled",
		"Buys detected building shortages from AI suppliers with per-supplier cooldowns.",
		status.AutoResupplyStatusLabel,
		"Auto resupply"
	)
	bindToggle(
		Groups.ResourceControls,
		"AutoResupplyOnlyNegativeFlow",
		"Only resupply negative flow",
		"AutoResupplyOnlyNegativeFlow",
		"Requires the country's resource flow to be negative before buying."
	)
	Groups.ResourceControls:AddSlider("ResupplyMaxTrades", {
		Text = "Maximum trades per scan",
		Default = clampNumber(ctx.Resupply and ctx.Resupply.MaxTradesPerScan, 6, 1, 20),
		Min = 1,
		Max = 20,
		Rounding = 0
	}):OnChanged(function(value)
		if ctx.Resupply then
			ctx.Resupply.MaxTradesPerScan = value
		end
	end)
	bindToggle(
		Groups.ResourceControls,
		"DebtGuardEnabled",
		"Enable debt guard",
		"DebtGuardEnabled",
		"Sells a bounded share of the strongest positive-flow resource when funds require intervention.",
		status.DebtStatusLabel,
		"Debt guard"
	)
	Groups.ResourceControls:AddSlider("DebtGuardFloor", {
		Text = "Proactive balance floor",
		Default = config.DebtGuardFloor,
		Min = 0,
		Max = 10000000,
		Rounding = 0,
		Prefix = "$",
		FormatDisplayValue = function(_, value)
			return ("$%s / $%s"):format(formatNumber(value), formatNumber(10000000))
		end
	}):OnChanged(function(value)
		config.DebtGuardFloor = value
	end)
	bindToggle(
		Groups.ResourceControls,
		"UnitTagsEnabled",
		"Force unit tags visible",
		"UnitTagsEnabled",
		"Temporarily enables unit tags and restores their previous state when disabled.",
		status.UnitTagsStatusLabel,
		"Unit tags"
	)
	Groups.ResourceControls:AddButton({
		Text = "Run resupply scan now",
		Func = function()
			notifyAction("Resupply scan", function()
				local details = ctx.scanAndResupplyOnce()
				if type(details) == "table" and #details > 0 then
					local message = table.concat(details, " | ")
					status.AutoResupplyDetailsLabel:SetText("Resupply details: " .. message)
					return true, message
				end
				status.AutoResupplyDetailsLabel:SetText("Resupply details: no actionable shortage")
				return true, "No actionable shortage was found."
			end, function()
				return status.AutoResupplyDetailsLabel.Text
			end)
		end
	})
	Groups.ResourceControls:AddButton({
		Text = "Run debt guard now",
		Func = function()
			notifyAction("Debt guard", ctx.doDebtGuardOnce, function()
				return ctx.DebtRecovery and ctx.DebtRecovery.LastStatus
			end)
		end
	})

	local annexToggle
	local peaceToggle
	bindToggle(
		Groups.WarControls,
		"AutoJustifyEnabled",
		"Enable auto justify",
		"AutoJustifyEnabled",
		"Requests conquest justification for eligible targets."
	)
	bindToggle(
		Groups.WarControls,
		"AutoDeclareEnabled",
		"Enable auto declare (AI only)",
		"AutoDeclareEnabled",
		"Declares only on AI countries with a replicated conquest casus belli."
	)
	peaceToggle = Groups.WarControls:AddToggle("AutoPeaceEnabled", {
		Text = "Enable partial peace demands",
		Default = config.AutoPeaceEnabled,
		Tooltip = "Sends 75 percent money and resource demands. Mutually exclusive with annex."
	})
	annexToggle = Groups.WarControls:AddToggle("AutoAnnexEnabled", {
		Text = "Enable full annex demands",
		Default = config.AutoAnnexEnabled,
		Tooltip = "Sends annex-all demands when the city threshold is met. Mutually exclusive with partial peace."
	})
	peaceToggle:OnChanged(function(value)
		config.AutoPeaceEnabled = value == true
		if value and annexToggle.Value then
			annexToggle:SetValue(false)
		end
		if updateDashboard then updateDashboard() end
	end)
	annexToggle:OnChanged(function(value)
		config.AutoAnnexEnabled = value == true
		if value and peaceToggle.Value then
			peaceToggle:SetValue(false)
		end
		if updateDashboard then updateDashboard() end
	end)
	Groups.WarControls:AddSlider("AutoAnnexExtraction", {
		Text = "Annex money and resource demand",
		Default = config.AutoAnnexExtractionPercent,
		Min = 0,
		Max = 100,
		Rounding = 0,
		Suffix = "%"
	}):OnChanged(function(value)
		config.AutoAnnexExtractionPercent = value
	end)
	bindToggle(
		Groups.WarControls,
		"AutoPromoteEnabled",
		"Promote corrupt leaders when safe",
		"AutoPromoteEnabled",
		"Promotes only when political power exceeds twice the strongest opponent.",
		status.PromoteStatusLabel,
		"Auto promote"
	)
	Groups.WarControls:AddButton({
		Text = "Run enabled war cycle now",
		Func = function()
			local callback
			if config.AutoAnnexEnabled then
				callback = ctx.doAutoAnnex
			elseif config.AutoPeaceEnabled then
				callback = ctx.doAutoPeace
			elseif config.AutoDeclareEnabled then
				callback = ctx.doAutoDeclare
			else
				callback = ctx.doAutoJustify
			end
			notifyAction("War cycle", callback, function()
				return ctx.War and ctx.War.LastStatus
			end)
		end
	})

	bindToggle(
		Groups.WarFilters,
		"AutoJustifyAIOnly",
		"Justify AI countries only",
		"AutoJustifyAIOnly",
		"This filter applies to justification. Auto declare remains AI-only."
	)
	bindToggle(
		Groups.WarFilters,
		"AutoJustifySkipAllies",
		"Skip allies",
		"AutoJustifySkipAllies",
		"Excludes countries found in the local alliance data."
	)
	bindToggle(
		Groups.WarFilters,
		"AutoJustifySkipWars",
		"Skip countries already at war",
		"AutoJustifySkipWars",
		"Excludes targets currently listed in Workspace.Wars."
	)
	bindToggle(
		Groups.WarFilters,
		"AutoJustifyRequireCities",
		"Require at least one city",
		"AutoJustifyRequireCities",
		"Excludes countries without a detected city."
	)
	Groups.WarFilters:AddSlider("AutoJustifyRetry", {
		Text = "Justification retry interval",
		Default = config.AutoJustifyRetrySeconds,
		Min = 10,
		Max = 300,
		Rounding = 0,
		Suffix = "s"
	}):OnChanged(function(value)
		config.AutoJustifyRetrySeconds = value
	end)

	bindToggle(
		Groups.WatcherControls,
		"WatcherEnabled",
		"Rebel funding watch",
		"WatcherEnabled",
		"Notifies only when a new rebel funder appears.",
		status.WatcherStatusLabel,
		"Rebel watch"
	)
	bindToggle(
		Groups.WatcherControls,
		"JustifyWatchEnabled",
		"Justification progress watch",
		"JustifyWatchEnabled",
		"Tracks new, completed, and hostile justification actions.",
		status.JustWatchStatusLabel,
		"Justification watch"
	)
	bindToggle(
		Groups.WatcherControls,
		"LeaderWatchEnabled",
		"Corrupt leader watch",
		"LeaderWatchEnabled",
		"Notifies when a corrupt leader appears in the current leader folder.",
		status.LeaderWatchStatusLabel,
		"Leader watch"
	)

	bindToggle(
		Groups.SettingsControls,
		"BrainDashboardEnabled",
		"Dashboard monitoring",
		"BrainDashboardEnabled",
		"Reads nation state for the dashboard and next-action decision."
	)
	bindToggle(
		Groups.SettingsControls,
		"NotificationsEnabled",
		"Bottom-right notifications",
		"NotificationsEnabled",
		"Shows automation events in the custom Obsidian-style notification stack."
	)
	bindToggle(
		Groups.SettingsControls,
		"Debug",
		"Debug logging",
		"Debug",
		"Prints detailed automation diagnostics to the executor console."
	)
	Groups.SettingsControls:AddButton({
		Text = "Test notification",
		Func = function()
			showToast("Notification test", "Bottom-right notification delivery is working.", 4, "bell-ring")
		end
	})

	local unloadStarted = false
	local cleanupFunction
	Groups.SettingsControls:AddButton({
		Text = "Unload automation UI",
		Risky = true,
		DoubleClick = true,
		Tooltip = "Double-click to unload the UI and stop the current automation runtime.",
		Func = function()
			if _G and type(_G.RoNNationBrainRuntimeCleanup) == "function" then
				_G.RoNNationBrainRuntimeCleanup()
			elseif cleanupFunction then
				cleanupFunction()
			end
		end
	})

	local function invalidateCountryStatuses()
		status.TradeCountryLabel:SetText("Country: not leader")
		status.TradePartnerLabel:SetText("Partners: unavailable")
		status.TradeFlowLabel:SetText("Flow: unavailable")
		status.TradeIncomeLabel:SetText("Trade export: unavailable")
		status.TradePercentLabel:SetText(
			"Trade percent: " .. tostring(math.floor(config.TradeTargetPercent * 100 + 0.5)) .. "%"
		)
		status.BuildCitiesFolderLabel:SetText("Cities folder: unavailable")
		status.BuildCitiesCountLabel:SetText("Cities found: 0")
		status.BuildCityLabel:SetText("City: unavailable")
		status.BuildTierLabel:SetText("Tier: unavailable")
		status.BuildInfraLabel:SetText("Infrastructure: unavailable")
		status.BuildFundsLabel:SetText("Funds: unavailable")
		status.BuildQueueLabel:SetText("Queue: unavailable")
	end

	local function stateStatus(state, fallback)
		if state and type(state.LastStatus) == "string" and state.LastStatus ~= "" then
			return state.LastStatus
		end
		return fallback
	end

	local function chooseNextAction(snapshot)
		if not snapshot.leader then
			return {
				name = "Refresh dashboard",
				description = "Leadership data is unavailable, so no nation-changing action is safe.",
				callback = updateDashboard,
				status = function() return "Waiting for leadership data" end
			}
		end

		if config.DebtGuardEnabled and type(snapshot.funds) == "number" and snapshot.funds < 0 then
			return {
				name = "Debt recovery",
				description = "Balance is negative. Debt Guard has priority over buying or construction.",
				callback = ctx.doDebtGuardOnce,
				status = function() return stateStatus(ctx.DebtRecovery, status.DebtStatusLabel.Text) end
			}
		end

		if config.AutoResupplyEnabled and snapshot.topNeed then
			return {
				name = "Resupply production",
				description = snapshot.needSummary .. ". The scan will use validated AI suppliers.",
				callback = ctx.scanAndResupplyOnce,
				status = function() return status.AutoResupplyDetailsLabel.Text end
			}
		end

		local mode = config.BrainStrategyMode
		if mode == "Military Readiness" then
			if config.AutoAnnexEnabled then
				return {
					name = "Evaluate annex demand",
					description = "Full annex is enabled and takes precedence over partial peace.",
					callback = ctx.doAutoAnnex,
					status = function() return stateStatus(ctx.War, status.WarStatusLabel.Text) end
				}
			elseif config.AutoPeaceEnabled then
				return {
					name = "Evaluate peace demand",
					description = "Partial peace is enabled; city thresholds will be checked first.",
					callback = ctx.doAutoPeace,
					status = function() return stateStatus(ctx.War, status.WarStatusLabel.Text) end
				}
			elseif config.AutoDeclareEnabled then
				return {
					name = "Evaluate AI declarations",
					description = "Only AI targets with a replicated conquest casus belli are eligible.",
					callback = ctx.doAutoDeclare,
					status = function() return stateStatus(ctx.War, status.WarStatusLabel.Text) end
				}
			elseif config.AutoJustifyEnabled then
				return {
					name = "Evaluate justification targets",
					description = "The configured alliance, war, city, and AI filters will be applied.",
					callback = ctx.doAutoJustify,
					status = function() return stateStatus(ctx.War, status.WarStatusLabel.Text) end
				}
			end
		end

		if config.TradeEnabled then
			return {
				name = "Run trade scan",
				description = "Trade is enabled. The cycle will fail closed on missing flow or price data.",
				callback = function()
					return ctx.attemptOneTrade(
						status.TradeStatusLabel,
						status.TradeAttemptingLabel,
						setTradeValidList,
						status.TradeFlowSafetyLabel
					)
				end,
				status = function() return status.TradeAttemptingLabel.Text end
			}
		end
		if config.AutoBuildEnabled then
			return {
				name = "Run build cycle",
				description = "Build is enabled. Only affordable buildings in the selected set are eligible.",
				callback = function()
					return ctx.attemptAutoBuildOnce(
						status.BuildAttemptLabel,
						status.BuildCityLabel,
						status.BuildTierLabel,
						status.BuildInfraLabel,
						status.BuildFundsLabel,
						status.BuildQueueLabel,
						status.BuildCitiesCountLabel,
						status.BuildCitiesFolderLabel
					)
				end,
				status = function() return status.BuildAttemptLabel.Text end
			}
		end
		if config.AutoPolicyEnabled then
			return {
				name = "Run policy cycle",
				description = "Selected policies will be evaluated against current political power.",
				callback = ctx.doAutoPolicy,
				status = function() return stateStatus(ctx.Policy, status.PolicyStatusLabel.Text) end
			}
		end

		return {
			name = "Refresh dashboard",
			description = "No enabled automation currently requires a nation-changing action.",
			callback = updateDashboard,
			status = function() return "Nation snapshot refreshed" end
		}
	end

	updateDashboard = function()
		if not config.BrainDashboardEnabled then
			decisionLabel:SetText("Dashboard monitoring is paused in Settings.")
			evidenceLabel:SetText("No nation data is being read while monitoring is paused.")
			shortageLabel:SetText("Resource check paused.")
			nextAction = {
				name = "Refresh dashboard",
				callback = updateDashboard,
				status = function() return "Dashboard monitoring is paused" end
			}
			return
		end

		local leaderCallOk, leaderOk, myCountry = safeCall(ctx.assertStillLeader)
		local hasLeader = leaderCallOk and leaderOk == true and myCountry ~= nil
		local snapshot = {
			leader = hasLeader,
			country = hasLeader and myCountry.Name or nil
		}

		if not hasLeader then
			status.DashCountryLabel:SetText("Country: not leader")
			status.DashFundsLabel:SetText("Balance: unavailable")
			status.DashPoliticalLabel:SetText("Political power: unavailable")
			status.DashCitiesLabel:SetText("Cities: unavailable")
			status.DashTradeLabel:SetText("Trade partners: unavailable")
			status.DashFlowLabel:SetText("Selected flow: unavailable")
			status.DashWarsLabel:SetText("Active wars: unavailable")
			status.DashAutoLabel:SetText("Enabled automations: " .. tostring(#getActiveAutomationNames(config)))
			invalidateCountryStatuses()
			decisionLabel:SetText("Waiting for leadership data before selecting an action.")
			evidenceLabel:SetText(
				leaderCallOk and "The local player is not the detected country leader."
					or ("Leadership check failed: " .. tostring(leaderOk))
			)
			shortageLabel:SetText("Resource check unavailable.")
		else
			local _, funds = safeCall(ctx.getMyFunds)
			local _, political = safeCall(ctx.getPolicyPower, myCountry)
			local cityCallOk, cities = safeCall(ctx.getAllMyCitiesSorted)
			if not cityCallOk or type(cities) ~= "table" then
				cities = {}
			end
			local _, partners = safeCall(ctx.getTradeCount, myCountry, config.TradeResource)
			local _, flow = safeCall(ctx.getCountryResourceFlow, myCountry, config.TradeResource)
			local _, net = safeCall(ctx.getNetIncome, myCountry)
			local needCallOk, needs = safeCall(ctx.computeTotalNeedByResource, cities)
			if not needCallOk or type(needs) ~= "table" then
				needs = {}
			end

			snapshot.funds = type(funds) == "number" and funds or nil
			snapshot.political = type(political) == "number" and political or nil
			snapshot.cities = #cities
			snapshot.partners = type(partners) == "number" and partners or nil
			snapshot.flow = type(flow) == "number" and flow or nil
			snapshot.net = type(net) == "number" and net or nil
			snapshot.wars = countCountryWars(ctx.workspace, myCountry.Name)
			snapshot.needSummary, snapshot.topNeed = summarizeNeeds(needs)

			local active = getActiveAutomationNames(config)
			status.DashCountryLabel:SetText("Country: " .. myCountry.Name)
			status.DashFundsLabel:SetText("Balance: $" .. formatNumber(snapshot.funds))
			status.DashPoliticalLabel:SetText("Political power: " .. formatNumber(snapshot.political))
			status.DashCitiesLabel:SetText("Cities: " .. tostring(snapshot.cities))
			status.DashTradeLabel:SetText(
				("Trade partners (%s): %s"):format(config.TradeResource, formatNumber(snapshot.partners))
			)
			status.DashFlowLabel:SetText(
				("Selected flow (%s): %s"):format(config.TradeResource, formatNumber(snapshot.flow))
			)
			status.DashWarsLabel:SetText("Active wars: " .. tostring(snapshot.wars))
			status.DashAutoLabel:SetText(
				#active > 0 and ("Enabled: " .. table.concat(active, ", ")) or "Enabled automations: none"
			)

			evidenceLabel:SetText(
				("Balance $%s | Net %s | %d cities | %d wars"):format(
					formatNumber(snapshot.funds),
					formatNumber(snapshot.net),
					snapshot.cities,
					snapshot.wars
				)
			)
			shortageLabel:SetText(snapshot.needSummary)
		end

		status.DashWarLabel:SetText("War: " .. stateStatus(ctx.War, "Idle"))
		status.DashBuildLabel:SetText("Build: " .. stateStatus(ctx.AutoBuild, status.AutoBuildStatusLabel.Text))
		status.DashResourceLabel:SetText(
			"Resources: " .. stateStatus(ctx.DebtRecovery, status.AutoResupplyStatusLabel.Text)
		)
		status.DashWatcherLabel:SetText(
			"Watchers: " .. stateStatus(ctx.Watcher, status.WatcherStatusLabel.Text)
		)
		status.DashPolicyLabel:SetText("Policy: " .. stateStatus(ctx.Policy, status.PolicyStatusLabel.Text))

		feedTrade:SetText("Trade | " .. status.TradeStatusLabel.Text .. " | " .. status.TradeAttemptingLabel.Text)
		feedBuild:SetText("Build | " .. status.AutoBuildStatusLabel.Text .. " | " .. status.BuildAttemptLabel.Text)
		feedResources:SetText(
			"Resources | " .. status.AutoResupplyStatusLabel.Text .. " | " .. status.DebtStatusLabel.Text
		)
		feedWar:SetText("War | " .. status.WarStatusLabel.Text)
		feedWatchers:SetText(
			"Watchers | " .. status.WatcherStatusLabel.Text .. " | " .. status.JustWatchStatusLabel.Text
		)

		nextAction = chooseNextAction(snapshot)
		decisionLabel:SetText(nextAction.name .. ": " .. nextAction.description)
	end

	setTradeValidList = function(names)
		names = type(names) == "table" and names or {}
		status.TradeValidLabel:SetText("Valid countries: " .. tostring(#names))

		local shown = {}
		local limit = math.min(#names, 10)
		for index = 1, limit do
			shown[#shown + 1] = tostring(names[index])
		end
		if #names > limit then
			shown[#shown + 1] = "+" .. tostring(#names - limit) .. " more"
		end
		status.TradeValidListLabel:SetText(
			#shown > 0 and ("Valid list: " .. table.concat(shown, ", ")) or "Valid list: none"
		)
	end

	SaveManager:SetLibrary(Library)
	ThemeManager:SetLibrary(Library)
	SaveManager:SetFolder("RoN_Automation")
	ThemeManager:SetFolder("RoN_Automation")
	SaveManager:IgnoreThemeSettings()
	ThemeManager:ApplyToTab(Tabs.Settings, "palette")
	SaveManager:BuildConfigSection(Tabs.Settings, "save")
	ThemeManager:LoadDefault()
	installResponsiveLayout()

	local function clearCustomArtifacts()
		destroyToastHost()
		if _G and _G.RoNNationBrainCleanup == cleanupFunction then
			_G.RoNNationBrainCleanup = nil
		end
	end

	cleanupFunction = function()
		if unloadStarted then
			return
		end
		unloadStarted = true
		clearCustomArtifacts()
		pcall(function()
			Library:Unload()
		end)
	end

	Library:OnUnload(function()
		unloadStarted = true
		clearCustomArtifacts()
	end)
	if _G then
		_G.RoNNationBrainCleanup = cleanupFunction
	end

	updateDashboard()
	SaveManager:LoadAutoloadConfig()
	normalizeConfig(config)
	updateDashboard()

	return {
		UI = Library,
		Window = Window,
		Tabs = Tabs,
		Status = status,
		Notify = function(title, body, duration)
			local icon = "bell"
			local lowered = tostring(title or ""):lower()
			if lowered:find("trade", 1, true) then
				icon = "repeat-2"
			elseif lowered:find("war", 1, true) or lowered:find("annex", 1, true) then
				icon = "swords"
			elseif lowered:find("build", 1, true) then
				icon = "hammer"
			elseif lowered:find("debt", 1, true) or lowered:find("resource", 1, true) then
				icon = "package-open"
			elseif lowered:find("error", 1, true) or lowered:find("fail", 1, true) then
				icon = "triangle-alert"
			end
			return showToast(title, body, duration, icon)
		end,
		setTradeValidList = setTradeValidList,
		updateDashboard = updateDashboard,
		updateBrainUI = updateDashboard,
		Destroy = cleanupFunction
	}
end

return BrainUI
