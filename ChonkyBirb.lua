local ADDON, Chonk = ...

-- Core: Chonk namespace, module system, AceDB + per-spec profiles, defaults, slash command.

LibStub("AceEvent-3.0"):Embed(Chonk)
LibStub("AceConsole-3.0"):Embed(Chonk)
LibStub("AceTimer-3.0"):Embed(Chonk)

LibStub("LibSharedMedia-3.0"):Register("statusbar", "ChonkyBirb Flat", [[Interface\AddOns\ChonkyBirb\media\textures\CHONKFlat.tga]])
LibStub("LibSharedMedia-3.0"):Register("font", "Roboto Medium", [[Interface\AddOns\ChonkyBirb\media\fonts\Roboto-Medium.ttf]])
LibStub("LibSharedMedia-3.0"):Register("border", "ChonkyBirb 1PX", [[Interface\AddOns\ChonkyBirb\media\textures\CHONK1PXBorder.tga]])

_G.ChonkyBirb = Chonk

Chonk.modules = {}
Chonk.moduleOrder = {}

function Chonk:RegisterModule(module, key, name)
	module.moduleKey = key
	module.moduleName = name
	self.modules[key] = module
	self.moduleOrder[#self.moduleOrder + 1] = module
	return module
end

function Chonk:FireModuleEvent(event, ...)
	for i = 1, #self.moduleOrder do
		local module = self.moduleOrder[i]
		local handler = module[event]
		if handler then handler(module, ...) end
	end
end

local defaults = {
	profile = {
		enabled = true,
		locked = true,
		linkBars = false,   -- drag any bar moves them all together
		linkGroup = { x = 0, y = 0 },   -- group-move slider handle (delta applied to every bar)
		hidePRD = false,   -- hide Blizzard's Personal Resource Display (nameplateShowSelf CVar)
		autoHide = { mounted = false, vehicle = false, petBattle = false },   -- hides ALL bars
		-- Global appearance defaults; per-bar/per-text fields stay nil until overridden (see eff()).
		barDefaults = {
			strata = "LOW",   -- pip bars are seeded to MEDIUM so they can sit on top (see seedBar)
			font = { face = "Roboto Medium", size = 12, outline = "SHADOW", color = { 1, 1, 1 },
			         shadowColor = { 0, 0, 0, 1 }, shadowX = 1, shadowY = -1 },
			border = { edge = "ChonkyBirb 1PX", size = 1, color = { 0, 0, 0, 1 } },
			background = { texture = "Solid", color = { 0, 0, 0, 0.5 } },
		},
		bars = {
			["*"] = {
				enabled = true,
				width = 330,
				height = 30,   -- segmented bars are seeded to 12 (see seedBar)
				texture = "ChonkyBirb Flat",
				border = {},        -- empty -> inherits barDefaults
				background = {},
				color = { mode = "static", static = { 1, 1, 1 } },
				segment = { gap = 2, renderer = "pips", offMode = "alpha", offAlpha = 0.25, offColor = { 1, 1, 1, 1 } },
				recharge = { mode = "alpha", alpha = 0.4, color = { 1, 1, 1, 0.4 } },
				castPredict = false,
				castColorMode = "bar",   -- "bar" = live bar color + castAlpha | "custom" = castColor
				castAlpha = 0.35,
				texts = {},     -- text fields; texts[1] seeded per bar
				markers = {},   -- value markers: { value, width, height (nil = bar height), color }
				fillDirection = "right",
				visibility = { mode = "always", conditions = {} },
				position = { point = "CENTER", x = 0, y = 0, scale = 1.0 },   -- own anchor, bars never grouped
			},
		},
		minimap = { hide = false },
	},
	global = { configVersion = 1 },
}
Chonk.defaults = defaults

function Chonk:Initialize()
	self:UnregisterEvent("PLAYER_LOGIN")

	self.db = LibStub("AceDB-3.0"):New("ChonkyBirbDB", defaults)
	LibStub("LibDualSpec-1.0"):EnhanceDatabase(self.db, "ChonkyBirb")
	self.db.RegisterCallback(self, "OnProfileChanged", "Rebuild")
	self.db.RegisterCallback(self, "OnProfileCopied", "Rebuild")
	self.db.RegisterCallback(self, "OnProfileReset", "Rebuild")

	self:RegisterChatCommand("chonk", "OnSlash")
	self:RegisterChatCommand("chonkybirb", "OnSlash")
	self:RegisterChatCommand("cb", "OnSlash")

	self:FireModuleEvent("OnInitialize")
	self:FireModuleEvent("OnEnable")
	self:Rebuild()
end

-- Full rebuild (destroy + recreate the bar set): login, profile switch, spec change.
function Chonk:Rebuild()
	self.profile = self.db.profile
	self:FireModuleEvent("OnProfileChange")
end

-- Light refresh (re-apply settings to the EXISTING bars, no destroy → no flash): config edits.
function Chonk:ApplySettings()
	self.profile = self.db.profile
	self:FireModuleEvent("OnRefresh")
end

function Chonk:OnSlash(input)
	if self.OpenConfig then
		self:OpenConfig(input)
	else
		self:Print("options coming soon")
	end
end

Chonk:RegisterEvent("PLAYER_LOGIN", "Initialize")
