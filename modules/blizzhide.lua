local ADDON, Chonk = ...

-- Hides Blizzard's floating Personal Resource Display via the nameplateShowSelf CVar.

local BlizzHide = Chonk:RegisterModule({}, "blizzhide", "Blizzard Hide")
Chonk.BlizzHide = BlizzHide

local driver = CreateFrame("Frame")

-- Nameplate CVars can be locked in combat: defer to PLAYER_REGEN_ENABLED, and pcall as a backstop.
function BlizzHide:SetPRD(hide)
	local value = hide and "0" or "1"
	if InCombatLockdown() then
		self.pending = value
		driver:RegisterEvent("PLAYER_REGEN_ENABLED")
		return
	end
	self.pending = nil
	pcall(SetCVar, "nameplateShowSelf", value)
end

driver:SetScript("OnEvent", function()
	driver:UnregisterEvent("PLAYER_REGEN_ENABLED")
	if BlizzHide.pending then
		pcall(SetCVar, "nameplateShowSelf", BlizzHide.pending)
		BlizzHide.pending = nil
	end
end)

local function enforce()
	if Chonk.db.profile.hidePRD then
		BlizzHide:SetPRD(true)
	end
end

BlizzHide.OnEnable = enforce
BlizzHide.OnProfileChange = enforce
