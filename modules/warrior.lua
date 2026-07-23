local ADDON, Chonk = ...

local D = Chonk.BarDefs
local C = Chonk.BarColors
local PT = Enum.PowerType

-- Warrior: Rage on all three specs. No cast-time generators (all-instant builders).
Chonk.Registry[1] = {
	[1] = { D.power("rage", "Rage", PT.Rage, C.rage), D.health() },
	[2] = { D.power("rage", "Rage", PT.Rage, C.rage), D.health() },
	[3] = { D.power("rage", "Rage", PT.Rage, C.rage), D.health() },
}
