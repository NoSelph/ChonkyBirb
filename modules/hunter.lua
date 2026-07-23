local ADDON, Chonk = ...

local D = Chonk.BarDefs
local C = Chonk.BarColors
local PT = Enum.PowerType

-- Hunter: Focus on all three specs.
Chonk.Registry[3] = {
	[1] = { D.power("focus", "Focus", PT.Focus, C.focus), D.health() },
	[2] = { D.power("focus", "Focus", PT.Focus, C.focus), D.health() },
	[3] = { D.power("focus", "Focus", PT.Focus, C.focus), D.health() },
}

-- Cast-time Focus generation
Chonk.CastGen[56641]  = { pt = PT.Focus, amount = 20 }   -- Steady Shot
Chonk.CastGen[257044] = { pt = PT.Focus, amount = 7 }    -- Rapid Fire (channel total: 1 x 7 shots)
