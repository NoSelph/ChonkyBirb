local ADDON, Chonk = ...

-- Text tags + compiler. Blizzard formats everything so secrets never land in my hands.

local H = Chonk.Helpers

local Tags = {}
Chonk.TextTags = Tags

local function abbrev(v)
	if H.IsNil(v) then return "" end
	return string.format("%s", AbbreviateNumbers(v))   -- short form (12.7k)
end

local function full(v)
	if H.IsNil(v) then return "" end
	return string.format("%s", v)                      -- absolute form; %s on a secret is whitelisted
end

Tags.cur        = function(ctx) return abbrev(ctx.cur) end
Tags.max        = function(ctx) return abbrev(ctx.max) end
Tags.curmax     = function(ctx) return string.format("%s/%s", abbrev(ctx.cur), abbrev(ctx.max)) end
Tags.curfull    = function(ctx) return full(ctx.cur) end
Tags.maxfull    = function(ctx) return full(ctx.max) end
Tags.curmaxfull = function(ctx) return string.format("%s/%s", full(ctx.cur), full(ctx.max)) end
Tags.name       = function(ctx) return ctx.bar.desc.label or "" end

Tags.percent = function(ctx)
	local bar = ctx.bar
	local pct
	if bar.desc.source == "health" then
		pct = H.UnitHealthPercent("player", false, CurveConstants.ScaleTo100)
	elseif bar.powerType then
		pct = H.UnitPowerPercent("player", bar.powerType, false, CurveConstants.ScaleTo100)
	end
	if H.IsNil(pct) then return "" end
	return string.format("%.0f%%", pct)
end

Tags.deficit = function(ctx)
	local bar = ctx.bar
	local missing
	if bar.desc.source == "health" then
		missing = H.UnitHealthMissing("player")
	elseif bar.powerType then
		missing = H.UnitPowerMissing("player", bar.powerType, false)
	end
	if H.IsNil(missing) then return "" end
	return abbrev(missing)
end

-- Absolute class-resource tags: read one specific resource regardless of the bar; class-gated in config.
local RESOURCE_POWER = {
	combopoints   = Enum.PowerType.ComboPoints,
	soulshards    = Enum.PowerType.SoulShards,
	holypower     = Enum.PowerType.HolyPower,
	chi           = Enum.PowerType.Chi,
	arcanecharges = Enum.PowerType.ArcaneCharges,
	runicpower    = Enum.PowerType.RunicPower,
	essence       = Enum.PowerType.Essence,
	insanity      = Enum.PowerType.Insanity,
	maelstrom     = Enum.PowerType.Maelstrom,
	astralpower   = Enum.PowerType.LunarPower,
	fury          = Enum.PowerType.Fury,
	mana          = Enum.PowerType.Mana,
}
for token, pt in pairs(RESOURCE_POWER) do
	Tags[token] = function() return abbrev(H.UnitPower("player", pt, false)) end
end

-- Compiler: "[cur] / [max]" -> { format = "%s / %s", keys }, cached; unknown [tags] stay literal.
local Text = {}
Chonk.Text = Text

local compileCache = {}

function Text:Compile(str)
	str = str or ""
	local c = compileCache[str]
	if c then return c end

	local keys = {}
	local fmt = str:gsub("%%", "%%%%")
	fmt = fmt:gsub("%[(.-)%]", function(key)
		if Tags[key] then
			keys[#keys + 1] = key
			return "%s"
		end
		return "[" .. key .. "]"
	end)

	c = { format = fmt, keys = keys }
	compileCache[str] = c
	return c
end

function Text:DefaultElement(tagStr)
	return {
		text = tagStr or "[cur]",
		point = "CENTER", x = 0, y = 0,
		font = {},   -- empty -> inherits barDefaults.font
	}
end
