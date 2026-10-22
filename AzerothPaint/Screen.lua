local ADDON, ns = ...

-- A sheet of glass over the game, saved per character. Hold the bound key and:
-- drag to draw, right-click to write a note, or shake the mouse to wipe it clean.

local THICKNESS, MIN_DIST = 4, 3
local SHAKE_DIST, SHAKE_TIME, SHAKE_REVERSALS = 40, 0.7, 4
local HINT = "Drag to draw  -  Right-click to write a note  -  Shake to erase"
local strokes, notes -- UIParent units from the bottom-left

local frame = CreateFrame("Frame", "AzerothPaintScreen", UIParent)
frame:SetAllPoints()
frame:SetFrameStrata("DIALOG")
local lines = ns.NewLines(frame)

local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
hint:SetPoint("TOP", 0, -80)
hint:Hide()

local function Cursor()
	local x, y = GetCursorPosition()
	local scale = frame:GetEffectiveScale()
	return x / scale, y / scale
end

local function Redraw()
	lines:Clear()
	for _, stroke in ipairs(strokes) do
		ns.DrawStroke(lines, "BOTTOMLEFT", stroke, 1, 1, THICKNESS)
	end
end

local current
ns.Draggable(frame, Cursor, MIN_DIST,
	function(x, y)
		local r, g, b = ns.ClassColor("player")
		current = { r = r, g = g, b = b, x, y }
		table.insert(strokes, current)
	end,
	function(x, y)
		table.insert(current, x)
		table.insert(current, y)
		ns.DrawStroke(lines, "BOTTOMLEFT", current, 1, 1, THICKNESS, #current / 2 - 1)
	end,
	function()
		if #current < 4 then table.remove(strokes) end -- a click, not a stroke
	end)

-- Notes are edit boxes that never take the mouse. Focus waits until the key is
-- released, so the held key doesn't type into the note or get stuck down.
local boxes, pendingNote = {}, nil
local RedrawNotes

local function CommitNote(box)
	box.note.text = box:GetText()
	if box.note.text == "" then
		tDeleteItem(notes, box.note)
		RedrawNotes()
	end
end

local function NoteBox(i)
	local box = boxes[i]
	if not box then
		box = CreateFrame("EditBox", nil, frame)
		box:SetFontObject(GameFontNormalHuge)
		box:SetSize(400, 32)
		box:SetAutoFocus(false)
		box:EnableMouse(false)
		box:SetScript("OnEnterPressed", box.ClearFocus)
		box:SetScript("OnEscapePressed", box.ClearFocus)
		box:SetScript("OnEditFocusLost", CommitNote)
		boxes[i] = box
	end
	return box
end

function RedrawNotes()
	for _, box in ipairs(boxes) do box:Hide() end
	for i, note in ipairs(notes) do
		local box = NoteBox(i)
		box.note = note
		box:SetPoint("LEFT", frame, "BOTTOMLEFT", note.x, note.y)
		box:SetText(note.text)
		box:SetTextColor(note.r, note.g, note.b)
		box:Show()
	end
end

frame:HookScript("OnMouseDown", function(_, button)
	if button ~= "RightButton" then return end
	hint:SetText("Release the key to type")
	for _, box in ipairs(boxes) do
		if box:IsShown() and box:IsMouseOver() then
			pendingNote = box
			return
		end
	end
	local x, y = Cursor()
	local r, g, b = ns.ClassColor("player")
	table.insert(notes, { x = x, y = y, text = "", r = r, g = g, b = b })
	RedrawNotes()
	pendingNote = boxes[#notes]
end)

function ns.ClearScreen()
	pendingNote = nil
	wipe(strokes)
	wipe(notes)
	Redraw()
	RedrawNotes()
end

local fade = frame:CreateAnimationGroup()
local alpha = fade:CreateAnimation("Alpha")
alpha:SetFromAlpha(1)
alpha:SetToAlpha(0)
alpha:SetDuration(0.4)
fade:SetToFinalAlpha(true)
fade:SetScript("OnFinished", function()
	ns.ClearScreen()
	frame:SetAlpha(1)
end)

-- Counts left/right direction changes of at least SHAKE_DIST while no mouse
-- button is down (so zig-zag drawing never erases).
local shaker = CreateFrame("Frame")
shaker:Hide()
local lastX, dir, travel, reversals
shaker:SetScript("OnShow", function()
	lastX, reversals = nil, {}
end)
shaker:SetScript("OnUpdate", function()
	if IsMouseButtonDown() then
		lastX = nil
		return
	end
	local x = Cursor()
	if not lastX then
		lastX, dir, travel = x, 0, 0
		return
	end
	local dx = x - lastX
	lastX = x
	if dx == 0 then return end
	local d = dx > 0 and 1 or -1
	if d == dir then
		travel = travel + math.abs(dx)
		return
	end
	if travel >= SHAKE_DIST then
		local now = GetTime()
		table.insert(reversals, now)
		while reversals[1] < now - SHAKE_TIME do table.remove(reversals, 1) end
		if #reversals >= SHAKE_REVERSALS and (#strokes > 0 or #notes > 0) and not fade:IsPlaying() then
			wipe(reversals)
			fade:Play()
		end
	end
	dir, travel = d, math.abs(dx)
end)

function ns.Hold(down)
	if not strokes then return end
	if not down and frame:IsMouseEnabled() then
		frame:GetScript("OnMouseUp")(frame, "LeftButton") -- finish a stroke in progress
	end
	frame:EnableMouse(down)
	shaker:SetShown(down)
	hint:SetText(HINT)
	hint:SetShown(down)
	if not down and pendingNote then
		pendingNote:SetFocus()
		pendingNote = nil
	end
end

frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, _, name)
	if name ~= ADDON then return end
	frame:UnregisterEvent("ADDON_LOADED")
	-- Setting mouse scripts turns the mouse on, so switch it off once they're all in.
	frame:EnableMouse(false)
	local db = ns.DB()
	db.screen = db.screen or {}
	db.notes = db.notes or {}
	strokes, notes = db.screen, db.notes
	Redraw()
	RedrawNotes()
end)
