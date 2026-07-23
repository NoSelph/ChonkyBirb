local ADDON, Chonk = ...

-- The generic bar widget: fill/pips, text fields, cast prediction, value markers.

local H = Chonk.Helpers
local LSM = LibStub("LibSharedMedia-3.0")
local DEFAULT_TEXTURE = [[Interface\AddOns\ChonkyBirb\media\textures\CHONKFlat.tga]]
local DEFAULT_BORDER = [[Interface\AddOns\ChonkyBirb\media\textures\CHONK1PXBorder.tga]]

local GHOST_ALPHA = 0.35

local ResourceBar = {}
ResourceBar.__index = ResourceBar
Chonk.ResourceBar = ResourceBar

-- Only the fill StatusBar ever receives secrets.
-- bg/border/text hang off the container so the BarValue aspect can't spread to them.
function Chonk.CreateResourceBar(desc)
	local self = setmetatable({}, ResourceBar)
	self.id = desc.id
	self.desc = desc
	self.powerType = desc.powerType
	self.segmented = (desc.kind == "segmented")

	local container = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
	container:SetFrameStrata("MEDIUM")
	container:SetClampedToScreen(true)
	container:Hide()   -- Visibility:ProcessAll reveals the right bars, no rebuild flash
	self.container = container

	local bg = container:CreateTexture(nil, "BACKGROUND")
	self.bg = bg

	local bar = CreateFrame("StatusBar", nil, container)
	self.bar = bar

	local textHost = CreateFrame("Frame", nil, container)
	textHost:SetAllPoints(container)
	textHost:SetFrameLevel(container:GetFrameLevel() + 10)   -- text above fill/pips
	self.textHost = textHost
	self.fontStrings = {}
	self.fontObjects = {}

	if self.segmented then
		bar:Hide()
		self.pips = {}
		self.pipCount = 0
	else
		-- Continuous-bar cast ghost: a StatusBar hanging off the fill's edge inside a clip frame.
		-- Its own (gain/max) math does the sizing, no addon arithmetic on the secret value/max.
		local clip = CreateFrame("Frame", nil, container)
		clip:SetClipsChildren(true)
		self.castClip = clip
		local overlay = CreateFrame("StatusBar", nil, clip)
		overlay:Hide()
		self.castOverlay = overlay
	end

	return self
end

-- User colour first (seeded from the registry default on first build), registry colour as fallback.
local function resolveOnColor(self)
	local col = (self.cfg and self.cfg.color and self.cfg.color.static) or self.desc.defaultColor or { 1, 1, 1 }
	return col[1], col[2], col[3], col[4] or 1
end

local function resolveCastColor(self)
	local cfg = self.cfg
	if cfg and cfg.castColorMode == "custom" and cfg.castColor then
		local c = cfg.castColor
		return c[1], c[2], c[3], c[4] or GHOST_ALPHA
	end
	local r, g, b = resolveOnColor(self)
	return r, g, b, (cfg and cfg.castAlpha) or GHOST_ALPHA
end

local function insetPoints(region, c, inset)
	region:ClearAllPoints()
	region:SetPoint("TOPLEFT", c, "TOPLEFT", inset, -inset)
	region:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -inset, inset)
end

-- Effective field value: per-bar / per-text-field override wins, else the global default.
local function eff(ov, def, key)
	local v = ov and ov[key]
	if v == nil then return def[key] end
	return v
end

function ResourceBar:ApplySettings(cfg)
	self.cfg = cfg
	local c = self.container
	c:SetScale(cfg.position and cfg.position.scale or 1.0)   -- scale first, the pixel base depends on it
	local px = H.PixelBase(c)
	c:SetSize(H.Snap(cfg.width, px), H.Snap(cfg.height, px))

	local def = Chonk.db.profile.barDefaults

	-- Strata on the container: children inherit it, the whole bar changes layer together.
	c:SetFrameStrata(eff(cfg, def, "strata") or "MEDIUM")

	-- Border on the container; bar/bg/pips are inset by its thickness so the ring shows.
	local bdEdge = eff(cfg.border, def.border, "edge")
	local bdSize = eff(cfg.border, def.border, "size")
	local inset = 0
	if bdEdge and bdEdge ~= "None" and (bdSize or 0) > 0 then
		inset = bdSize
		local maxInset = math.floor(math.min(cfg.width, cfg.height) / 2) - 1
		if inset > maxInset then inset = maxInset end
		if inset < 1 then inset = 1 end
		inset = H.Snap(inset, px)
		c:SetBackdrop({ edgeFile = LSM:Fetch("border", bdEdge) or DEFAULT_BORDER, edgeSize = H.Snap(bdSize, px) })
		local bc = eff(cfg.border, def.border, "color") or { 0, 0, 0, 1 }
		c:SetBackdropBorderColor(bc[1], bc[2], bc[3], bc[4] or 1)
	else
		c:SetBackdrop(nil)
	end
	self.inset = inset

	local bgc = eff(cfg.background, def.background, "color") or { 0, 0, 0, 0.5 }
	insetPoints(self.bg, c, inset)
	local bgTex = LSM:Fetch("background", eff(cfg.background, def.background, "texture"))
	if bgTex then
		self.bg:SetTexture(bgTex)
		self.bg:SetVertexColor(bgc[1], bgc[2], bgc[3], bgc[4] or 1)
	else
		self.bg:SetColorTexture(bgc[1], bgc[2], bgc[3], bgc[4] or 1)
	end

	self:LayoutTexts()
	self:LayoutMarkers()

	-- Colour-by-percent curve, evaluated engine-side on update (the % is secret in combat).
	-- Also drives the pip fills on segmented power bars.
	local usesPercent = self.desc.source == "health"
		or (self.powerType ~= nil and (self.desc.source == "power" or self.desc.source == "essence"))
	local cv = cfg.color.curve
	if usesPercent and cfg.color.mode == "curve" and cv and #cv.points > 0 then
		local curve = self._colorCurve
		if not curve then
			curve = C_CurveUtil.CreateColorCurve()
			self._colorCurve = curve
		end
		curve:ClearPoints()
		curve:SetType(cv.type == "linear" and Enum.LuaCurveType.Linear or Enum.LuaCurveType.Step)
		local pts = {}
		for i, pt in ipairs(cv.points) do pts[i] = pt end
		table.sort(pts, function(a, b) return (a[1] or 0) < (b[1] or 0) end)
		for _, pt in ipairs(pts) do
			local col = pt[2] or {}
			curve:AddPoint(pt[1] or 0, CreateColor(col[1] or 0, col[2] or 0, col[3] or 0, col[4] or 1))
		end
	else
		self._colorCurve = nil
	end

	if self.segmented then
		self.pipCount = 0   -- force a pip re-layout
		self:LayoutPips(self.desc.maxNodes)
		return
	end

	insetPoints(self.bar, c, inset)
	self.bar:SetStatusBarTexture(LSM:Fetch("statusbar", cfg.texture) or DEFAULT_TEXTURE)
	local r, g, b, a = resolveOnColor(self)
	self.bar:SetStatusBarColor(r, g, b, a)

	local dir = cfg.fillDirection
	local vertical = (dir == "up" or dir == "down")
	self.bar:SetOrientation(vertical and "VERTICAL" or "HORIZONTAL")
	self.bar:SetReverseFill(dir == "left" or dir == "down")

	-- Cast ghost: same inner size, anchored to the fill's edge, clipped to the inner area.
	insetPoints(self.castClip, c, inset)
	local overlay = self.castOverlay
	overlay:SetSize(math.max(cfg.width - inset * 2, 1), math.max(cfg.height - inset * 2, 1))
	overlay:ClearAllPoints()
	overlay:SetPoint("TOPLEFT", self.bar:GetStatusBarTexture(), "TOPRIGHT", 0, 0)
	overlay:SetStatusBarTexture(LSM:Fetch("statusbar", cfg.texture) or DEFAULT_TEXTURE)
	overlay:SetStatusBarColor(resolveCastColor(self))
end

-- Anchor point -> (x, y) fractions: 0 = left/bottom, 1 = right/top.
local POINTS = {
	TOPLEFT = { 0, 1 },    TOP = { 0.5, 1 },    TOPRIGHT = { 1, 1 },
	LEFT = { 0, 0.5 },     CENTER = { 0.5, 0.5 }, RIGHT = { 1, 0.5 },
	BOTTOMLEFT = { 0, 0 }, BOTTOM = { 0.5, 0 }, BOTTOMRIGHT = { 1, 0 },
}
Chonk.AnchorPoints = POINTS

-- On-screen x/y range for the bar's rect. UIParent units; its anchor point sits at (fx*uw, fy*uh).
local function screenBounds(self, point, scale)
	local uw, uh = UIParent:GetWidth(), UIParent:GetHeight()
	local bw = (self.cfg.width or 0) * scale
	local bh = (self.cfg.height or 0) * scale
	local f = POINTS[point]
	local fx, fy = f[1], f[2]
	local minX, maxX = fx * bw - fx * uw, uw - bw + fx * bw - fx * uw
	local minY, maxY = fy * bh - fy * uh, uh - bh + fy * bh - fy * uh
	return minX, maxX, minY, maxY
end

-- Clamp x/y so the bar's rect stays on-screen.
local function clampToScreen(self, point, x, y, scale)
	local minX, maxX, minY, maxY = screenBounds(self, point, scale)
	if x < minX then x = minX elseif x > maxX then x = maxX end
	if y < minY then y = minY elseif y > maxY then y = maxY end
	return x, y
end

-- On-screen bounds for this bar's current position, so a group move can be clamped as one box.
function ResourceBar:ClampBounds()
	local pos = self.cfg.position
	local point = POINTS[pos.point] and pos.point or "CENTER"
	return screenBounds(self, point, pos.scale or 1.0)
end

-- Own anchor on UIParent; clamped x/y are written back so the sliders follow.
function ResourceBar:Position()
	local c = self.container
	local pos = self.cfg.position
	local point = POINTS[pos.point] and pos.point or "CENTER"
	local scale = pos.scale or 1.0
	c:SetScale(scale)

	local x, y = clampToScreen(self, point, pos.x or 0, pos.y or 0, scale)
	pos.x, pos.y = x, y
	c:ClearAllPoints()
	c:SetPoint(point, UIParent, point, x, y)

	-- Snap the rendered rect onto the physical pixel grid; a 1px border on a fractional edge draws 1 or
	-- 2 pixels depending on where it lands. Stored pos stays untouched, the sliders keep their values.
	local l, b = c:GetRect()
	if l then
		local px = H.PixelBase(c)
		local dx = H.SnapCoord(l, px) - l
		local dy = H.SnapCoord(b, px) - b
		if dx ~= 0 or dy ~= 0 then
			c:ClearAllPoints()
			c:SetPoint(point, UIParent, point, x + dx, y + dy)
		end
	end
end

local TEXT_POINTS = {
	TOPLEFT = true, TOP = true, TOPRIGHT = true, LEFT = true, CENTER = true,
	RIGHT = true, BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true,
}

-- Font + shadow live on a font OBJECT (SetFontObject).
-- A shadow set directly on a FontString that carries secret text doesn't render.
local fontObjectCount = 0

local function applyFontStyle(self, index, fs, f, def)
	local fo = self.fontObjects[index]
	if not fo then
		fontObjectCount = fontObjectCount + 1
		fo = CreateFont("ChonkFontObject" .. fontObjectCount)
		self.fontObjects[index] = fo
	end

	local outline = eff(f, def, "outline")
	local flags = (outline == "SHADOW") and "" or outline
	fo:SetFont(LSM:Fetch("font", eff(f, def, "face")) or STANDARD_TEXT_FONT, eff(f, def, "size"), flags)
	if outline == "SHADOW" then
		local sc = eff(f, def, "shadowColor") or { 0, 0, 0, 1 }
		fo:SetShadowColor(sc[1], sc[2], sc[3], sc[4] or 1)
		fo:SetShadowOffset(eff(f, def, "shadowX") or 0.8, eff(f, def, "shadowY") or -0.8)
	else
		fo:SetShadowOffset(0, 0)
	end

	fs:SetFontObject(fo)
	local fc = eff(f, def, "color") or { 1, 1, 1 }
	fs:SetTextColor(fc[1], fc[2], fc[3], fc[4] or 1)
end

function ResourceBar:LayoutTexts()
	local texts = self.cfg.texts
	local n = texts and #texts or 0
	local fontDef = Chonk.db.profile.barDefaults.font
	for i = 1, n do
		local t = texts[i]
		local fs = self.fontStrings[i]
		if not fs then
			fs = self.textHost:CreateFontString(nil, "OVERLAY")
			self.fontStrings[i] = fs
		end

		applyFontStyle(self, i, fs, t.font, fontDef)

		local point = TEXT_POINTS[t.point] and t.point or "CENTER"
		fs:ClearAllPoints()
		fs:SetPoint(point, self.container, point, t.x or 0, t.y or 0)
		fs:Show()
	end
	for i = n + 1, #self.fontStrings do
		self.fontStrings[i]:SetText("")
		self.fontStrings[i]:Hide()
	end
end

-- One StatusBar per pip with range [i-1, i]: fed the count, pip i fills exactly when count >= i — no addon comparison.
-- No-ops once pipCount matches.
function ResourceBar:LayoutPips(count)
	if not count or count < 1 then count = 1 end
	if self.pipCount == count then return end
	self.pipCount = count

	local cfg = self.cfg
	local inset = self.inset or 0
	local gap = (cfg.segment and cfg.segment.gap) or 0
	local reverse = (cfg.fillDirection == "left")
	local tex = LSM:Fetch("statusbar", cfg.texture) or DEFAULT_TEXTURE

	local avail = cfg.width - inset * 2
	local pipW = (avail - gap * (count - 1)) / count
	if pipW < 1 then pipW = 1 end
	local pipH = cfg.height - inset * 2
	if pipH < 1 then pipH = 1 end

	local onR, onG, onB, onA = resolveOnColor(self)
	-- Unfilled-pip colour: the bar colour at offAlpha, or an explicit colour.
	local seg = cfg.segment
	local dimR, dimG, dimB, dimA
	if seg and seg.offMode == "color" then
		local off = seg.offColor or { 1, 1, 1, 1 }
		dimR, dimG, dimB, dimA = off[1], off[2], off[3], off[4] or 1
	else
		dimR, dimG, dimB, dimA = onR, onG, onB, (seg and seg.offAlpha) or 0.25
	end

	for i = 1, count do
		local pip = self.pips[i]
		if not pip then
			pip = CreateFrame("StatusBar", nil, self.container)
			pip.bg = pip:CreateTexture(nil, "BACKGROUND", nil, -8)
			pip.bg:SetAllPoints(pip)
			self.pips[i] = pip
		end
		pip:SetStatusBarTexture(tex)
		local fill = pip:GetStatusBarTexture()
		if fill then fill:SetDrawLayer("BORDER") end
		pip:SetStatusBarColor(onR, onG, onB, onA)
		pip.bg:SetColorTexture(dimR, dimG, dimB, dimA)
		pip:SetMinMaxValues(i - 1, i)
		pip:SetSize(pipW, pipH)
		pip:ClearAllPoints()

		local slot = reverse and (count - i) or (i - 1)
		pip:SetPoint("LEFT", self.container, "LEFT", inset + slot * (pipW + gap), 0)
		pip:Show()
	end

	for i = count + 1, #self.pips do
		self.pips[i]:Hide()
	end
end

local function pipTimerTick(pip)
	local t = GetTime()
	pip:SetValue(t)
	if t >= pip.timerEnd then
		pip:SetValue(pip.timerEnd)
		pip:SetAlpha(1)
		if pip.restoreColor then
			pip:SetStatusBarColor(pip.restoreColor[1], pip.restoreColor[2], pip.restoreColor[3], pip.restoreColor[4])
			pip.restoreColor = nil
		end
		pip:SetScript("OnUpdate", nil)
		pip.timerEnd = nil
	end
end

-- Per-pip state (runes): full, or a live [start, endTime] recharge window the bar maps GetTime() into.
-- Recharge look per cfg.recharge: bar colour at .alpha, or an explicit .color.
local function setPipState(self, pip, state)
	local rc = self.cfg.recharge
	if state and state.endTime then
		pip.timerEnd = state.endTime
		pip:SetMinMaxValues(state.start, state.endTime)
		pip:SetValue(GetTime())
		if rc and rc.mode == "color" then
			local c = rc.color or { 1, 1, 1, 0.4 }
			if not pip.restoreColor then
				local r, g, b, a = resolveOnColor(self)
				pip.restoreColor = { r, g, b, a }
			end
			pip:SetStatusBarColor(c[1], c[2], c[3], c[4] or 1)
			pip:SetAlpha(1)
		else
			pip:SetAlpha((rc and rc.alpha) or 0.4)
		end
		pip:SetScript("OnUpdate", pipTimerTick)
	else
		pip.timerEnd = nil
		pip:SetScript("OnUpdate", nil)
		pip:SetMinMaxValues(0, 1)
		pip:SetValue(state and state.full and 1 or 0)
		pip:SetAlpha(1)
		if pip.restoreColor then
			pip:SetStatusBarColor(pip.restoreColor[1], pip.restoreColor[2], pip.restoreColor[3], pip.restoreColor[4])
			pip.restoreColor = nil
		end
	end
end

local MOVING_EDGE = { right = "RIGHT", left = "LEFT", up = "TOP", down = "BOTTOM" }

-- Value markers: an invisible StatusBar does the (value/max) placement internally, secret max included.
-- The visible tick hangs off its fill's moving edge.
function ResourceBar:LayoutMarkers()
	local markers = self.cfg.markers
	local n = markers and #markers or 0

	-- Render list: a static marker is one tick, a spell-cost marker repeats at 1x..Nx its cost.
	local entries = {}
	for i = 1, n do
		local m = markers[i]
		-- Talent gate: the marker can require its spell list to be all known / any known / none known.
		local shown = true
		local mode = m.showMode
		if m.spellID and mode then
			if mode == "allKnown" or mode == "known" then
				shown = H.AreAllSpellsKnown(m.spellID)
			elseif mode == "anyKnown" then
				shown = H.IsAnySpellKnown(m.spellID)
			elseif mode == "noneKnown" or mode == "missing" then
				shown = not H.IsAnySpellKnown(m.spellID)
			end
		end
		if m.mode == "cost" then
			for k = 1, m.costCount or 1 do
				entries[#entries + 1] = { m = m, k = k, shown = shown }
			end
		else
			entries[#entries + 1] = { m = m, shown = shown }
		end
	end
	self._markerEntries = entries

	local hosts = self.markerHosts
	if #entries > 0 and not hosts then
		hosts = {}
		self.markerHosts = hosts
	end
	if not hosts then return end

	local c = self.container
	local inset = self.inset or 0
	local dir = self.cfg.fillDirection or "right"
	local vertical = (dir == "up" or dir == "down")
	local edge = MOVING_EDGE[dir] or "RIGHT"
	local innerW = math.max(self.cfg.width - inset * 2, 1)
	local innerH = math.max(self.cfg.height - inset * 2, 1)

	for i = 1, #entries do
		local e = entries[i]
		local m = e.m
		local host = hosts[i]
		if not host then
			-- Clip parent: an over-max value clamps the fill to the bar edge.
			-- Shrinking the clip by half a tick on that edge makes the clamped tick vanish — no secret comparison.
			local clip = CreateFrame("Frame", nil, c)
			clip:SetClipsChildren(true)
			host = CreateFrame("StatusBar", nil, clip)
			host.clipFrame = clip
			host:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
			host.tick = host:CreateTexture(nil, "OVERLAY")
			hosts[i] = host
		end

		-- Clip along the fill axis only (over-max hiding); ticks may be taller than the bar itself.
		local CROSS_PAD = 500
		local px = H.PixelBase(c)
		local tickW = H.Snap(m.width or 2, px)
		local shrink = math.ceil(tickW / 2)
		local clip = host.clipFrame
		clip:SetFrameLevel(self.bar:GetFrameLevel() + 2)   -- the clipped subtree renders at ITS level
		clip:ClearAllPoints()
		if vertical then
			clip:SetPoint("TOPLEFT", c, "TOPLEFT",
				-CROSS_PAD, -(inset + (dir == "down" and shrink or 0)))
			clip:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT",
				CROSS_PAD, inset + (dir == "up" and shrink or 0))
		else
			clip:SetPoint("TOPLEFT", c, "TOPLEFT",
				inset + (dir == "left" and shrink or 0), CROSS_PAD)
			clip:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT",
				-(inset + (dir == "right" and shrink or 0)), -CROSS_PAD)
		end

		host:SetStatusBarColor(0, 0, 0, 0)   -- positioning engine only, fill stays invisible
		host:SetFrameLevel(clip:GetFrameLevel() + 1)
		insetPoints(host, c, inset)
		host:SetOrientation(vertical and "VERTICAL" or "HORIZONTAL")
		host:SetReverseFill(dir == "left" or dir == "down")

		local col = m.color or { 1, 1, 1, 0.8 }
		host.tick:SetColorTexture(col[1], col[2], col[3], col[4] or 0.8)
		local tickLen = H.Snap(m.height or (vertical and innerW or innerH), px)
		if vertical then
			host.tick:SetSize(tickLen, tickW)   -- tick lies across a vertical bar
		else
			host.tick:SetSize(tickW, tickLen)
		end
		host.tick:ClearAllPoints()
		host.tick:SetPoint("CENTER", host:GetStatusBarTexture(), edge, 0, 0)
		host:SetShown(e.shown)
	end
	for i = #entries + 1, #hosts do
		hosts[i]:Hide()
	end
end

function ResourceBar:UpdateMarkers()
	local hosts, entries = self.markerHosts, self._markerEntries
	if not hosts or not entries or H.IsNil(self._max) then return end
	for i = 1, #entries do
		local e = entries[i]
		local host = hosts[i]
		if host then
			host:SetMinMaxValues(0, self._max)
			if e.k then
				-- Live cost, with a memory: free-spell procs report no cost, keep the last real one.
				-- Only a spell that never had a cost (unknown, wrong resource) stays hidden.
				local cost = H.SpellPowerCost(e.m.costSpell, self.powerType)
				if cost then e.lastCost = cost end
				if e.lastCost then
					host:SetValue(e.lastCost * e.k)
					host:SetShown(e.shown)
				else
					host:Hide()
				end
			else
				host:SetValue(e.m.value or 0)
			end
		end
	end
end

-- No per-frame gate, a proc landing the same frame as a handled event still has to repaint.
function ResourceBar:Update()
	if not self.cfg or not self.cfg.enabled then return end
	if not UnitExists("player") then return end

	if self.segmented then
		self:UpdateSegmented()
	else
		self:UpdateContinuous()
	end
	self:UpdateCastOverlay()
	self:UpdateMarkers()
end

-- string.format on secrets is whitelisted and SetText takes secrets (Text aspect).
function ResourceBar:RefreshTexts(cur, max)
	local texts = self.cfg.texts
	local n = texts and #texts or 0
	if n == 0 then return end

	local ctx = self._textCtx
	if not ctx then ctx = {}; self._textCtx = ctx end
	ctx.bar, ctx.cur, ctx.max = self, cur, max
	local vals = self._textVals
	if not vals then vals = {}; self._textVals = vals end

	for i = 1, n do
		local fs = self.fontStrings[i]
		if fs then
			local c = Chonk.Text:Compile(texts[i].text)
			local keys = c.keys
			for j = 1, #keys do
				local fn = Chonk.TextTags[keys[j]]
				local ok, s = pcall(fn, ctx)
				if not ok then s = "" end   -- only test ok: `s or ""` would boolean-test a secret
				vals[j] = s
			end
			local ok, out = pcall(string.format, c.format, unpack(vals, 1, #keys))
			if not ok then out = "" end
			fs:SetText(out)
		end
	end
end

function ResourceBar:UpdateContinuous()
	local max, cur
	local source = self.desc.source
	local handler = Chonk.Sources[source]
	if source == "health" then
		max = H.UnitHealthMax("player")
		cur = H.UnitHealth("player")
	elseif handler then
		cur, max = handler(self)   -- bespoke class resources (stagger, soul fragments, ...)
	else
		-- Display-modified values (Astral Power & co are shown at 1/10 of raw).
		max = H.UnitPowerMax("player", self.powerType, false)
		cur = H.UnitPower("player", self.powerType, false)
	end
	-- IsNil = failed pcall, checked without comparing a secret.
	if H.IsNil(max) or H.IsNil(cur) then return end
	self._max = max

	self.bar:SetMinMaxValues(0, max)
	self.bar:SetValue(cur)

	if self._colorCurve then
		local color
		if source == "health" then
			color = H.UnitHealthPercent("player", false, self._colorCurve)
		else
			color = H.UnitPowerPercent("player", self.powerType, false, self._colorCurve)
		end
		if color then
			self.bar:SetStatusBarColor(color:GetRGBA())
		end
	end

	self:RefreshTexts(cur, max)
end

-- Colour-by-percent on pips: Blizzard evaluates the curve from the power percent (secret in combat).
-- The colour goes to the pip FILLS only, bg keeps its plain dim.
-- A pip mid-recharge with a colour override gets its restore value refreshed instead.
function ResourceBar:ApplyPipCurveColor()
	if not (self._colorCurve and self.powerType) then return end
	local color = H.UnitPowerPercent("player", self.powerType, false, self._colorCurve)
	if not color then return end
	local r, g, b, a = color:GetRGBA()
	for i = 1, self.pipCount do
		local pip = self.pips[i]
		if pip.restoreColor then
			pip.restoreColor[1], pip.restoreColor[2], pip.restoreColor[3], pip.restoreColor[4] = r, g, b, a
		else
			pip:SetStatusBarColor(r, g, b, a)
		end
	end
end

function ResourceBar:UpdateSegmented()
	local handler = Chonk.Sources[self.desc.source]
	if handler then
		local cur, max, states = handler(self)
		if H.IsUsableNumber(max) and max >= 1 then
			self:LayoutPips(max)
		else
			self:LayoutPips(self.desc.maxNodes)
		end
		if not H.IsNil(max) then self._max = max end
		if H.IsNil(cur) then return end
		self._cur = cur
		if states then
			for i = 1, self.pipCount do
				setPipState(self, self.pips[i], states[i])
			end
		else
			-- No states (e.g. essence gone secret): a pip left mid-recharge keeps a stale range/timer.
			-- Clear it back to the plain [i-1, i] count fill.
			for i = 1, self.pipCount do
				local pip = self.pips[i]
				if pip.timerEnd or pip.restoreColor then setPipState(self, pip, nil) end
				pip:SetMinMaxValues(i - 1, i)
				pip:SetValue(cur)
			end
		end
		self:ApplyPipCurveColor()
		self:RefreshTexts(cur, max)
		return
	end

	-- Aura-stack pips (Maelstrom Weapon): fixed node count.
	if self.desc.source == "aura" then
		self:LayoutPips(self.desc.maxNodes)
		self._max = self.desc.maxNodes
		local aura = H.GetPlayerAura(self.desc.auraSpellID)
		local count = 0
		if aura then count = aura.applications end   -- may be secret: assign, never test it
		self._cur = count
		for i = 1, self.pipCount do
			self.pips[i]:SetValue(count)
		end
		self:RefreshTexts(count, self.desc.maxNodes)
		return
	end

	local max = H.UnitPowerMax("player", self.powerType, false)
	if H.IsUsableNumber(max) and max >= 1 then
		self:LayoutPips(max)
	else
		self:LayoutPips(self.desc.maxNodes)
	end
	if not H.IsNil(max) then self._max = max end

	if not self.powerType then return end

	local cur = H.UnitPower("player", self.powerType, false)
	if H.IsNil(cur) then return end
	self._cur = cur

	for i = 1, self.pipCount do
		self.pips[i]:SetValue(cur)
	end
	self:ApplyPipCurveColor()
	self:RefreshTexts(cur, max)
end

local function currentCastSpellID()
	local ok, _, _, _, _, _, _, _, _, spellID = pcall(UnitCastingInfo, "player")
	if ok and spellID ~= nil then return spellID end
	local okc, _, _, _, _, _, _, _, chSpellID = pcall(UnitChannelInfo, "player")
	if okc then return chSpellID end
end

-- Cast prediction: while casting a known generator of this bar's resource, preview the curated gain as a ghost.
-- The current value/max stay untouched.
function ResourceBar:UpdateCastOverlay()
	local amount
	if self.cfg.castPredict and self.powerType then
		local spellID = currentCastSpellID()
		if H.IsUsableNumber(spellID) then   -- a secret spellID can't be used as a table key
			local entry = Chonk.CastGen[spellID]
			if entry and entry.pt == self.powerType then
				amount = entry.amount or (entry.bySpec and entry.bySpec[H.PlayerSpecIndex()])
			end
		end
	end

	if self.segmented then
		self:UpdateCastPips(amount)
		return
	end

	local overlay = self.castOverlay
	if not overlay then return end
	if amount and (self.cfg.fillDirection or "right") == "right" and not H.IsNil(self._max) then
		if self.cfg.castColorMode ~= "custom" then
			-- Live bar color, curve-recolored included, passed straight through.
			local r, g, b = self.bar:GetStatusBarColor()
			overlay:SetStatusBarColor(r, g, b, self.cfg.castAlpha or GHOST_ALPHA)
		end
		overlay:SetMinMaxValues(0, self._max)
		overlay:SetValue(amount)
		overlay:Show()
	else
		overlay:Hide()
	end
end

-- Cast pips, the range-shift trick: pip i lights when cur >= i.
-- A cast pip with window [i-1-g, i-g] fed the SAME cur lights exactly when the pip WILL be lit after the +g cast.
-- Fractional gains partially fill by construction.
function ResourceBar:UpdateCastPips(gain)
	local casts = self.castPips
	if not gain then
		if casts then
			for i = 1, #casts do casts[i]:Hide() end
		end
		return
	end

	if H.IsNil(self._cur) then return end
	if not casts then casts = {}; self.castPips = casts end

	local tex = LSM:Fetch("statusbar", self.cfg.texture) or DEFAULT_TEXTURE
	local gr, gg, gb, ga = resolveCastColor(self)
	for i = 1, self.pipCount do
		local cp = casts[i]
		if not cp then
			cp = CreateFrame("StatusBar", nil, self.container)
			casts[i] = cp
		end
		local pip = self.pips[i]
		cp:SetFrameLevel(pip:GetFrameLevel() + 1)
		cp:SetAllPoints(pip)
		cp:SetStatusBarTexture(tex)
		cp:SetStatusBarColor(gr, gg, gb, ga)
		cp:SetMinMaxValues(i - 1 - gain, i - gain)
		cp:SetValue(self._cur)
		cp:Show()
	end
	for i = self.pipCount + 1, #casts do
		casts[i]:Hide()
	end
end

function ResourceBar:Destroy()
	if self.pips then
		for i = 1, #self.pips do
			local pip = self.pips[i]
			pip:Hide()
			pip:SetParent(nil)
			pip:ClearAllPoints()
		end
	end
	self.container:Hide()
	self.container:SetParent(nil)
	self.container:ClearAllPoints()
end
