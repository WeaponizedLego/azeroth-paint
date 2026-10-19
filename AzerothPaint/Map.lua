local _, ns = ...

-- Doodles on the world map, shared with your group. Points are stored in the
-- map's normalized 0-1 coordinates, so they land on the same spot for anyone
-- viewing the same map. Everything is wiped when you close your map.

local PREFIX = "AzerothPaint"
local MIN_DIST = 0.003
local MAX_POINTS_PER_SENDER = 1500 -- per map opening, so one person can't flood it
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local DEC = {}
for i = 1, #B64 do DEC[B64:sub(i, i)] = i - 1 end

-- Each coordinate becomes 2 characters (12 bits of precision).
local function Enc(v)
	local n = math.min(4095, math.max(0, math.floor(v * 4095 + 0.5)))
	local hi, lo = math.floor(n / 64) + 1, n % 64 + 1
	return B64:sub(hi, hi) .. B64:sub(lo, lo)
end

local function Channel()
	if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
	if IsInRaid() then return "RAID" end
	if IsInGroup() then return "PARTY" end
end

-- Addon messages allow a burst of 10 per prefix, then 1 per second.
local queue, waiting = {}, false
local function Pump()
	waiting = false
	while queue[1] do
		local channel = Channel()
		if not channel then
			wipe(queue)
			return
		end
		if C_ChatInfo.SendAddonMessage(PREFIX, queue[1], channel) == Enum.SendAddonMessageResult.AddonMessageThrottle then
			waiting = true
			C_Timer.After(1, Pump)
			return
		end
		table.remove(queue, 1)
	end
end

-- Message: "<mapID>:<points>". Long strokes are split into chunks that share
-- their end point, so each chunk is a standalone polyline.
local function Send(stroke)
	if not Channel() then return end
	local header = stroke.mapID .. ":"
	local perMessage = math.floor((255 - #header) / 4)
	local count = #stroke / 2
	local first = 1
	repeat
		local last = math.min(count, first + perMessage - 1)
		local parts = { header }
		for p = first, last do
			parts[#parts + 1] = Enc(stroke[2 * p - 1]) .. Enc(stroke[2 * p])
		end
		queue[#queue + 1] = table.concat(parts)
		first = last
	until last >= count
	if not waiting then Pump() end
end

local function Init()
	local map = WorldMapFrame
	local canvas = map:GetCanvas()
	local strokes = {}
	local received = {} -- points per sender since the map opened

	local layer = CreateFrame("Frame", nil, canvas)
	layer:SetAllPoints()
	layer:SetFrameLevel(8000)
	local lines = ns.NewLines(layer)

	local function Draw(stroke, from)
		if not map:IsShown() or stroke.mapID ~= map:GetMapID() then return end
		local w, h = layer:GetSize()
		ns.DrawStroke(lines, "TOPLEFT", stroke, w, -h, w * 0.004, from)
	end

	local function Redraw()
		lines:Clear()
		for _, stroke in ipairs(strokes) do Draw(stroke) end
	end

	-- Catches mouse input over the map while drawing; mouse wheel still zooms.
	local input = CreateFrame("Frame", nil, map.ScrollContainer)
	input:SetAllPoints()
	input:SetFrameLevel(9000)
	input:EnableMouse(true)
	input:Hide()

	local button = CreateFrame("Button", nil, map.ScrollContainer, "UIPanelButtonTemplate")
	button:SetSize(110, 22)
	button:SetPoint("BOTTOMLEFT", 10, 10)
	button:SetFrameLevel(9100)

	local function SetDrawing(on)
		input:SetShown(on)
		button:SetText(on and "Stop drawing" or "Draw")
	end
	SetDrawing(false)
	button:SetScript("OnClick", function() SetDrawing(not input:IsShown()) end)

	local show = CreateFrame("CheckButton", nil, map.ScrollContainer, "UICheckButtonTemplate")
	show:SetSize(24, 24)
	show:SetPoint("LEFT", button, "RIGHT", 6, 0)
	show:SetFrameLevel(9100)
	local label = show:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	label:SetPoint("LEFT", show, "RIGHT", 2, 0)
	label:SetText("Show group drawings")
	show:HookScript("OnShow", function() show:SetChecked(not ns.DB().mapMuted) end)
	show:HookScript("OnClick", function()
		ns.DB().mapMuted = not show:GetChecked()
		if ns.DB().mapMuted then
			for i = #strokes, 1, -1 do
				if strokes[i].from then table.remove(strokes, i) end
			end
			Redraw()
		end
	end)

	local current
	ns.Draggable(input, function() return map:GetNormalizedCursorPosition() end, MIN_DIST,
		function(x, y)
			local r, g, b = ns.ClassColor("player")
			current = { mapID = map:GetMapID(), r = r, g = g, b = b, x, y }
			table.insert(strokes, current)
		end,
		function(x, y)
			table.insert(current, x)
			table.insert(current, y)
			Draw(current, #current / 2 - 1)
		end,
		function()
			if #current < 4 then
				table.remove(strokes) -- a click, not a stroke
			else
				Send(current)
			end
		end)

	map:HookScript("OnShow", Redraw)
	map:HookScript("OnHide", function()
		wipe(strokes)
		wipe(received)
		lines:Clear()
		SetDrawing(false)
	end)
	hooksecurefunc(map, "OnMapChanged", Redraw)
	layer:SetScript("OnSizeChanged", Redraw)

	local events = CreateFrame("Frame")
	events:RegisterEvent("CHAT_MSG_ADDON")
	events:SetScript("OnEvent", function(_, _, prefix, msg, _, sender)
		if issecretvalue and (issecretvalue(prefix) or issecretvalue(msg) or issecretvalue(sender)) then return end
		if prefix ~= PREFIX or ns.DB().mapMuted then return end
		local name = Ambiguate(sender, "none")
		if UnitIsUnit(name, "player") then return end
		local mapID, data = msg:match("^(%d+):(.+)$")
		if not mapID then return end

		local r, g, b = ns.ClassColor(name)
		local stroke = { mapID = tonumber(mapID), from = name, r = r, g = g, b = b }
		for i = 1, #data - 1, 2 do
			local hi, lo = DEC[data:sub(i, i)], DEC[data:sub(i + 1, i + 1)]
			if not hi or not lo then return end
			stroke[#stroke + 1] = (hi * 64 + lo) / 4095
		end
		if #stroke < 4 then return end
		local total = (received[name] or 0) + #stroke / 2
		if total > MAX_POINTS_PER_SENDER then return end
		received[name] = total
		table.insert(strokes, stroke)
		Draw(stroke)
	end)
end

C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
EventUtil.ContinueOnAddOnLoaded("Blizzard_WorldMap", Init)
