local ADDON, Chonk = ...

-- Shared registry infrastructure; the class files (warrior.lua .. evoker.lua) fill these tables.

local L = LibStub("AceLocale-3.0"):GetLocale("ChonkyBirb")

Chonk.Registry = {}   -- [classID][specIndex] = ordered bar descriptor list
Chonk.Sources = {}    -- [source] = function(bar) -> cur, max (bespoke resource readers)
Chonk.CastGen = {}    -- [spellID] = { pt, amount | bySpec } (cast-time generation, display units)

Chonk.BarColors = {
	mana        = { 0.16, 0.31, 0.54 },   -- #29508A
	rage        = { 0.44, 0.04, 0.06 },   -- #710B10
	energy      = { 0.54, 0.50, 0.16 },   -- #8A8029
	focus       = { 0.69, 0.43, 0.20 },   -- #B06E34
	runicPower  = { 0.16, 0.49, 0.54 },   -- #297D8A
	runes       = { 0.48, 0.15, 0.20 },   -- #7A2634
	astral      = { 0.26, 0.37, 0.54 },   -- #425E8A
	soulShards  = { 0.38, 0.34, 0.48 },   -- #60567A
	holyPower   = { 0.79, 0.75, 0.46 },   -- #C9BE75
	chi         = { 0.31, 0.54, 0.49 },   -- #4F8A7C
	insanity    = { 0.30, 0.12, 0.48 },   -- #4C1F7A
	maelstrom   = { 0.12, 0.33, 0.54 },   -- #1F548A
	fury        = { 0.44, 0.18, 0.54 },   -- #702E8A
	combo       = { 0.82, 0.61, 0.29 },   -- #D29B4B
	arcane      = { 0.21, 0.21, 0.54 },   -- #36368A
	essence     = { 0.22, 0.46, 0.46 },   -- #377575
	health      = { 0.46, 0.57, 0.12 },   -- #76911E
	stagger     = { 0.34, 0.45, 0.30 },   -- #56734D
	soulFrag    = { 0.33, 0.19, 0.43 },   -- #54306E
}

-- Descriptor builders (pure data).
local Defs = {}
Chonk.BarDefs = Defs

function Defs.power(id, labelKey, pt, color, vis)
	return { id = id, label = L[labelKey], source = "power", powerType = pt, kind = "power", defaultColor = color, defaultVisibility = vis }
end

function Defs.seg(id, labelKey, pt, color, maxNodes, vis)
	return { id = id, label = L[labelKey], source = "power", powerType = pt, kind = "segmented", maxNodes = maxNodes, defaultColor = color, defaultVisibility = vis }
end

function Defs.health()
	return { id = "health", label = L["Health"], source = "health", kind = "power", defaultColor = Chonk.BarColors.health }
end

function Chonk:GetBarsForSpec(classID, specIndex)
	local byClass = classID and self.Registry[classID]
	local list = byClass and specIndex and byClass[specIndex]
	return list or { Defs.health() }
end
