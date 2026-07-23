local ADDON, Chonk = ...

-- Event driver: value updates on power/cast events, full rebuild on spec/talent/login changes.

local Engine = Chonk:RegisterModule({}, "engine", "Engine")
Chonk.Engine = Engine

local driver = CreateFrame("Frame")
Engine.driver = driver

local UNIT_EVENTS = {
	"UNIT_POWER_FREQUENT", "UNIT_POWER_UPDATE", "UNIT_MAXPOWER",
	"UNIT_DISPLAYPOWER", "UNIT_HEALTH", "UNIT_MAXHEALTH",
	"UNIT_AURA",
	"UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_SUCCEEDED",
	"UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP",
	"UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_DELAYED",
}

-- Form swaps fire UNIT_DISPLAYPOWER but must NOT rebuild (rebuilding flashes every bar).
local REBUILD_EVENTS = {
	PLAYER_SPECIALIZATION_CHANGED = true,
	PLAYER_ENTERING_WORLD = true,
	TRAIT_CONFIG_UPDATED = true,
	-- Pixel snapping is tied to the resolution and UI scale: re-lay everything out when they move.
	UI_SCALE_CHANGED = true,
	DISPLAY_SIZE_CHANGED = true,
}

function Engine:OnProfileChange()
	self:Rebuild()
end

function Engine:OnRefresh()
	Chonk.BarFactory:Refresh()
	if Chonk.Visibility then Chonk.Visibility:MarkDirty() end
end

function Engine:Rebuild()
	Chonk.BarFactory:Rebuild()
	if Chonk.Visibility then Chonk.Visibility:MarkDirty() end
	self:RegisterEvents()
	self:UpdateStaggerTicker()
end

-- Stagger decays with no event, so poll while a stagger bar exists.
function Engine:UpdateStaggerTicker()
	if self.staggerTicker then
		self.staggerTicker:Cancel()
		self.staggerTicker = nil
	end
	if Chonk.BarFactory.hasStagger then
		self.staggerTicker = C_Timer.NewTicker(0.25, function()
			Chonk.BarFactory:UpdateAll()
		end)
	end
end

function Engine:RegisterEvents()
	driver:UnregisterAllEvents()
	for i = 1, #UNIT_EVENTS do
		driver:RegisterUnitEvent(UNIT_EVENTS[i], "player")
	end
	driver:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
	driver:RegisterEvent("PLAYER_ENTERING_WORLD")
	driver:RegisterEvent("TRAIT_CONFIG_UPDATED")
	driver:RegisterEvent("UI_SCALE_CHANGED")
	driver:RegisterEvent("DISPLAY_SIZE_CHANGED")
	driver:RegisterEvent("RUNE_POWER_UPDATE")
end

function Engine:ScheduleRebuild()
	if self.rebuildTimer then return end
	self.rebuildTimer = C_Timer.NewTimer(0.35, function()
		Engine.rebuildTimer = nil
		Engine:Rebuild()
	end)
end

driver:SetScript("OnEvent", function(_, event)
	if REBUILD_EVENTS[event] then
		Engine:ScheduleRebuild()
	else
		Chonk.BarFactory:UpdateAll()
	end
end)
