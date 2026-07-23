local ADDON, Chonk = ...

-- Builds/refreshes the active spec's bar set.

local H = Chonk.Helpers

local BarFactory = Chonk:RegisterModule({}, "barfactory", "Bar Factory")
Chonk.BarFactory = BarFactory
BarFactory.bars = {}

local RENDERABLE = { power = true, health = true, stagger = true, aura = true, soulfragments = true, runes = true, essence = true }

-- One-time seeds for a fresh bar entry (visibility, position, colour, first text field); after that the user's DB wins.
-- Runs BEFORE ApplySettings so it sees the seeded values.
local function seedBar(desc, cfg, renderIndex)
	local dv = desc.defaultVisibility
	local vis = cfg.visibility
	if dv and not vis._seeded then
		vis.mode = dv.mode or vis.mode
		if dv.conditions then
			for k, v in pairs(dv.conditions) do
				vis.conditions[k] = v
			end
		end
		vis._seeded = true
	end

	-- Segmented bars default flatter than continuous ones; the wildcard default can't vary by kind.
	-- Height is seeded ONLY on a brand-new bar (position not seeded yet): never touch an existing one.
	if desc.kind == "segmented" and not cfg.position._seeded then
		cfg.height = desc.defaultHeight or 12
		cfg.strata = "MEDIUM"
	end

	local pos = cfg.position
	if not pos._seeded then
		pos.point = pos.point or "CENTER"
		pos.x = pos.x or 0
		pos.y = -(renderIndex - 1) * (cfg.height + 4)   -- spread fresh bars so they don't overlap
		pos.scale = pos.scale or 1.0
		pos._seeded = true
	end

	local col = cfg.color
	if not col._seeded then
		if desc.defaultColor then
			col.static = { desc.defaultColor[1], desc.defaultColor[2], desc.defaultColor[3] }
		end
		col._seeded = true
	end

	if not cfg.castColor then
		local dc = desc.defaultColor or { 1, 1, 1 }
		cfg.castColor = { dc[1], dc[2], dc[3], 0.35 }
	end

	if #cfg.texts == 0 then
		cfg.texts[1] = Chonk.Text:DefaultElement(desc.defaultText)
	end
end

function BarFactory:Rebuild()
	for i = 1, #self.bars do
		self.bars[i]:Destroy()
	end
	wipe(self.bars)
	self.hasStagger = false

	local profile = Chonk.db and Chonk.db.profile
	if not profile or not profile.enabled then return end

	local classID = H.PlayerClassID()
	local specIndex = H.PlayerSpecIndex()
	if not classID or not specIndex then return end

	local descs = Chonk:GetBarsForSpec(classID, specIndex)
	for i = 1, #descs do
		local desc = descs[i]
		if RENDERABLE[desc.source] then
			local cfg = profile.bars[desc.id]
			local bar = Chonk.CreateResourceBar(desc)
			self.bars[#self.bars + 1] = bar
			seedBar(desc, cfg, #self.bars)
			bar:ApplySettings(cfg)
			bar:Position()
			if desc.source == "stagger" then self.hasStagger = true end
		end
	end

	if Chonk.Visibility then Chonk.Visibility:MarkDirty() end

	self:UpdateAll()
end

-- Light refresh for config edits: re-apply to the existing bars, no destroy -> no flash.
function BarFactory:Refresh()
	local profile = Chonk.db and Chonk.db.profile
	if not profile then return end
	for i = 1, #self.bars do
		local bar = self.bars[i]
		bar:ApplySettings(profile.bars[bar.id])
		bar:Position()
	end
	self:UpdateAll()
end

function BarFactory:UpdateAll()
	for i = 1, #self.bars do
		self.bars[i]:Update()
	end
end
