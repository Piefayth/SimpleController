-- Simple Controller: the core the suite's bar addons share. It holds the one editor
-- (Editor.lua: Blizzard's bind screen and Edit Action Bars, extended), which addons
-- extend through the global SimpleController:
--   AddBar{ keys, first, small, big }  a bar of eight slots from `first`, picked in the
--       editor by `keys` held (shoulders and triggers), drawn where `small` and `big`
--       (its frames of play, at rest and grown) are
--   AddExtras{ first, bar, keys = fn, copy = fn(parent) }  buttons each on its own key
--       (keys() gives them by index), their row of play `bar`, a copy of it for the editor
--   OnEditor(fn(open))  the editor opening and closing (its owner hides its bars of play)
--   AddTargetAction{ key, target = fn(slot), run = fn(slot, thing, editing, done), label, choose,
--       handOver, fresh = fn(), pick = { label, choose } }  somewhere other than a bar
--       slot (Wheels: a wheel). Holding something, `key` (prompt `label`) lights the slots
--       `target` accepts, fading the rest, the box saying `label` and `choose`; the one
--       pressed gets run(slot, thing, editing, done) after the editor closes, thing =
--       { kind, id, name, icon }, editing: in Edit Action Bars; its shade and hidden bars
--       of play stay until done() (or EditHolding opens it again). Editing with nothing
--       held, `key` holds `fresh()` ({ func, params } putting a new thing on the cursor; prompt
--       `handOver`), or with `pick` chooses a target the same way, run(slot, nil, true).
--       Bare `key` hands over from Blizzard's screens too: its bind screen with
--       `handOver` (prompt `label`: its targets are chosen at once), its Edit Action Bar
--       with `handOver` (`fresh()` held) or `pick` (its targets chosen).
--   EditHolding({ func, params } | nil)  the editor opened in Edit Action Bars, holding
--       what func(params) puts on the cursor, or nothing
--   Prompt(parent, keys)  the buttons that pick a bar, as a frame to put under it
--   Glow(prompt, on)  its buttons' glow, as Blizzard's active bar shows its triggers'
-- Alone, with nothing using it, it says so at login.
local _, SC = ...

SimpleController = SC

-- The glow Blizzard plays on a trigger's prompt as its bar becomes the active one
-- (Blizzard_GamepadActionBars' ActionBarFocusFX.lua and ModifierGlow templates): a
-- flash over the icon, by icon set, and a glow behind it that settles faint and stays
-- while lit. Every button of a prompt glows; only the triggers have a flash picture,
-- so any other button flashes as its own lit icon, added over itself.
local GLOW_TOP = {
	PADLTRIGGER = { Generic = "gamepad-actionbar-fx-triggerL-top", Letters = "gamepad-actionbar-fx-triggerL-top",
		Shapes = "gamepad-actionbar-fx-triggerL-top-ps", Reverse = "gamepad-actionbar-fx-triggerL-top-switch" },
	PADRTRIGGER = { Generic = "gamepad-actionbar-fx-triggerR-top", Letters = "gamepad-actionbar-fx-triggerR-top",
		Shapes = "gamepad-actionbar-fx-triggerR-top-ps", Reverse = "gamepad-actionbar-fx-triggerR-top-switch" },
}
local glows = {} -- prompt -> { lit, each button's pieces }

local function fade(group, texture, from, to, duration)
	local alpha = group:CreateAnimation("Alpha")
	alpha:SetTarget(texture)
	alpha:SetFromAlpha(from)
	alpha:SetToAlpha(to)
	alpha:SetDuration(duration)
end

local function buildGlow(icon, key)
	local top = CreateFrame("Frame", nil, icon)
	top:SetAllPoints()
	top.texture = top:CreateTexture(nil, "OVERLAY")
	if GLOW_TOP[key] then
		top.texture:SetSize(62, 62)
		top.texture:SetPoint("CENTER")
	else
		-- the lit icon Blizzard shows focused (InputIconTexture's ActiveTexture), where it is
		top.texture:SetAllPoints(icon.ActiveTexture)
		top.texture:SetBlendMode("ADD")
	end
	top.start = top:CreateAnimationGroup()
	top.start:SetToFinalAlpha(true)
	fade(top.start, top.texture, 1, 0, 0.3)
	top.start:SetScript("OnFinished", function() top:Hide() end)
	top:Hide()
	local behind = CreateFrame("Frame", nil, icon)
	behind:SetSize(88, 88)
	behind:SetPoint("CENTER")
	behind.texture = behind:CreateTexture(nil, "BACKGROUND")
	behind.texture:SetAllPoints()
	behind.texture:SetAtlas("gamepad-actionbar-fx-trigger-behind")
	behind.start = behind:CreateAnimationGroup()
	behind.start:SetToFinalAlpha(true)
	fade(behind.start, behind.texture, 0.7, 0.2, 0.5)
	behind.stop = behind:CreateAnimationGroup()
	behind.stop:SetToFinalAlpha(true)
	fade(behind.stop, behind.texture, 0.2, 0, 0.33)
	behind.stop:SetScript("OnFinished", function() behind:Hide() end)
	behind:Hide()
	return { key = key, icon = icon, top = top, behind = behind }
end

-- The flash's picture now: the trigger's by icon set, else the icon's own lit one.
local function flashAtlas(piece)
	local set = GLOW_TOP[piece.key]
	if set then return set[InputDeviceIconSetManager:GetActiveInputDeviceIconSet()] end
	return piece.icon.ActiveTexture:GetAtlas()
end

-- Lights or dims `prompt`'s glows (a prompt of names: nothing).
function SC.Glow(prompt, on)
	local glow = glows[prompt]
	if not glow or glow.lit == on then return end
	glow.lit = on
	for _, piece in ipairs(glow) do
		local top, behind = piece.top, piece.behind
		if on then
			behind.stop:Stop()
			-- under the bars' buttons, as Blizzard's is (its frame level 1)
			behind:SetFrameLevel(1)
			behind:Show()
			behind.start:Play()
			if top.texture:SetAtlas(flashAtlas(piece) or "") then
				top:Show()
				top.start:Play()
			end
		else
			top.start:Stop()
			top:Hide()
			behind.start:Stop()
			behind.stop:Play()
		end
	end
end

-- Blizzard's prompt for `keys`, or their names where it has no picture for one (a
-- paddle: a prompt given one fails). Either answers SetFocused and SetPressable.
local PROMPTS = { "InputPromptOneIconTemplate", "InputPromptTwoIconTemplate", "InputPromptThreeIconTemplate" }
local function pictured(key)
	local ok, textures = pcall(InputIconTextureSetUtility.GetActiveInputIconButtonTextures, key)
	return ok and textures ~= nil
end
function SC.Prompt(parent, keys)
	local all = PROMPTS[#keys] ~= nil
	for _, key in ipairs(keys) do all = all and pictured(key) end
	if all then
		local prompt = CreateFrame("Frame", nil, parent, PROMPTS[#keys])
		local glow = { lit = false }
		for i, key in ipairs(keys) do
			prompt:SetPromptInputIconKey(i, key)
			glow[i] = buildGlow(prompt.InputIcons[i], key)
		end
		glows[prompt] = glow
		prompt:SetUseDropShadow(true)
		prompt:RefreshInputPromptSize()
		return prompt
	end
	local prompt = CreateFrame("Frame", nil, parent)
	prompt:SetSize(1, 1)
	local names = {}
	for i, key in ipairs(keys) do names[i] = GetBindingText(key) end
	local text = prompt:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	text:SetPoint("CENTER")
	text:SetText(table.concat(names, " + "))
	-- the prompt's lit and pressable looks: a name has neither
	function prompt.SetFocused() end
	function prompt.SetPressable() end
	return prompt
end
SC.bars, SC.onEditor, SC.targetActions = {}, {}, {}

function SC.AddBar(bar) SC.bars[#SC.bars + 1] = bar end
function SC.AddExtras(extras) SC.extras = extras end
function SC.OnEditor(fn) SC.onEditor[#SC.onEditor + 1] = fn end
function SC.AddTargetAction(action) SC.targetActions[#SC.targetActions + 1] = action end

-- something extends the editor
function SC.Used()
	return #SC.bars > 0 or SC.extras ~= nil or #SC.targetActions > 0
end

-- The suite's notices, each addon's named: lines in a message frame of ours under
-- Blizzard's error text, fading as it does. Never Blizzard's chat frame: a line an
-- addon adds there is the addon's, and opening chat in a fight reads it, so the
-- controller's focus switch runs tainted and every binding and bar it changes is
-- refused ("Interface action failed", blamed on Bars, 2026-11-24).
local notices = CreateFrame("MessageFrame", "SimpleControllerNotices", UIParent)
notices:SetSize(900, 90)
notices:SetPoint("TOP", UIParent, "TOP", 0, -190)
notices:SetFrameStrata("DIALOG")
notices:SetFontObject(GameFontHighlightLarge)
notices:SetJustifyH("CENTER")
notices:SetTimeVisible(10)
notices:SetFadeDuration(2)
function SC.Say(text, from)
	notices:AddMessage(("|cffffd100Simple Controller%s:|r %s"):format(from and (": " .. from) or "", text))
end

local afterCombat = {}
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_ENTERING_WORLD") -- after every addon's PLAYER_LOGIN, where they register
events:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_ENTERING_WORLD" then
		-- once a UI session, at a login or a reload alike
		events:UnregisterEvent("PLAYER_ENTERING_WORLD")
		if not SC.Used() then
			return SC.Say("Simple Controller does nothing on its own: Simple Controller: Bars or Wheels uses it.")
		end
		-- the editor's copies made under the loading screen: made at its first opening,
		-- they cost a frame you could feel
		SC.AfterCombat(SC.Prebuild)
		return
	end
	local queued = afterCombat
	afterCombat = {}
	for _, fn in ipairs(queued) do fn() end
end)
function SC.AfterCombat(fn)
	if InCombatLockdown() then afterCombat[#afterCombat + 1] = fn else fn() end
end
