local UniversalUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/tetizz/roblox-stuff/main/universal_ui.lua"))()

local app = UniversalUI.new({
	Name = "UniversalUIDemo",
	Title = "Universal UI",
	Subtitle = "Reusable Library",
	ToggleKey = Enum.KeyCode.RightShift,
	ThemeName = "NationBrain"
})

local dashboard = app:AddTab("Dashboard", "[]")
local controls = app:AddTab("Controls", "//")

local overview = dashboard:AddSection("Live Overview")
overview:AddLabel("This UI is game-agnostic. Feed it data from any script.")
local status = overview:AddStatus("System", "Online")
local progress = overview:AddProgress("Confidence", 87)
overview:AddButton("Refresh", function()
	status:SetText("Refreshed")
	progress:Set(90)
	app:Notify("Universal UI", "Demo refresh complete", 3)
end)

local settings = controls:AddSection("Controls")
settings:AddToggle("Automation Enabled", false, function(value)
	status:SetText(value and "Automation enabled" or "Automation disabled")
end)
settings:AddDropdown("Mode", { "Passive", "Balanced", "Aggressive" }, "Balanced", function(value)
	app:SetStatus("Mode: " .. tostring(value))
end)
settings:AddSlider("Scan Delay", 1.5, 0.1, 10, "s", function(value)
	app:SetStatus("Scan Delay: " .. tostring(value) .. "s")
end)

return app
