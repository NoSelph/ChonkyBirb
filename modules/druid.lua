local ADDON, Chonk = ...

local H = Chonk.Helpers

local D = Chonk.BarDefs
local C = Chonk.BarColors
local PT = Enum.PowerType

-- Druid: form-dependent, several power bars per spec, Automatic visibility by default.
local AUTO = { mode = "auto" }

Chonk.Registry[11] = {
	[1] = {
		D.power("astralPower", "Astral Power", PT.LunarPower, C.astral, AUTO),
		D.power("mana", "Mana", PT.Mana, C.mana, AUTO),
		D.power("energy", "Energy", PT.Energy, C.energy, AUTO),
		D.power("rage", "Rage", PT.Rage, C.rage, AUTO),
		D.seg("comboPoints", "Combo Points", PT.ComboPoints, C.combo, 5, AUTO),
		D.health(),
	},
	[2] = {
		D.power("energy", "Energy", PT.Energy, C.energy, AUTO),
		D.seg("comboPoints", "Combo Points", PT.ComboPoints, C.combo, 5, AUTO),
		D.power("rage", "Rage", PT.Rage, C.rage, AUTO),
		D.power("mana", "Mana", PT.Mana, C.mana, AUTO),
		D.health(),
	},
	[3] = {
		D.power("rage", "Rage", PT.Rage, C.rage, AUTO),
		D.power("energy", "Energy", PT.Energy, C.energy, AUTO),
		D.seg("comboPoints", "Combo Points", PT.ComboPoints, C.combo, 5, AUTO),
		D.power("mana", "Mana", PT.Mana, C.mana, AUTO),
		D.health(),
	},
	[4] = {
		D.power("mana", "Mana", PT.Mana, C.mana, AUTO),
		D.power("rage", "Rage", PT.Rage, C.rage, AUTO),
		D.power("energy", "Energy", PT.Energy, C.energy, AUTO),
		D.health(),
	},
}

-- Automatic visibility, per bar id: which spec/form combos actually use that resource.
-- Travel/flight/aquatic count as casterish (anything that's not cat/bear/borb).
local function casterish(ctx)
	return not (ctx.formMurderMittens or ctx.formAbsoluteUnit or ctx.formBorb)
end

Chonk.DruidAuto = {
	rage        = function(ctx, spec) return ctx.formAbsoluteUnit or (spec == 3 and casterish(ctx)) end,
	energy      = function(ctx, spec) return ctx.formMurderMittens or (spec == 2 and casterish(ctx)) end,
	comboPoints = function(ctx, spec) return ctx.formMurderMittens or (spec == 2 and casterish(ctx)) end,
	astralPower = function(ctx, spec) return spec == 1 and (ctx.formBorb or casterish(ctx)) end,
	mana        = function(ctx, spec) return spec == 4 end,
}

-- Cast-time Astral Power generation (Balance; base values).
Chonk.CastGen[190984] = { pt = PT.LunarPower, amount = 6 }    -- Wrath
Chonk.CastGen[194153] = { pt = PT.LunarPower, amount = 8 }    -- Starfire
Chonk.CastGen[202347] = { pt = PT.LunarPower, amount = 12 }   -- Stellar Flare
Chonk.CastGen[274281] = { pt = PT.LunarPower, amount = 10 }   -- New Moon
Chonk.CastGen[274282] = { pt = PT.LunarPower, amount = 20 }   -- Half Moon
Chonk.CastGen[274283] = { pt = PT.LunarPower, amount = 40 }   -- Full Moon

-- Raw GetShapeshiftFormID() -> context key; the DRUID_* globals don't cover every form.
-- Moonkin alone has several variant ids (glyphs/races).
local FORM_KEYS = {
	[1] = "formMurderMittens", [3] = "formZoomies", [4] = "formSoggy", [5] = "formAbsoluteUnit",
	[27] = "formTurboBirb", [29] = "formBirb",
	[31] = "formBorb", [32] = "formBorb", [33] = "formBorb", [34] = "formBorb", [35] = "formBorb",
}
local ZOOMIES_KEYS = { formZoomies = true, formSoggy = true, formTurboBirb = true, formBirb = true }

local Forms = {}
Chonk.Forms = Forms

local DRUID = 11

function Forms:Get()
	local formId
	local ok, id = pcall(GetShapeshiftFormID)   -- no-arg untainted global -> plain number or nil
	if ok then formId = id end

	local ctx = {
		formId = formId,
		formMurderMittens = false, formAbsoluteUnit = false, formBorb = false,
		formZoomies = false, formSoggy = false, formBirb = false, formTurboBirb = false,
		formAnyZoomies = false, formJustAGuy = false,
	}

	if H.PlayerClassID() ~= DRUID then
		return ctx
	end

	-- plain number -> safe as a table key.
	local key = formId and FORM_KEYS[formId]
	if key then
		ctx[key] = true
		ctx.formAnyZoomies = ZOOMIES_KEYS[key] or false
	end
	ctx.formJustAGuy = formId == nil or formId == 0

	return ctx
end
