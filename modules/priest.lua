local ADDON, Chonk = ...

local D = Chonk.BarDefs
local C = Chonk.BarColors
local PT = Enum.PowerType

-- Priest: Mana (Disc/Holy), Insanity + Mana (Shadow).
Chonk.Registry[5] = {
	[1] = { D.power("mana", "Mana", PT.Mana, C.mana), D.health() },
	[2] = { D.power("mana", "Mana", PT.Mana, C.mana), D.health() },
	[3] = { D.power("insanity", "Insanity", PT.Insanity, C.insanity), D.power("mana", "Mana", PT.Mana, C.mana), D.health() },
}

-- Cast-time Insanity generation (Shadow; base values). Channels are flat per-channel totals.
Chonk.CastGen[8092]   = { pt = PT.Insanity, amount = 6 }    -- Mind Blast
Chonk.CastGen[34914]  = { pt = PT.Insanity, amount = 4 }    -- Vampiric Touch
Chonk.CastGen[228260] = { pt = PT.Insanity, amount = 10 }   -- Void Eruption
Chonk.CastGen[375901] = { pt = PT.Insanity, amount = 10 }   -- Mindgames
Chonk.CastGen[120644] = { pt = PT.Insanity, amount = 5 }    -- Halo
Chonk.CastGen[450983] = { pt = PT.Insanity, amount = 6 }    -- Void Blast
Chonk.CastGen[15407]  = { pt = PT.Insanity, amount = 3 }    -- Mind Flay (channel)
Chonk.CastGen[391403] = { pt = PT.Insanity, amount = 4 }    -- Mind Flay: Insanity (channel)
Chonk.CastGen[263165] = { pt = PT.Insanity, amount = 6 }    -- Void Torrent (channel)
