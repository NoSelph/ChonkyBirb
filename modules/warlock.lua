local ADDON, Chonk = ...

local D = Chonk.BarDefs
local C = Chonk.BarColors
local PT = Enum.PowerType

-- Warlock: Mana + Soul Shards (pips) on all three specs. Shards default taller than other pip bars.
local function shards()
	local d = D.seg("soulShards", "Soul Shards", PT.SoulShards, C.soulShards, 5)
	d.defaultHeight = 30
	return d
end

Chonk.Registry[9] = {
	[1] = { D.power("mana", "Mana", PT.Mana, C.mana), shards(), D.health() },
	[2] = { D.power("mana", "Mana", PT.Mana, C.mana), shards(), D.health() },
	[3] = { D.power("mana", "Mana", PT.Mana, C.mana), shards(), D.health() },
}

-- Cast-time Soul Shard generation (display units: whole shards; Destruction fragments are /10).
-- Infernal Bolt's gain differs by spec, hence bySpec (2 = Demonology, 3 = Destruction).
Chonk.CastGen[686]    = { pt = PT.SoulShards, amount = 1 }     -- Shadow Bolt (Demonology)
Chonk.CastGen[264178] = { pt = PT.SoulShards, amount = 2 }     -- Demonbolt
Chonk.CastGen[434635] = { pt = PT.SoulShards, amount = 1 }     -- Ruination
Chonk.CastGen[434506] = { pt = PT.SoulShards, bySpec = { [2] = 3, [3] = 2 } }   -- Infernal Bolt
Chonk.CastGen[29722]  = { pt = PT.SoulShards, amount = 0.2 }   -- Incinerate (2 fragments)
Chonk.CastGen[6353]   = { pt = PT.SoulShards, amount = 1 }     -- Soul Fire (10 fragments)
