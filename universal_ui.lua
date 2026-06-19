-- Universal Roblox UI Library
-- Pull from: https://raw.githubusercontent.com/tetizz/roblox-stuff/main/universal_ui.lua

local UniversalUI = {}

UniversalUI.Name = "Universal UI"
UniversalUI.Version = "2026-06-19.5"

UniversalUI.Themes = {
	Default = {
		bg = Color3.fromRGB(5, 14, 23),
		panel = Color3.fromRGB(9, 23, 34),
		panel2 = Color3.fromRGB(12, 28, 41),
		panel3 = Color3.fromRGB(15, 36, 52),
		line = Color3.fromRGB(41, 62, 76),
		lineBright = Color3.fromRGB(72, 130, 181),
		text = Color3.fromRGB(218, 226, 235),
		muted = Color3.fromRGB(143, 153, 166),
		green = Color3.fromRGB(119, 218, 88),
		blue = Color3.fromRGB(58, 157, 255),
		amber = Color3.fromRGB(255, 177, 50),
		red = Color3.fromRGB(235, 91, 74),
		dark = Color3.fromRGB(4, 10, 16)
	},
	NationBrain = {
		bg = Color3.fromRGB(5, 14, 23),
		panel = Color3.fromRGB(9, 23, 34),
		panel2 = Color3.fromRGB(12, 28, 41),
		panel3 = Color3.fromRGB(15, 36, 52),
		line = Color3.fromRGB(41, 62, 76),
		lineBright = Color3.fromRGB(72, 130, 181),
		text = Color3.fromRGB(218, 226, 235),
		muted = Color3.fromRGB(143, 153, 166),
		green = Color3.fromRGB(119, 218, 88),
		blue = Color3.fromRGB(58, 157, 255),
		amber = Color3.fromRGB(255, 177, 50),
		red = Color3.fromRGB(235, 91, 74),
		dark = Color3.fromRGB(4, 10, 16)
	}
}

local function shallowCopy(source)
	local copy = {}
	for key, value in pairs(source or {}) do
		copy[key] = value
	end
	return copy
end

local function mergeTheme(base, override)
	local theme = shallowCopy(base or UniversalUI.Themes.Default)
	for key, value in pairs(override or {}) do
		theme[key] = value
	end
	return theme
end

local function clamp(value, minValue, maxValue)
	value = tonumber(value) or 0
	if value < minValue then return minValue end
	if value > maxValue then return maxValue end
	return value
end

local function sanitizeKey(text)
	text = tostring(text or "UniversalUI")
	text = text:gsub("[^%w_]", "_")
	if text == "" then
		return "UniversalUI"
	end
	return text
end

local function inst(className, props)
	local obj = Instance.new(className)
	for key, value in pairs(props or {}) do
		local ok = pcall(function()
			obj[key] = value
		end)
		if not ok then
			warn("[UniversalUI] invalid property:", tostring(className), tostring(key))
		end
	end
	return obj
end

local function corner(parent, radius)
	return inst("UICorner", {
		CornerRadius = UDim.new(0, radius or 8),
		Parent = parent
	})
end

local function stroke(parent, color, transparency, thickness)
	return inst("UIStroke", {
		Color = color or UniversalUI.Themes.Default.line,
		Transparency = transparency or 0.25,
		Thickness = thickness or 1,
		Parent = parent
	})
end

local function gradient(parent, a, b, rotation)
	return inst("UIGradient", {
		Color = ColorSequence.new(a, b),
		Rotation = rotation or 90,
		Parent = parent
	})
end

local function text(parent, value, pos, size, fontSize, color, bold)
	local label = inst("TextLabel", {
		BackgroundTransparency = 1,
		Position = pos or UDim2.fromOffset(0, 0),
		Size = size or UDim2.fromOffset(100, 24),
		Text = tostring(value or ""),
		TextColor3 = color or UniversalUI.Themes.Default.text,
		TextSize = fontSize or 13,
		Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextWrapped = true,
		Parent = parent
	})
	return label
end

local function panel(parent, pos, size, name, theme)
	theme = theme or UniversalUI.Themes.Default
	local frame = inst("Frame", {
		Name = name or "Panel",
		BackgroundColor3 = theme.panel,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		Position = pos or UDim2.fromOffset(0, 0),
		Size = size or UDim2.fromOffset(100, 100),
		Parent = parent
	})
	corner(frame, 8)
	stroke(frame, theme.line, 0.25, 1)
	gradient(frame, theme.panel2, theme.bg, 90)
	return frame
end

local function line(parent, x1, y1, x2, y2, color, thickness, transparency)
	local dx = x2 - x1
	local dy = y2 - y1
	local length = math.sqrt(dx * dx + dy * dy)
	return inst("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = color or UniversalUI.Themes.Default.blue,
		BackgroundTransparency = transparency or 0.15,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset((x1 + x2) / 2, (y1 + y2) / 2),
		Rotation = math.deg(math.atan2(dy, dx)),
		Size = UDim2.fromOffset(length, thickness or 2),
		Parent = parent
	})
end

local function dashedLine(parent, x1, y1, x2, y2, color, parts)
	parts = parts or 14
	for i = 0, parts - 1, 2 do
		local a = i / parts
		local b = math.min((i + 1) / parts, 1)
		line(
			parent,
			x1 + (x2 - x1) * a,
			y1 + (y2 - y1) * a,
			x1 + (x2 - x1) * b,
			y1 + (y2 - y1) * b,
			color or UniversalUI.Themes.Default.green,
			2,
			0.15
		)
	end
end

local function progress(parent, pos, size, color, theme)
	theme = theme or UniversalUI.Themes.Default
	local outer = inst("Frame", {
		BackgroundColor3 = Color3.fromRGB(34, 48, 58),
		BorderSizePixel = 0,
		Position = pos or UDim2.fromOffset(0, 0),
		Size = size or UDim2.fromOffset(100, 8),
		Parent = parent
	})
	corner(outer, 4)
	local fill = inst("Frame", {
		BackgroundColor3 = color or theme.green,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 0, 1, 0),
		Parent = outer
	})
	corner(fill, 4)
	local obj = {
		Root = outer,
		Fill = fill,
		Value = 0
	}
	function obj:Set(value)
		self.Value = clamp(value, 0, 100)
		self.Fill.Size = UDim2.new(self.Value / 100, 0, 1, 0)
	end
	return obj
end

local function button(parent, value, pos, size, callback, theme, owner)
	theme = theme or UniversalUI.Themes.Default
	local btn = inst("TextButton", {
		BackgroundColor3 = Color3.fromRGB(14, 45, 76),
		BorderSizePixel = 0,
		Position = pos or UDim2.fromOffset(0, 0),
		Size = size or UDim2.fromOffset(120, 32),
		Text = tostring(value or "Button"),
		TextColor3 = Color3.fromRGB(126, 188, 255),
		TextSize = 13,
		Font = Enum.Font.GothamBold,
		AutoButtonColor = false,
		Parent = parent
	})
	corner(btn, 6)
	stroke(btn, theme.lineBright, 0.15, 1)
	if callback then
		local conn = btn.MouseButton1Click:Connect(function()
			local ok, err = pcall(callback)
			if not ok then
				warn("[UniversalUI] button callback failed:", tostring(err))
			end
		end)
		if owner and owner.Connections then
			owner.Connections[#owner.Connections + 1] = conn
		end
	end
	return btn
end

local function safeCall(label, callback, ...)
	if not callback then
		return true
	end
	if type(callback) ~= "function" then
		return false, "callback missing"
	end
	local args = { ... }
	local ok, err = pcall(function()
		return callback(unpack(args))
	end)
	if not ok then
		warn("[UniversalUI]", tostring(label or "callback"), tostring(err))
	end
	return ok, err
end

local function runCallback(callback, ...)
	return safeCall("callback failed:", callback, ...)
end

local function safeFireServer(label, remote, ...)
	if not remote or type(remote.FireServer) ~= "function" then
		warn("[UniversalUI]", tostring(label or "remote"), "missing FireServer")
		return false, "missing FireServer"
	end
	local args = { ... }
	local ok, err = pcall(function()
		remote:FireServer(unpack(args))
	end)
	if not ok then
		warn("[UniversalUI]", tostring(label or "remote"), tostring(err))
	end
	return ok, err
end

local function safeInvokeServer(label, remote, ...)
	if not remote or type(remote.InvokeServer) ~= "function" then
		warn("[UniversalUI]", tostring(label or "remote"), "missing InvokeServer")
		return false, "missing InvokeServer"
	end
	local args = { ... }
	local results = { pcall(function()
		return remote:InvokeServer(unpack(args))
	end) }
	if not results[1] then
		warn("[UniversalUI]", tostring(label or "remote"), tostring(results[2]))
	end
	return unpack(results)
end

local function disconnectConnections(list)
	for _, conn in ipairs(list or {}) do
		if conn and conn.Disconnect then
			pcall(function()
				conn:Disconnect()
			end)
		end
	end
end

local function resolveParent(parent)
	if parent then
		return parent
	end
	if type(gethui) == "function" then
		local ok, hui = pcall(gethui)
		if ok and hui then
			return hui
		end
	end
	local okCore, coreGui = pcall(function()
		return game:GetService("CoreGui")
	end)
	if okCore and coreGui then
		return coreGui
	end
	local players = game:GetService("Players")
	local localPlayer = players.LocalPlayer
	return localPlayer and localPlayer:WaitForChild("PlayerGui")
end

UniversalUI.Primitives = {
	inst = inst,
	corner = corner,
	stroke = stroke,
	gradient = gradient,
	text = text,
	panel = panel,
	line = line,
	dashedLine = dashedLine,
	progress = progress,
	button = button,
	clamp = clamp,
	mergeTheme = mergeTheme,
	disconnectConnections = disconnectConnections,
	safeCall = safeCall,
	safeFireServer = safeFireServer,
	safeInvokeServer = safeInvokeServer
}

local function makeStatus(initial)
	local obj = {
		Text = tostring(initial or ""),
		Label = nil
	}
	function obj:SetText(value)
		self.Text = tostring(value or "")
		if self.Label and self.Label.Parent then
			self.Label.Text = self.Text
		end
	end
	return obj
end

local WindowMethods = {}
local TabMethods = {}
local SectionMethods = {}
local RuntimeMethods = {}

local function track(window, conn)
	window.Connections[#window.Connections + 1] = conn
	return conn
end

function RuntimeMethods:Track(conn)
	self.Connections[#self.Connections + 1] = conn
	return conn
end

function RuntimeMethods:DisconnectAll()
	disconnectConnections(self.Connections)
	self.Connections = {}
end

function RuntimeMethods:Destroy()
	self.Alive = false
	for _, token in ipairs(self.Tasks) do
		token.Alive = false
	end
	self.Tasks = {}
	self:DisconnectAll()
	if _G and self.CleanupKey and _G[self.CleanupKey] == self.DestroyCallback then
		_G[self.CleanupKey] = nil
	end
end

function RuntimeMethods:Every(key, interval, callback)
	if not self.Alive then
		return false
	end
	local t = os.clock()
	key = tostring(key or "loop")
	interval = tonumber(interval) or 1
	local last = self.Last[key]
	if last and (t - last) < interval then
		return false
	end
	self.Last[key] = t

	local ok, err
	if type(callback) == "function" then
		ok, err = pcall(callback, self)
	else
		ok, err = false, "callback missing"
	end
	if ok then
		self.Errors[key] = 0
		return true
	end

	self.Errors[key] = (self.Errors[key] or 0) + 1
	local lastWarn = self.LastWarn[key] or 0
	if (t - lastWarn) >= self.ErrorCooldown then
		self.LastWarn[key] = t
		warn("[UniversalUI Runtime]", self.Name, key, tostring(err))
	end
	return false, err
end

local function removeRuntimeTask(runtime, token)
	for i = #runtime.Tasks, 1, -1 do
		if runtime.Tasks[i] == token then
			table.remove(runtime.Tasks, i)
			return
		end
	end
end

function RuntimeMethods:Delay(seconds, callback)
	local token = { Alive = true }
	self.Tasks[#self.Tasks + 1] = token
	task.delay(tonumber(seconds) or 0, function()
		if self.Alive and token.Alive then
			safeCall(self.Name .. ".delay", callback, self)
		end
		token.Alive = false
		removeRuntimeTask(self, token)
	end)
	return function()
		token.Alive = false
		removeRuntimeTask(self, token)
	end
end

function RuntimeMethods:Spawn(callback)
	local token = { Alive = true }
	self.Tasks[#self.Tasks + 1] = token
	task.spawn(function()
		if self.Alive and token.Alive then
			safeCall(self.Name .. ".spawn", callback, self)
		end
		token.Alive = false
		removeRuntimeTask(self, token)
	end)
	return function()
		token.Alive = false
		removeRuntimeTask(self, token)
	end
end

function UniversalUI.createRuntime(options)
	options = options or {}
	local name = tostring(options.Name or "UniversalRuntime")
	local cleanupKey = "_UniversalRuntime_" .. sanitizeKey(options.CleanupKey or name)

	if _G and type(_G[cleanupKey]) == "function" then
		pcall(_G[cleanupKey])
	end

	local runtime = setmetatable({
		Name = name,
		Alive = true,
		Connections = {},
		Tasks = {},
		Last = {},
		Errors = {},
		LastWarn = {},
		ErrorCooldown = tonumber(options.ErrorCooldown) or 10,
		CleanupKey = cleanupKey,
		DestroyCallback = nil
	}, { __index = RuntimeMethods })

	runtime.DestroyCallback = function()
		runtime:Destroy()
	end
	if _G then
		_G[cleanupKey] = runtime.DestroyCallback
	end
	return runtime
end

local function updateScrollCanvas(tab)
	if not tab.Page or not tab.Layout then
		return
	end
	local height = tab.Layout.AbsoluteContentSize.Y + 18
	tab.Page.CanvasSize = UDim2.fromOffset(0, math.max(height, tab.Page.AbsoluteSize.Y))
end

local function setButtonSelected(btn, selected, theme)
	btn.BackgroundColor3 = selected and Color3.fromRGB(18, 44, 57) or Color3.fromRGB(9, 20, 30)
	btn.TextColor3 = selected and theme.green or theme.muted
	local marker = btn:FindFirstChild("Marker")
	if marker then
		marker.Visible = selected
	end
end

local function makeDraggable(window, handle)
	local dragging = false
	local dragStart
	local startPos
	track(window, handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = window.Root.Position
		end
	end))
	track(window, game:GetService("UserInputService").InputChanged:Connect(function(input)
		if not dragging then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local delta = input.Position - dragStart
		window.Root.Position = UDim2.new(
			startPos.X.Scale,
			startPos.X.Offset + delta.X,
			startPos.Y.Scale,
			startPos.Y.Offset + delta.Y
		)
	end))
	track(window, game:GetService("UserInputService").InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end))
end

function WindowMethods:Destroy()
	if _G and self.CleanupKey and _G[self.CleanupKey] == self.DestroyCallback then
		_G[self.CleanupKey] = nil
	end
	disconnectConnections(self.Connections)
	self.Connections = {}
	if self.Screen and self.Screen.Parent then
		self.Screen:Destroy()
	end
end

function WindowMethods:Show()
	self.Screen.Enabled = true
end

function WindowMethods:Hide()
	self.Screen.Enabled = false
end

function WindowMethods:Toggle()
	self.Screen.Enabled = not self.Screen.Enabled
end

function WindowMethods:SetTitle(title, subtitle)
	if self.TitleLabel then
		self.TitleLabel.Text = tostring(title or self.Title or "Universal UI")
	end
	if subtitle and self.SubtitleLabel then
		self.SubtitleLabel.Text = tostring(subtitle)
	end
end

function WindowMethods:SetStatus(textValue, color)
	if self.StatusLabel then
		self.StatusLabel.Text = tostring(textValue or "")
		if color then
			self.StatusLabel.TextColor3 = color
		end
	end
end

function WindowMethods:Notify(titleValue, bodyValue, duration)
	if type(titleValue) == "table" then
		local opts = titleValue
		titleValue = opts.Title or opts.title or "Notice"
		bodyValue = opts.Description or opts.Text or opts.Body or opts.description or opts.text or opts.body or ""
		duration = opts.Time or opts.Duration or opts.time or opts.duration or duration
	end
	local theme = self.Theme
	local toast = panel(
		self.Root,
		UDim2.new(1, -290, 0, 58),
		UDim2.fromOffset(260, 76),
		"Toast",
		theme
	)
	toast.ZIndex = 70
	text(toast, titleValue or "Notice", UDim2.fromOffset(12, 8), UDim2.fromOffset(236, 22), 13, theme.text, true).ZIndex = 71
	text(toast, bodyValue or "", UDim2.fromOffset(12, 30), UDim2.fromOffset(236, 34), 12, theme.muted, false).ZIndex = 71
	task.delay(duration or 3, function()
		if toast and toast.Parent then
			toast:Destroy()
		end
	end)
	return toast
end

function WindowMethods:SelectTab(name)
	for _, tab in ipairs(self.Tabs) do
		local selected = tab.Name == name
		tab.Page.Visible = selected
		setButtonSelected(tab.Button, selected, self.Theme)
		if selected then
			self.ActiveTab = tab
			updateScrollCanvas(tab)
		end
	end
end

function WindowMethods:AddTab(name, icon)
	local theme = self.Theme
	local tab = setmetatable({
		Name = tostring(name or ("Tab " .. tostring(#self.Tabs + 1))),
		Icon = tostring(icon or ""),
		Window = self,
		Sections = {}
	}, { __index = TabMethods })

	local tabText = tab.Icon ~= "" and (tab.Icon .. "  " .. tab.Name) or tab.Name
	local btn = inst("TextButton", {
		BackgroundColor3 = Color3.fromRGB(9, 20, 30),
		BorderSizePixel = 0,
		Size = UDim2.new(1, -18, 0, 42),
		Text = tabText,
		TextColor3 = theme.muted,
		TextSize = 14,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		AutoButtonColor = false,
		Parent = self.TabList
	})
	corner(btn, 6)
	local marker = inst("Frame", {
		Name = "Marker",
		BackgroundColor3 = theme.green,
		BorderSizePixel = 0,
		Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.new(0, 4, 1, -8),
		Visible = false,
		Parent = btn
	})
	corner(marker, 4)
	tab.Button = btn

	local page = inst("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromOffset(0, 0),
		ScrollBarImageColor3 = theme.lineBright,
		ScrollBarThickness = 4,
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Parent = self.PageHost
	})
	local layout = inst("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = page
	})
	inst("UIPadding", {
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 12),
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
		Parent = page
	})
	tab.Page = page
	tab.Layout = layout
	track(self, layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		updateScrollCanvas(tab)
	end))
	track(self, btn.MouseButton1Click:Connect(function()
		self:SelectTab(tab.Name)
	end))

	self.Tabs[#self.Tabs + 1] = tab
	self.TabByName[tab.Name] = tab
	if not self.ActiveTab then
		self:SelectTab(tab.Name)
	end
	return tab
end

function TabMethods:AddSection(title, options)
	options = options or {}
	local theme = self.Window.Theme
	local section = setmetatable({
		Tab = self,
		Window = self.Window,
		Theme = theme,
		NextY = 46,
		Controls = {}
	}, { __index = SectionMethods })
	local frame = panel(self.Page, UDim2.fromOffset(0, 0), UDim2.new(1, -8, 0, 58), title or "Section", theme)
	frame.LayoutOrder = #self.Sections + 1
	frame.ClipsDescendants = false
	text(frame, string.upper(tostring(title or "Section")), UDim2.fromOffset(16, 12), UDim2.new(1, -32, 0, 22), 13, theme.text, true)
	section.Frame = frame
	self.Sections[#self.Sections + 1] = section
	updateScrollCanvas(self)
	return section
end

function SectionMethods:_resize()
	self.Frame.Size = UDim2.new(1, -8, 0, self.NextY + 12)
	updateScrollCanvas(self.Tab)
end

function SectionMethods:_row(height, name)
	local row = inst("Frame", {
		Name = name or "Row",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		Position = UDim2.fromOffset(16, self.NextY),
		Size = UDim2.new(1, -32, 0, height),
		Parent = self.Frame
	})
	self.NextY = self.NextY + height + 8
	self:_resize()
	return row
end

function SectionMethods:AddLabel(value, color)
	local row = self:_row(24, "LabelRow")
	local label = text(row, value or "", UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 24), 13, color or self.Theme.text, false)
	return label
end

function SectionMethods:AddParagraph(value)
	local row = self:_row(52, "ParagraphRow")
	local label = text(row, value or "", UDim2.fromOffset(0, 0), UDim2.new(1, 0, 1, 0), 12, self.Theme.muted, false)
	label.TextYAlignment = Enum.TextYAlignment.Top
	return label
end

function SectionMethods:AddDivider()
	local row = self:_row(12, "DividerRow")
	local bar = inst("Frame", {
		BackgroundColor3 = self.Theme.line,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.new(1, 0, 0, 1),
		Parent = row
	})
	return bar
end

function SectionMethods:AddStatus(titleValue, initial)
	local theme = self.Theme
	local row = self:_row(28, "StatusRow")
	text(row, titleValue or "Status", UDim2.fromOffset(0, 0), UDim2.new(0.38, 0, 1, 0), 12, theme.muted, true)
	local label = text(row, initial or "", UDim2.new(0.38, 8, 0, 0), UDim2.new(0.62, -8, 1, 0), 12, theme.text, false)
	local status = makeStatus(initial)
	status.Label = label
	return status
end

function SectionMethods:AddButton(titleValue, callback)
	local theme = self.Theme
	local row = self:_row(36, "ButtonRow")
	local btn = button(row, titleValue or "Run", UDim2.fromOffset(0, 0), UDim2.new(1, 0, 1, 0), callback, theme, self.Window)
	self.Controls[#self.Controls + 1] = btn
	return btn
end

function SectionMethods:AddTextBox(titleValue, initial, placeholder, callback)
	local theme = self.Theme
	local row = self:_row(48, "TextBoxRow")
	text(row, titleValue or "Text", UDim2.fromOffset(0, 0), UDim2.new(0.42, -8, 1, 0), 13, theme.text, false)
	local box = inst("TextBox", {
		BackgroundColor3 = Color3.fromRGB(10, 24, 36),
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		PlaceholderText = tostring(placeholder or ""),
		Position = UDim2.new(0.42, 0, 0, 8),
		Size = UDim2.new(0.58, 0, 0, 30),
		Text = tostring(initial or ""),
		TextColor3 = theme.text,
		TextSize = 12,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row
	})
	corner(box, 5)
	stroke(box, theme.line, 0.15, 1)

	local control = {
		Text = box.Text,
		Callbacks = {}
	}
	local function apply(value, fire, enterPressed)
		box.Text = tostring(value or "")
		control.Text = box.Text
		if fire then
			runCallback(callback, box.Text, enterPressed)
			for _, fn in ipairs(control.Callbacks) do
				runCallback(fn, box.Text, enterPressed)
			end
		end
	end
	function control:Set(value)
		apply(value, false)
	end
	function control:SetText(value)
		apply(value, false)
	end
	function control:Get()
		return box.Text
	end
	function control:OnChanged(fn)
		if type(fn) == "function" then
			self.Callbacks[#self.Callbacks + 1] = fn
		end
		return self
	end
	track(self.Window, box.FocusLost:Connect(function(enterPressed)
		apply(box.Text, true, enterPressed)
	end))
	self.Controls[#self.Controls + 1] = control
	return control
end

SectionMethods.AddTextbox = SectionMethods.AddTextBox

function SectionMethods:AddProgress(titleValue, initial, color)
	local theme = self.Theme
	local row = self:_row(48, "ProgressRow")
	text(row, titleValue or "Progress", UDim2.fromOffset(0, 0), UDim2.new(0.72, 0, 0, 22), 12, theme.text, true)
	local valueLabel = text(row, "0%", UDim2.new(0.72, 0, 0, 0), UDim2.new(0.28, 0, 0, 22), 12, color or theme.green, true)
	valueLabel.TextXAlignment = Enum.TextXAlignment.Right
	local bar = progress(row, UDim2.fromOffset(0, 32), UDim2.new(1, 0, 0, 8), color or theme.green, theme)
	local oldSet = bar.Set
	function bar:Set(value)
		oldSet(self, value)
		valueLabel.Text = tostring(math.floor(self.Value + 0.5)) .. "%"
	end
	bar:Set(initial or 0)
	return bar
end

function SectionMethods:AddToggle(titleValue, initial, callback)
	local theme = self.Theme
	local row = self:_row(42, "ToggleRow")
	local value = initial == true
	text(row, titleValue or "Toggle", UDim2.fromOffset(0, 0), UDim2.new(1, -72, 1, 0), 13, theme.text, false)
	local btn = inst("TextButton", {
		BackgroundColor3 = value and theme.green or Color3.fromRGB(42, 51, 61),
		BorderSizePixel = 0,
		Position = UDim2.new(1, -58, 0, 10),
		Size = UDim2.fromOffset(58, 22),
		Text = value and "ON" or "OFF",
		TextColor3 = value and theme.dark or theme.muted,
		TextSize = 11,
		Font = Enum.Font.GothamBold,
		AutoButtonColor = false,
		Parent = row
	})
	corner(btn, 11)
	local control = {
		Value = value,
		Callbacks = {}
	}
	local function apply(nextValue, fire)
		value = nextValue == true
		control.Value = value
		btn.BackgroundColor3 = value and theme.green or Color3.fromRGB(42, 51, 61)
		btn.Text = value and "ON" or "OFF"
		btn.TextColor3 = value and theme.dark or theme.muted
		if fire then
			runCallback(callback, value)
			for _, fn in ipairs(control.Callbacks) do
				runCallback(fn, value)
			end
		end
	end
	function control:Set(nextValue)
		apply(nextValue, false)
	end
	function control:SetValue(nextValue)
		apply(nextValue, false)
	end
	function control:Get()
		return value
	end
	function control:OnChanged(fn)
		if type(fn) == "function" then
			self.Callbacks[#self.Callbacks + 1] = fn
		end
		return self
	end
	track(self.Window, btn.MouseButton1Click:Connect(function()
		apply(not value, true)
	end))
	self.Controls[#self.Controls + 1] = control
	return control
end

function SectionMethods:AddDropdown(titleValue, values, current, callback)
	local theme = self.Theme
	values = values or {}
	local row = self:_row(44, "DropdownRow")
	text(row, titleValue or "Dropdown", UDim2.fromOffset(0, 0), UDim2.new(0.42, -8, 1, 0), 13, theme.text, false)
	local btn = button(row, tostring(current or values[1] or ""), UDim2.new(0.42, 0, 0, 7), UDim2.new(0.58, 0, 0, 30), nil, theme)
	btn.TextColor3 = theme.green
	local list = inst("ScrollingFrame", {
		BackgroundColor3 = theme.bg,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromOffset(0, math.max(#values * 28, 28)),
		Position = UDim2.new(0.42, 0, 0, 39),
		ScrollBarThickness = 3,
		Size = UDim2.new(0.58, 0, 0, math.min(math.max(#values, 1) * 28, 168)),
		Visible = false,
		ZIndex = 80,
		Parent = row
	})
	corner(list, 5)
	stroke(list, theme.line, 0.15, 1)
	local control = {}
	local selected = current or values[1]
	local function setSelected(value, fire)
		selected = value
		btn.Text = tostring(value or "")
		list.Visible = false
		if fire then
			runCallback(callback, value)
		end
	end
	for i, optionValue in ipairs(values) do
		local option = inst("TextButton", {
			BackgroundColor3 = theme.bg,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, (i - 1) * 28),
			Size = UDim2.new(1, 0, 0, 28),
			Text = tostring(optionValue),
			TextColor3 = theme.text,
			TextSize = 12,
			Font = Enum.Font.Gotham,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 81,
			AutoButtonColor = false,
			Parent = list
		})
		track(self.Window, option.MouseButton1Click:Connect(function()
			setSelected(optionValue, true)
		end))
	end
	function control:Set(value)
		setSelected(value, false)
	end
	function control:Get()
		return selected
	end
	track(self.Window, btn.MouseButton1Click:Connect(function()
		if self.Window.OpenDropdown and self.Window.OpenDropdown ~= list then
			self.Window.OpenDropdown.Visible = false
		end
		list.Visible = not list.Visible
		self.Window.OpenDropdown = list.Visible and list or nil
	end))
	self.Controls[#self.Controls + 1] = control
	return control
end

function SectionMethods:AddSlider(titleValue, initial, minValue, maxValue, suffix, callback)
	local theme = self.Theme
	local userInput = game:GetService("UserInputService")
	local row = self:_row(54, "SliderRow")
	minValue = tonumber(minValue) or 0
	maxValue = tonumber(maxValue) or 100
	local value = tonumber(initial) or minValue
	if maxValue == minValue then
		maxValue = minValue + 1
	end
	text(row, titleValue or "Slider", UDim2.fromOffset(0, 0), UDim2.new(0.72, 0, 0, 24), 13, theme.text, false)
	local valueLabel = text(row, "", UDim2.new(0.72, 0, 0, 0), UDim2.new(0.28, 0, 0, 24), 12, theme.green, true)
	valueLabel.TextXAlignment = Enum.TextXAlignment.Right
	local bar = inst("Frame", {
		BackgroundColor3 = Color3.fromRGB(36, 51, 61),
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 36),
		Size = UDim2.new(1, 0, 0, 8),
		Parent = row
	})
	corner(bar, 4)
	local fill = inst("Frame", {
		BackgroundColor3 = theme.green,
		BorderSizePixel = 0,
		Parent = bar
	})
	corner(fill, 4)
	local dragging = false
	local control = {
		Value = value,
		Min = minValue,
		Max = maxValue,
		Callbacks = {}
	}
	local function apply(nextValue, fire)
		value = clamp(nextValue, minValue, maxValue)
		if maxValue - minValue > 20 then
			value = math.floor(value + 0.5)
		else
			value = math.floor(value * 10 + 0.5) / 10
		end
		control.Value = value
		control.Min = minValue
		control.Max = maxValue
		fill.Size = UDim2.new((value - minValue) / (maxValue - minValue), 0, 1, 0)
		valueLabel.Text = tostring(value) .. (suffix or "")
		if fire then
			runCallback(callback, value)
			for _, fn in ipairs(control.Callbacks) do
				runCallback(fn, value)
			end
		end
	end
	local function setFromX(x, fire)
		local alpha = 0
		if bar.AbsoluteSize.X > 0 then
			alpha = (x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X
		end
		apply(minValue + (maxValue - minValue) * clamp(alpha, 0, 1), fire)
	end
	function control:Set(nextValue)
		apply(nextValue, false)
	end
	function control:SetValue(nextValue)
		apply(nextValue, false)
	end
	function control:SetMin(nextValue)
		minValue = tonumber(nextValue) or minValue
		if maxValue <= minValue then
			maxValue = minValue + 1
		end
		apply(value, false)
	end
	function control:SetMax(nextValue)
		maxValue = tonumber(nextValue) or maxValue
		if maxValue <= minValue then
			minValue = maxValue - 1
		end
		apply(value, false)
	end
	function control:Get()
		return value
	end
	function control:OnChanged(fn)
		if type(fn) == "function" then
			self.Callbacks[#self.Callbacks + 1] = fn
		end
		return self
	end
	apply(value, false)
	track(self.Window, bar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			setFromX(input.Position.X, true)
		end
	end))
	track(self.Window, userInput.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			setFromX(input.Position.X, true)
		end
	end))
	track(self.Window, userInput.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end))
	self.Controls[#self.Controls + 1] = control
	return control
end

function UniversalUI.new(options)
	options = options or {}
	local themeName = options.ThemeName or "Default"
	local theme = mergeTheme(UniversalUI.Themes[themeName] or UniversalUI.Themes.Default, options.Theme)
	local parent = resolveParent(options.Parent)
	local name = tostring(options.Name or "UniversalUI")
	local cleanupKey = "_UniversalUI_" .. sanitizeKey(options.CleanupKey or name)

	if _G and type(_G[cleanupKey]) == "function" then
		pcall(_G[cleanupKey])
	end

	local screen = inst("ScreenGui", {
		Name = name,
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = parent
	})

	local size = options.Size or UDim2.fromOffset(920, 560)
	local position = options.Position or UDim2.new(0.5, -460, 0.5, -280)

	local root = inst("Frame", {
		Name = "Root",
		BackgroundColor3 = theme.bg,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Position = position,
		Size = size,
		Parent = screen
	})
	corner(root, 10)
	stroke(root, theme.line, 0.18, 1)
	gradient(root, theme.panel2, theme.bg, 90)

	local window = setmetatable({
		Name = name,
		Title = tostring(options.Title or name),
		Subtitle = tostring(options.Subtitle or "SYSTEM ONLINE"),
		Theme = theme,
		Screen = screen,
		Root = root,
		Tabs = {},
		TabByName = {},
		Connections = {},
		CleanupKey = cleanupKey,
		DestroyCallback = nil,
		OpenDropdown = nil
	}, { __index = WindowMethods })

	local sidebarWidth = options.SidebarWidth or 210
	local topHeight = 58

	local sidebar = inst("Frame", {
		Name = "Sidebar",
		BackgroundColor3 = Color3.fromRGB(7, 18, 27),
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(0, sidebarWidth, 1, 0),
		Parent = root
	})
	stroke(sidebar, theme.line, 0.35, 1)

	window.TitleLabel = text(sidebar, window.Title, UDim2.fromOffset(18, 12), UDim2.new(1, -36, 0, 28), 20, theme.text, true)
	window.SubtitleLabel = text(sidebar, window.Subtitle, UDim2.fromOffset(18, 42), UDim2.new(1, -36, 0, 22), 12, theme.green, true)

	local tabList = inst("Frame", {
		Name = "TabList",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 88),
		Size = UDim2.new(1, -12, 1, -120),
		Parent = sidebar
	})
	inst("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = tabList
	})
	window.TabList = tabList

	local header = inst("Frame", {
		Name = "Header",
		BackgroundColor3 = Color3.fromRGB(6, 16, 24),
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(sidebarWidth, 0),
		Size = UDim2.new(1, -sidebarWidth, 0, topHeight),
		Parent = root
	})
	stroke(header, theme.line, 0.55, 1)
	window.StatusLabel = text(header, "Ready", UDim2.fromOffset(18, 0), UDim2.new(1, -36, 1, 0), 13, theme.green, true)
	window.StatusLabel.TextXAlignment = Enum.TextXAlignment.Right

	local pageHost = inst("Frame", {
		Name = "PageHost",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(sidebarWidth, topHeight),
		Size = UDim2.new(1, -sidebarWidth, 1, -topHeight),
		Parent = root
	})
	window.PageHost = pageHost

	makeDraggable(window, header)
	makeDraggable(window, sidebar)

	local toggleKey = options.ToggleKey or Enum.KeyCode.RightShift
	track(window, game:GetService("UserInputService").InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == toggleKey then
			window:Toggle()
		end
	end))

	window.DestroyCallback = function()
		window:Destroy()
	end
	if _G then
		_G[cleanupKey] = window.DestroyCallback
	end

	return window
end

UniversalUI.makeStatus = makeStatus
UniversalUI.resolveParent = resolveParent
UniversalUI.safeCall = safeCall
UniversalUI.safeFireServer = safeFireServer
UniversalUI.safeInvokeServer = safeInvokeServer
UniversalUI.RuntimeMethods = RuntimeMethods

return UniversalUI
