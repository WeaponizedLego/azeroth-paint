local _, ns = ...

-- A reusable pool of Line regions on one frame. Clear() hides them all.
function ns.NewLines(frame)
	local lines, used = {}, 0
	local pool = {}

	function pool:Add(point, x1, y1, x2, y2, r, g, b, thickness)
		used = used + 1
		local line = lines[used]
		if not line then
			line = frame:CreateLine(nil, "OVERLAY")
			lines[used] = line
		end
		line:SetColorTexture(r, g, b, 0.9)
		line:SetThickness(thickness)
		line:SetStartPoint(point, frame, x1, y1)
		line:SetEndPoint(point, frame, x2, y2)
		line:Show()
	end

	function pool:Clear()
		for i = 1, used do
			lines[i]:Hide()
		end
		used = 0
	end

	return pool
end

-- A stroke is a flat list of points {x1, y1, x2, y2, ...} plus r, g, b fields.
-- Draws its segments from point `from` onward, scaling coordinates by sx, sy.
function ns.DrawStroke(lines, point, stroke, sx, sy, thickness, from)
	for i = 2 * (from or 1) + 1, #stroke - 1, 2 do
		lines:Add(point, stroke[i - 2] * sx, stroke[i - 1] * sy, stroke[i] * sx, stroke[i + 1] * sy,
			stroke.r, stroke.g, stroke.b, thickness)
	end
end

-- While the left button is held on `frame`, samples getCursor() every frame and
-- calls onPoint(x, y) once the cursor has moved at least minDist.
function ns.Draggable(frame, getCursor, minDist, onStart, onPoint, onDone)
	local lastX, lastY
	local function Track()
		local x, y = getCursor()
		if (x - lastX) ^ 2 + (y - lastY) ^ 2 >= minDist ^ 2 then
			lastX, lastY = x, y
			onPoint(x, y)
		end
	end
	frame:SetScript("OnMouseDown", function(_, button)
		if button ~= "LeftButton" then return end
		lastX, lastY = getCursor()
		onStart(lastX, lastY)
		frame:SetScript("OnUpdate", Track)
	end)
	frame:SetScript("OnMouseUp", function(_, button)
		if button ~= "LeftButton" or not lastX then return end
		frame:SetScript("OnUpdate", nil)
		lastX = nil
		onDone()
	end)
end

function ns.ClassColor(unit)
	local c = RAID_CLASS_COLORS[select(2, UnitClass(unit)) or ""]
	if c then return c.r, c.g, c.b end
	return 1, 0.82, 0
end

-- Always read the global: saved variables replace it after our files run.
function ns.DB()
	AzerothPaintDB = AzerothPaintDB or {}
	return AzerothPaintDB
end

BINDING_NAME_AZEROTHPAINT_HOLD = "Hold to draw on screen"

function AzerothPaint_Hold(keystate)
	ns.Hold(keystate == "down")
end

local function Help()
	local key = GetBindingKey("AZEROTHPAINT_HOLD")
	print("|cffffd100Azeroth Paint:|r " .. (key
		and ("hold " .. key .. " and drag to draw, right-click to write a note, shake the mouse to erase.")
		or "bind a key under Key Bindings > AddOns > Hold to draw on screen.")
		.. " /paint clear wipes the screen.")
end

SLASH_AZEROTHPAINT1 = "/paint"
SlashCmdList.AZEROTHPAINT = function(msg)
	if msg == "clear" then
		ns.ClearScreen()
	else
		Help()
	end
end

local login = CreateFrame("Frame")
login:RegisterEvent("PLAYER_LOGIN")
login:SetScript("OnEvent", function()
	if not GetBindingKey("AZEROTHPAINT_HOLD") then Help() end
end)
