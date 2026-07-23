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

-- Brewmaster stagger: colour picked by which debuff is up (plain); the amount is secret in combat so it goes straight to SetValue.
-- Levels follow the thresholds: light <30%, moderate 30-60%, heavy >60% of max health.
local STAGGER_HEAVY, STAGGER_MODERATE = 124273, 124274

Chonk.StaggerColors = {
	light    = { 0.34, 0.45, 0.30 },   -- #56734D
	moderate = { 0.65, 0.58, 0.15 },   -- #A69425
	heavy    = { 0.59, 0.15, 0.15 },   -- #962525
}

Chonk.Sources.stagger = function(bar)
	local level = "light"
	if H.GetPlayerAura(STAGGER_HEAVY) then
		level = "heavy"
	elseif H.GetPlayerAura(STAGGER_MODERATE) then
		level = "moderate"
	end
	local sc = bar.cfg.staggerColors or Chonk.StaggerColors
	local col = sc[level] or Chonk.StaggerColors[level]
	bar.bar:SetStatusBarColor(col[1], col[2], col[3], col[4] or 1)

	return H.UnitStagger("player"), H.UnitHealthMax("player")
end
