local ADDON, Chonk = ...

local L = LibStub("AceLocale-3.0"):GetLocale("ChonkyBirb")

local D = Chonk.BarDefs
local C = Chonk.BarColors
local PT = Enum.PowerType

-- Shaman: Maelstrom (Elemental), Maelstrom Weapon stacks (Enhancement, aura pips), Mana (Resto).
Chonk.Registry[7] = {
	[1] = { D.power("maelstrom", "Maelstrom", PT.Maelstrom, C.maelstrom), D.power("mana", "Mana", PT.Mana, C.mana), D.health() },
	[2] = {
		{ id = "maelstromWeapon", label = L["Maelstrom Weapon"], source = "aura", kind = "segmented", auraSpellID = 344179, maxNodes = 10, defaultColor = C.maelstrom },
		D.power("mana", "Mana", PT.Mana, C.mana), D.health(),
	},
	[3] = { D.power("mana", "Mana", PT.Mana, C.mana), D.health() },
}

-- Cast-time Maelstrom generation (Elemental; base values, single target).
Chonk.CastGen[188196] = { pt = PT.Maelstrom, amount = 6 }    -- Lightning Bolt
Chonk.CastGen[51505]  = { pt = PT.Maelstrom, amount = 8 }    -- Lava Burst
Chonk.CastGen[188443] = { pt = PT.Maelstrom, amount = 2 }    -- Chain Lightning
Chonk.CastGen[462818] = { pt = PT.Maelstrom, amount = 10 }   -- Icefury
