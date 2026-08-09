local ADDON, Chonk = ...

local L = LibStub("AceLocale-3.0"):GetLocale("ChonkyBirb")
local H = Chonk.Helpers

local D = Chonk.BarDefs
local C = Chonk.BarColors
local PT = Enum.PowerType

-- Monk: Energy + Stagger (Brewmaster), Mana (Mistweaver), Energy + Chi (Windwalker).
Chonk.Registry[10] = {
	[1] = {
		D.power("energy", "Energy", PT.Energy, C.energy),
		{ id = "stagger", label = L["Stagger"], source = "stagger", kind = "power", defaultColor = C.stagger },
		D.health(),
	},
	[2] = { D.power("mana", "Mana", PT.Mana, C.mana), D.health() },
	[3] = { D.power("energy", "Energy", PT.Energy, C.energy), D.seg("chi", "Chi", PT.Chi, C.chi, 5), D.health() },
}

-- Brewmaster stagger levels by percent of max health, same thresholds the game uses (30% / 60%).
-- The math only runs on plain numbers; when stagger goes secret the last level sticks.
Chonk.StaggerColors = {
	light    = { 0.34, 0.45, 0.30 },   -- #56734D
	moderate = { 0.65, 0.58, 0.15 },   -- #A69425
	heavy    = { 0.59, 0.15, 0.15 },   -- #962525
}

local HEAVY_AT    = (STAGGER_STATES and STAGGER_STATES.RED and STAGGER_STATES.RED.threshold) or 0.6
local MODERATE_AT = (STAGGER_STATES and STAGGER_STATES.YELLOW and STAGGER_STATES.YELLOW.threshold) or 0.3

Chonk.Sources.stagger = function(bar)
	local stagger = H.UnitStagger("player")
	local maxHealth = H.UnitHealthMax("player")

	local level = bar._staggerLevel or "light"
	if H.IsUsableNumber(stagger) and H.IsUsableNumber(maxHealth) and maxHealth > 0 then
		local pct = stagger / maxHealth
		level = (pct >= HEAVY_AT and "heavy") or (pct >= MODERATE_AT and "moderate") or "light"
	end
	bar._staggerLevel = level

	local sc = bar.cfg.staggerColors or Chonk.StaggerColors
	local col = sc[level] or Chonk.StaggerColors[level]
	bar.bar:SetStatusBarColor(col[1], col[2], col[3], col[4] or 1)

	return stagger, maxHealth
end
