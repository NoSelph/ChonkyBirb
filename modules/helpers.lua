local ADDON, Chonk = ...

-- pcall wrappers for the Unit*/spell APIs that throw on restricted tokens. IsUsableNumber before doing math on anything that comes back.

local pcall, issecretvalue = pcall, issecretvalue

local H = {}
Chonk.Helpers = H

function H.UnitPower(unit, powerType, unmodified)
	local ok, v = pcall(UnitPower, unit, powerType, unmodified)
	if ok then return v end
end

function H.UnitPowerMax(unit, powerType, unmodified)
	local ok, v = pcall(UnitPowerMax, unit, powerType, unmodified)
	if ok then return v end
end

function H.UnitPowerPercent(unit, powerType, unmodified, curve)
	local ok, v = pcall(UnitPowerPercent, unit, powerType, unmodified, curve)
	if ok then return v end
end

function H.UnitPartialPower(unit, powerType, unmodified)
	local ok, v = pcall(UnitPartialPower, unit, powerType, unmodified)
	if ok then return v end
end

function H.PowerRegen(powerType)
	local ok, base = pcall(GetPowerRegenForPowerType, powerType)
	if ok then return base end
end

function H.UnitHealth(unit)
	local ok, v = pcall(UnitHealth, unit)
	if ok then return v end
end

function H.UnitHealthMax(unit)
	local ok, v = pcall(UnitHealthMax, unit)
	if ok then return v end
end

function H.UnitHealthPercent(unit, usePredicted, curve)
	local ok, v = pcall(UnitHealthPercent, unit, usePredicted, curve)
	if ok then return v end
end

function H.UnitStagger(unit)
	local ok, v = pcall(UnitStagger, unit)
	if ok then return v end
end

function H.UnitHealthMissing(unit)
	local ok, v = pcall(UnitHealthMissing, unit)
	if ok then return v end
end

function H.UnitPowerMissing(unit, powerType, unmodified)
	local ok, v = pcall(UnitPowerMissing, unit, powerType, unmodified)
	if ok then return v end
end

function H.GetPlayerAura(spellID)
	local ok, v = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spellID)
	if ok then return v end
end

-- Max cumulative aura stacks (plain number).
function H.SpellMaxAuraStacks(spellID)
	local fn = C_Spell and C_Spell.GetSpellMaxCumulativeAuraApplications
	if not fn then return end
	local ok, v = pcall(fn, spellID)
	if ok then return v end
end

-- Accepts a spell ID, name, or chat link (SpellIdentifier); name lookups need the spell in the spellbook.
function H.ResolveSpell(identifier)
	local fn = C_Spell and C_Spell.GetSpellInfo
	if not fn or not identifier or identifier == "" then return end
	local ok, info = pcall(fn, identifier)
	if ok and info then return info.spellID, info.name, info.iconID end
end

function H.IsSpellKnown(spellID)
	local fn = C_SpellBook and C_SpellBook.IsSpellKnown
	if not fn then return false end
	local ok, known = pcall(fn, spellID)
	return ok and known or false
end

-- Works with an id or a raw name/link. An unlearned name can't resolve, so it counts as not known until the talent shows up.
function H.IsSpellIdentifierKnown(identifier)
	local id = tonumber(identifier) or H.ResolveSpell(identifier)
	if not id then return false end
	return H.IsSpellKnown(id)
end

-- value is a scalar identifier or a list of them.
function H.IsAnySpellKnown(value)
	if type(value) ~= "table" then return H.IsSpellIdentifierKnown(value) end
	for i = 1, #value do
		if H.IsSpellIdentifierKnown(value[i]) then return true end
	end
	return false
end

-- Spell cost for one power type; the API already returns display units (Astral Power 40, not 400).
function H.SpellPowerCost(identifier, powerType)
	local fn = C_Spell and C_Spell.GetSpellPowerCost
	if not fn or not powerType then return end
	local id = tonumber(identifier) or H.ResolveSpell(identifier)
	if not id then return end
	local ok, costs = pcall(fn, id)
	if not ok or type(costs) ~= "table" then return end
	for i = 1, #costs do
		local c = costs[i]
		if c and c.type == powerType then
			if (c.cost or 0) > 0 then return c.cost end
			if (c.minCost or 0) > 0 then return c.minCost end
			-- costPerSec/costPercent are percentages of base max: no flat value to place a tick at.
		end
	end
end

function H.AreAllSpellsKnown(value)
	if type(value) ~= "table" then return H.IsSpellIdentifierKnown(value) end
	for i = 1, #value do
		if not H.IsSpellIdentifierKnown(value[i]) then return false end
	end
	return #value > 0
end

-- One physical pixel in a region's units (768-unit virtual screen / effective scale).
function H.PixelBase(region)
	local _, ph = GetPhysicalScreenSize()
	return 768 / ph / region:GetEffectiveScale()
end

-- Nearest whole-pixel multiple, at least one pixel (sizes/thicknesses).
function H.Snap(value, px)
	local n = math.floor(value / px + 0.5)
	if n < 1 then n = 1 end
	return n * px
end

-- Same but unclamped (coordinates can be zero or negative).
function H.SnapCoord(value, px)
	return math.floor(value / px + 0.5) * px
end

function H.GetTime()
	local ok, v = pcall(GetTime)
	if ok then return v end
	return 0
end

function H.IsUsableNumber(v)
	return v ~= nil and not issecretvalue(v)
end

-- True only for a genuine nil: checks issecretvalue first so we never compare a secret to nil.
function H.IsNil(v)
	return (not issecretvalue(v)) and v == nil
end

function H.PlayerClassID()
	local ok, _, _, classID = pcall(UnitClass, "player")
	if ok then return classID end
end

function H.PlayerSpecIndex()
	local getter = (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization) or GetSpecialization
	if not getter then return end
	local ok, idx = pcall(getter)
	if ok then return idx end
end
