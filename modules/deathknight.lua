local ADDON, Chonk = ...

local L = LibStub("AceLocale-3.0"):GetLocale("ChonkyBirb")

local D = Chonk.BarDefs
local C = Chonk.BarColors
local PT = Enum.PowerType

-- Death Knight: Runic Power + Runes. Runes aren't a UnitPower thing, gotta count them with GetRuneCooldown.
local RUNES_FROST  = { 0.06, 0.33, 0.60 }   -- #0F5599
local RUNES_UNHOLY = { 0.44, 0.51, 0.16 }   -- #708329

local function runes(color)
	return { id = "runes", label = L["Runes"], source = "runes", kind = "segmented", maxNodes = 6, defaultColor = color }
end

Chonk.Registry[6] = {
	[1] = { D.power("runicPower", "Runic Power", PT.RunicPower, C.runicPower), runes(C.runes), D.health() },
	[2] = { D.power("runicPower", "Runic Power", PT.RunicPower, C.runicPower), runes(RUNES_FROST), D.health() },
	[3] = { D.power("runicPower", "Runic Power", PT.RunicPower, C.runicPower), runes(RUNES_UNHOLY), D.health() },
}

local function readyRunes()
	local ready = 0
	for i = 1, 6 do
		local _, _, isReady = GetRuneCooldown(i)
		if isReady then ready = ready + 1 end
	end
	return ready
end

-- Fixed slots: pip i is always rune i; a spent rune shows its recharge fill in place.
Chonk.Sources.runes = function()
	local ready = 0
	local states = {}
	for i = 1, 6 do
		local startTime, duration, isReady = GetRuneCooldown(i)
		if isReady then
			ready = ready + 1
			states[i] = { full = true }
		elseif startTime then
			states[i] = { start = startTime, endTime = startTime + duration }
		end
	end
	return ready, 6, states
end

Chonk.TextTags.runes = function()
	return string.format("%d", readyRunes())
end
