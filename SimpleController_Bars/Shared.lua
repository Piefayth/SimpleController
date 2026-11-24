-- What the bars and the extra buttons share: the settings, the after-combat queue,
-- a notice, the eight keys of a gamepad bar, and the press look.
local _, CB = ...

-- Each bar's buttons in Blizzard's order: d-pad left, up, right, down; square,
-- triangle, circle, cross.
CB.KEYS = { "PADDLEFT", "PADDUP", "PADDRIGHT", "PADDDOWN", "PAD3", "PAD4", "PAD2", "PAD1" }
CB.PRESS_DROP = 2 -- Blizzard's PUSHED_BUTTON_ANCHOR_OFFSET; its addon may load after this one
CB.HOLD_TIME = 86400
CB.PROMPT_Y = -35 -- where Blizzard's XML puts each bar's trigger prompt

function CB.KeysText(keys, sep)
	local names = {}
	for i, key in ipairs(keys) do names[i] = GetBindingText(key) end
	return table.concat(names, sep or " + ")
end

-- Whether a source's eight slots hold nothing.
function CB.IsEmpty(source)
	for slot = source.first, source.first + 7 do
		if HasAction(slot) then return false end
	end
	return true
end

-- Blizzard's controller interface is on: everything here is built on its bars.
function CB.ControllerMode()
	return C_InputInterfaceStyle.GetCurrentStyle() == Enum.InputDeviceInterfaceType.Gamepad
end

-- Whether Blizzard's prompts have a picture for a key: the standard controller
-- buttons do; a paddle or a keyboard key does not, and a prompt given one fails.
function CB.HasPicture(key)
	local ok, textures = pcall(InputIconTextureSetUtility.GetActiveInputIconButtonTextures, key)
	return ok and textures ~= nil
end

-- A row by what the player holds: a chord's buttons, or the extra buttons.
function CB.RowName(row)
	return row.keys and CB.KeysText(row.keys) or "Extra buttons"
end

local afterCombat = {}
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_LOGIN")
local atLogin = {}
events:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_LOGIN" then
		SimpleControllerBarsDB = SimpleControllerBarsDB or {}
		for _, fn in ipairs(atLogin) do fn() end
		return
	end
	local queued = afterCombat
	afterCombat = {}
	for _, fn in ipairs(queued) do fn() end
end)

function CB.AtLogin(fn) atLogin[#atLogin + 1] = fn end

function CB.AfterCombat(fn)
	if InCombatLockdown() then afterCombat[#afterCombat + 1] = fn else fn() end
end

-- A line in the middle of the screen that fades: chat is Blizzard's frame.
local notice
function CB.Say(text)
	if not notice then
		notice = CreateFrame("Frame", nil, UIParent)
		notice:SetSize(800, 40)
		notice:SetPoint("TOP", 0, -180)
		notice:SetFrameStrata("DIALOG")
		notice.text = notice:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
		notice.text:SetAllPoints()
		local fade = notice:CreateAnimationGroup()
		local out = fade:CreateAnimation("Alpha")
		out:SetFromAlpha(1)
		out:SetToAlpha(0)
		out:SetStartDelay(4)
		out:SetDuration(1)
		fade:SetScript("OnFinished", function() notice:Hide() end)
		notice.fade = fade
	end
	notice.text:SetText(text)
	notice:Show()
	notice.fade:Stop()
	notice.fade:Play()
end

-- A press looks like Blizzard's: the button drops by PRESS_DROP under its pushed
-- art, done from secure code so it works in a fight. A watch holds `center` (a
-- protected point on the bar) and `button<i>`/`cover<i>` for each button.
CB.PRESS = ([[
	local i = ...
	local button, cover = self:GetFrameRef("button" .. i), self:GetFrameRef("cover" .. i)
	if cover:IsShown() then return end
	cover:Show()
	local point, _, relativePoint, x, y = button:GetPoint(1)
	button:ClearAllPoints()
	button:SetPoint(point, self:GetFrameRef("center"), relativePoint, x, y - %d)
]]):format(CB.PRESS_DROP)

CB.RELEASE = ([[
	local i = ...
	local button, cover = self:GetFrameRef("button" .. i), self:GetFrameRef("cover" .. i)
	if not cover:IsShown() then return end
	cover:Hide()
	local point, _, relativePoint, x, y = button:GetPoint(1)
	button:ClearAllPoints()
	button:SetPoint(point, self:GetFrameRef("center"), relativePoint, x, y + %d)
]]):format(CB.PRESS_DROP)

-- Blizzard's pushed art over a button, shown by the secure press.
function CB.Cover(shown)
	local cover = CreateFrame("Frame", nil, shown, "SecureHandlerBaseTemplate")
	cover:SetFrameLevel(shown:GetFrameLevel() + 5)
	cover:SetAllPoints()
	local art = cover:CreateTexture(nil, "OVERLAY")
	art:SetAllPoints()
	art:SetAtlas(shown.PushedTexture:GetAtlas())
	cover:Hide()
	return cover
end

-- A watch for the press look on `bar`. Secure code may anchor only to an explicitly
-- protected frame, and the bar is protected only through its buttons: `center`
-- marks the bar's centre.
function CB.Watch(name, parent, bar)
	local watch = CreateFrame("Frame", name, parent, "SecureHandlerBaseTemplate")
	watch:SetSize(1, 1)
	watch:SetPoint("CENTER")
	local center = CreateFrame("Frame", nil, bar, "SecureHandlerBaseTemplate")
	center:SetSize(1, 1)
	center:SetPoint("CENTER")
	watch:SetFrameRef("center", center)
	watch:SetAttribute("cb-press", CB.PRESS)
	watch:SetAttribute("cb-release", CB.RELEASE)
	return watch, center
end

-- A frame of ours visible exactly while one of Blizzard's is: our bars and labels
-- live in it, never inside Blizzard's frames. It is never shown or hidden for them,
-- only made transparent: a frame shown or hidden in the middle of Blizzard's own work
-- runs our buttons' show and hide there (its action button template's, reading values
-- our code wrote), and Blizzard's work then runs tainted. Measured twice: our bars
-- inside the bind screen, then a mirror that showed and hid this box from Blizzard's
-- show and hide; both had entering Edit Action Bar refused its focus call (taint.log,
-- 2026-11-23). The alpha is set by a secure snippet on a bare frame inside Blizzard's,
-- as the chords' watchers are: no addon Lua runs there, and it works in a fight.
local mirrors = {}
function CB.Mirror(blizzard)
	if mirrors[blizzard] then return mirrors[blizzard] end
	local box = CreateFrame("Frame", nil, UIParent, "SecureHandlerBaseTemplate")
	box:SetFrameStrata(blizzard:GetFrameStrata())
	box:SetFrameLevel(blizzard:GetFrameLevel() + 10)
	box:SetSize(1, 1)
	box:SetPoint("CENTER")
	box:SetAlpha(blizzard:IsVisible() and 1 or 0)
	local proxy = CreateFrame("Frame", nil, blizzard, "SecureHandlerBaseTemplate")
	proxy:SetFrameRef("box", box)
	SecureHandlerWrapScript(proxy, "OnShow", proxy, [[ self:GetFrameRef("box"):SetAlpha(1) ]])
	SecureHandlerWrapScript(proxy, "OnHide", proxy, [[ self:GetFrameRef("box"):SetAlpha(0) ]])
	mirrors[blizzard] = box
	return box
end

-- The buttons to hold, under a bar of ours, in the bar's mirror box.
function CB.Prompt(template, keys, under, box)
	local prompt = CreateFrame("Frame", nil, box, template)
	for i, key in ipairs(keys) do prompt:SetPromptInputIconKey(i, key) end
	prompt:SetUseDropShadow(true)
	prompt:RefreshInputPromptSize()
	prompt:SetPoint("CENTER", under, "CENTER", 0, CB.PROMPT_Y)
	return prompt
end

-- A row's own offset from where it is put (the Layout page's sliders), per character.
function CB.Offset(row)
	local db = SimpleControllerBarsDB
	return db[row.setting .. "X"] or 0, db[row.setting .. "Y"] or 0
end

-- Whether our button labels show (the Layout settings), and whether each button shows
-- its button's glyph: Blizzard's own "Show Button Prompts" in Edit Mode, read.
function CB.ShowPrompts() return SimpleControllerBarsDB.prompts ~= false end
function CB.ButtonIcons(bar)
	if GamepadMainActionBarFrame and GamepadMainActionBarFrame.showButtonIcons then bar:ShowButtonIcons() else bar:HideButtonIcons() end
end

-- Laying out again after a Layout change: each part adds its own.
local relayouts = {}
function CB.OnRelayout(fn) relayouts[#relayouts + 1] = fn end
function CB.Relayout()
	CB.AfterCombat(function() for _, fn in ipairs(relayouts) do fn() end end)
end

-- Sized and placed against the bottom bar, as Blizzard's own bars are, then moved
-- by the row's own offset.
function CB.Put(bars, bar, x, y, row)
	if row then
		local dx, dy = CB.Offset(row)
		x, y = x + dx, y + dy
	end
	local bottom = bars.bottomBar
	local scale = bottom:GetEffectiveScale()
	bar:SetScale(scale / bar:GetParent():GetEffectiveScale())
	bar:ClearAllPoints()
	bar:SetPoint("CENTER", bottom, "CENTER", x, y)
end

-- Blizzard's bind screen (GamepadActionBarEditFrame) knows only its own slots: while
-- it is binding, what it holds is put in one of ours the way it places its own
-- (AssignActionToGamepadStandardSlot). Its state is only read; it stays open,
-- since closing it from here would taint it.
function CB.PlaceHeld(edit, slot, where)
	local name = edit.BindingInfoFrame.ActionName:GetText() or "It"
	ClearCursor()
	local ok = pcall(edit.pickupFunc, unpack(edit.pickupParams))
	if not ok or not GetCursorInfo() then
		ClearCursor()
		return CB.Say(("Could not pick up %s to bind it."):format(name))
	end
	PlaceAction(slot)
	local replaced = GetCursorInfo() ~= nil
	ClearCursor()
	CB.Say(("%s is on %s%s. Circle closes the bind screen."):format(name, where, replaced and ", replacing what was there" or ""))
end

function CB.Binding(edit)
	return edit.activeMode == "BIND_ACTION" and not InCombatLockdown() and not GamepadRadial:IsShown()
end

-- Blizzard's editor opening and closing, seen from outside: a frame of ours polls
-- whether it is shown. Never an OnShow or OnHide script on a frame inside it: those
-- run in the middle of Blizzard's own show and hide, and what Blizzard does after
-- (giving the spellbook its focus back) then runs tainted ("Interface action failed"
-- in the spellbook after a bind, 2026-11-23).
local editorWatchers, editorShown = {}, false
function CB.OnEditor(fn) editorWatchers[#editorWatchers + 1] = fn end
local editorPoll = CreateFrame("Frame")
editorPoll:SetScript("OnUpdate", function()
	local shown = GamepadActionBarEditFrame ~= nil and GamepadActionBarEditFrame:IsShown()
	if shown == editorShown then return end
	editorShown = shown
	for _, fn in ipairs(editorWatchers) do fn(shown) end
end)

-- Blizzard's editor in any of its modes: binding, picking up, putting down.
function CB.Editing(edit)
	return edit.activeMode ~= nil and edit.activeMode ~= "INACTIVE" and not InCombatLockdown() and not GamepadRadial:IsShown()
end
