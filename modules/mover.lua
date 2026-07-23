local ADDON, Chonk = ...

-- Unlock drag: move bars around and persist their per-bar anchor position.

local L = LibStub("AceLocale-3.0"):GetLocale("ChonkyBirb")

local Mover = Chonk:RegisterModule({}, "mover", "Mover")
Chonk.Mover = Mover

-- Inverse of ResourceBar:Position — the dragged spot becomes the bar's own anchor offset from UIParent's same point.
-- Container coords x scale = UIParent units.
local function savePosition(bar)
	local c = bar.container
	local l, b, w, h = c:GetRect()
	if not l then return end
	local s = c:GetScale()
	local pos = bar.cfg.position
	local f = Chonk.AnchorPoints[pos.point] or Chonk.AnchorPoints.CENTER
	local px = (l + w * f[1]) * s
	local py = (b + h * f[2]) * s
	pos.x = px - UIParent:GetWidth() * f[1]
	pos.y = py - UIParent:GetHeight() * f[2]
	pos._seeded = true
end

local function enabledBars()
	local t = {}
	local bars = Chonk.BarFactory and Chonk.BarFactory.bars
	if bars then
		for i = 1, #bars do
			if bars[i].cfg.enabled then t[#t + 1] = bars[i] end
		end
	end
	return t
end

-- Shift the whole group by one UIParent-unit delta, clamped so the group's bounding box stays on-screen.
-- Clamping the box instead of each bar keeps the relative offsets exact, no bunching at the edges.
local function applyGroupDelta(base, dx, dy)
	local dxMin, dxMax, dyMin, dyMax = -math.huge, math.huge, -math.huge, math.huge
	for bar, b0 in pairs(base) do
		local minX, maxX, minY, maxY = bar:ClampBounds()
		if minX - b0.x > dxMin then dxMin = minX - b0.x end
		if maxX - b0.x < dxMax then dxMax = maxX - b0.x end
		if minY - b0.y > dyMin then dyMin = minY - b0.y end
		if maxY - b0.y < dyMax then dyMax = maxY - b0.y end
	end
	if dx < dxMin then dx = dxMin elseif dx > dxMax then dx = dxMax end
	if dy < dyMin then dy = dyMin elseif dy > dyMax then dy = dyMax end
	for bar, b0 in pairs(base) do
		bar.cfg.position.x = b0.x + dx
		bar.cfg.position.y = b0.y + dy
		bar.cfg.position._seeded = true
		bar:Position()   -- pre-clamped delta -> the per-bar clamp is a no-op here
	end
	return dx, dy
end

local function enableDrag(bar)
	local c = bar.container
	c:SetMovable(true)
	c:EnableMouse(true)
	c:RegisterForDrag("LeftButton")
	c:SetScript("OnDragStart", function(f)
		if Chonk.db.profile.linkBars then
			-- Track the cursor and move the group as one; no StartMoving on the grabbed bar so it can't outrun the clamped group.
			local es = UIParent:GetEffectiveScale()
			local cx, cy = GetCursorPosition()
			local base = {}
			for _, b in ipairs(enabledBars()) do
				base[b] = { x = b.cfg.position.x or 0, y = b.cfg.position.y or 0 }
			end
			Mover.groupBase = base
			Mover.groupApplied = nil
			f:SetScript("OnUpdate", function()
				local ncx, ncy = GetCursorPosition()
				local ax, ay = applyGroupDelta(base, (ncx - cx) / es, (ncy - cy) / es)
				Mover.groupApplied = { x = ax, y = ay }
			end)
		else
			f:StartMoving()
		end
	end)
	c:SetScript("OnDragStop", function(f)
		f:SetScript("OnUpdate", nil)
		if Mover.groupBase then
			-- Fold the net group move into the slider handle so the X/Y sliders reflect the drag.
			local a = Mover.groupApplied
			if a then
				local g = Chonk.db.profile.linkGroup
				g.x, g.y = (g.x or 0) + a.x, (g.y or 0) + a.y
			end
			Mover.groupBase, Mover.groupApplied = nil, nil   -- positions already applied each frame
		else
			f:StopMovingOrSizing()
			savePosition(bar)
			bar:Position()
		end
		local reg = LibStub("AceConfigRegistry-3.0", true)
		if reg then reg:NotifyChange("ChonkyBirb") end
	end)
end

local function disableDrag(bar)
	local c = bar.container
	c:SetScript("OnDragStart", nil)
	c:SetScript("OnDragStop", nil)
	c:SetScript("OnUpdate", nil)
	c:RegisterForDrag()
	c:EnableMouse(false)
	c:SetMovable(false)
end

local function relock()
	Chonk.db.profile.locked = true
	Chonk:ApplySettings()
	local reg = LibStub("AceConfigRegistry-3.0", true)
	if reg then reg:NotifyChange("ChonkyBirb") end
end

-- Movable reminder shown while unlocked, with a Lock button.
local function buildUnlockPopup()
	local f = CreateFrame("Frame", "ChonkyBirbUnlockPopup", UIParent, "BackdropTemplate")
	f:SetSize(300, 92)
	f:SetPoint("CENTER", UIParent, "CENTER", 0, 250)
	f:SetFrameStrata("DIALOG")
	f:SetClampedToScreen(true)
	f:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true, tileSize = 32, edgeSize = 32,
		insets = { left = 11, right = 12, top = 12, bottom = 11 },
	})
	f:EnableMouse(true)
	f:SetMovable(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)

	local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOP", 0, -14)
	title:SetText("Chonky Birb")

	local text = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	text:SetPoint("TOP", title, "BOTTOM", 0, -4)
	text:SetWidth(268)
	text:SetJustifyH("CENTER")
	text:SetText(L["Bars unlocked — drag or use the sliders to move them."])

	local lock = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	lock:SetSize(110, 21)
	lock:SetPoint("BOTTOM", 0, 11)
	lock:SetText(L["Lock"])
	lock:SetScript("OnClick", relock)

	return f
end

-- Positioning is a between-pulls activity: entering combat locks everything back down.
function Mover:OnEnable()
	Chonk:RegisterEvent("PLAYER_REGEN_DISABLED", function()
		if Chonk.db and Chonk.db.profile and not Chonk.db.profile.locked then relock() end
	end)
end

function Mover:UpdatePopup(unlocked)
	if not self.popup then self.popup = buildUnlockPopup() end
	self.popup:SetShown(unlocked)
end

-- Re-applied after every rebuild/refresh so drag state always matches the lock setting.
function Mover:OnProfileChange()
	if not (Chonk.db and Chonk.db.profile) then return end
	local unlocked = not Chonk.db.profile.locked
	self:UpdatePopup(unlocked)
	local bars = Chonk.BarFactory and Chonk.BarFactory.bars
	if bars then
		for i = 1, #bars do
			if unlocked then enableDrag(bars[i]) else disableDrag(bars[i]) end
		end
	end
end

Mover.OnRefresh = Mover.OnProfileChange
