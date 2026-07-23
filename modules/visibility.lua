local ADDON, Chonk = ...

-- Show/hide engine: plain-boolean context + per-bar rules + global auto-hide.

local Vis = Chonk:RegisterModule({}, "visibility", "Visibility")
Chonk.Visibility = Vis

-- Context only reads plain-returning status APIs; target-dependent calls sit under pcall.
function Vis:RefreshContext()
	local ctx = {}

	ctx.inCombat = InCombatLockdown()

	local okV, inVehicle = pcall(UnitInVehicle, "player")
	ctx.inVehicle = okV and inVehicle or false

	ctx.inPetBattle = (C_PetBattles and C_PetBattles.IsInBattle()) or false
	ctx.perched = IsMounted()
	ctx.flappin = IsFlying() or false

	local okT, onTaxi = pcall(UnitOnTaxi, "player")
	ctx.onTaxi = okT and onTaxi or false

	-- Instanced zones are nests: smol (5-man), big (raid), battle (BG), arena.
	local inInstance, instanceType = IsInInstance()
	ctx.inNest = inInstance or false
	ctx.instanceType = instanceType
	ctx.inSmolNest = instanceType == "party"
	ctx.inBigNest = instanceType == "raid"
	ctx.inBattleNest = instanceType == "pvp"
	ctx.inArenaNest = instanceType == "arena"

	local hasTarget = UnitExists("target")
	ctx.hasTarget = hasTarget or false
	if hasTarget then
		-- UnitCanAttack is true for neutral (yellow) mobs too; angy means red reaction only.
		local okA, isEnemy = pcall(UnitIsEnemy, "player", "target")
		ctx.targetAngy = okA and isEnemy or false
		local okC, canAttack = pcall(UnitCanAttack, "player", "target")
		ctx.targetSnacc = okC and canAttack or false
		local okF, isFriend = pcall(UnitIsFriend, "player", "target")
		ctx.targetFren = okF and isFriend or false
	else
		ctx.targetAngy = false
		ctx.targetSnacc = false
		ctx.targetFren = false
	end

	ctx.inFlock = IsInGroup()
	ctx.inBigFlock = IsInRaid()
	ctx.pvpRuffled = UnitIsPVP("player") or false
	ctx.warMode = (C_PvP and C_PvP.IsWarModeActive and C_PvP.IsWarModeActive()) or false

	-- Plain return; keep the last good value if the token doesn't resolve.
	local okP, displayPower = pcall(UnitPowerType, "player")
	if okP then self.displayPower = displayPower end
	ctx.displayPower = self.displayPower

	local forms = Chonk.Forms:Get()
	for k, v in pairs(forms) do
		ctx[k] = v
	end

	self.context = ctx
	return ctx
end

-- Secondary resources ride along with their spender's display power.
local SECONDARY_DISPLAY = { [Enum.PowerType.ComboPoints] = Enum.PowerType.Energy }

-- Global auto-hide first, then mode always/auto/never/custom (custom = OR of the checked conditions).
function Vis:ShouldShow(context, rule, bar)
	local ah = Chonk.db.profile.autoHide
	if ah then
		if ah.mounted and context.perched then return false end
		if ah.vehicle and context.inVehicle then return false end
		if ah.petBattle and context.inPetBattle then return false end
	end

	if not rule then return true end
	local mode = rule.mode or "always"
	if mode == "always" then return true end
	if mode == "never" then return false end

	-- Automatic: the bar shows while its resource is the relevant one; druids get their own matrix.
	if mode == "auto" then
		if Chonk.Helpers.PlayerClassID() == 11 and bar and Chonk.DruidAuto[bar.id] then
			return Chonk.DruidAuto[bar.id](context, Chonk.Helpers.PlayerSpecIndex()) or false
		end
		local pt = bar and bar.powerType
		if not pt then return true end
		local want = SECONDARY_DISPLAY[pt] or pt
		return context.displayPower == want
	end

	local conds = rule.conditions
	if conds then
		for k, on in pairs(conds) do
			if on and context[k] then return true end
		end
	end
	return false
end

function Vis:ProcessAll()
	-- The safety ticker can fire before PLAYER_LOGIN created the DB.
	if not (Chonk.db and Chonk.db.profile) then return end

	local bars = Chonk.BarFactory and Chonk.BarFactory.bars
	if not bars then return end

	-- Unlocked = positioning preview: every enabled bar shows.
	if not Chonk.db.profile.locked then
		for i = 1, #bars do
			bars[i].container:SetShown(bars[i].cfg.enabled)
		end
		return
	end

	self:RefreshContext()
	for i = 1, #bars do
		local bar = bars[i]
		if not bar.cfg.enabled then
			bar.container:Hide()
		else
			bar.container:SetShown(self:ShouldShow(self.context, bar.cfg.visibility, bar))
		end
	end
end

function Vis:MarkDirty()
	if self._scheduled then return end
	self._scheduled = true
	C_Timer.After(0, function()
		Vis._scheduled = false
		Vis:ProcessAll()
	end)
end

function Vis:OnProfileChange()
	self:MarkDirty()
end

local driver = CreateFrame("Frame")
Vis.driver = driver

local EVENTS = {
	"PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED",
	"UPDATE_SHAPESHIFT_FORM", "UPDATE_SHAPESHIFT_FORMS",
	"PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA",
	"UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE",
	"PLAYER_MOUNT_DISPLAY_CHANGED", "PLAYER_TARGET_CHANGED",
	"GROUP_ROSTER_UPDATE", "PLAYER_FLAGS_CHANGED",
}
for i = 1, #EVENTS do
	driver:RegisterEvent(EVENTS[i])
end
driver:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")

driver:SetScript("OnEvent", function()
	Vis:MarkDirty()
end)

-- Safety net for state changes no event fires for.
C_Timer.NewTicker(0.5, function()
	Vis:MarkDirty()
end)
