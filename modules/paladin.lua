local ADDON, Chonk = ...

local D = Chonk.BarDefs
local C = Chonk.BarColors
local PT = Enum.PowerType

-- Paladin: Holy Power (pips) + Mana on all three specs. Holy Power builders are instant -> no CastGen.
Chonk.Registry[2] = {
	[1] = { D.seg("holyPower", "Holy Power", PT.HolyPower, C.holyPower, 5), D.power("mana", "Mana", PT.Mana, C.mana), D.health() },
	[2] = { D.seg("holyPower", "Holy Power", PT.HolyPower, C.holyPower, 5), D.power("mana", "Mana", PT.Mana, C.mana), D.health() },
	[3] = { D.seg("holyPower", "Holy Power", PT.HolyPower, C.holyPower, 5), D.power("mana", "Mana", PT.Mana, C.mana), D.health() },
}
