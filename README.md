# roblox-stuff

Scripts I made.

- `RoN Automation.lua` - optimized Rise of Nations automation hub that loads the custom Nation Brain interface library.
- `ron_brain_ui.lua` - custom RoN Nation Brain GUI library used by the main automation script.
- `universal_ui.lua` - reusable Roblox UI toolkit for any game script.
- `universal_ui_demo.lua` - small standalone demo for the universal UI toolkit.
- `init.lua` - short loader for `RoN Automation.lua`.
- `load ron automation.lua` - short loadstring loader for `RoN Automation.lua`.
- `side projects` - optimized separate tycoon helper script.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/tetizz/roblox-stuff/main/init.lua"))()
```

Universal UI library:

```lua
local UI = loadstring(game:HttpGet("https://raw.githubusercontent.com/tetizz/roblox-stuff/main/universal_ui.lua"))()

local app = UI.new({
	Name = "MyHub",
	Title = "My Hub",
	Subtitle = "SYSTEM ONLINE",
	ThemeName = "NationBrain"
})

local tab = app:AddTab("Main", "[]")
local section = tab:AddSection("Automation")
local status = section:AddStatus("State", "Idle")
section:AddToggle("Enabled", false, function(value)
	status:SetText(value and "Running" or "Idle")
end)
```

Demo loader:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/tetizz/roblox-stuff/main/universal_ui_demo.lua"))()
```
