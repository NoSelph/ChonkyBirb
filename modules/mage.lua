local ADDON, Chonk = ...

local D = Chonk.BarDefs
local C = Chonk.BarColors
local PT = Enum.PowerType

-- Mage: Mana everywhere, Arcane Charges (pips) for Arcane.
Chonk.Registry[8] = {
	[1] = { D.power("mana", "Mana", PT.Mana, C.mana), D.seg("arcaneCharges", "Arcane Charges", PT.ArcaneCharges, C.arcane, 4), D.health() },
	[2] = { D.power("mana", "Mana", PT.Mana, C.mana), D.health() },
	[3] = { D.power("mana", "Mana", PT.Mana, C.mana), D.health() },
}

-- Cast-time Arcane Charge generation.
Chonk.CastGen[30451] = { pt = PT.ArcaneCharges, amount = 1 }   -- Arcane Blast
