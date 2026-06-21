-- RoN Nation Brain UI Library
-- Pull from: https://raw.githubusercontent.com/tetizz/roblox-stuff/main/ron_brain_ui.lua

local BrainUI = {}
BrainUI.Version = "2026-06-20.11"
BrainUI.UniversalUIVersion = "2026-06-19.6"

local UniversalUILibraryUrl = "https://raw.githubusercontent.com/tetizz/roblox-stuff/main/universal_ui.lua"

local function loadUniversalUI()
	local ok, result = pcall(function()
		local source = game:HttpGet(UniversalUILibraryUrl)
		local chunk, loadErr = loadstring(source)
		if not chunk then
			error(loadErr or "loadstring failed")
		end
		local library = chunk()
		if type(library) ~= "table" or library.Version ~= BrainUI.UniversalUIVersion then
			error("universal UI version mismatch: " .. tostring(library and library.Version))
		end
		return library
	end)
	if ok then
		return result
	end
	warn("[RoN Nation Brain] universal UI unavailable:", tostring(result))
end

function BrainUI.new(ctx)
	local CONFIG = ctx.CONFIG
	local CoreGui = ctx.CoreGui
	local UserInputService = ctx.UserInputService
	local workspace = ctx.workspace
	local Resources = ctx.Resources
	local BuildingsFolder = ctx.BuildingsFolder
	local CountryData = ctx.CountryData
	local Policy = ctx.Policy

	local assertStillLeader = ctx.assertStillLeader
	local getAllMyCitiesSorted = ctx.getAllMyCitiesSorted
	local getMyFunds = ctx.getMyFunds
	local getPolicyPower = ctx.getPolicyPower
	local getCountryResourceFlow = ctx.getCountryResourceFlow
	local getTradeCount = ctx.getTradeCount
	local getNetIncome = ctx.getNetIncome
	local computeTotalNeedByResource = ctx.computeTotalNeedByResource
	local scanAndResupplyOnce = ctx.scanAndResupplyOnce
	local attemptAutoBuildOnce = ctx.attemptAutoBuildOnce
	local doAutoPolicy = ctx.doAutoPolicy
	local attemptOneTrade = ctx.attemptOneTrade
	local doAutoJustify = ctx.doAutoJustify
	local doAutoDeclare = ctx.doAutoDeclare
	local doAutoPeace = ctx.doAutoPeace
	local doAutoAnnex = ctx.doAutoAnnex
	local doAutoPromote = ctx.doAutoPromote
	local doDebtGuardOnce = ctx.doDebtGuardOnce
	local safeNotify = ctx.safeNotify
	local buildPolicyInfo = ctx.buildPolicyInfo

	local UniversalUI = ctx.UniversalUI or loadUniversalUI()
	local Primitives = UniversalUI and UniversalUI.Primitives
	local TweenService = game:GetService("TweenService")
	local RunService = game:GetService("RunService")

	local updateBrainUI
-- Custom Nation Brain UI
--============================================================
local UI = {
	ActiveTab = "Dashboard",
	Buttons = {},
	Brain = {},
	StatusLabels = {},
	QueueRows = {},
	ResourceRows = {},
	Cards = {},
	PageConnections = {},
	RootConnections = {},
	Animations = {},
	LastAction = { id = "refresh", title = "Refresh nation scan", risk = "Low" }
}

local DashCountryLabel, DashFundsLabel, DashPoliticalLabel, DashCitiesLabel, DashTradeLabel, DashFlowLabel, DashWarsLabel
local DashAutoLabel, DashWarLabel, DashBuildLabel, DashResourceLabel, DashWatcherLabel, DashPolicyLabel
local TradeStatusLabel, TradeCountryLabel, TradePartnerLabel, TradeFlowLabel, TradeIncomeLabel, TradePercentLabel
local TradeAttemptingLabel, TradeValidLabel, TradeValidListLabel, TradeFlowSafetyLabel
local WarStatusLabel, PromoteStatusLabel, AutoResupplyStatusLabel, AutoResupplyDetailsLabel, UnitTagsStatusLabel
local PolicyStatusLabel, PolicyCountLabel, WatcherStatusLabel, JustWatchStatusLabel, LeaderWatchStatusLabel
local AutoBuildStatusLabel, BuildCitiesFolderLabel, BuildCitiesCountLabel, BuildCityLabel, BuildTierLabel
local BuildInfraLabel, BuildFundsLabel, BuildQueueLabel, BuildAttemptLabel

local C = (UniversalUI and UniversalUI.Themes and UniversalUI.Themes.NationBrain) or {
	bg = Color3.fromRGB(5, 14, 23),
	panel = Color3.fromRGB(9, 23, 34),
	panel2 = Color3.fromRGB(12, 28, 41),
	line = Color3.fromRGB(41, 62, 76),
	text = Color3.fromRGB(218, 226, 235),
	muted = Color3.fromRGB(143, 153, 166),
	green = Color3.fromRGB(119, 218, 88),
	blue = Color3.fromRGB(58, 157, 255),
	amber = Color3.fromRGB(255, 177, 50),
	red = Color3.fromRGB(235, 91, 74)
}

local function clamp(n, lo, hi)
	if Primitives and Primitives.clamp then
		return Primitives.clamp(n, lo, hi)
	end
	n = tonumber(n) or 0
	if n < lo then return lo end
	if n > hi then return hi end
	return n
end

local function inst(className, props)
	if Primitives and Primitives.inst then
		return Primitives.inst(className, props)
	end
	local obj = Instance.new(className)
	for key, value in pairs(props or {}) do
		obj[key] = value
	end
	return obj
end

local function corner(parent, radius)
	if Primitives and Primitives.corner then
		return Primitives.corner(parent, radius)
	end
	return inst("UICorner", {
		CornerRadius = UDim.new(0, radius or 8),
		Parent = parent
	})
end

local function stroke(parent, color, transparency, thickness)
	if Primitives and Primitives.stroke then
		return Primitives.stroke(parent, color or C.line, transparency, thickness)
	end
	return inst("UIStroke", {
		Color = color or C.line,
		Transparency = transparency or 0.25,
		Thickness = thickness or 1,
		Parent = parent
	})
end

local function gradient(parent, a, b, rotation)
	if Primitives and Primitives.gradient then
		return Primitives.gradient(parent, a, b, rotation)
	end
	return inst("UIGradient", {
		Color = ColorSequence.new(a, b),
		Rotation = rotation or 90,
		Parent = parent
	})
end

local function makeText(parent, text, pos, size, fontSize, color, bold)
	if Primitives and Primitives.text then
		return Primitives.text(parent, text, pos, size, fontSize, color or C.text, bold)
	end
	local label = inst("TextLabel", {
		BackgroundTransparency = 1,
		Position = pos,
		Size = size,
		Text = text or "",
		TextColor3 = color or C.text,
		TextSize = fontSize or 14,
		Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextWrapped = true,
		Parent = parent
	})
	return label
end

local function makePanel(parent, pos, size, name)
	if Primitives and Primitives.panel then
		return Primitives.panel(parent, pos, size, name, C)
	end
	local frame = inst("Frame", {
		Name = name or "Panel",
		BackgroundColor3 = C.panel,
		BorderSizePixel = 0,
		Position = pos,
		Size = size,
		Parent = parent
	})
	corner(frame, 8)
	stroke(frame, C.line, 0.25, 1)
	gradient(frame, Color3.fromRGB(12, 29, 43), Color3.fromRGB(5, 13, 22), 90)
	return frame
end

local function makeLine(parent, x1, y1, x2, y2, color, thickness, transparency)
	if Primitives and Primitives.line then
		return Primitives.line(parent, x1, y1, x2, y2, color, thickness, transparency)
	end
	local dx = x2 - x1
	local dy = y2 - y1
	local length = math.sqrt(dx * dx + dy * dy)
	local line = inst("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = color or C.blue,
		BackgroundTransparency = transparency or 0.15,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset((x1 + x2) / 2, (y1 + y2) / 2),
		Rotation = math.deg(math.atan2(dy, dx)),
		Size = UDim2.fromOffset(length, thickness or 2),
		Parent = parent
	})
	return line
end

local function makeDashedLine(parent, x1, y1, x2, y2, color)
	if Primitives and Primitives.dashedLine then
		return Primitives.dashedLine(parent, x1, y1, x2, y2, color or C.green)
	end
	local parts = 14
	for i = 0, parts - 1, 2 do
		local a = i / parts
		local b = math.min((i + 1) / parts, 1)
		makeLine(
			parent,
			x1 + (x2 - x1) * a,
			y1 + (y2 - y1) * a,
			x1 + (x2 - x1) * b,
			y1 + (y2 - y1) * b,
			color or C.green,
			2,
			0.15
		)
	end
end

local function wrapStatus(text)
	local obj = { Text = text or "" }
	function obj:SetText(value)
		self.Text = tostring(value or "")
		if self.Label and self.Label.Parent then
			self.Label.Text = self.Text
		end
	end
	return obj
end

local function runUICallback(callback, ...)
	if not callback then
		return
	end
	local ok, err = pcall(callback, ...)
	if not ok then
		warn("[RoN Nation Brain] UI callback failed:", tostring(err))
	end
end

local function bindStatus(parent, y, title, obj)
	makeText(parent, title, UDim2.fromOffset(18, y), UDim2.fromOffset(180, 24), 13, C.muted, true)
	local label = makeText(parent, obj.Text, UDim2.fromOffset(210, y), UDim2.fromOffset(760, 24), 13, C.text, false)
	label.TextXAlignment = Enum.TextXAlignment.Left
	obj.Label = label
	return y + 32
end

local function trackPageConnection(conn)
	UI.PageConnections[#UI.PageConnections + 1] = conn
	return conn
end

local function trackRootConnection(conn)
	UI.RootConnections[#UI.RootConnections + 1] = conn
	return conn
end

local function disconnectConnections(list)
	for _, conn in ipairs(list) do
		if conn and conn.Disconnect then
			pcall(function()
				conn:Disconnect()
			end)
		end
	end
end

local function resetPageAnimations()
	UI.Animations = {
		Time = 0,
		Lines = {},
		Particles = {},
		Dots = {},
		Nodes = {},
		Orbits = {},
		QueueRows = {},
		Cards = {}
	}
end

resetPageAnimations()

local function tweenObject(obj, duration, props, easingStyle, easingDirection)
	if not obj or not obj.Parent then
		return
	end
	local ok = pcall(function()
		local tween = TweenService:Create(
			obj,
			TweenInfo.new(duration or 0.18, easingStyle or Enum.EasingStyle.Quad, easingDirection or Enum.EasingDirection.Out),
			props
		)
		tween:Play()
	end)
	if not ok then
		for key, value in pairs(props or {}) do
			pcall(function()
				obj[key] = value
			end)
		end
	end
end

local function registerAnimatedLine(line, minTransparency, maxTransparency, speed, phase)
	if line then
		UI.Animations.Lines[#UI.Animations.Lines + 1] = {
			Object = line,
			Min = minTransparency or 0.05,
			Max = maxTransparency or 0.65,
			Speed = speed or 1,
			Phase = phase or 0
		}
	end
	return line
end

local function registerFlowParticle(parent, x1, y1, x2, y2, color, speed, phase, size)
	local dot = inst("Frame", {
		BackgroundColor3 = color or C.blue,
		BackgroundTransparency = 0.05,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(x1, y1),
		Size = UDim2.fromOffset(size or 6, size or 6),
		ZIndex = 8,
		Parent = parent
	})
	corner(dot, 8)
	UI.Animations.Particles[#UI.Animations.Particles + 1] = {
		Object = dot,
		From = Vector2.new(x1, y1),
		To = Vector2.new(x2, y2),
		Speed = speed or 0.28,
		Phase = phase or 0
	}
	return dot
end

local function makeAnimatedLine(parent, x1, y1, x2, y2, color, thickness, transparency, phase)
	local line = makeLine(parent, x1, y1, x2, y2, color, thickness, transparency)
	registerAnimatedLine(line, 0.05, 0.6, 1.2, phase or 0)
	registerFlowParticle(parent, x1, y1, x2, y2, color, 0.24, phase or 0, 5)
	return line
end

local function registerPulseDot(dot, minSize, maxSize, speed, phase)
	if dot then
		UI.Animations.Dots[#UI.Animations.Dots + 1] = {
			Object = dot,
			BasePosition = dot.Position,
			MinSize = minSize or 4,
			MaxSize = maxSize or 7,
			Speed = speed or 1,
			Phase = phase or 0
		}
	end
	return dot
end

local function registerNode(node, strokeObj, phase)
	if node then
		UI.Animations.Nodes[#UI.Animations.Nodes + 1] = {
			Frame = node,
			Stroke = strokeObj,
			BaseTransparency = node.BackgroundTransparency,
			Phase = phase or 0
		}
	end
	return node
end

local function registerOrbit(parent, centerX, centerY, radiusX, radiusY, color, speed, phase)
	local dot = inst("Frame", {
		BackgroundColor3 = color or C.blue,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(7, 7),
		ZIndex = 9,
		Parent = parent
	})
	corner(dot, 7)
	UI.Animations.Orbits[#UI.Animations.Orbits + 1] = {
		Object = dot,
		Center = Vector2.new(centerX, centerY),
		Radius = Vector2.new(radiusX, radiusY),
		Speed = speed or 0.7,
		Phase = phase or 0
	}
	return dot
end

local function registerQueueRow(frame, index)
	if frame then
		UI.Animations.QueueRows[#UI.Animations.QueueRows + 1] = {
			Frame = frame,
			Index = index or 1
		}
	end
	return frame
end

local function registerAnimatedCard(panel, index)
	if panel then
		UI.Animations.Cards[#UI.Animations.Cards + 1] = {
			Frame = panel,
			Stroke = panel:FindFirstChildOfClass("UIStroke"),
			Index = index or 1
		}
	end
	return panel
end

local function animateDashboard(dt)
	if not UI.Screen or not UI.Screen.Parent or not UI.Page or UI.ActiveTab ~= "Dashboard" or not CONFIG.BrainDashboardEnabled then
		return
	end

	local anim = UI.Animations
	anim.Time = (anim.Time or 0) + (dt or 0.016)
	local t = anim.Time
	local danger = UI.LastCascade or UI.LastInRecovery
	local guard = UI.LastGuardState
	local accent = danger and C.red or (guard and C.amber or C.blue)

	for _, item in ipairs(anim.Lines or {}) do
		local obj = item.Object
		if obj and obj.Parent then
			local alpha = (math.sin(t * item.Speed + item.Phase) + 1) * 0.5
			obj.BackgroundTransparency = item.Min + (item.Max - item.Min) * alpha
			obj.BackgroundColor3 = accent
		end
	end

	for _, item in ipairs(anim.Particles or {}) do
		local obj = item.Object
		if obj and obj.Parent then
			local alpha = (t * item.Speed + item.Phase) % 1
			local pos = item.From + (item.To - item.From) * alpha
			obj.Position = UDim2.fromOffset(pos.X - obj.AbsoluteSize.X / 2, pos.Y - obj.AbsoluteSize.Y / 2)
			obj.BackgroundColor3 = accent
			obj.BackgroundTransparency = 0.08 + 0.45 * math.abs(alpha - 0.5) * 2
		end
	end

	for _, item in ipairs(anim.Dots or {}) do
		local obj = item.Object
		if obj and obj.Parent then
			local alpha = (math.sin(t * item.Speed + item.Phase) + 1) * 0.5
			local size = item.MinSize + (item.MaxSize - item.MinSize) * alpha
			obj.Size = UDim2.fromOffset(size, size)
			obj.Position = item.BasePosition + UDim2.fromOffset(-(size - item.MinSize) / 2, -(size - item.MinSize) / 2)
			obj.BackgroundTransparency = 0.08 + 0.25 * (1 - alpha)
			obj.BackgroundColor3 = accent
		end
	end

	for _, item in ipairs(anim.Orbits or {}) do
		local obj = item.Object
		if obj and obj.Parent then
			local a = t * item.Speed + item.Phase
			local x = item.Center.X + math.cos(a) * item.Radius.X
			local y = item.Center.Y + math.sin(a) * item.Radius.Y
			obj.Position = UDim2.fromOffset(x - 3, y - 3)
			obj.BackgroundColor3 = accent
		end
	end

	for _, item in ipairs(anim.Nodes or {}) do
		local frame = item.Frame
		if frame and frame.Parent then
			local alpha = (math.sin(t * 1.4 + item.Phase) + 1) * 0.5
			frame.BackgroundTransparency = (item.BaseTransparency or 0) + 0.06 * alpha
			if item.Stroke and item.Stroke.Parent then
				item.Stroke.Transparency = 0.12 + 0.32 * (1 - alpha)
			end
		end
	end

	for _, item in ipairs(anim.QueueRows or {}) do
		local frame = item.Frame
		if frame and frame.Parent then
			local alpha = (math.sin(t * 1.1 + item.Index * 0.6) + 1) * 0.5
			frame.BackgroundTransparency = 0.72 + 0.08 * alpha
		end
	end

	for _, item in ipairs(anim.Cards or {}) do
		local strokeObj = item.Stroke
		if strokeObj and strokeObj.Parent then
			local alpha = (math.sin(t * 0.9 + item.Index * 0.4) + 1) * 0.5
			strokeObj.Transparency = 0.32 + 0.18 * alpha
		end
	end
end

local function startAnimationLoop()
	if UI.AnimationConnection then
		return
	end
	UI.AnimationConnection = trackRootConnection(RunService.Heartbeat:Connect(animateDashboard))
end

local function installGlobalCleanup()
	if _G and type(_G.RoNNationBrainCleanup) == "function" then
		pcall(_G.RoNNationBrainCleanup)
	end
	if _G then
		_G.RoNNationBrainCleanup = function()
			disconnectConnections(UI.PageConnections)
			disconnectConnections(UI.RootConnections)
			UI.PageConnections = {}
			UI.RootConnections = {}
			UI.AnimationConnection = nil
			resetPageAnimations()
			if UI.Screen and UI.Screen.Parent then
				UI.Screen:Destroy()
			end
		end
	end
end

local function setBar(bar, value)
	if not bar or not bar.Fill then return end
	value = clamp(value, 0, 100)
	tweenObject(bar.Fill, 0.28, { Size = UDim2.new(value / 100, 0, 1, 0) })
	if bar.Text then
		bar.Text.Text = tostring(math.floor(value + 0.5)) .. "%"
	end
end

local function scoreColor(score)
	score = tonumber(score) or 0
	if score >= 75 then return C.green end
	if score >= 45 then return C.amber end
	return C.red
end

local function formatMoney(value)
	value = tonumber(value)
	if not value then return "?" end
	local abs = math.abs(value)
	if abs >= 1000000000000 then
		return string.format("%.2fT", value / 1000000000000)
	elseif abs >= 1000000000 then
		return string.format("%.2fB", value / 1000000000)
	elseif abs >= 1000000 then
		return string.format("%.2fM", value / 1000000)
	elseif abs >= 1000 then
		return string.format("%.1fK", value / 1000)
	end
	return tostring(math.floor(value))
end

local function readObjectValue(obj)
	if not obj then return end
	local ok, value = pcall(function()
		return obj.Value
	end)
	if ok then
		return value
	end
end

local function readNumberObject(obj)
	if not obj then return end
	local value = readObjectValue(obj)
	if obj:IsA("NumberValue") or obj:IsA("IntValue") then
		return value
	end
	if obj:IsA("Vector3Value") and typeof(value) == "Vector3" then
		return tonumber(value.X)
	end
	if obj:IsA("StringValue") then
		return tonumber(value)
	end
end

local function findNumber(root, names, folders)
	if not root then return end
	local function try(container)
		if not container then return end
		for _, name in ipairs(names) do
			local attr = container:GetAttribute(name)
			if type(attr) == "number" then
				return attr
			end
			local child = container:FindFirstChild(name)
			local value = readNumberObject(child)
			if type(value) == "number" then
				return value
			end
		end
	end

	local direct = try(root)
	if direct then return direct end
	for _, folderName in ipairs(folders or {}) do
		local value = try(root:FindFirstChild(folderName))
		if value then return value end
	end
end

local function countMyWars(myCountryName)
	local warsFolder = workspace:FindFirstChild("Wars")
	if not warsFolder or not myCountryName then
		return 0
	end

	local total = 0
	for _, war in ipairs(warsFolder:GetChildren()) do
		local attacker = war:FindFirstChild("Attacker")
		local defender = war:FindFirstChild("Defender")
		if (attacker and attacker:FindFirstChild(myCountryName)) or (defender and defender:FindFirstChild(myCountryName)) then
			total = total + 1
		end
	end
	return total
end

local function countJustificationsAgainst(myCountryName)
	if not myCountryName then return 0 end
	local threats = 0
	for _, country in ipairs(CountryData:GetChildren()) do
		if country.Name ~= myCountryName then
			local dip = country:FindFirstChild("Diplomacy")
			local actions = dip and dip:FindFirstChild("Actions")
			if actions and actions:FindFirstChild(myCountryName) then
				threats = threats + 1
			end
		end
	end
	return threats
end

local function joinEnabled(items)
	local enabled = {}
	for _, item in ipairs(items) do
		if item.on then
			enabled[#enabled + 1] = item.name
		end
	end
	if #enabled == 0 then
		return "none"
	end
	return table.concat(enabled, ", ")
end

local function resourceFlowRows(myCountry, maxRows)
	local rows = {}
	local folder = myCountry and myCountry:FindFirstChild("Resources")
	if not folder then return rows end
	for _, resource in ipairs(folder:GetChildren()) do
		local flow = resource:FindFirstChild("Flow")
		local value = readObjectValue(flow)
		if type(value) == "number" then
			rows[#rows + 1] = {
				name = resource.Name,
				flow = value
			}
		end
	end
	table.sort(rows, function(a, b)
		if a.flow < 0 and b.flow >= 0 then return true end
		if b.flow < 0 and a.flow >= 0 then return false end
		return math.abs(a.flow) > math.abs(b.flow)
	end)
	while #rows > (maxRows or 5) do
		table.remove(rows)
	end
	return rows
end

local function firstResourceProblem(myCountry, cities)
	local needs = computeTotalNeedByResource(cities or {})
	local bestName
	local bestNeed = 0
	for name, need in pairs(needs) do
		if need > bestNeed then
			bestName = name
			bestNeed = need
		end
	end
	if bestName then
		return bestName, bestNeed
	end
	local rows = resourceFlowRows(myCountry, 20)
	for _, row in ipairs(rows) do
		if row.flow < 0 then
			return row.name, math.abs(row.flow)
		end
	end
end

-- Map net income (per hour) to an Economy base score on a logarithmic curve.
-- Anchored to the real RoN economy scale:
--   ~50,000  -> ~38  (struggling)
--   ~1,000,000 -> ~68 (good; midpoint on the log ladder)
--   ~20,000,000 -> ~98 (essentially unlimited)
-- Doubling raises the score by a fixed step, matching how economies scale.
local NET_LOW = 50000      -- net considered "really low"
local NET_HIGH = 20000000  -- net considered "do whatever you want"
local NET_LOW_SCORE = 38   -- score at NET_LOW
local NET_HIGH_SCORE = 98  -- score at NET_HIGH (cap)

local function netIncomeScore(net)
	if type(net) ~= "number" then
		return NET_LOW_SCORE - 3  -- unknown net: a touch below a low surplus
	end
	if net <= 0 then
		-- Deficit: deeper is worse, down toward 0.
		return clamp(30 - math.min(math.abs(net) / 5000, 1) * 30, 0, 30)
	end
	if net <= NET_LOW then
		-- Tiny surplus to "really low": ramp from NET_LOW_SCORE down a bit.
		return clamp(NET_LOW_SCORE - (1 - net / NET_LOW) * 12, 20, NET_LOW_SCORE)
	end
	-- NET_LOW..NET_HIGH and beyond: logarithmic growth to the cap.
	local span = math.log(NET_HIGH / NET_LOW)          -- doublings from low to high
	local growth = math.log(net / NET_LOW)             -- doublings above low
	return clamp(NET_LOW_SCORE + (growth / span) * (NET_HIGH_SCORE - NET_LOW_SCORE), NET_LOW_SCORE, NET_HIGH_SCORE)
end

local function buildBrainSnapshot()
	local ok, myCountry = assertStillLeader()
	if not ok then
		return {
			online = false,
			country = "?",
			leader = "?",
			cities = 0,
			funds = nil,
			power = 0,
			wars = 0,
			threats = 0,
			confidence = 0,
			inRecovery = false,
			guardState = false,
			cascade = false,
			recoveryProgress = 0,
			resourceNeeds = {},
			starvedCount = 0,
			goal = "Waiting for country leadership",
			goalProgress = 0,
			nextAction = { id = "refresh", title = "Wait for leader data", priority = "Low", eta = "00:05", risk = "Low" },
			actions = {
				{ id = "refresh", title = "Wait for leader data", priority = "Low", eta = "00:05", risk = "Low" }
			},
			nodes = {
				Scanner = 0,
				Economy = 0,
				Politics = 0,
				Diplomacy = 0,
				Military = 0,
				Planner = 0,
				Executor = 0
			},
			metrics = {
				stability = nil,
				money = nil,
				power = 0,
				resourceFlow = {},
				readiness = nil,
				warRisk = 0
			}
		}
	end

	local cities = getAllMyCitiesSorted()
	local funds = select(1, getMyFunds())
	local net = getNetIncome(myCountry)
	local power = getPolicyPower(myCountry)
	local stability = findNumber(myCountry, { "Stability", "Stable" }, { "Government", "Politics", "Stats" })
	local corruption = findNumber(myCountry, { "Corruption" }, { "Government", "Politics", "Stats" })
	local readiness = findNumber(myCountry, { "Readiness", "MilitaryReadiness" }, { "Military", "Power", "Stats" })
	local wars = countMyWars(myCountry.Name)
	local threats = countJustificationsAgainst(myCountry.Name)
	local resourceRows = resourceFlowRows(myCountry, 5)
	local problemResource = firstResourceProblem(myCountry, cities)

	-- Full map of resources starved by non-operational buildings {name=need}.
	-- Computed once; used to diagnose the deficit cascade (negative balance ->
	-- imports cancel -> factories stop) and to drive recovery actions.
	local resourceNeeds = computeTotalNeedByResource(cities)
	local starvedCount = 0
	local starvedTotal = 0
	for _, need in pairs(resourceNeeds) do
		starvedCount = starvedCount + 1
		starvedTotal = starvedTotal + (tonumber(need) or 0)
	end

	-- Economy: logarithmic curve over net income, anchored to real RoN scale
	-- (50K ~= struggling, 1M ~= strong). See netIncomeScore for the math.
	local economyScore = netIncomeScore(net)
	if type(funds) == "number" and funds > 100000000 then
		economyScore = economyScore + 8
	end
	if problemResource then
		economyScore = economyScore - 12
	end
	economyScore = clamp(economyScore, 0, 100)

	-- Recovery mode: the GAME cancels incoming trades when the BALANCE (money
	-- on hand) goes negative -- not net income. So the cascade trigger keys on
	-- funds, not net. (Net still feeds the economy SCORE as a flow/trajectory.)
	-- When factories are ALSO starved, we're in the import-collapse cascade:
	-- negative balance -> incoming trades cancel -> factories stop producing.
	local inRecovery = type(funds) == "number" and funds < 0
	local cascade = inRecovery and starvedCount > 0
	local recoveryProgress = 0
	if inRecovery then
		-- Progress back to a zero balance. -50K is a deep hole -> 0%.
		local BALANCE_DEEP = 50000
		recoveryProgress = clamp(100 - (math.abs(funds) / BALANCE_DEEP) * 100, 0, 100)
	end

	-- GUARD (proactive tier): balance below the floor but not yet in debt, AND
	-- net income negative (heading toward debt, not self-healing). This is the
	-- tier where Debt Guard sells surplus gently BEFORE the cascade can start.
	local guardState = (not inRecovery)
		and type(funds) == "number" and funds < (CONFIG.DebtGuardFloor or 0)
		and type(net) == "number" and net < 0

	local politicsScore = clamp((stability or 70) - ((corruption or 0) * 0.5) + math.min(power / 25, 15), 0, 100)
	local diplomacyScore = clamp(88 - wars * 16 - threats * 24, 0, 100)
	local militaryScore = clamp(readiness or (wars > 0 and 70 or 82), 0, 100)
	local plannerScore = clamp((economyScore + politicsScore + diplomacyScore + militaryScore) / 4, 0, 100)
	local executorScore = 72
	-- Count every automation CONFIG flag that exists, so the Executor node
	-- reflects what's actually running (not just 4 of them).
	local executorActive = CONFIG.TradeEnabled
		or CONFIG.AutoBuildEnabled
		or CONFIG.AutoResupplyEnabled
		or CONFIG.AutoPolicyEnabled
		or CONFIG.AutoPromoteEnabled
		or CONFIG.UnitTagsEnabled
		or CONFIG.AutoJustifyEnabled
		or CONFIG.AutoDeclareEnabled
		or CONFIG.AutoPeaceEnabled
		or CONFIG.AutoAnnexEnabled
	if executorActive then
		executorScore = 92
	end

	local warRisk = clamp(wars * 24 + threats * 32 + ((readiness and readiness < 50) and 20 or 0) + ((stability and stability < 45) and 20 or 0), 0, 100)

	-- Scanner reflects real data coverage: how many of the key inputs
	-- actually returned a number (vs nil/unknown). Reuses values already read.
	local knownInputs = 0
	local totalInputs = 7
	if type(funds) == "number" then knownInputs = knownInputs + 1 end
	if type(net) == "number" then knownInputs = knownInputs + 1 end
	if type(power) == "number" then knownInputs = knownInputs + 1 end
	if type(stability) == "number" then knownInputs = knownInputs + 1 end
	if type(corruption) == "number" then knownInputs = knownInputs + 1 end
	if type(readiness) == "number" then knownInputs = knownInputs + 1 end
	if type(threats) == "number" then knownInputs = knownInputs + 1 end
	local scannerScore = clamp((knownInputs / totalInputs) * 100, 0, 100)

	local confidence = clamp((scannerScore + economyScore + politicsScore + diplomacyScore + militaryScore + plannerScore + executorScore) / 7, 0, 100)

	local actions = {}
	local function push(id, title, priority, eta, risk)
		actions[#actions + 1] = {
			id = id,
			title = title,
			priority = priority,
			eta = eta,
			risk = risk
		}
	end

	-- Recovery / cascade actions lead the queue.
	-- KEY RULE: while balance < 0 (in debt) you cannot issue BUY requests, so
	-- resupply (which buys) is useless here. The only debt-legal lever is to
	-- SELL resources to raise the balance back to >= 0, and stop the spenders
	-- (Auto Build, wars). Buying/resupply only becomes valid again post-recovery.
	-- Proven handler: trade -> doDebtGuardOnce (orchestrator sells surplus).
	if cascade then
		-- Imports cancelled AND factories starving: sell hard to climb out of
		-- debt first; resupply is blocked until balance recovers.
		push("trade", "Sell surplus to exit debt (buying blocked)", "High", "00:08", "Medium")
		push("economy", "Reduce spending (stop Auto Build / wars)", "Medium", "00:12", "Low")
	elseif inRecovery then
		push("trade", "Sell surplus to exit debt", "High", "00:10", "Medium")
	end
	-- Resupply buys resources: only useful when NOT in debt (balance >= 0).
	if problemResource and not inRecovery then
		push("resupply", "Resupply " .. tostring(problemResource), "High", "00:12", "Low")
	end
	if CONFIG.AutoBuildEnabled then
		push("build", "Run build planner cycle", "Medium", "00:20", "Low")
	else
		push("build-advisor", "Review build priorities", "Medium", "00:30", "Low")
	end
	if power >= 100 and CONFIG.AutoPolicyEnabled then
		push("policy", "Run policy planner", "Medium", "00:22", "Low")
	end
	if CONFIG.BrainStrategyMode == "World Dominance" or CONFIG.BrainStrategyMode == "Formable Rush" then
		push("war-advisor", "Score next conquest target", "High", "00:35", "Medium")
	elseif CONFIG.BrainStrategyMode == "Isolationism" then
		push("defense", "Keep defensive readiness", "Medium", "00:40", "Low")
	else
		push("trade", "Optimize trade network", "Medium", "00:45", "Low")
	end
	-- War/annex actions: surfaced only when relevant, driven by the proven
	-- war count and the existing CONFIG flags (no guessing about game state).
	if CONFIG.AutoAnnexEnabled and wars > 0 then
		push("annex", "Annex winning wars", "High", "00:10", "Medium")
	end
	if CONFIG.AutoDeclareEnabled then
		push("declare", "Declare on justified targets", "Medium", "00:25", "High")
	end
	if CONFIG.AutoPromoteEnabled then
		push("promote", "Promote corrupt leaders", "Low", "00:30", "Low")
	end
	if #actions == 0 then
		push("refresh", "Maintain current plan", "Low", "01:00", "Low")
	end

	local goal = "Build national advantage"
	local goalProgress = confidence
	if CONFIG.BrainStrategyMode == "Economic Power" then
		goal = "Achieve economic dominance"
		goalProgress = economyScore
	elseif CONFIG.BrainStrategyMode == "Isolationism" then
		goal = "Grow safely without wars"
		goalProgress = math.min(economyScore, diplomacyScore)
	elseif CONFIG.BrainStrategyMode == "Tall Development" then
		goal = "Develop core cities"
		goalProgress = economyScore
	elseif CONFIG.BrainStrategyMode == "World Dominance" then
		goal = "Prepare controlled expansion"
		goalProgress = math.min(militaryScore, economyScore)
	elseif CONFIG.BrainStrategyMode == "Formable Rush" then
		goal = "Advance formable path"
		goalProgress = math.min(diplomacyScore, militaryScore)
	elseif CONFIG.BrainStrategyMode == "Defensive Survival" then
		goal = "Lower national danger"
		goalProgress = 100 - warRisk
	end

	return {
		online = true,
		country = myCountry.Name,
		leader = tostring(readObjectValue(myCountry:FindFirstChild("Leader")) or "?"),
		cities = #cities,
		funds = funds,
		net = net,
		power = power,
		wars = wars,
		threats = threats,
		confidence = confidence,
		inRecovery = inRecovery,
		guardState = guardState,
		cascade = cascade,
		recoveryProgress = recoveryProgress,
		resourceNeeds = resourceNeeds,
		starvedCount = starvedCount,
		goal = goal,
		goalProgress = clamp(goalProgress, 0, 100),
		nextAction = actions[1],
		actions = actions,
		nodes = {
			Scanner = scannerScore,
			Economy = economyScore,
			Politics = politicsScore,
			Diplomacy = diplomacyScore,
			Military = militaryScore,
			Planner = plannerScore,
			Executor = executorScore
		},
		metrics = {
			stability = stability,
			money = funds,
			net = net,
			power = power,
			resourceFlow = resourceRows,
			readiness = readiness,
			warRisk = warRisk
		}
	}
end

local function makeProgress(parent, pos, size, color)
	if Primitives and Primitives.progress then
		return Primitives.progress(parent, pos, size, color or C.green, C)
	end
	local outer = inst("Frame", {
		BackgroundColor3 = Color3.fromRGB(34, 48, 58),
		BorderSizePixel = 0,
		Position = pos,
		Size = size,
		Parent = parent
	})
	corner(outer, 4)
	local fill = inst("Frame", {
		BackgroundColor3 = color or C.green,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 0, 1, 0),
		Parent = outer
	})
	corner(fill, 4)
	return { Root = outer, Fill = fill }
end

local function attachButtonAnimation(button)
	if not button or not button.Parent then
		return button
	end

	local baseColor = button.BackgroundColor3
	local hoverColor = Color3.fromRGB(19, 58, 94)
	local pressColor = Color3.fromRGB(28, 91, 143)
	local baseText = button.TextColor3
	local hoverText = Color3.fromRGB(175, 216, 255)
	local baseSize = button.Size
	local basePosition = button.Position
	local pressSize = UDim2.new(baseSize.X.Scale, baseSize.X.Offset - 2, baseSize.Y.Scale, baseSize.Y.Offset - 2)
	local pressPosition = UDim2.new(basePosition.X.Scale, basePosition.X.Offset + 1, basePosition.Y.Scale, basePosition.Y.Offset + 1)

	trackPageConnection(button.MouseEnter:Connect(function()
		tweenObject(button, 0.16, {
			BackgroundColor3 = hoverColor,
			TextColor3 = hoverText
		})
	end))
	trackPageConnection(button.MouseLeave:Connect(function()
		tweenObject(button, 0.2, {
			BackgroundColor3 = baseColor,
			TextColor3 = baseText
		})
	end))
	trackPageConnection(button.MouseButton1Down:Connect(function()
		tweenObject(button, 0.08, {
			BackgroundColor3 = pressColor,
			Size = pressSize,
			Position = pressPosition
		}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	end))
	trackPageConnection(button.MouseButton1Up:Connect(function()
		tweenObject(button, 0.1, {
			BackgroundColor3 = hoverColor,
			Size = baseSize,
			Position = basePosition
		}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	end))

	return button
end

local function makeButton(parent, text, pos, size, callback)
	if Primitives and Primitives.button then
		return attachButtonAnimation(Primitives.button(parent, text, pos, size, callback, C, { Connections = UI.PageConnections }))
	end
	local button = inst("TextButton", {
		BackgroundColor3 = Color3.fromRGB(14, 45, 76),
		BorderSizePixel = 0,
		Position = pos,
		Size = size,
		Text = text,
		TextColor3 = Color3.fromRGB(126, 188, 255),
		TextSize = 14,
		Font = Enum.Font.GothamBold,
		Parent = parent
	})
	corner(button, 6)
	stroke(button, Color3.fromRGB(47, 111, 179), 0.15, 1)
	trackPageConnection(button.MouseButton1Click:Connect(function()
		runUICallback(callback)
	end))
	return attachButtonAnimation(button)
end

local function makeToggle(parent, y, text, value, callback)
	local row = makePanel(parent, UDim2.fromOffset(18, y), UDim2.fromOffset(470, 44), "ToggleRow")
	makeText(row, text, UDim2.fromOffset(14, 0), UDim2.fromOffset(340, 44), 14, C.text, false)
	local button = inst("TextButton", {
		BackgroundColor3 = value and C.green or Color3.fromRGB(42, 51, 61),
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(398, 11),
		Size = UDim2.fromOffset(50, 22),
		Text = value and "ON" or "OFF",
		TextColor3 = Color3.fromRGB(8, 16, 20),
		TextSize = 11,
		Font = Enum.Font.GothamBold,
		Parent = row
	})
	corner(button, 11)
	trackPageConnection(button.MouseButton1Click:Connect(function()
		value = not value
		button.BackgroundColor3 = value and C.green or Color3.fromRGB(42, 51, 61)
		button.Text = value and "ON" or "OFF"
		runUICallback(callback, value)
	end))
	return y + 52
end

local function makeDropdown(parent, y, text, values, current, callback)
	local row = makePanel(parent, UDim2.fromOffset(18, y), UDim2.fromOffset(470, 46), "DropdownRow")
	makeText(row, text, UDim2.fromOffset(14, 0), UDim2.fromOffset(170, 46), 14, C.text, false)
	local button = inst("TextButton", {
		BackgroundColor3 = Color3.fromRGB(10, 23, 34),
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(190, 8),
		Size = UDim2.fromOffset(260, 30),
		Text = tostring(current),
		TextColor3 = C.green,
		TextSize = 13,
		Font = Enum.Font.GothamBold,
		Parent = row
	})
	corner(button, 5)
	stroke(button, C.line, 0.2, 1)
	local list = inst("ScrollingFrame", {
		BackgroundColor3 = Color3.fromRGB(7, 19, 29),
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(190, 42),
		Size = UDim2.fromOffset(260, math.min(#values * 28, 168)),
		CanvasSize = UDim2.fromOffset(0, #values * 28),
		ScrollBarThickness = 3,
		Visible = false,
		ZIndex = 20,
		Parent = row
	})
	corner(list, 5)
	stroke(list, C.line, 0.15, 1)
	for i, value in ipairs(values) do
		local option = inst("TextButton", {
			BackgroundColor3 = Color3.fromRGB(7, 19, 29),
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, (i - 1) * 28),
			Size = UDim2.fromOffset(260, 28),
			Text = tostring(value),
			TextColor3 = C.text,
			TextSize = 12,
			Font = Enum.Font.Gotham,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 21,
			Parent = list
		})
		trackPageConnection(option.MouseButton1Click:Connect(function()
			current = value
			button.Text = tostring(value)
			list.Visible = false
			runUICallback(callback, value)
		end))
	end
	trackPageConnection(button.MouseButton1Click:Connect(function()
		list.Visible = not list.Visible
	end))
	return y + 54
end

local function makeSlider(parent, y, text, value, min, max, suffix, callback)
	local row = makePanel(parent, UDim2.fromOffset(18, y), UDim2.fromOffset(470, 56), "SliderRow")
	local title = makeText(row, text, UDim2.fromOffset(14, 2), UDim2.fromOffset(300, 24), 14, C.text, false)
	local valueLabel = makeText(row, tostring(value) .. (suffix or ""), UDim2.fromOffset(350, 2), UDim2.fromOffset(90, 24), 13, C.green, true)
	valueLabel.TextXAlignment = Enum.TextXAlignment.Right
	local bar = inst("Frame", {
		BackgroundColor3 = Color3.fromRGB(36, 51, 61),
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(16, 35),
		Size = UDim2.fromOffset(430, 7),
		Parent = row
	})
	corner(bar, 4)
	local fill = inst("Frame", {
		BackgroundColor3 = C.green,
		BorderSizePixel = 0,
		Parent = bar
	})
	corner(fill, 4)
	local dragging = false
	local function setFromAlpha(alpha, fire)
		alpha = clamp(alpha, 0, 1)
		local nextValue = min + (max - min) * alpha
		if max - min > 20 then
			nextValue = math.floor(nextValue + 0.5)
		else
			nextValue = math.floor(nextValue * 10 + 0.5) / 10
		end
		value = nextValue
		fill.Size = UDim2.new((value - min) / (max - min), 0, 1, 0)
		valueLabel.Text = tostring(value) .. (suffix or "")
		if fire then
			runUICallback(callback, value)
		end
	end
	setFromAlpha((value - min) / (max - min), false)
	trackPageConnection(bar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			setFromAlpha((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, true)
		end
	end))
	trackPageConnection(UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			setFromAlpha((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, true)
		end
	end))
	trackPageConnection(UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end))
	return y + 64
end

local function makeSectionTitle(parent, y, title)
	makeText(parent, title, UDim2.fromOffset(18, y), UDim2.fromOffset(470, 28), 16, C.text, true)
	return y + 34
end

local function getResourceNames()
	local list = {}
	for _, r in ipairs(Resources:GetChildren()) do
		if r:IsA("NumberValue") then
			list[#list + 1] = r.Name
		end
	end
	table.sort(list)
	return list
end

local function getBuildingNames()
	local list = {}
	for _, b in ipairs(BuildingsFolder:GetChildren()) do
		if b.Name ~= "Expand Canal" then
			list[#list + 1] = b.Name
		end
	end
	table.sort(list)
	return list
end

local function clearPage()
	if not UI.Page then return end
	disconnectConnections(UI.PageConnections)
	UI.PageConnections = {}
	resetPageAnimations()
	for _, child in ipairs(UI.Page:GetChildren()) do
		child:Destroy()
	end
end

local function makeScrollPage()
	local scroll = inst("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromOffset(0, 900),
		Position = UDim2.fromOffset(0, 0),
		ScrollBarThickness = 5,
		Size = UDim2.fromScale(1, 1),
		Parent = UI.Page
	})
	return scroll
end

local function executeBrainAction()
	local action = UI.LastAction or { id = "refresh", title = "Refresh nation scan", risk = "Low" }
	if action.id == "resupply" then
		local statuses = scanAndResupplyOnce()
		safeNotify("Nation Brain", "Resupply cycle: " .. tostring(#statuses) .. " status rows", 3)
	elseif action.id == "build" and CONFIG.AutoBuildEnabled then
		attemptAutoBuildOnce(
			BuildAttemptLabel,
			BuildCityLabel, BuildTierLabel, BuildInfraLabel,
			BuildFundsLabel, BuildQueueLabel,
			BuildCitiesCountLabel, BuildCitiesFolderLabel
		)
		safeNotify("Nation Brain", "Build planner cycle executed", 3)
	elseif action.id == "policy" then
		doAutoPolicy()
		safeNotify("Nation Brain", "Policy planner cycle executed", 3)
	elseif action.id == "trade" then
		if (UI.LastInRecovery or UI.LastGuardState) and doDebtGuardOnce then
			-- In/near debt: orchestrator picks proactive (guard) vs recovery.
			doDebtGuardOnce()
		elseif attemptOneTrade then
			-- Normal: trade cycle updates the trade status labels itself.
			attemptOneTrade(TradeStatusLabel, TradeAttemptingLabel, setTradeValidList, TradeFlowSafetyLabel)
			safeNotify("Nation Brain", "Trade cycle executed", 3)
		end
	elseif action.id == "economy" then
		-- Debt-aware: while balance < 0 you cannot BUY, so skip resupply (it
		-- buys) and only run the SELL cycle to raise the balance back to >= 0.
		-- Once out of debt, resupply becomes valid again and runs too.
		if not UI.LastInRecovery then
			scanAndResupplyOnce()
		end
		if attemptOneTrade then
			attemptOneTrade(TradeStatusLabel, TradeAttemptingLabel, setTradeValidList, TradeFlowSafetyLabel)
		end
		safeNotify("Nation Brain", UI.LastInRecovery and "Deficit relief: sold surplus (buying blocked)" or "Deficit relief cycle executed", 3)
	elseif action.id == "annex" and doAutoAnnex then
		doAutoAnnex()
		safeNotify("Nation Brain", "Annex cycle executed", 3)
	elseif action.id == "war-advisor" then
		-- Conquest advisory: justify so a CB is ready, then declare if one is.
		if doAutoJustify then doAutoJustify() end
		if doAutoDeclare then doAutoDeclare() end
		safeNotify("Nation Brain", "Conquest cycle executed", 3)
	elseif action.id == "declare" and doAutoDeclare then
		doAutoDeclare()
		safeNotify("Nation Brain", "Declare cycle executed", 3)
	elseif action.id == "promote" and doAutoPromote then
		doAutoPromote()
		safeNotify("Nation Brain", "Promote cycle executed", 3)
	else
		safeNotify("Nation Brain", tostring(action.title) .. " is advisor-only", 3)
	end
end

local function renderDashboardPage()
	clearPage()
	UI.Brain = {}
	UI.QueueRows = {}
	UI.ResourceRows = {}
	UI.Cards = {}

	local model = makePanel(UI.Page, UDim2.fromOffset(12, 10), UDim2.fromOffset(650, 475), "LiveBrainModel")
	makeText(model, "LIVE BRAIN MODEL", UDim2.fromOffset(18, 14), UDim2.fromOffset(280, 28), 15, C.text, true)
	UI.Brain.State = makeText(model, "ACTIVE", UDim2.fromOffset(560, 14), UDim2.fromOffset(70, 28), 13, C.green, true)
	UI.Brain.State.TextXAlignment = Enum.TextXAlignment.Right

	local center = inst("Frame", {
		BackgroundColor3 = Color3.fromRGB(8, 29, 52),
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(270, 195),
		Size = UDim2.fromOffset(140, 110),
		Parent = model
	})
	corner(center, 52)
	stroke(center, C.blue, 0.1, 2)
	makeText(center, "BRAIN", UDim2.fromOffset(0, 39), UDim2.fromOffset(140, 26), 20, C.blue, true).TextXAlignment = Enum.TextXAlignment.Center
	registerNode(center, center:FindFirstChildOfClass("UIStroke"), 0)
	registerOrbit(model, 340, 250, 112, 72, C.blue, 0.9, 0)
	registerOrbit(model, 340, 250, 95, 58, C.green, -0.7, 1.8)

	local points = {
		{ 24, 28 }, { 52, 18 }, { 86, 25 }, { 113, 42 }, { 102, 74 },
		{ 76, 92 }, { 40, 78 }, { 25, 55 }, { 62, 54 }, { 86, 58 }
	}
	for i = 1, #points - 1 do
		makeLine(center, points[i][1], points[i][2], points[i + 1][1], points[i + 1][2], C.blue, 1, 0.35)
	end
	for _, p in ipairs(points) do
		local dot = inst("Frame", {
			BackgroundColor3 = C.blue,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(p[1] - 2, p[2] - 2),
			Size = UDim2.fromOffset(5, 5),
			Parent = center
		})
		corner(dot, 5)
		registerPulseDot(dot, 5, 8, 2.2, p[1] * 0.05 + p[2] * 0.03)
	end

	local nodeInfo = {
		{ "Scanner", "Live Intel", 302, 58, "SCN" },
		{ "Economy", "Monitoring", 85, 145, "ECO" },
		{ "Politics", "Stability Watch", 475, 145, "POL" },
		{ "Diplomacy", "Relations Net", 55, 265, "DIP" },
		{ "Military", "Force Posture", 505, 265, "MIL" },
		{ "Planner", "Scenario Build", 165, 375, "PLN" },
		{ "Executor", "Action Control", 420, 375, "EXE" }
	}

	makeAnimatedLine(model, 340, 195, 340, 125, C.blue, 2, 0.05, 0.0)
	makeAnimatedLine(model, 270, 250, 205, 250, C.blue, 2, 0.05, 0.3)
	makeAnimatedLine(model, 410, 250, 505, 250, C.blue, 2, 0.05, 0.6)
	makeAnimatedLine(model, 306, 305, 242, 375, C.blue, 2, 0.05, 0.9)
	makeAnimatedLine(model, 385, 305, 470, 375, C.blue, 2, 0.05, 1.2)
	makeDashedLine(model, 215, 145, 302, 100, C.green)
	makeDashedLine(model, 458, 100, 540, 145, C.green)
	makeDashedLine(model, 145, 265, 166, 375, C.green)
	makeDashedLine(model, 570, 265, 510, 375, C.green)
	makeDashedLine(model, 255, 420, 420, 420, C.green)

	for _, info in ipairs(nodeInfo) do
		local name, sub, x, y, icon = info[1], info[2], info[3], info[4], info[5]
		local node = makePanel(model, UDim2.fromOffset(x, y), UDim2.fromOffset(150, 76), name .. "Node")
		node.BackgroundColor3 = Color3.fromRGB(11, 28, 35)
		stroke(node, C.green, 0.25, 1)
		makeText(node, icon, UDim2.fromOffset(12, 14), UDim2.fromOffset(42, 44), 18, C.green, true).TextXAlignment = Enum.TextXAlignment.Center
		makeText(node, name, UDim2.fromOffset(58, 10), UDim2.fromOffset(84, 22), 14, C.text, true)
		makeText(node, sub, UDim2.fromOffset(58, 33), UDim2.fromOffset(84, 18), 11, C.muted, false)
		local pct = makeText(node, "0%", UDim2.fromOffset(58, 52), UDim2.fromOffset(84, 18), 13, C.green, true)
		UI.Brain[name] = { Frame = node, Percent = pct, Stroke = node:FindFirstChildOfClass("UIStroke") }
		registerNode(node, UI.Brain[name].Stroke, x * 0.01 + y * 0.007)
	end

	makeText(model, "Data Flow", UDim2.fromOffset(230, 438), UDim2.fromOffset(95, 20), 12, C.muted, false)
	makeText(model, "Feedback Loop", UDim2.fromOffset(350, 438), UDim2.fromOffset(110, 20), 12, C.muted, false)
	makeText(model, "Priority Link", UDim2.fromOffset(490, 438), UDim2.fromOffset(105, 20), 12, C.muted, false)

	local right = makePanel(UI.Page, UDim2.fromOffset(675, 10), UDim2.fromOffset(365, 475), "RightBrainPanel")
	makeText(right, "STRATEGY MODE", UDim2.fromOffset(18, 12), UDim2.fromOffset(180, 24), 13, C.text, true)
	UI.Brain.Strategy = makeText(right, CONFIG.BrainStrategyMode, UDim2.fromOffset(18, 40), UDim2.fromOffset(320, 34), 17, C.green, true)
	makeText(right, "CURRENT GOAL", UDim2.fromOffset(18, 100), UDim2.fromOffset(180, 20), 13, C.text, true)
	UI.Brain.Goal = makeText(right, "?", UDim2.fromOffset(58, 126), UDim2.fromOffset(270, 24), 14, C.green, true)
	UI.Brain.GoalBar = makeProgress(right, UDim2.fromOffset(58, 160), UDim2.fromOffset(250, 6), C.green)
	UI.Brain.GoalValue = makeText(right, "0/100", UDim2.fromOffset(310, 150), UDim2.fromOffset(45, 24), 12, C.muted, false)
	makeText(right, "ACTION QUEUE", UDim2.fromOffset(18, 198), UDim2.fromOffset(180, 20), 13, C.text, true)
	for i = 1, 5 do
		local y = 222 + (i - 1) * 28
		makeText(right, tostring(i), UDim2.fromOffset(18, y), UDim2.fromOffset(20, 24), 12, C.muted, false)
		local rowBg = inst("Frame", {
			BackgroundColor3 = Color3.fromRGB(15, 31, 45),
			BackgroundTransparency = 0.78,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(12, y + 2),
			Size = UDim2.fromOffset(338, 22),
			ZIndex = 0,
			Parent = right
		})
		corner(rowBg, 4)
		registerQueueRow(rowBg, i)
		local title = makeText(right, "-", UDim2.fromOffset(45, y), UDim2.fromOffset(210, 24), 12, C.text, false)
		local priority = makeText(right, "-", UDim2.fromOffset(255, y), UDim2.fromOffset(58, 24), 12, C.amber, false)
		local eta = makeText(right, "-", UDim2.fromOffset(315, y), UDim2.fromOffset(42, 24), 12, C.muted, false)
		UI.QueueRows[i] = { Title = title, Priority = priority, Eta = eta }
	end
	makeText(right, "CONFIDENCE SCORE", UDim2.fromOffset(18, 370), UDim2.fromOffset(160, 22), 13, C.text, true)
	UI.Brain.Confidence = makeText(right, "0%", UDim2.fromOffset(270, 356), UDim2.fromOffset(70, 38), 28, C.green, true)
	UI.Brain.Confidence.TextXAlignment = Enum.TextXAlignment.Right
	UI.Brain.ConfidenceBar = makeProgress(right, UDim2.fromOffset(18, 400), UDim2.fromOffset(320, 8), C.green)
	UI.Brain.NextAction = makeText(right, "Next: ?", UDim2.fromOffset(18, 424), UDim2.fromOffset(225, 28), 14, C.blue, true)
	UI.Brain.NextRisk = makeText(right, "Risk: ?", UDim2.fromOffset(18, 448), UDim2.fromOffset(160, 20), 12, C.muted, false)
	makeButton(right, "Execute Now", UDim2.fromOffset(242, 430), UDim2.fromOffset(100, 34), executeBrainAction)

	local bottom = inst("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 500),
		Size = UDim2.fromOffset(1028, 125),
		Parent = UI.Page
	})
	local cards = {
		{ "Stability", "stability", C.green },
		{ "Money", "money", C.green },
		{ "Political Power", "power", C.blue },
		{ "Resource Flow", "resource", C.green },
		{ "Readiness", "readiness", C.green },
		{ "War Risk", "war", C.amber }
	}
	for i, card in ipairs(cards) do
		local w = i == 4 and 200 or 154
		local x = (i - 1) * 164
		if i >= 5 then x = x + 46 end
		local panel = makePanel(bottom, UDim2.fromOffset(x, 0), UDim2.fromOffset(w, 125), card[2] .. "Card")
		registerAnimatedCard(panel, i)
		makeText(panel, string.upper(card[1]), UDim2.fromOffset(14, 12), UDim2.fromOffset(w - 28, 18), 11, C.text, true)
		UI.Cards[card[2]] = {
			Value = makeText(panel, "?", UDim2.fromOffset(14, 40), UDim2.fromOffset(w - 28, 32), 24, card[3], true),
			Detail = makeText(panel, "?", UDim2.fromOffset(14, 82), UDim2.fromOffset(w - 28, 24), 12, card[3], false),
			Panel = panel
		}
		if card[2] ~= "resource" then
			makeLine(panel, 16, 103, 42, 92, card[3], 2, 0.1)
			makeLine(panel, 42, 92, 70, 99, card[3], 2, 0.1)
			makeLine(panel, 70, 99, 102, 88, card[3], 2, 0.1)
			makeLine(panel, 102, 88, 134, 97, card[3], 2, 0.1)
		else
			for j = 1, 5 do
				local row = makeText(panel, "-", UDim2.fromOffset(14, 33 + (j - 1) * 16), UDim2.fromOffset(w - 28, 16), 11, C.muted, false)
				UI.ResourceRows[j] = row
			end
		end
	end
end

local function renderControlPage(title, draw)
	clearPage()
	local left = makePanel(UI.Page, UDim2.fromOffset(12, 10), UDim2.fromOffset(510, 615), title .. "Controls")
	local right = makePanel(UI.Page, UDim2.fromOffset(535, 10), UDim2.fromOffset(505, 615), title .. "Status")
	makeText(left, string.upper(title), UDim2.fromOffset(18, 14), UDim2.fromOffset(450, 28), 16, C.text, true)
	makeText(right, "LIVE STATUS", UDim2.fromOffset(18, 14), UDim2.fromOffset(450, 28), 16, C.text, true)
	local controlScroll = inst("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromOffset(0, 1200),
		Position = UDim2.fromOffset(0, 52),
		ScrollBarThickness = 4,
		Size = UDim2.fromOffset(505, 550),
		Parent = left
	})
	local statusScroll = inst("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromOffset(0, 1200),
		Position = UDim2.fromOffset(0, 52),
		ScrollBarThickness = 4,
		Size = UDim2.fromOffset(500, 550),
		Parent = right
	})
	draw(controlScroll, statusScroll)
end

local function renderStrategyPage()
	renderControlPage("Strategy", function(left, right)
		local y = 0
		y = makeDropdown(left, y, "Strategy Mode", { "Economic Power", "Isolationism", "Tall Development", "World Dominance", "Formable Rush", "Defensive Survival" }, CONFIG.BrainStrategyMode, function(v)
			CONFIG.BrainStrategyMode = v
			updateBrainUI()
		end)
		y = makeToggle(left, y, "Brain Dashboard Visible", CONFIG.BrainDashboardEnabled, function(v)
			CONFIG.BrainDashboardEnabled = v
			if UI.Screen then UI.Screen.Enabled = v end
		end)
		y = makeToggle(left, y, "Auto Policy", CONFIG.AutoPolicyEnabled, function(v)
			CONFIG.AutoPolicyEnabled = v
			PolicyStatusLabel:SetText("Auto Policy: " .. (v and "Running" or "Idle"))
		end)
		y = makeSectionTitle(left, y, "Policy Selection")
		if #Policy.Info == 0 then
			makeText(left, "No policies folder found.", UDim2.fromOffset(18, y), UDim2.fromOffset(430, 24), 13, C.muted, false)
		else
			for _, policy in ipairs(Policy.Info) do
				y = makeToggle(left, y, policy.name .. " (" .. tostring(policy.cost) .. " PP)", Policy.Selected[policy.name] == true, function(v)
					Policy.Selected[policy.name] = v
				end)
			end
		end

		local sy = 0
		sy = bindStatus(right, sy, "Policy", PolicyStatusLabel)
		sy = bindStatus(right, sy, "Policies", PolicyCountLabel)
		sy = bindStatus(right, sy, "Enabled", DashAutoLabel)
		sy = bindStatus(right, sy, "Goal", DashPolicyLabel)
	end)
end

local function renderEconomyPage()
	renderControlPage("Economy", function(left, right)
		local y = 0
		y = makeToggle(left, y, "Enable Auto Trading", CONFIG.TradeEnabled, function(v)
			CONFIG.TradeEnabled = v
			TradeStatusLabel:SetText("Status: " .. (v and "Running" or "Idle"))
		end)
		y = makeDropdown(left, y, "Trade Resource", getResourceNames(), CONFIG.TradeResource, function(v)
			CONFIG.TradeResource = v
		end)
		y = makeSlider(left, y, "Trade Percent", math.floor(CONFIG.TradeTargetPercent * 100 + 0.5), 0, 80, "%", function(v)
			CONFIG.TradeTargetPercent = v / 100
		end)
		y = makeSlider(left, y, "Trade Loop Delay", CONFIG.TradeDelaySeconds, 0.1, 10, "s", function(v)
			CONFIG.TradeDelaySeconds = v
		end)
		y = makeSlider(left, y, "Trade Retry Delay", CONFIG.TradeCooldownSeconds, 10, 600, "s", function(v)
			CONFIG.TradeCooldownSeconds = v
		end)
		y = makeToggle(left, y, "Bypass Flow Safety", CONFIG.TradeBypassFlowSafety, function(v)
			CONFIG.TradeBypassFlowSafety = v
			TradeFlowSafetyLabel:SetText("Flow Safety: " .. (v and "BYPASS" or "ON"))
		end)
		y = makeSectionTitle(left, y, "Resource Automation")
		y = makeToggle(left, y, "Auto Resupply (AI only)", CONFIG.AutoResupplyEnabled, function(v)
			CONFIG.AutoResupplyEnabled = v
			AutoResupplyStatusLabel:SetText("Auto Resupply: " .. (v and "Running" or "Idle"))
		end)
		y = makeToggle(left, y, "Only Negative Flow", CONFIG.AutoResupplyOnlyNegativeFlow, function(v)
			CONFIG.AutoResupplyOnlyNegativeFlow = v
		end)
		y = makeSlider(left, y, "Max Trades Per Scan", Resupply.MaxTradesPerScan, 1, 20, "", function(v)
			Resupply.MaxTradesPerScan = v
		end)
		y = makeToggle(left, y, "Debt Guard (proactive)", CONFIG.DebtGuardEnabled, function(v)
			CONFIG.DebtGuardEnabled = v
			DebtStatusLabel:SetText("Debt Guard: " .. (v and "Running" or "Idle"))
		end)
		y = makeSlider(left, y, "Debt Guard Floor", CONFIG.DebtGuardFloor, 0, 5000000, "", function(v)
			CONFIG.DebtGuardFloor = v
		end)

		local sy = 0
		sy = bindStatus(right, sy, "Trade", TradeStatusLabel)
		sy = bindStatus(right, sy, "Country", TradeCountryLabel)
		sy = bindStatus(right, sy, "Partners", TradePartnerLabel)
		sy = bindStatus(right, sy, "Flow", TradeFlowLabel)
		sy = bindStatus(right, sy, "Income", TradeIncomeLabel)
		sy = bindStatus(right, sy, "Percent", TradePercentLabel)
		sy = bindStatus(right, sy, "Attempt", TradeAttemptingLabel)
		sy = bindStatus(right, sy, "Valid", TradeValidLabel)
		sy = bindStatus(right, sy, "List", TradeValidListLabel)
		sy = bindStatus(right, sy, "Safety", TradeFlowSafetyLabel)
		sy = bindStatus(right, sy, "Resupply", AutoResupplyStatusLabel)
		sy = bindStatus(right, sy, "Details", AutoResupplyDetailsLabel)
		sy = bindStatus(right, sy, "Debt Guard", DebtStatusLabel)
	end)
end

local function renderBuildPage()
	renderControlPage("Build", function(left, right)
		local y = 0
		y = makeToggle(left, y, "Auto Build", CONFIG.AutoBuildEnabled, function(v)
			CONFIG.AutoBuildEnabled = v
			AutoBuildStatusLabel:SetText("Auto Build: " .. (v and "Running" or "Idle"))
		end)
		y = makeDropdown(left, y, "Priority Mode", { "Selected Order", "Infrastructure First", "Develop First", "Factories First" }, CONFIG.AutoBuildPriority, function(v)
			CONFIG.AutoBuildPriority = v
		end)
		y = makeToggle(left, y, "Skip Queued Cities", CONFIG.AutoBuildSkipQueued, function(v)
			CONFIG.AutoBuildSkipQueued = v
		end)
		y = makeSectionTitle(left, y, "Buildings")
		local selectedMap = {}
		for _, name in ipairs(CONFIG.AutoBuildSelected) do
			selectedMap[name] = true
		end
		for _, buildingName in ipairs(getBuildingNames()) do
			y = makeToggle(left, y, buildingName, selectedMap[buildingName] == true, function(v)
				selectedMap[buildingName] = v
				local ordered = {}
				for _, n in ipairs(getBuildingNames()) do
					if selectedMap[n] then
						ordered[#ordered + 1] = n
					end
				end
				CONFIG.AutoBuildSelected = ordered
			end)
		end

		local sy = 0
		sy = bindStatus(right, sy, "Build", AutoBuildStatusLabel)
		sy = bindStatus(right, sy, "Cities Folder", BuildCitiesFolderLabel)
		sy = bindStatus(right, sy, "Cities Found", BuildCitiesCountLabel)
		sy = bindStatus(right, sy, "City", BuildCityLabel)
		sy = bindStatus(right, sy, "Tier", BuildTierLabel)
		sy = bindStatus(right, sy, "Infrastructure", BuildInfraLabel)
		sy = bindStatus(right, sy, "Funds", BuildFundsLabel)
		sy = bindStatus(right, sy, "Queue", BuildQueueLabel)
		sy = bindStatus(right, sy, "Attempt", BuildAttemptLabel)
	end)
end

local function renderDiplomacyPage()
	renderControlPage("Diplomacy", function(left, right)
		local y = 0
		y = makeToggle(left, y, "Auto Justify", CONFIG.AutoJustifyEnabled, function(v)
			CONFIG.AutoJustifyEnabled = v
		end)
		y = makeToggle(left, y, "AI Only", CONFIG.AutoJustifyAIOnly, function(v)
			CONFIG.AutoJustifyAIOnly = v
		end)
		y = makeToggle(left, y, "Skip Allies", CONFIG.AutoJustifySkipAllies, function(v)
			CONFIG.AutoJustifySkipAllies = v
		end)
		y = makeToggle(left, y, "Skip Countries At War", CONFIG.AutoJustifySkipWars, function(v)
			CONFIG.AutoJustifySkipWars = v
		end)
		y = makeToggle(left, y, "Require Cities", CONFIG.AutoJustifyRequireCities, function(v)
			CONFIG.AutoJustifyRequireCities = v
		end)
		y = makeSlider(left, y, "Justify Retry Delay", CONFIG.AutoJustifyRetrySeconds, 10, 300, "s", function(v)
			CONFIG.AutoJustifyRetrySeconds = v
		end)

		local sy = 0
		sy = bindStatus(right, sy, "War", WarStatusLabel)
		sy = bindStatus(right, sy, "Justify Watch", JustWatchStatusLabel)
		sy = bindStatus(right, sy, "Enabled", DashAutoLabel)
	end)
end

local function renderWarPage()
	renderControlPage("War", function(left, right)
		local y = 0
		y = makeToggle(left, y, "Auto Declare (AI only)", CONFIG.AutoDeclareEnabled, function(v)
			CONFIG.AutoDeclareEnabled = v
		end)
		y = makeToggle(left, y, "Auto Peace", CONFIG.AutoPeaceEnabled, function(v)
			CONFIG.AutoPeaceEnabled = v
		end)
		y = makeToggle(left, y, "Auto Annex (winning wars)", CONFIG.AutoAnnexEnabled, function(v)
			CONFIG.AutoAnnexEnabled = v
		end)
		y = makeSlider(left, y, "Annex Extraction", CONFIG.AutoAnnexExtractionPercent, 0, 100, "%", function(v)
			CONFIG.AutoAnnexExtractionPercent = v
		end)
		y = makeToggle(left, y, "Auto Promote Corrupt Leaders", CONFIG.AutoPromoteEnabled, function(v)
			CONFIG.AutoPromoteEnabled = v
			PromoteStatusLabel:SetText("Auto Promote: " .. (v and "Running" or "Idle"))
		end)
		y = makeToggle(left, y, "Unit Tags", CONFIG.UnitTagsEnabled, function(v)
			CONFIG.UnitTagsEnabled = v
			UnitTagsStatusLabel:SetText("Unit Tags: " .. (v and "Running" or "Idle"))
		end)

		local sy = 0
		sy = bindStatus(right, sy, "War", WarStatusLabel)
		sy = bindStatus(right, sy, "Promote", PromoteStatusLabel)
		sy = bindStatus(right, sy, "Unit Tags", UnitTagsStatusLabel)
		sy = bindStatus(right, sy, "Wars", DashWarsLabel)
		sy = bindStatus(right, sy, "War Risk", DashWarLabel)
	end)
end

local function renderWatchersPage()
	renderControlPage("Watchers", function(left, right)
		local y = 0
		y = makeToggle(left, y, "Rebel Watch", CONFIG.WatcherEnabled, function(v)
			CONFIG.WatcherEnabled = v
			WatcherStatusLabel:SetText("Rebel Watch: " .. (v and "Running" or "Idle"))
		end)
		y = makeToggle(left, y, "Justification Watch", CONFIG.JustifyWatchEnabled, function(v)
			CONFIG.JustifyWatchEnabled = v
			JustWatchStatusLabel:SetText("Justify Watch: " .. (v and "Running" or "Idle"))
		end)
		y = makeToggle(left, y, "Leader Watch", CONFIG.LeaderWatchEnabled, function(v)
			CONFIG.LeaderWatchEnabled = v
			LeaderWatchStatusLabel:SetText("Leader Watch: " .. (v and "Running" or "Idle"))
		end)
		y = makeToggle(left, y, "Notifications", CONFIG.NotificationsEnabled, function(v)
			CONFIG.NotificationsEnabled = v
		end)

		local sy = 0
		sy = bindStatus(right, sy, "Rebels", WatcherStatusLabel)
		sy = bindStatus(right, sy, "Justify", JustWatchStatusLabel)
		sy = bindStatus(right, sy, "Leaders", LeaderWatchStatusLabel)
		sy = bindStatus(right, sy, "Watcher Set", DashWatcherLabel)
	end)
end

local function renderSettingsPage()
	renderControlPage("Settings", function(left, right)
		local y = 0
		y = makeToggle(left, y, "Debug Prints", CONFIG.Debug, function(v)
			CONFIG.Debug = v
		end)
		y = makeToggle(left, y, "Notifications", CONFIG.NotificationsEnabled, function(v)
			CONFIG.NotificationsEnabled = v
		end)
		makeButton(left, "Unload Nation Brain UI", UDim2.fromOffset(18, y + 8), UDim2.fromOffset(220, 36), function()
			if _G and type(_G.RoNNationBrainCleanup) == "function" then
				_G.RoNNationBrainCleanup()
			end
		end)

		local sy = 0
		sy = bindStatus(right, sy, "Country", DashCountryLabel)
		sy = bindStatus(right, sy, "Funds", DashFundsLabel)
		sy = bindStatus(right, sy, "PP", DashPoliticalLabel)
		sy = bindStatus(right, sy, "Cities", DashCitiesLabel)
		sy = bindStatus(right, sy, "Enabled", DashAutoLabel)
	end)
end

local PageRenderers = {
	Dashboard = renderDashboardPage,
	Strategy = renderStrategyPage,
	Economy = renderEconomyPage,
	Build = renderBuildPage,
	Diplomacy = renderDiplomacyPage,
	War = renderWarPage,
	Watchers = renderWatchersPage,
	Settings = renderSettingsPage
}

local function switchTab(tab)
	UI.ActiveTab = tab
	for name, button in pairs(UI.Buttons) do
		button.BackgroundColor3 = name == tab and Color3.fromRGB(18, 38, 49) or Color3.fromRGB(8, 19, 29)
		button.TextColor3 = name == tab and C.green or C.muted
	end
	local renderer = PageRenderers[tab]
	if renderer then
		renderer()
	end
	updateBrainUI()
end

local function makeSidebarButton(name, y, label)
	local button = inst("TextButton", {
		BackgroundColor3 = Color3.fromRGB(8, 19, 29),
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.fromOffset(210, 48),
		Text = "  " .. label,
		TextColor3 = C.muted,
		TextSize = 17,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = UI.Sidebar
	})
	trackRootConnection(button.MouseButton1Click:Connect(function()
		switchTab(name)
	end))
	UI.Buttons[name] = button
	return button
end

local function makeDraggable(frame, handle)
	local dragging = false
	local dragStart
	local startPos
	trackRootConnection(handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = frame.Position
		end
	end))
	trackRootConnection(UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end))
	trackRootConnection(UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end))
end

local function createNationBrainUI()
	local old = CoreGui:FindFirstChild("RoNNationBrain")
	if old then old:Destroy() end

	UI.Screen = inst("ScreenGui", {
		Name = "RoNNationBrain",
		DisplayOrder = 100,
		Enabled = CONFIG.BrainDashboardEnabled,
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		Parent = CoreGui
	})

	UI.Root = inst("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = C.bg,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(1260, 700),
		Parent = UI.Screen
	})
	corner(UI.Root, 8)
	stroke(UI.Root, Color3.fromRGB(19, 39, 55), 0.05, 1)
	local scale = inst("UIScale", { Scale = 1, Parent = UI.Root })
	UI.Scale = scale
	pcall(function()
		local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
		if viewport then
			scale.Scale = math.min(1, viewport.X / 1300, viewport.Y / 730)
		end
	end)

	UI.Sidebar = inst("Frame", {
		BackgroundColor3 = Color3.fromRGB(8, 20, 30),
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.fromOffset(210, 700),
		Parent = UI.Root
	})
	stroke(UI.Sidebar, C.line, 0.35, 1)
	makeText(UI.Sidebar, "RoN Nation Brain", UDim2.fromOffset(18, 16), UDim2.fromOffset(175, 32), 23, C.text, true)
	makeText(UI.Sidebar, "SYSTEM ONLINE", UDim2.fromOffset(30, 50), UDim2.fromOffset(160, 24), 12, C.green, true)
	local dot = inst("Frame", { BackgroundColor3 = C.green, BorderSizePixel = 0, Position = UDim2.fromOffset(18, 59), Size = UDim2.fromOffset(8, 8), Parent = UI.Sidebar })
	corner(dot, 8)

	makeSidebarButton("Dashboard", 92, "Dashboard")
	makeSidebarButton("Strategy", 142, "Strategy")
	makeSidebarButton("Economy", 192, "Economy")
	makeSidebarButton("Build", 242, "Build")
	makeSidebarButton("Diplomacy", 292, "Diplomacy")
	makeSidebarButton("War", 342, "War")
	makeSidebarButton("Watchers", 392, "Watchers")
	makeSidebarButton("Settings", 442, "Settings")

	UI.SideCountry = makeText(UI.Sidebar, "Nation    ?", UDim2.fromOffset(18, 520), UDim2.fromOffset(174, 22), 12, C.muted, false)
	UI.SideLeader = makeText(UI.Sidebar, "Leader    ?", UDim2.fromOffset(18, 545), UDim2.fromOffset(174, 22), 12, C.muted, false)
	UI.SideRank = makeText(UI.Sidebar, "Cities    ?", UDim2.fromOffset(18, 570), UDim2.fromOffset(174, 22), 12, C.muted, false)
	UI.SideServer = makeText(UI.Sidebar, "Strategy  ?", UDim2.fromOffset(18, 595), UDim2.fromOffset(174, 22), 12, C.muted, false)
	makeText(UI.Sidebar, "v2.0.0", UDim2.fromOffset(18, 662), UDim2.fromOffset(80, 22), 11, C.muted, false)

	UI.Header = inst("Frame", {
		BackgroundColor3 = Color3.fromRGB(7, 17, 26),
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(210, 0),
		Size = UDim2.fromOffset(1050, 58),
		Parent = UI.Root
	})
	makeText(UI.Header, "Real Time", UDim2.fromOffset(820, 16), UDim2.fromOffset(90, 24), 12, C.muted, false)
	UI.Clock = makeText(UI.Header, "00:00:00 UTC", UDim2.fromOffset(910, 16), UDim2.fromOffset(120, 24), 13, C.muted, false)
	makeDraggable(UI.Root, UI.Header)

	UI.Page = inst("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(210, 58),
		Size = UDim2.fromOffset(1050, 642),
		Parent = UI.Root
	})

	switchTab("Dashboard")
	startAnimationLoop()
end

-- Dashboard labels used by the scheduler and status pages.
DashCountryLabel = wrapStatus("Country: ?")
DashFundsLabel = wrapStatus("Funds: ?")
DashPoliticalLabel = wrapStatus("Political Power: ?")
DashCitiesLabel = wrapStatus("Cities: ?")
DashTradeLabel = wrapStatus("Trade: ?")
DashFlowLabel = wrapStatus("Flow: ?")
DashWarsLabel = wrapStatus("Wars: ?")
DashAutoLabel = wrapStatus("Enabled: none")
DashWarLabel = wrapStatus("War: idle")
DashBuildLabel = wrapStatus("Build: idle")
DashResourceLabel = wrapStatus("Resources: idle")
DashWatcherLabel = wrapStatus("Watchers: idle")
DashPolicyLabel = wrapStatus("Policy: idle")

TradeStatusLabel = wrapStatus("Status: Idle")
TradeCountryLabel = wrapStatus("Country: ?")
TradePartnerLabel = wrapStatus("Partners: ?")
TradeFlowLabel = wrapStatus("Flow: ?")
TradeIncomeLabel = wrapStatus("Trade Export: ?")
TradePercentLabel = wrapStatus("Trade Percent: ?")
TradeAttemptingLabel = wrapStatus("Attempting to trade: (none)")
TradeValidLabel = wrapStatus("Valid countries: 0")
TradeValidListLabel = wrapStatus("Valid list: (none)")
TradeFlowSafetyLabel = wrapStatus("Flow Safety: ON")

WarStatusLabel = wrapStatus("Auto Wars: Idle")
PromoteStatusLabel = wrapStatus("Auto Promote: Idle")
DebtStatusLabel = wrapStatus("Debt Guard: Idle")
AutoResupplyStatusLabel = wrapStatus("Auto Resupply: Idle")
AutoResupplyDetailsLabel = wrapStatus("Resupply Details: (none)")
UnitTagsStatusLabel = wrapStatus("Unit Tags: Idle")
PolicyStatusLabel = wrapStatus("Auto Policy: Idle")
PolicyCountLabel = wrapStatus("Policies Loaded: 0")
WatcherStatusLabel = wrapStatus("Rebel Watch: Idle")
JustWatchStatusLabel = wrapStatus("Justify Watch: Idle")
LeaderWatchStatusLabel = wrapStatus("Leader Watch: Idle")

AutoBuildStatusLabel = wrapStatus("Auto Build: Idle")
BuildCitiesFolderLabel = wrapStatus("Cities Folder: ?")
BuildCitiesCountLabel = wrapStatus("Cities Found: 0")
BuildCityLabel = wrapStatus("City: ?")
BuildTierLabel = wrapStatus("Tier: ?")
BuildInfraLabel = wrapStatus("Infrastructure: ?")
BuildFundsLabel = wrapStatus("Funds: ?")
BuildQueueLabel = wrapStatus("Queue Unit: ?")
BuildAttemptLabel = wrapStatus("Build Attempt: (none)")

local function setTradeValidList(names)
	TradeValidLabel:SetText("Valid countries: " .. tostring(#names))
	local maxShow = 12
	local shown = {}
	for i = 1, math.min(#names, maxShow) do
		shown[#shown + 1] = names[i]
	end
	local suffix = ""
	if #names > maxShow then
		suffix = " ... +" .. tostring(#names - maxShow)
	end
	TradeValidListLabel:SetText(#shown == 0 and "Valid list: (none)" or ("Valid list: " .. table.concat(shown, ", ") .. suffix))
end

function updateBrainUI()
	if not UI.Screen or not UI.Screen.Parent then return end
	UI.Screen.Enabled = CONFIG.BrainDashboardEnabled
	if not CONFIG.BrainDashboardEnabled then
		return
	end
	if UI.Clock then
		UI.Clock.Text = os.date("!%H:%M:%S") .. " UTC"
	end

	local snap = buildBrainSnapshot()
	UI.LastAction = snap.nextAction
	UI.LastFunds = snap.funds
	UI.LastInRecovery = snap.inRecovery
	UI.LastGuardState = snap.guardState
	UI.LastCascade = snap.cascade
	if UI.SideCountry then
		UI.SideCountry.Text = "Nation    " .. tostring(snap.country)
		UI.SideLeader.Text = "Leader    " .. tostring(snap.leader)
		UI.SideRank.Text = "Cities    " .. tostring(snap.cities)
		UI.SideServer.Text = "Strategy  " .. tostring(CONFIG.BrainStrategyMode)
	end

	if UI.ActiveTab ~= "Dashboard" then
		return
	end

	if UI.Brain.State then
		if snap.cascade then
			-- Import-collapse cascade: deficit has canceled incoming trades and
			-- now factories are starving -> can't produce -> can't earn out.
			UI.Brain.State.Text = "CASCADE"
			UI.Brain.State.TextColor3 = C.red
		elseif snap.inRecovery then
			UI.Brain.State.Text = "RECOVERY"
			UI.Brain.State.TextColor3 = C.red
		elseif snap.guardState then
			-- Proactive: balance low + losing money, heading toward debt but
			-- not there yet. Debt Guard sells surplus gently here.
			UI.Brain.State.Text = "GUARD"
			UI.Brain.State.TextColor3 = C.amber
		else
			UI.Brain.State.Text = snap.online and "ACTIVE" or "WAITING"
			UI.Brain.State.TextColor3 = snap.online and C.green or C.amber
		end
	end
	for name, score in pairs(snap.nodes) do
		local node = UI.Brain[name]
		if node and node.Percent then
			node.Percent.Text = tostring(math.floor(score + 0.5)) .. "%"
			node.Percent.TextColor3 = scoreColor(score)
			if node.Stroke then
				node.Stroke.Color = scoreColor(score)
			end
		end
	end
	if UI.Brain.Strategy then
		UI.Brain.Strategy.Text = CONFIG.BrainStrategyMode
	end
	if UI.Brain.Goal then
		-- A deficit is an emergency that supersedes the chosen strategy goal.
		if snap.cascade then
			UI.Brain.Goal.Text = "Restart production (imports cancelled)"
		elseif snap.inRecovery then
			UI.Brain.Goal.Text = "Recover economy (deficit)"
		else
			UI.Brain.Goal.Text = snap.goal
		end
	end
	if UI.Brain.GoalBar then
		setBar(UI.Brain.GoalBar, snap.inRecovery and snap.recoveryProgress or snap.goalProgress)
		-- Flag the bar red during the cascade, amber during plain recovery.
		if UI.Brain.GoalBar.Fill then
			UI.Brain.GoalBar.Fill.BackgroundColor3 = snap.cascade and C.red or (snap.inRecovery and C.amber or C.green)
		end
	end
	if UI.Brain.GoalValue then
		local gp = snap.inRecovery and snap.recoveryProgress or snap.goalProgress
		UI.Brain.GoalValue.Text = tostring(math.floor(gp + 0.5)) .. "/100"
	end
	for i = 1, 5 do
		local row = UI.QueueRows[i]
		local action = snap.actions[i]
		if row then
			row.Title.Text = action and action.title or "-"
			row.Priority.Text = action and action.priority or "-"
			row.Priority.TextColor3 = action and (action.priority == "High" and C.amber or action.priority == "Low" and C.blue or C.green) or C.muted
			row.Eta.Text = action and action.eta or "-"
		end
	end
	if UI.Brain.Confidence then
		UI.Brain.Confidence.Text = tostring(math.floor(snap.confidence + 0.5)) .. "%"
		UI.Brain.Confidence.TextColor3 = scoreColor(snap.confidence)
	end
	if UI.Brain.ConfidenceBar then
		UI.Brain.ConfidenceBar.Fill.BackgroundColor3 = scoreColor(snap.confidence)
		setBar(UI.Brain.ConfidenceBar, snap.confidence)
	end
	if UI.Brain.NextAction then
		local suffix = ""
		if snap.cascade then
			-- Show which resources the cancelled imports have starved.
			local needs = snap.resourceNeeds or {}
			local parts = {}
			for name, need in pairs(needs) do
				parts[#parts + 1] = tostring(name) .. " " .. tostring(math.floor(tonumber(need) or 0))
			end
			if #parts > 0 then
				suffix = "  |  Starved: " .. table.concat(parts, ", ")
			end
		end
		UI.Brain.NextAction.Text = "Next: " .. tostring(snap.nextAction.title) .. suffix
	end
	if UI.Brain.NextRisk then
		UI.Brain.NextRisk.Text = "ETA: " .. tostring(snap.nextAction.eta) .. "  |  Risk: " .. tostring(snap.nextAction.risk)
	end

	local cards = UI.Cards
	if cards.stability then
		cards.stability.Value.Text = snap.metrics.stability and (tostring(math.floor(snap.metrics.stability + 0.5)) .. "%") or "?"
		cards.stability.Detail.Text = snap.metrics.stability and (snap.metrics.stability >= 70 and "Stable" or "Needs work") or "Unknown"
	end
	if cards.money then
		cards.money.Value.Text = "$ " .. formatMoney(snap.metrics.money)
		cards.money.Detail.Text = snap.metrics.net and ("Net: $" .. formatMoney(snap.metrics.net) .. "/h") or "Net: ?"
	end
	if cards.power then
		cards.power.Value.Text = tostring(math.floor((snap.metrics.power or 0) + 0.5))
		cards.power.Detail.Text = "Political power"
	end
	if cards.resource then
		cards.resource.Value.Text = "Flow"
		cards.resource.Detail.Text = "Top resources"
		for i = 1, 5 do
			local row = UI.ResourceRows[i]
			local res = snap.metrics.resourceFlow[i]
			if row then
				if res then
					row.Text = res.name .. "  " .. tostring(math.floor(res.flow * 10 + 0.5) / 10) .. "/h"
					row.TextColor3 = res.flow < 0 and C.red or C.green
				else
					row.Text = "-"
					row.TextColor3 = C.muted
				end
			end
		end
	end
	if cards.readiness then
		cards.readiness.Value.Text = snap.metrics.readiness and (tostring(math.floor(snap.metrics.readiness + 0.5)) .. "%") or "?"
		cards.readiness.Detail.Text = snap.metrics.readiness and (snap.metrics.readiness >= 70 and "High" or "Low") or "Unknown"
	end
	if cards.war then
		cards.war.Value.Text = tostring(math.floor((snap.metrics.warRisk or 0) + 0.5)) .. "%"
		cards.war.Value.TextColor3 = scoreColor(100 - (snap.metrics.warRisk or 0))
		cards.war.Detail.Text = snap.metrics.warRisk >= 50 and "High" or "Low"
	end
end

local function updateDashboard()
	local ok, myCountry = assertStillLeader()
	if ok then
		local cities = getAllMyCitiesSorted()
		local funds, source = getMyFunds()
		local power = getPolicyPower(myCountry)
		local flow = getCountryResourceFlow(myCountry, CONFIG.TradeResource)
		local tradeCount = getTradeCount(myCountry, CONFIG.TradeResource)

		DashCountryLabel:SetText("Country: " .. myCountry.Name)
		DashFundsLabel:SetText("Funds: " .. tostring(funds) .. " (" .. tostring(source) .. ")")
		DashPoliticalLabel:SetText("Political Power: " .. tostring(power))
		DashCitiesLabel:SetText("Cities: " .. tostring(#cities))
		DashTradeLabel:SetText("Trade: " .. tostring(tradeCount) .. " " .. tostring(CONFIG.TradeResource))
		DashFlowLabel:SetText("Flow: " .. tostring(flow))
		DashWarsLabel:SetText("Wars: " .. tostring(countMyWars(myCountry.Name)))
	else
		DashCountryLabel:SetText("Country: (not leader)")
		DashFundsLabel:SetText("Funds: ?")
		DashPoliticalLabel:SetText("Political Power: ?")
		DashCitiesLabel:SetText("Cities: ?")
		DashTradeLabel:SetText("Trade: ?")
		DashFlowLabel:SetText("Flow: ?")
		DashWarsLabel:SetText("Wars: ?")
	end

	DashAutoLabel:SetText("Enabled: " .. joinEnabled({
		{ name = "Trade", on = CONFIG.TradeEnabled },
		{ name = "War", on = CONFIG.AutoJustifyEnabled or CONFIG.AutoDeclareEnabled or CONFIG.AutoPeaceEnabled },
		{ name = "Build", on = CONFIG.AutoBuildEnabled },
		{ name = "Resources", on = CONFIG.AutoResupplyEnabled or CONFIG.UnitTagsEnabled },
		{ name = "Policies", on = CONFIG.AutoPolicyEnabled },
		{ name = "Watchers", on = CONFIG.WatcherEnabled or CONFIG.JustifyWatchEnabled or CONFIG.LeaderWatchEnabled }
	}))
	DashWarLabel:SetText("War: " .. tostring(War.LastStatus))
	DashBuildLabel:SetText("Build: " .. (CONFIG.AutoBuildEnabled and "running" or "idle"))
	DashResourceLabel:SetText("Resources: " .. joinEnabled({
		{ name = "Resupply", on = CONFIG.AutoResupplyEnabled },
		{ name = "Tags", on = CONFIG.UnitTagsEnabled }
	}))
	DashWatcherLabel:SetText("Watchers: " .. joinEnabled({
		{ name = "Rebel", on = CONFIG.WatcherEnabled },
		{ name = "Justify", on = CONFIG.JustifyWatchEnabled },
		{ name = "Leader", on = CONFIG.LeaderWatchEnabled }
	}))
	DashPolicyLabel:SetText("Policy: " .. tostring(Policy.LastStatus))
	updateBrainUI()
end

installGlobalCleanup()
buildPolicyInfo()
PolicyCountLabel:SetText("Policies Loaded: " .. tostring(#Policy.Info))
createNationBrainUI()

trackRootConnection(UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.RightShift then
		CONFIG.BrainDashboardEnabled = not CONFIG.BrainDashboardEnabled
		if UI.Screen then
			UI.Screen.Enabled = CONFIG.BrainDashboardEnabled
		end
	end
end))

--============================================================

	return {
		UI = UI,
		Status = {
			DashCountryLabel = DashCountryLabel,
			DashFundsLabel = DashFundsLabel,
			DashPoliticalLabel = DashPoliticalLabel,
			DashCitiesLabel = DashCitiesLabel,
			DashTradeLabel = DashTradeLabel,
			DashFlowLabel = DashFlowLabel,
			DashWarsLabel = DashWarsLabel,
			DashAutoLabel = DashAutoLabel,
			DashWarLabel = DashWarLabel,
			DashBuildLabel = DashBuildLabel,
			DashResourceLabel = DashResourceLabel,
			DashWatcherLabel = DashWatcherLabel,
			DashPolicyLabel = DashPolicyLabel,
			TradeStatusLabel = TradeStatusLabel,
			TradeCountryLabel = TradeCountryLabel,
			TradePartnerLabel = TradePartnerLabel,
			TradeFlowLabel = TradeFlowLabel,
			TradeIncomeLabel = TradeIncomeLabel,
			TradePercentLabel = TradePercentLabel,
			TradeAttemptingLabel = TradeAttemptingLabel,
			TradeValidLabel = TradeValidLabel,
			TradeValidListLabel = TradeValidListLabel,
			TradeFlowSafetyLabel = TradeFlowSafetyLabel,
			WarStatusLabel = WarStatusLabel,
			PromoteStatusLabel = PromoteStatusLabel,
			DebtStatusLabel = DebtStatusLabel,
			AutoResupplyStatusLabel = AutoResupplyStatusLabel,
			AutoResupplyDetailsLabel = AutoResupplyDetailsLabel,
			UnitTagsStatusLabel = UnitTagsStatusLabel,
			PolicyStatusLabel = PolicyStatusLabel,
			PolicyCountLabel = PolicyCountLabel,
			WatcherStatusLabel = WatcherStatusLabel,
			JustWatchStatusLabel = JustWatchStatusLabel,
			LeaderWatchStatusLabel = LeaderWatchStatusLabel,
			AutoBuildStatusLabel = AutoBuildStatusLabel,
			BuildCitiesFolderLabel = BuildCitiesFolderLabel,
			BuildCitiesCountLabel = BuildCitiesCountLabel,
			BuildCityLabel = BuildCityLabel,
			BuildTierLabel = BuildTierLabel,
			BuildInfraLabel = BuildInfraLabel,
			BuildFundsLabel = BuildFundsLabel,
			BuildQueueLabel = BuildQueueLabel,
			BuildAttemptLabel = BuildAttemptLabel
		},
		setTradeValidList = setTradeValidList,
		updateDashboard = updateDashboard,
		updateBrainUI = updateBrainUI,
		createNationBrainUI = createNationBrainUI
	}
end

return BrainUI
