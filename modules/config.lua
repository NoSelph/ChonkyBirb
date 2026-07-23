local ADDON, Chonk = ...

-- AceConfig options, built lazily on the first /chonk.

local H = Chonk.Helpers
local LSM = LibStub("LibSharedMedia-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("ChonkyBirb")

local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

local registered = false

------------------------------------------------------------
-- Generic get/set: dot path in info.arg, a trailing "$key" segment becomes the option key
------------------------------------------------------------

local function resolvePath(arg, optKey)
	local node = Chonk.db.profile
	local last
	for seg in string.gmatch(arg, "[^%.]+") do
		if last ~= nil then
			-- numeric segments index list entries (e.g. texts.1.text)
			node = node[tonumber(last) or last]
			if node == nil then return nil end
		end
		last = seg
	end
	if last == "$key" then last = optKey end
	return node, last
end

local function get(info)
	local node, key = resolvePath(info.arg, info[#info])
	if not node then return nil end
	return node[key]
end

-- No NotifyChange in value sets: the window rebuild would destroy a slider mid-drag.
local function set(info, value)
	local node, key = resolvePath(info.arg, info[#info])
	if node then node[key] = value end
	Chonk:ApplySettings()
end

-- set + window rebuild, for selects that gate other options. Never on sliders.
local function setNotify(info, value)
	local node, key = resolvePath(info.arg, info[#info])
	if node then node[key] = value end
	Chonk:ApplySettings()
	if registered then AceConfigRegistry:NotifyChange("ChonkyBirb") end
end

-- Colors are {r,g,b[,a]} arrays; read tolerates named shapes too.
local function getColor(info)
	local t = get(info)
	if not t then return 0, 0, 0, 1 end
	return t[1] or t.r or 0, t[2] or t.g or 0, t[3] or t.b or 0, t[4] or t.a or 1
end

local function setColor(info, r, g, b, a)
	local node, key = resolvePath(info.arg, info[#info])
	if node then
		local t = node[key]
		if type(t) ~= "table" then t = {}; node[key] = t end
		t[1], t[2], t[3] = r, g, b
		if a ~= nil then t[4] = a end
	end
	Chonk:ApplySettings()
end

-- Inherited get/set: arg = { overridePath, defaultPath }.
-- A nil override shows the global default; writing anything creates the override.
local function getInh(info)
	local node, key = resolvePath(info.arg[1], info[#info])
	local v = node and node[key]
	if v ~= nil then return v end
	local dn, dk = resolvePath(info.arg[2], info[#info])
	return dn and dn[dk]
end

local function setInh(info, value)
	local node, key = resolvePath(info.arg[1], info[#info])
	if node then node[key] = value end
	Chonk:ApplySettings()
end

-- setInh + window rebuild, for the inherited select that gates other options.
local function setInhNotify(info, value)
	setInh(info, value)
	if registered then AceConfigRegistry:NotifyChange("ChonkyBirb") end
end

local function getInhColor(info)
	local node, key = resolvePath(info.arg[1], info[#info])
	local t = node and node[key]
	if t == nil then
		local dn, dk = resolvePath(info.arg[2], info[#info])
		t = dn and dn[dk]
	end
	if not t then return 0, 0, 0, 1 end
	return t[1] or 0, t[2] or 0, t[3] or 0, t[4] or 1
end

local function setInhColor(info, r, g, b, a)
	local node, key = resolvePath(info.arg[1], info[#info])
	if node then
		local t = node[key]
		if type(t) ~= "table" then t = {}; node[key] = t end
		t[1], t[2], t[3] = r, g, b
		if a ~= nil then t[4] = a end
	end
	Chonk:ApplySettings()
end

local function statusbars() return LSM:HashTable("statusbar") end
local function borders() return LSM:HashTable("border") end
local function backgrounds() return LSM:HashTable("background") end
local function fonts() return LSM:HashTable("font") end

------------------------------------------------------------
-- Visibility
------------------------------------------------------------

-- Show conditions; def.header starts a section, class = classID gate. Keys map to context booleans.
local CONDITION_DEFS = {
	{ key = "inCombat",     label = "In Combat",         header = "Combat & Target" },
	{ key = "hasTarget",    label = "Has Target" },
	{ key = "targetAngy",   label = "Hostile Target" },
	{ key = "targetSnacc",  label = "Attackable Target" },
	{ key = "targetFren",   label = "Friendly Target" },
	{ key = "inFlock",      label = "In Any Group",      header = "Group" },
	{ key = "inBigFlock",   label = "In Raid Group" },
	{ key = "inNest",       label = "In Instance",       header = "Instance" },
	{ key = "inSmolNest",   label = "In Dungeon" },
	{ key = "inBigNest",    label = "In Raid" },
	{ key = "inBattleNest", label = "In Battleground" },
	{ key = "inArenaNest",  label = "In Arena" },
	{ key = "pvpRuffled",   label = "PvP Flagged",       header = "PvP" },
	{ key = "warMode",      label = "War Mode" },
	{ key = "perched",      label = "Mounted",           header = "Mount" },
	{ key = "flappin",      label = "Flying" },
	{ key = "formMurderMittens", label = "Cat Form",        class = 11, header = "Druid Forms" },
	{ key = "formAbsoluteUnit",  label = "Bear Form",       class = 11 },
	{ key = "formBorb",       label = "Moonkin Form",       class = 11 },
	{ key = "formZoomies",    label = "Travel Form (Stag)", class = 11 },
	{ key = "formSoggy",      label = "Aquatic Form",       class = 11 },
	{ key = "formBirb",       label = "Flight Form",        class = 11 },
	{ key = "formTurboBirb",  label = "Swift Flight Form",  class = 11 },
	{ key = "formAnyZoomies", label = "Travel Form (Any)",  class = 11 },
	{ key = "formJustAGuy",   label = "Humanoid Form",      class = 11 },
}

-- Custom mode = OR of the checked conditions; section headers share their first toggle's hidden gate.
local function buildVisibilityGroup(barId, p)
	local function notCustom() return Chonk.db.profile.bars[barId].visibility.mode ~= "custom" end
	local args = {
		mode = {
			order = 1, type = "select", name = L["Show"],
			desc = L["Automatic shows the bar only while its resource is relevant (forms, spec)."],
			values = { always = L["Always"], auto = L["Automatic"], never = L["Never"], custom = L["Custom"] },
			sorting = { "always", "auto", "custom", "never" },
			arg = p .. "visibility.mode", get = get, set = setNotify,
		},
		help = {
			order = 2, type = "description", hidden = notCustom,
			name = L["The bar shows when any checked condition is true."],
		},
	}
	local carg = p .. "visibility.conditions.$key"
	for i, def in ipairs(CONDITION_DEFS) do
		local gate = function() return notCustom() or (def.class ~= nil and H.PlayerClassID() ~= def.class) end
		if def.header then
			args["hdr" .. i] = { order = 10 + i - 0.5, type = "header", name = L[def.header], hidden = gate }
		end
		args[def.key] = {
			order = 10 + i, type = "toggle", name = L[def.label],
			hidden = gate,
			arg = carg, get = get, set = set,
		}
	end
	return { order = 60, type = "group", name = L["Visibility"], args = args }
end

------------------------------------------------------------
-- Per-bar group
------------------------------------------------------------

local FILL_DIRECTIONS = { "right", "left", "up", "down" }

local TEXT_ANCHORS = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }
local TEXT_ANCHOR_VALUES = {}
for _, pt in ipairs(TEXT_ANCHORS) do TEXT_ANCHOR_VALUES[pt] = pt end

local STRATA_SORT = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "TOOLTIP" }
local STRATA_VALUES = {}
for _, s in ipairs(STRATA_SORT) do STRATA_VALUES[s] = s end

local OUTLINE_VALUES = { SHADOW = L["Shadow"], [""] = L["None"], OUTLINE = L["Outline"], THICKOUTLINE = L["Thick Outline"] }
local OUTLINE_SORT = { "SHADOW", "", "OUTLINE", "THICKOUTLINE" }

local function escapePattern(s)
	return (s:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"))
end

-- Tag checkboxes: tick inserts the token into the text field, untick removes it. classes = classID gate.
local TEXT_TAGS = {
	{ token = "[cur]",        name = "Current Value",      desc = "Current value of this bar's resource (short form)." },
	{ token = "[max]",        name = "Max Value",          desc = "Maximum value of this bar's resource (short form)." },
	{ token = "[curmax]",     name = "Current / Max",      desc = "Current and maximum, shown as cur/max (short form)." },
	{ token = "[percent]",    name = "Percent",            desc = "Current value as a percentage (0-100%)." },
	{ token = "[deficit]",    name = "Deficit",            desc = "Missing amount (max minus current)." },
	{ token = "[curfull]",    name = "Current (full)",     desc = "Current value, full number (not abbreviated)." },
	{ token = "[maxfull]",    name = "Max (full)",         desc = "Maximum value, full number (not abbreviated)." },
	{ token = "[curmaxfull]", name = "Current / Max (full)", desc = "Current and maximum as cur/max, full numbers." },
	{ token = "[name]",       name = "Resource Name",      desc = "Name of the resource (e.g. Energy)." },
	-- Absolute class resources: read THAT resource on any bar.
	{ token = "[combopoints]",   name = "Combo Points",   desc = "Current number of combo points.",   classes = { 4, 11 } },
	{ token = "[soulshards]",    name = "Soul Shards",    desc = "Current number of soul shards.",    classes = { 9 } },
	{ token = "[holypower]",     name = "Holy Power",     desc = "Current holy power.",               classes = { 2 } },
	{ token = "[chi]",           name = "Chi",            desc = "Current number of Chi.",            classes = { 10 } },
	{ token = "[arcanecharges]", name = "Arcane Charges", desc = "Current number of arcane charges.", classes = { 8 } },
	{ token = "[runes]",         name = "Runes",          desc = "Current number of ready runes.",    classes = { 6 } },
	{ token = "[runicpower]",    name = "Runic Power",    desc = "Current runic power.",              classes = { 6 } },
	{ token = "[essence]",       name = "Essence",        desc = "Current number of essence.",        classes = { 13 } },
	{ token = "[insanity]",      name = "Insanity",       desc = "Current insanity.",                 classes = { 5 } },
	{ token = "[maelstrom]",     name = "Maelstrom",      desc = "Current maelstrom.",                classes = { 7 } },
	{ token = "[astralpower]",   name = "Astral Power",   desc = "Current astral power.",             classes = { 11 } },
	{ token = "[fury]",          name = "Fury",           desc = "Current fury.",                     classes = { 12 } },
	{ token = "[mana]",          name = "Mana",           desc = "Current mana.",                     classes = { 2, 5, 7, 8, 9, 10, 11, 13 } },
}
for _, tag in ipairs(TEXT_TAGS) do tag.pat = "%s*" .. escapePattern(tag.token) end

local function tagAllowed(tag)
	if not tag.classes then return true end
	local cid = H.PlayerClassID()
	for i = 1, #tag.classes do
		if tag.classes[i] == cid then return true end
	end
	return false
end

local function buildTagToggles(barId, index)
	local args = {}
	for ti, tag in ipairs(TEXT_TAGS) do
		args["tag" .. ti] = {
			order = ti, type = "toggle", name = L[tag.name], desc = L[tag.desc],
			hidden = tag.classes and function() return not tagAllowed(tag) end or nil,
			get = function()
				local e = Chonk.db.profile.bars[barId].texts[index]
				return e ~= nil and e.text ~= nil and e.text:find(tag.token, 1, true) ~= nil
			end,
			set = function(_, value)
				local e = Chonk.db.profile.bars[barId].texts[index]
				if not e then return end
				local s = e.text or ""
				if value then
					if not s:find(tag.token, 1, true) then
						s = (s == "" and tag.token) or (s .. " " .. tag.token)
					end
				else
					s = s:gsub(tag.pat, ""):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
				end
				e.text = s
				Chonk:ApplySettings()
				AceConfigRegistry:NotifyChange("ChonkyBirb")
			end,
		}
	end
	return { order = 1.5, type = "group", inline = true, name = L["Tags"], args = args }
end

local function buildTextElement(barId, index)
	local tp = "bars." .. barId .. ".texts." .. index .. "."
	local tf = tp .. "font."
	local df = "barDefaults.font."
	local function notShadow()
		local e = Chonk.db.profile.bars[barId].texts[index]
		if not e then return true end
		local outline = e.font.outline
		if outline == nil then outline = Chonk.db.profile.barDefaults.font.outline end   -- effective
		return outline ~= "SHADOW"
	end
	return {
		order = 10 + index, type = "group", inline = true, name = L["Text"] .. " " .. index,
		args = {
			text = { order = 1, type = "input", width = "full", name = L["Text"],
				arg = tp .. "text", get = get, set = set },
			tags = buildTagToggles(barId, index),
			point = { order = 2, type = "select", name = L["Anchor"],
				values = TEXT_ANCHOR_VALUES, sorting = TEXT_ANCHORS, arg = tp .. "point", get = get, set = set },
			x = { order = 3, type = "range", name = L["X"], min = -300, max = 300, step = 1,
				arg = tp .. "x", get = get, set = set },
			y = { order = 4, type = "range", name = L["Y"], min = -300, max = 300, step = 1,
				arg = tp .. "y", get = get, set = set },
			-- Font fields inherit barDefaults.font until overridden here.
			face = { order = 5, type = "select", dialogControl = "LSM30_Font", values = fonts, name = L["Font"],
				arg = { tf .. "face", df .. "face" }, get = getInh, set = setInh },
			size = { order = 6, type = "range", name = L["Font Size"], min = 6, max = 32, step = 1,
				arg = { tf .. "size", df .. "size" }, get = getInh, set = setInh },
			outline = { order = 7, type = "select", name = L["Outline"], values = OUTLINE_VALUES, sorting = OUTLINE_SORT,
				arg = { tf .. "outline", df .. "outline" }, get = getInh, set = setInhNotify },
			color = { order = 8, type = "color", name = L["Font Color"], hasAlpha = true,
				arg = { tf .. "color", df .. "color" }, get = getInhColor, set = setInhColor },
			shadowColor = { order = 9, type = "color", name = L["Shadow Color"], hasAlpha = true,
				disabled = notShadow, arg = { tf .. "shadowColor", df .. "shadowColor" }, get = getInhColor, set = setInhColor },
			shadowX = { order = 10, type = "range", name = L["Shadow X"], min = -5, max = 5, step = 0.1,
				disabled = notShadow, arg = { tf .. "shadowX", df .. "shadowX" }, get = getInh, set = setInh },
			shadowY = { order = 11, type = "range", name = L["Shadow Y"], min = -5, max = 5, step = 0.1,
				disabled = notShadow, arg = { tf .. "shadowY", df .. "shadowY" }, get = getInh, set = setInh },
			resetFont = { order = 12, type = "execute", name = L["Reset to default"],
				desc = L["Clear this text's font overrides so it follows the global default font."],
				func = function()
					local e = Chonk.db.profile.bars[barId].texts[index]
					if e then wipe(e.font) end
					Chonk:ApplySettings()
					AceConfigRegistry:NotifyChange("ChonkyBirb")
				end },
			remove = { order = 20, type = "execute", name = L["Remove"],
				func = function()
					tremove(Chonk.db.profile.bars[barId].texts, index)
					Chonk:ApplySettings()
					AceConfigRegistry:NotifyChange("ChonkyBirb")
				end },
		},
	}
end

local function buildTextsGroup(barId)
	local cfg = Chonk.db.profile.bars[barId]
	local args = {
		add = { order = 1, type = "execute", name = L["Add Text"],
			func = function()
				tinsert(cfg.texts, Chonk.Text:DefaultElement())
				Chonk:ApplySettings()
				AceConfigRegistry:NotifyChange("ChonkyBirb")
			end },
	}
	for i = 1, #cfg.texts do
		args["text" .. i] = buildTextElement(barId, i)
	end
	return { order = 50, type = "group", name = L["Texts"], args = args }
end

-- One row per gate spell: icon + name + id, with a remove cross beside it.
local function addMarkerSpellRows(args, barId, index)
	local m = Chonk.db.profile.bars[barId].markers[index]
	local list = m and m.spellID
	if not list or not m.showMode then return end
	if type(list) ~= "table" then list = { list } end

	for si = 1, #list do
		local ident = list[si]
		local id = tonumber(ident)
		local name, icon
		if id then
			_, name, icon = H.ResolveSpell(id)
		end
		local label = name and string.format("%s (%d)", name, id) or tostring(ident)
		args["spell" .. si] = {
			order = 4.6 + si * 0.01, type = "description", width = 1.6, fontSize = "medium",
			name = label, image = icon, imageWidth = 16, imageHeight = 16,
		}
		args["spellRemove" .. si] = {
			order = 4.6 + si * 0.01 + 0.001, type = "execute", width = 0.4, name = L["Remove"],
			func = function()
				local mk = Chonk.db.profile.bars[barId].markers[index]
				local l = mk and mk.spellID
				if type(l) ~= "table" then
					if mk then mk.spellID = nil end
				else
					tremove(l, si)
					if #l == 0 then mk.spellID = nil end
				end
				Chonk:ApplySettings()
				AceConfigRegistry:NotifyChange("ChonkyBirb")
			end,
		}
	end
end

local function buildMarkerElement(barId, index)
	local mp = "bars." .. barId .. ".markers." .. index .. "."
	local element = {
		order = 10 + index, type = "group", inline = true, name = L["Marker"] .. " " .. index,
		args = {
			markerMode = { order = 0.9, type = "select", name = L["Marker Type"],
				values = { static = L["Static Value"], cost = L["Spell Cost"] },
				sorting = { "static", "cost" },
				get = function()
					local m = Chonk.db.profile.bars[barId].markers[index]
					return (m and m.mode) or "static"
				end,
				set = function(_, v)
					local m = Chonk.db.profile.bars[barId].markers[index]
					if m then m.mode = v ~= "static" and v or nil end
					Chonk:ApplySettings()
					AceConfigRegistry:NotifyChange("ChonkyBirb")
				end },
			value = { order = 1, type = "input", name = L["Value"],
				desc = L["Position of the marker, in resource value."],
				hidden = function()
					local m = Chonk.db.profile.bars[barId].markers[index]
					return m and m.mode == "cost"
				end,
				get = function()
					local m = Chonk.db.profile.bars[barId].markers[index]
					return m and tostring(m.value or 0) or "0"
				end,
				set = function(_, v)
					local n = tonumber(v)
					local m = Chonk.db.profile.bars[barId].markers[index]
					if not m or not n or n < 0 then return end
					m.value = n
					Chonk:ApplySettings()
				end },
			costSpell = { order = 1.1, type = "input", name = L["Spell"],
				desc = L["Spell ID, name, or a shift-clicked talent link."],
				hidden = function()
					local m = Chonk.db.profile.bars[barId].markers[index]
					return not (m and m.mode == "cost")
				end,
				get = function()
					local m = Chonk.db.profile.bars[barId].markers[index]
					local v = m and m.costSpell
					if not v then return "" end
					local id = tonumber(v)
					if not id then return tostring(v) end
					local _, name = H.ResolveSpell(id)
					return name and string.format("%s (%d)", name, id) or tostring(id)
				end,
				set = function(_, v)
					local m = Chonk.db.profile.bars[barId].markers[index]
					if not m then return end
					local displayId = v:match("^.+%((%d+)%)%s*$")
					local id = (displayId and tonumber(displayId)) or tonumber(v) or H.ResolveSpell(v)
					m.costSpell = id or (v ~= "" and v or nil)
					Chonk:ApplySettings()
					AceConfigRegistry:NotifyChange("ChonkyBirb")
				end },
			costInfo = { order = 1.15, type = "description", fontSize = "medium",
				hidden = function()
					local m = Chonk.db.profile.bars[barId].markers[index]
					return not (m and m.mode == "cost" and m.costSpell)
				end,
				name = function()
					local m = Chonk.db.profile.bars[barId].markers[index]
					if not (m and m.costSpell) then return "" end
					local pt
					local bars = Chonk.BarFactory and Chonk.BarFactory.bars
					if bars then
						for _, b in ipairs(bars) do
							if b.id == barId then pt = b.powerType break end
						end
					end
					local cost = H.SpellPowerCost(m.costSpell, pt)
					if cost then
						return string.format("|cff7fff7f%s %s|r", L["Cost:"], tostring(cost))
					end
					return "|cffff7f7f" .. L["No flat cost found for this bar's resource."] .. "|r"
				end },
			costCount = { order = 1.2, type = "range", name = L["Count"],
				desc = L["Places markers at 1x, 2x, 3x... the spell's cost."],
				min = 1, max = 10, step = 1,
				hidden = function()
					local m = Chonk.db.profile.bars[barId].markers[index]
					return not (m and m.mode == "cost")
				end,
				get = function()
					local m = Chonk.db.profile.bars[barId].markers[index]
					return (m and m.costCount) or 1
				end,
				set = function(_, v)
					local m = Chonk.db.profile.bars[barId].markers[index]
					if m then m.costCount = v end
					Chonk:ApplySettings()
				end },
			width = { order = 2, type = "range", name = L["Width"], desc = L["Marker thickness."],
				min = 1, max = 16, step = 1, arg = mp .. "width", get = get, set = set },
			heightMode = { order = 3, type = "select", name = L["Height"],
				values = { bar = L["Bar Height"], custom = L["Custom"] },
				sorting = { "bar", "custom" },
				get = function()
					local m = Chonk.db.profile.bars[barId].markers[index]
					return (m and m.height) and "custom" or "bar"
				end,
				set = function(_, v)
					local b = Chonk.db.profile.bars[barId]
					local m = b.markers[index]
					if not m then return end
					m.height = v == "custom" and b.height or nil
					Chonk:ApplySettings()
					AceConfigRegistry:NotifyChange("ChonkyBirb")
				end },
			height = { order = 3.1, type = "range", name = L["Custom Height"],
				min = 1, max = 100, step = 1,
				hidden = function()
					local m = Chonk.db.profile.bars[barId].markers[index]
					return not (m and m.height)
				end,
				get = function()
					local m = Chonk.db.profile.bars[barId].markers[index]
					return m and m.height or 1
				end,
				set = function(_, v)
					local m = Chonk.db.profile.bars[barId].markers[index]
					if m then m.height = v end
					Chonk:ApplySettings()
				end },
			color = { order = 4, type = "color", name = L["Marker Color"], hasAlpha = true,
				desc = L["Marker color and opacity."],
				arg = mp .. "color", get = getColor, set = setColor },
			showMode = { order = 4.5, type = "select", name = L["Show"],
				values = {
					always = L["Always"], allKnown = L["All spells are known"],
					anyKnown = L["At least one spell is known"], noneKnown = L["No spell is known"],
				},
				sorting = { "always", "allKnown", "anyKnown", "noneKnown" },
				get = function()
					local m = Chonk.db.profile.bars[barId].markers[index]
					local v = m and m.showMode
					if v == "known" then v = "allKnown" elseif v == "missing" then v = "noneKnown" end
					return v or "always"
				end,
				set = function(_, v)
					local m = Chonk.db.profile.bars[barId].markers[index]
					if m then m.showMode = v ~= "always" and v or nil end
					Chonk:ApplySettings()
					AceConfigRegistry:NotifyChange("ChonkyBirb")
				end },
			addSpell = { order = 4.6, type = "input", name = L["Add Spell"],
				desc = L["Spell ID, name, or a shift-clicked talent link."],
				hidden = function()
					local m = Chonk.db.profile.bars[barId].markers[index]
					return not (m and m.showMode)
				end,
				get = function() return "" end,
				set = function(_, v)
					local m = Chonk.db.profile.bars[barId].markers[index]
					if not m or v == "" then return end
					-- Keep unresolvable text as-is (an unlearned talent's name resolves once picked).
					local id = tonumber(v) or H.ResolveSpell(v) or v
					local list = m.spellID
					if type(list) ~= "table" then
						list = list ~= nil and { list } or {}
						m.spellID = list
					end
					list[#list + 1] = id
					Chonk:ApplySettings()
					AceConfigRegistry:NotifyChange("ChonkyBirb")
				end },
			remove = { order = 5, type = "execute", name = L["Remove"],
				func = function()
					tremove(Chonk.db.profile.bars[barId].markers, index)
					Chonk:ApplySettings()
					AceConfigRegistry:NotifyChange("ChonkyBirb")
				end },
		},
	}
	addMarkerSpellRows(element.args, barId, index)
	return element
end

local function buildMarkersGroup(barId)
	local cfg = Chonk.db.profile.bars[barId]
	local args = {
		add = { order = 1, type = "execute", name = L["Add Marker"],
			func = function()
				tinsert(cfg.markers, { value = 0, width = 2, color = { 1, 1, 1, 0.8 } })
				Chonk:ApplySettings()
				AceConfigRegistry:NotifyChange("ChonkyBirb")
			end },
	}
	for i = 1, #cfg.markers do
		args["marker" .. i] = buildMarkerElement(barId, i)
	end
	return { order = 52, type = "group", name = L["Markers"], args = args }
end

local function buildColorCurvePoint(barId, index)
	return {
		order = 10 + index, type = "group", inline = true, name = L["Color"] .. " " .. index,
		hidden = function() return Chonk.db.profile.bars[barId].color.mode ~= "curve" end,
		args = {
			pct = { order = 1, type = "range", name = L["Percent"], min = 0, max = 100, step = 1,
				get = function()
					local pt = Chonk.db.profile.bars[barId].color.curve.points[index]
					return math.floor(((pt and pt[1]) or 0) * 100 + 0.5)
				end,
				set = function(_, v)
					local pt = Chonk.db.profile.bars[barId].color.curve.points[index]
					if pt then pt[1] = v / 100 end
					Chonk:ApplySettings()
				end },
			color = { order = 2, type = "color", name = L["Color"], hasAlpha = true,
				get = function()
					local pt = Chonk.db.profile.bars[barId].color.curve.points[index]
					local c = pt and pt[2]
					if not c then return 1, 1, 1, 1 end
					return c[1] or 0, c[2] or 0, c[3] or 0, c[4] or 1
				end,
				set = function(_, r, g, b, a)
					local pt = Chonk.db.profile.bars[barId].color.curve.points[index]
					if pt then pt[2] = { r, g, b, a } end
					Chonk:ApplySettings()
				end },
			remove = { order = 3, type = "execute", name = L["Remove"],
				func = function()
					tremove(Chonk.db.profile.bars[barId].color.curve.points, index)
					Chonk:ApplySettings()
					AceConfigRegistry:NotifyChange("ChonkyBirb")
				end },
		},
	}
end

local function buildColorCurveGroup(id, p, eligible)
	local function notCurve() return Chonk.db.profile.bars[id].color.mode ~= "curve" end
	local group = {
		order = 53, type = "group", name = L["Color by percent"],
		hidden = not eligible,
		args = {
			mode = { order = 1, type = "select", name = L["Color Mode"],
				desc = L["The bar recolors based on its fill percentage."],
				values = { static = L["Static"], curve = L["By Percent"] },
				sorting = { "static", "curve" },
				arg = p .. "color.mode", get = get, set = setNotify },
			curveType = { order = 2, type = "select", name = L["Curve Type"],
				values = { step = L["Sharp Steps"], linear = L["Smooth Gradient"] },
				sorting = { "step", "linear" }, hidden = notCurve,
				get = function()
					local cv = Chonk.db.profile.bars[id].color.curve
					return (cv and cv.type) or "step"
				end,
				set = function(_, v)
					local color = Chonk.db.profile.bars[id].color
					color.curve = color.curve or { type = "step", points = {} }
					color.curve.type = v
					Chonk:ApplySettings()
				end },
			add = { order = 3, type = "execute", name = L["Add Color"], hidden = notCurve,
				func = function()
					local color = Chonk.db.profile.bars[id].color
					color.curve = color.curve or { type = "step", points = {} }
					tinsert(color.curve.points, { 0.5, { 1, 1, 1 } })
					Chonk:ApplySettings()
					AceConfigRegistry:NotifyChange("ChonkyBirb")
				end },
		},
	}
	local cv = Chonk.db.profile.bars[id].color.curve
	for i = 1, (cv and #cv.points or 0) do
		group.args["point" .. i] = buildColorCurvePoint(id, i)
	end
	return group
end

-- Copy from = visual look + position only (texts/visibility/enabled stay).
-- Explicit field list because AceDB serves defaults via metatable and pairs() would miss them.
local COPY_FIELDS = { "width", "height", "texture", "border", "background", "color", "segment",
	"fillDirection", "strata", "position" }

local function copyBarSettings(srcId, dstId)
	if srcId == dstId then return end
	local src = Chonk.db.profile.bars[srcId]
	local dst = Chonk.db.profile.bars[dstId]
	for _, field in ipairs(COPY_FIELDS) do
		local v = src[field]
		if type(v) == "table" then
			dst[field] = CopyTable(v)
		else
			dst[field] = v
		end
	end
end

-- Prediction options only show on bars whose resource has curated generators.
local function powerTypeHasCastGen(pt)
	if pt == nil then return false end
	for _, entry in pairs(Chonk.CastGen) do
		if entry.pt == pt then return true end
	end
	return false
end

-- Brewmaster stagger: one colour per Blizzard threshold (light/moderate/heavy).
local function staggerColorOption(id, level, order, nameKey)
	return {
		order = order, type = "color", name = L[nameKey], hasAlpha = true,
		get = function()
			local b = Chonk.db.profile.bars[id]
			local c = (b.staggerColors and b.staggerColors[level]) or Chonk.StaggerColors[level]
			return c[1], c[2], c[3], c[4] or 1
		end,
		set = function(_, r, g, b, a)
			local bar = Chonk.db.profile.bars[id]
			bar.staggerColors = bar.staggerColors or {}
			bar.staggerColors[level] = { r, g, b, a }
			Chonk:ApplySettings()
		end,
	}
end

local function buildStaggerColorsGroup(desc, id)
	return {
		order = 17.7, type = "group", inline = true, name = L["Stagger Colors"],
		hidden = desc.source ~= "stagger",
		args = {
			light    = staggerColorOption(id, "light", 1, "Light"),
			moderate = staggerColorOption(id, "moderate", 2, "Moderate"),
			heavy    = staggerColorOption(id, "heavy", 3, "Heavy"),
		},
	}
end

local function buildCastPredictionGroup(desc, id, p)
	local function off() return not Chonk.db.profile.bars[id].castPredict end
	return {
		order = 55, type = "group", name = L["Cast Prediction"],
		hidden = not powerTypeHasCastGen(desc.powerType),
		args = {
			castPredict = {
				order = 1, type = "toggle", name = L["Predict cast generation"], width = "double",
				desc = L["While casting, preview the resource the cast will generate as a ghost segment."],
				arg = p .. "castPredict", get = get, set = setNotify,
			},
			spacer = { order = 1.5, type = "description", name = " " },
			castColorMode = {
				order = 2, type = "select", name = L["Color Mode"],
				values = { bar = L["Bar Color + Opacity"], custom = L["Custom Color"] },
				sorting = { "bar", "custom" },
				disabled = off,
				arg = p .. "castColorMode", get = get, set = setNotify,
			},
			castAlpha = {
				order = 3, type = "range", name = L["Opacity"], min = 0, max = 1, step = 0.05, isPercent = true,
				hidden = function() return Chonk.db.profile.bars[id].castColorMode == "custom" end,
				disabled = off,
				arg = p .. "castAlpha", get = get, set = set,
			},
			castColor = {
				order = 4, type = "color", name = L["Prediction Color"], hasAlpha = true,
				desc = L["Color and opacity of the cast-prediction ghost."],
				hidden = function() return Chonk.db.profile.bars[id].castColorMode ~= "custom" end,
				disabled = off,
				arg = p .. "castColor", get = getColor, set = setColor,
			},
		},
	}
end

local function buildBarGroup(desc, order)
	local id = desc.id
	local p = "bars." .. id .. "."
	-- X/Y bounds follow the resolution; the real guard is the clamp in ResourceBar:Position.
	local uw, uh = math.floor(UIParent:GetWidth()), math.floor(UIParent:GetHeight())
	local colorByPct = desc.source == "health"
		or (desc.powerType ~= nil and (desc.source == "power" or desc.source == "essence"))
	local hasRecharge = desc.source == "runes" or desc.source == "essence"

	return {
		order = order, type = "group", name = desc.label or id,
		args = {
			enabled = {
				order = 1, type = "toggle", name = L["Enabled"],
				arg = p .. "enabled", get = get, set = set,
			},
			copyFrom = {
				order = 2, type = "select", name = L["Copy settings from"],
				desc = L["Copy another bar's look + position onto this one. Tags, visibility and the enabled state are kept."],
				values = function()
					local t = {}
					local descs = Chonk:GetBarsForSpec(H.PlayerClassID(), H.PlayerSpecIndex())
					for _, d in ipairs(descs) do
						if d.id ~= id then t[d.id] = d.label or d.id end
					end
					return t
				end,
				get = function() return nil end,   -- action select, nothing stays selected
				set = function(_, srcId)
					copyBarSettings(srcId, id)
					Chonk:ApplySettings()
					AceConfigRegistry:NotifyChange("ChonkyBirb")
				end,
			},
			sizeHeader = { order = 5, type = "header", name = L["Width"] .. " / " .. L["Height"] },
			width = {
				order = 6, type = "range", name = L["Width"],
				min = 20, max = 600, step = 1, arg = p .. "width", get = get, set = set,
			},
			height = {
				order = 7, type = "range", name = L["Height"],
				min = 4, max = 100, step = 1, arg = p .. "height", get = get, set = set,
			},
			posHeader = { order = 8, type = "header", name = L["Position"] },
			anchor = {
				order = 8.1, type = "select", name = L["Anchor"],
				values = TEXT_ANCHOR_VALUES, sorting = TEXT_ANCHORS,
				arg = p .. "position.point", get = get, set = set,
			},
			posX = {
				order = 8.2, type = "range", name = L["Position X"],
				min = -uw, max = uw, step = 1, arg = p .. "position.x", get = get, set = set,
			},
			posY = {
				order = 8.3, type = "range", name = L["Position Y"],
				min = -uh, max = uh, step = 1, arg = p .. "position.y", get = get, set = set,
			},
			scale = {
				order = 8.4, type = "range", name = L["Scale"],
				min = 0.5, max = 2, step = 0.05, arg = p .. "position.scale", get = get, set = set,
			},
			strata = {
				order = 8.5, type = "select", name = L["Strata"],
				desc = L["Display layer. A bar on a higher strata fully covers a lower one (text included)."],
				values = STRATA_VALUES, sorting = STRATA_SORT,
				arg = { p .. "strata", "barDefaults.strata" }, get = getInh, set = setInh,
			},
			barHeader = { order = 15, type = "header", name = L["Bar Texture"] },
			texture = {
				order = 16, type = "select", name = L["Bar Texture"],
				dialogControl = "LSM30_Statusbar", values = statusbars,
				arg = p .. "texture", get = get, set = set,
			},
			barColor = {
				order = 17, type = "color", name = L["Bar Color"], hasAlpha = true,
				disabled = function() return Chonk.db.profile.bars[id].color.mode == "curve" end,
				arg = p .. "color.static", get = getColor, set = setColor,
			},
			colorCurve = buildColorCurveGroup(id, p, colorByPct),
			staggerColors = buildStaggerColorsGroup(desc, id),
			fillDirection = {
				order = 18, type = "select", name = L["Fill Direction"],
				values = {
					right = L["Left to Right"], left = L["Right to Left"],
					up = L["Bottom to Top"], down = L["Top to Bottom"],
				},
				sorting = FILL_DIRECTIONS, arg = p .. "fillDirection", get = get, set = set,
			},
			pipGap = {
				order = 19, type = "range", name = L["Segment Spacing"],
				desc = L["Gap between segments, in pixels."],
				min = 0, max = 20, step = 1,
				hidden = desc.kind ~= "segmented",
				arg = p .. "segment.gap", get = get, set = set,
			},
			pipOffMode = {
				order = 19.3, type = "select", name = L["Inactive Segments"],
				values = { alpha = L["Opacity"], color = L["Color + Opacity"] },
				sorting = { "alpha", "color" },
				hidden = desc.kind ~= "segmented",
				arg = p .. "segment.offMode", get = get, set = setNotify,
			},
			pipOffAlpha = {
				order = 19.4, type = "range", name = L["Opacity"], min = 0, max = 1, step = 0.05, isPercent = true,
				hidden = function() return desc.kind ~= "segmented" or Chonk.db.profile.bars[id].segment.offMode == "color" end,
				arg = p .. "segment.offAlpha", get = get, set = set,
			},
			pipOffColor = {
				order = 19.4, type = "color", name = L["Inactive Segment Color"], hasAlpha = true,
				hidden = function() return desc.kind ~= "segmented" or Chonk.db.profile.bars[id].segment.offMode ~= "color" end,
				arg = p .. "segment.offColor", get = getColor, set = setColor,
			},
			rechargeMode = {
				order = 19.6, type = "select", name = L["Recharge Display"],
				values = { alpha = L["Opacity"], color = L["Color + Opacity"] },
				sorting = { "alpha", "color" },
				hidden = not hasRecharge,
				arg = p .. "recharge.mode", get = get, set = setNotify,
			},
			rechargeAlpha = {
				order = 19.7, type = "range", name = L["Opacity"], min = 0, max = 1, step = 0.05, isPercent = true,
				hidden = function() return not hasRecharge or Chonk.db.profile.bars[id].recharge.mode == "color" end,
				arg = p .. "recharge.alpha", get = get, set = set,
			},
			rechargeColor = {
				order = 19.7, type = "color", name = L["Recharge Color"], hasAlpha = true,
				hidden = function() return not hasRecharge or Chonk.db.profile.bars[id].recharge.mode ~= "color" end,
				arg = p .. "recharge.color", get = getColor, set = setColor,
			},
			bgHeader = { order = 25, type = "header", name = L["Background Texture"] },
			bgTexture = {
				order = 26, type = "select", name = L["Background Texture"],
				dialogControl = "LSM30_Background", values = backgrounds,
				arg = { p .. "background.texture", "barDefaults.background.texture" }, get = getInh, set = setInh,
			},
			bgColor = {
				order = 27, type = "color", name = L["Background Color"], hasAlpha = true,
				arg = { p .. "background.color", "barDefaults.background.color" }, get = getInhColor, set = setInhColor,
			},
			borderHeader = { order = 35, type = "header", name = L["Border Texture"] },
			borderTexture = {
				order = 36, type = "select", name = L["Border Texture"],
				dialogControl = "LSM30_Border", values = borders,
				arg = { p .. "border.edge", "barDefaults.border.edge" }, get = getInh, set = setInh,
			},
			borderSize = {
				order = 37, type = "range", name = L["Border Size"],
				min = 0, max = 16, step = 1, arg = { p .. "border.size", "barDefaults.border.size" }, get = getInh, set = setInh,
			},
			borderColor = {
				order = 38, type = "color", name = L["Border Color"], hasAlpha = true,
				arg = { p .. "border.color", "barDefaults.border.color" }, get = getInhColor, set = setInhColor,
			},
			resetAppearance = {
				order = 39, type = "execute", name = L["Reset to default"],
				desc = L["Clear this bar's border & background overrides so they follow the global defaults."],
				func = function()
					local b = Chonk.db.profile.bars[id]
					wipe(b.border)
					wipe(b.background)
					b.strata = nil   -- back to inheriting barDefaults.strata
					Chonk:ApplySettings()
					AceConfigRegistry:NotifyChange("ChonkyBirb")
				end,
			},
			texts = buildTextsGroup(id),
			markers = buildMarkersGroup(id),
			castPrediction = buildCastPredictionGroup(desc, id, p),
			visibility = buildVisibilityGroup(id, p),
		},
	}
end

------------------------------------------------------------
-- Top-level groups
------------------------------------------------------------

local function defNotShadow() return Chonk.db.profile.barDefaults.font.outline ~= "SHADOW" end

local function groupNotLinked() return not Chonk.db.profile.linkBars end

-- Group slider: shift every enabled bar by the delta, clamped so the group's box stays on-screen.
-- The slider sticks at the edge instead of overshooting, same as a linked drag.
local function groupMove(axis, value)
	local g = Chonk.db.profile.linkGroup
	local delta = value - (g[axis] or 0)
	local bars = Chonk.BarFactory and Chonk.BarFactory.bars
	if not bars then return end

	local dMin, dMax = -math.huge, math.huge
	for i = 1, #bars do
		local bar = bars[i]
		if bar.cfg.enabled then
			local minX, maxX, minY, maxY = bar:ClampBounds()
			local cur = bar.cfg.position[axis] or 0
			local lo = (axis == "x") and minX or minY
			local hi = (axis == "x") and maxX or maxY
			if lo - cur > dMin then dMin = lo - cur end
			if hi - cur < dMax then dMax = hi - cur end
		end
	end
	if delta < dMin then delta = dMin elseif delta > dMax then delta = dMax end
	g[axis] = (g[axis] or 0) + delta

	for i = 1, #bars do
		local bar = bars[i]
		if bar.cfg.enabled then
			bar.cfg.position[axis] = (bar.cfg.position[axis] or 0) + delta
			bar.cfg.position._seeded = true
			bar:Position()
		end
	end
end

local function buildGeneralGroup()
	local uw, uh = math.floor(UIParent:GetWidth()), math.floor(UIParent:GetHeight())
	return {
		order = 1, type = "group", name = L["General"],
		args = {
			linkBars = {
				order = 5, type = "toggle", name = L["Link bars"], width = "double",
				desc = L["Drag one bar and they all move together."],
				arg = "linkBars", get = get, set = setNotify,
			},
			groupMoveHeader = { order = 6, type = "header", name = L["Move group"], hidden = groupNotLinked },
			groupX = {
				order = 6.1, type = "range", name = L["Position X"], min = -uw, max = uw, step = 1,
				hidden = groupNotLinked,
				get = function() return Chonk.db.profile.linkGroup.x end,
				set = function(_, v) groupMove("x", v) end,
			},
			groupY = {
				order = 6.2, type = "range", name = L["Position Y"], min = -uh, max = uh, step = 1,
				hidden = groupNotLinked,
				get = function() return Chonk.db.profile.linkGroup.y end,
				set = function(_, v) groupMove("y", v) end,
			},
			defaultsHeader = { order = 10, type = "header", name = L["Default appearance (all bars)"] },
			defaultFont = {
				order = 11, type = "group", inline = true, name = L["Default Font"],
				args = {
					face = { order = 1, type = "select", dialogControl = "LSM30_Font", values = fonts, name = L["Font"],
						arg = "barDefaults.font.face", get = get, set = set },
					size = { order = 2, type = "range", name = L["Font Size"], min = 6, max = 32, step = 1,
						arg = "barDefaults.font.size", get = get, set = set },
					outline = { order = 3, type = "select", name = L["Outline"], values = OUTLINE_VALUES, sorting = OUTLINE_SORT,
						arg = "barDefaults.font.outline", get = get, set = setNotify },
					color = { order = 4, type = "color", name = L["Font Color"], hasAlpha = true,
						arg = "barDefaults.font.color", get = getColor, set = setColor },
					shadowColor = { order = 5, type = "color", name = L["Shadow Color"], hasAlpha = true,
						disabled = defNotShadow, arg = "barDefaults.font.shadowColor", get = getColor, set = setColor },
					shadowX = { order = 6, type = "range", name = L["Shadow X"], min = -5, max = 5, step = 0.1,
						disabled = defNotShadow, arg = "barDefaults.font.shadowX", get = get, set = set },
					shadowY = { order = 7, type = "range", name = L["Shadow Y"], min = -5, max = 5, step = 0.1,
						disabled = defNotShadow, arg = "barDefaults.font.shadowY", get = get, set = set },
				},
			},
			defaultBorder = {
				order = 12, type = "group", inline = true, name = L["Default Border"],
				args = {
					edge = { order = 1, type = "select", dialogControl = "LSM30_Border", values = borders, name = L["Border Texture"],
						arg = "barDefaults.border.edge", get = get, set = set },
					size = { order = 2, type = "range", name = L["Border Size"], min = 0, max = 16, step = 1,
						arg = "barDefaults.border.size", get = get, set = set },
					color = { order = 3, type = "color", name = L["Border Color"], hasAlpha = true,
						arg = "barDefaults.border.color", get = getColor, set = setColor },
				},
			},
			defaultBackground = {
				order = 13, type = "group", inline = true, name = L["Default Background"],
				args = {
					texture = { order = 1, type = "select", dialogControl = "LSM30_Background", values = backgrounds, name = L["Background Texture"],
						arg = "barDefaults.background.texture", get = get, set = set },
					color = { order = 2, type = "color", name = L["Background Color"], hasAlpha = true,
						arg = "barDefaults.background.color", get = getColor, set = setColor },
				},
			},
			strata = {
				order = 19, type = "select", name = L["Strata"],
				desc = L["Display layer. A bar on a higher strata fully covers a lower one (text included)."],
				values = STRATA_VALUES, sorting = STRATA_SORT,
				arg = "barDefaults.strata", get = get, set = set,
			},
			autoHideHeader = { order = 20, type = "header", name = L["Auto-hide all bars while"] },
			autoHideMounted = {
				order = 21, type = "toggle", name = L["Mounted"],
				arg = "autoHide.mounted", get = get, set = set,
			},
			autoHideVehicle = {
				order = 22, type = "toggle", name = L["In Vehicle"],
				arg = "autoHide.vehicle", get = get, set = set,
			},
			autoHidePetBattle = {
				order = 23, type = "toggle", name = L["Pet Battle"],
				arg = "autoHide.petBattle", get = get, set = set,
			},
			blizzHeader = { order = 30, type = "header", name = L["Blizzard frames"] },
			hidePRD = {
				order = 31, type = "toggle", name = L["Hide Blizzard Resource Bars"], width = "double",
				desc = L["Hide Blizzard's detached resource bars."],
				get = function() return Chonk.db.profile.hidePRD end,
				set = function(_, value)
					Chonk.db.profile.hidePRD = value
					Chonk.BlizzHide:SetPRD(value)
				end,
			},
		},
	}
end

-- Rebuilt on each options open, so a spec change shows the right bar list.
local function buildBarsArgs()
	local args = {}
	local descs = Chonk:GetBarsForSpec(H.PlayerClassID(), H.PlayerSpecIndex())
	for i = 1, #descs do
		args[descs[i].id] = buildBarGroup(descs[i], i)
	end
	return args
end

local function buildProfilesGroup()
	local tbl = LibStub("AceDBOptions-3.0"):GetOptionsTable(Chonk.db)
	LibStub("LibDualSpec-1.0"):EnhanceOptions(tbl, Chonk.db)
	tbl.order = 100
	return tbl
end

local function buildOptions()
	return {
		type = "group", name = "Chonky Birb", childGroups = "tab",
		args = {
			unlock = {
				order = 0, type = "execute",
				name = function() return Chonk.db.profile.locked and L["Unlock"] or L["Lock"] end,
				desc = L["Unlock bars to drag and position them; every bar is shown while unlocked."],
				func = function()
					Chonk.db.profile.locked = not Chonk.db.profile.locked
					Chonk:ApplySettings()
					if Chonk.Visibility then Chonk.Visibility:MarkDirty() end
					AceConfigRegistry:NotifyChange("ChonkyBirb")
				end,
			},
			general = buildGeneralGroup(),
			bars = {
				order = 2, type = "group", name = L["Bars"], childGroups = "tree",
				args = buildBarsArgs(),
			},
			profiles = buildProfilesGroup(),
		},
	}
end

function Chonk:OpenConfig()
	if not registered then
		AceConfigRegistry:RegisterOptionsTable("ChonkyBirb", buildOptions)   -- function = re-enumerated per open
		AceConfigDialog:SetDefaultSize("ChonkyBirb", 780, 580)
		registered = true
	end
	AceConfigDialog:Open("ChonkyBirb")
end
