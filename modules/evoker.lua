local ADDON, Chonk = ...

-- Evoker: Mana + Essence everywhere.

local L = LibStub("AceLocale-3.0"):GetLocale("ChonkyBirb")
local H = Chonk.Helpers

local D = Chonk.BarDefs
local C = Chonk.BarColors
local PT = Enum.PowerType

-- Essence trickle-fills one point at a time.
-- Keep powerType for tags but read via a source so the filling point gets a recharge fill like the DK runes.
local function essence()
	return { id = "essence", label = L["Essence"], source = "essence", powerType = PT.Essence, kind = "segmented", maxNodes = 6, defaultColor = C.essence }
end

Chonk.Registry[13] = {
	[1] = { D.power("mana", "Mana", PT.Mana, C.mana), essence(), D.health() },
	[2] = { D.power("mana", "Mana", PT.Mana, C.mana), essence(), D.health() },
	[3] = { D.power("mana", "Mana", PT.Mana, C.mana), essence(), D.health() },
}

-- Recharge fill (start/endTime for the filling point) only when nothing is secret.
-- Otherwise just the count, and the pips fill without the animation.
Chonk.Sources.essence = function()
	local cur = H.UnitPower("player", PT.Essence, false)
	local max = H.UnitPowerMax("player", PT.Essence, false)
	if not (H.IsUsableNumber(cur) and H.IsUsableNumber(max)) then
		return cur, max
	end

	local partial = H.UnitPartialPower("player", PT.Essence, false)
	if not H.IsUsableNumber(partial) then
		return cur, max
	end

	local regen = H.PowerRegen(PT.Essence)
	if not H.IsUsableNumber(regen) or regen == 0 then regen = 0.2 end
	local duration = 1 / regen
	local elapsed = (partial / 1000) * duration
	local now = H.GetTime()

	local states = {}
	for i = 1, cur do
		states[i] = { full = true }
	end
	if cur < max then
		states[cur + 1] = { start = now - elapsed, endTime = now + (duration - elapsed) }
	end
	return cur, max, states
end
