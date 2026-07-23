local ADDON, Chonk = ...

-- Demon Hunter: Fury everywhere, plus Soul Fragments on Devourer (aura stacks).

local L = LibStub("AceLocale-3.0"):GetLocale("ChonkyBirb")
local H = Chonk.Helpers

local D = Chonk.BarDefs
local C = Chonk.BarColors
local PT = Enum.PowerType

-- Devourer secondary resource, read from aura stacks.
local function soulFragments()
	return { id = "soulFragments", label = L["Soul Fragments"], source = "soulfragments", kind = "power", defaultColor = C.soulFrag }
end

Chonk.Registry[12] = {
	[1] = { D.power("fury", "Fury", PT.Fury, C.fury), D.health() },
	[2] = { D.power("fury", "Fury", PT.Fury, C.fury), D.health() },
	[3] = { D.power("fury", "Fury", PT.Fury, C.fury), soulFragments(), D.health() },
}

-- Cast-time Fury generation (Devourer; base value).
Chonk.CastGen[473662] = { pt = PT.Fury, amount = 8 }   -- Consume

local DHIDS = (Constants and Constants.UnitPowerSpellIDs) or {}
local VOID_METAMORPHOSIS = DHIDS.VOID_METAMORPHOSIS_SPELL_ID or 1217607
local DARK_HEART = DHIDS.DARK_HEART_SPELL_ID or 1225789
local SILENCE_THE_WHISPERS = DHIDS.SILENCE_THE_WHISPERS_SPELL_ID or 1227702

-- Dark Heart stacks normally, Collapsing Star during Void Metamorphosis. Max = the active aura's max stacks (50 / 40).
Chonk.Sources.soulfragments = function(bar)
	local aura, max
	if H.GetPlayerAura(VOID_METAMORPHOSIS) then
		aura = H.GetPlayerAura(SILENCE_THE_WHISPERS)
		max = H.SpellMaxAuraStacks(SILENCE_THE_WHISPERS)
	else
		aura = H.GetPlayerAura(DARK_HEART)
		max = H.SpellMaxAuraStacks(DARK_HEART)
	end

	local cur = 0
	if aura then cur = aura.applications end   -- testing the table is fine, applications itself is secret in combat
	return cur, max
end
