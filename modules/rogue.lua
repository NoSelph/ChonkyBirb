local ADDON, Chonk = ...

local D = Chonk.BarDefs
local C = Chonk.BarColors
local PT = Enum.PowerType

-- Rogue: Energy + Combo Points (pips) on all three specs. Everything instant -> no CastGen.
Chonk.Registry[4] = {
	[1] = { D.power("energy", "Energy", PT.Energy, C.energy), D.seg("comboPoints", "Combo Points", PT.ComboPoints, C.combo, 5), D.health() },
	[2] = { D.power("energy", "Energy", PT.Energy, C.energy), D.seg("comboPoints", "Combo Points", PT.ComboPoints, C.combo, 5), D.health() },
	[3] = { D.power("energy", "Energy", PT.Energy, C.energy), D.seg("comboPoints", "Combo Points", PT.ComboPoints, C.combo, 5), D.health() },
}
