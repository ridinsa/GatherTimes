-- NameDisguiseFrame.lua : the "Random Name" window (right-click the main window's Settings button).
-- It only talks to the HideUnitNames module through _G.GatherTimesNameDisguise.
local _, GT = ...

local FRAME_H = 400
local ALPHA_MIN = 0.2                      -- never fully invisible: the window must stay findable

local function Label(parent, text, x, y, font)
    local label = GT.Font(parent, nil, "OVERLAY", font or "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x or 0, y or 0)
    label:SetText(GT.TR(text or ""))
    return label
end

local function AddOptionTip(frame, title, description)
    frame:HookScript("OnEnter", function(self)
        GT.Tip:SetOwner(self, "ANCHOR_RIGHT")
        GT.Tip:AddLine(GT.TR(title))
        GT.Tip:AddLine(GT.TR(description), 0.85, 0.85, 0.85, true)
        GT.Tip:Show()
    end)
    frame:HookScript("OnLeave", function() GT.Tip:Hide() end)
end

local function SavedAlpha(api)
    local a = tonumber(api.GetDB().frameAlpha)
    if not a or a ~= a then return 1 end
    return math.max(ALPHA_MIN, math.min(1, a))
end

-- see-through: only the backgrounds fade, the text and buttons stay fully readable
local function ApplyAlpha(f, a)
    local bg, hd = GT.colors.bg, GT.colors.header
    f.gtSkinAlpha = a
    if f.header then f.header.gtSkinAlpha = a end
    f:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] * a)
    if f.header then f.header:SetBackdropColor(hd[1], hd[2], hd[3], hd[4] * a) end
end

-- Builds the window once.  Returns the frame; raises an error on a broken widget (the caller catches it).
local function Build(self, api, onPartial)
    local f = self:CreateFlatFrame("GatherTimesNameDisguiseFrame", UIParent, 300, FRAME_H)
    onPartial(f)                                   -- so the caller can hide a half-built window after an error
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:SetMovable(false)
    f:EnableMouse(true)
    f:SetToplevel(true)
    f:Hide()

    f.header = self:CreateHeader(f, GT.TR("Random Name"), function() f:Hide() end)

    -- the check box and its caption come from the shared widget (a plain FontString cannot take mouse clicks)
    local function status()
        local db = api.GetDB()
        local playerStatus = GT.TR(db.hideAll and "Current status: Disguise Enabled" or "Current status: Disguise Disabled")
        local groupStatus = GT.TR(db.groupNames and "Party/raid names hidden" or "Party/raid names visible")
        f.status:SetText(playerStatus .. "\n" .. groupStatus .. "\n" .. GT.TRF("Fake level: %d", db.fakeLevel))
    end
    local toggle = self:CreateCheckLabel(f, "Disguise names",
        function() return api.IsEnabled() end,
        function(on) api.SetEnabled(on == true); status() end)
    toggle:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -38)
    f.toggle = toggle
    AddOptionTip(toggle, "Disguise names", "Replace your character name with a random or custom name in supported UI locations.")

    local groupToggle = self:CreateCheckLabel(f, "Hide party / raid names",
        function() return api.IsGroupNamesEnabled() end,
        function(on)
            api.SetGroupNames(on == true)
            status()
        end)
    groupToggle:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -64)
    f.groupToggle = groupToggle
    AddOptionTip(groupToggle, "Hide party / raid names", "Hide the names of party and raid members in supported UI locations.")

    -- Baganator's bag header ("<name>'s Bags"): blanked while Disguise names is on. Off = nothing runs for it.
    local bagToggle = self:CreateCheckLabel(f, "Hide name in bag header",
        function() return api.IsBagTitleHidden and api.IsBagTitleHidden() end,
        function(on) if api.SetBagTitleHidden then api.SetBagTitleHidden(on == true) end end)
    bagToggle:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -90)
    f.bagToggle = bagToggle
    AddOptionTip(bagToggle, "Hide name in bag header", "Hide your character name in supported bag-addon headers.")

    -- Target-of-target: made invisible while you are in combat (only while the disguise is on).
    local totToggle = self:CreateCheckLabel(f, "Hide target-of-target in combat",
        function() return api.IsHideToTInCombat and api.IsHideToTInCombat() end,
        function(on) if api.SetHideToTInCombat then api.SetHideToTInCombat(on == true) end end)
    totToggle:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -116)
    f.totToggle = totToggle
    AddOptionTip(totToggle, "Hide target-of-target in combat", "While Disguise names is on, the target-of-target frame is hidden during combat and comes back when combat ends.")

    Label(f, "Fake player name", 14, -143)
    local player = self:CreateEditBox(f, 270, 22)
    player:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -156)
    player:SetJustifyH("LEFT")
    player:SetMaxLetters(12)                        -- the longest character name the game allows
    f.playerEdit = player
    -- typed == the user changed the box and has not applied it yet: refreshes must not overwrite it
    local typed = {}
    player:HookScript("OnTextChanged", function(_, userInput) if userInput then typed.player = true end end)

    Label(f, "Fake pet name", 14, -187)
    local pet = self:CreateEditBox(f, 270, 22)
    pet:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -200)
    pet:SetJustifyH("LEFT")
    pet:SetMaxLetters(12)
    f.petEdit = pet
    pet:HookScript("OnTextChanged", function(_, userInput) if userInput then typed.pet = true end end)

    local random = self:CreateFlatButton(f, "Randomize Names", 142, 22)
    random:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -230)
    f.randomButton = random
    local apply = self:CreateFlatButton(f, "Apply", 122, 22)
    apply:SetPoint("LEFT", random, "RIGHT", 6, 0)
    f.applyButton = apply

    -- Opacity of the window background (20 - 100 %), saved with the names
    local fade = self:CreateSlider(f, 270, "Opacity: %s", 20, 100, 5,
        function() return math.floor(SavedAlpha(api) * 100 + 0.5) end,
        function(v)
            api.GetDB().frameAlpha = math.max(ALPHA_MIN, math.min(1, v / 100))
            ApplyAlpha(f, SavedAlpha(api))
        end,
        function(v) return v .. "%" end)
    fade:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -260)
    f.fade = fade
    AddOptionTip(fade.slider, "Opacity", "Adjust the Random Name window background opacity.")

    local level = self:CreateSlider(f, 270, "Random level range: 1-%s", 1, 60, 1,
        function() return api.GetMaxRandomLevel() end,
        function(v) api.SetMaxRandomLevel(v) end)
    level:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -296)
    f.level = level
    AddOptionTip(level.slider, "Random level range", "Set the highest level used when generating a random character level.")

    f.status = Label(f, "", 14, -336, "GameFontDisableSmall")
    f.status:SetWidth(270)
    f.status:SetJustifyH("LEFT")

    function f.refresh()
        local db = api.GetDB()
        if not typed.player then f.playerEdit:SetText(db.fakePlayerName or "") end
        if not typed.pet then f.petEdit:SetText(db.fakePetName or "") end
        f.toggle:SetChecked(db.hideAll == true)
        f.groupToggle:SetChecked(db.groupNames == true)
        f.bagToggle:SetChecked(db.hideBagTitle ~= false)
        f.totToggle:SetChecked(db.hideToTInCombat ~= false)
        status()
        f.fade:Refresh()
        f.level:Refresh()
        ApplyAlpha(f, SavedAlpha(api))
    end

    local function applyNames()
        local p, q = api.CleanName(f.playerEdit:GetText()), api.CleanName(f.petEdit:GetText())
        api.SetNames(p, q)                          -- an empty box keeps the old name
        typed.player, typed.pet = false, false
        api.ApplyNow()
        f.refresh()                                 -- shows what was really taken (cleaned, never empty)
        f.playerEdit:ClearFocus()
        f.petEdit:ClearFocus()
    end
    apply:SetScript("OnClick", applyNames)
    player:HookScript("OnEnterPressed", applyNames)
    pet:HookScript("OnEnterPressed", applyNames)
    random:SetScript("OnClick", function()
        typed.player, typed.pet = false, false
        api.Randomize()
        f.refresh()
    end)
    f:HookScript("OnShow", function() f.refresh() end)   -- hook, not SetScript: keeps the shared OnShow (Korean font) of CreateFlatFrame

    -- /hun commands change the same data while the window is open: keep it in step
    if api.AddListener then api.AddListener(function() if f:IsShown() then f.refresh() end end) end
    return f
end

function GT:ShowNameDisguiseFrame()
    -- Random Name uses the same side slot as the regular panels; close those first.
    if self.HidePanels then self:HidePanels() end
    local api = _G.GatherTimesNameDisguise
    if not (api and api.GetDB and api.SetEnabled) then self.cprint(GT.TR("Name Disguise module is not loaded.")); return end

    -- Keep Random Name tied to the main window: it closes with the main window and with its Settings panel.
    local settingsPanel = self.panels and self.panels.Settings
    if settingsPanel and not settingsPanel._randomNameCloseHooked then
        settingsPanel._randomNameCloseHooked = true
        settingsPanel:HookScript("OnHide", function()
            if GT.nameDisguiseFrame then GT.nameDisguiseFrame:Hide() end
        end)
    end
    if self.main and not self.main._randomNameCloseHooked then
        self.main._randomNameCloseHooked = true
        self.main:HookScript("OnHide", function()
            if GT.nameDisguiseFrame then GT.nameDisguiseFrame:Hide() end
        end)
    end

    if not self.nameDisguiseFrame then
        local partial
        local ok, result = pcall(Build, self, api, function(f) partial = f end)
        if not ok then
            -- never keep a half-built window: report once, hide the leftovers, try again on the next click
            if partial then partial:Hide() end
            if GT.ReportError then GT.ReportError("Random Name", result) else self.cprint(tostring(result)) end
            return
        end
        self.nameDisguiseFrame = result
    end

    local f = self.nameDisguiseFrame
    -- Clicking Rnd Name while open toggles it closed.
    if f:IsShown() then
        f:Hide()
        return
    end
    if self.main then
        f:SetWidth(self.main:GetWidth())
        f:SetScale(self.main:GetScale())
    end
    f:SetHeight(self.main and self.main:GetHeight() or FRAME_H)
    f:ClearAllPoints()
    -- Always position the compact Random Name frame beside the main GatherTimes frame.
    if self.main then
        f:SetPoint("TOPLEFT", self.main, "TOPRIGHT", 2, 0)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    f:Show()
    f:Raise()
end
