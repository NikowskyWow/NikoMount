-- =========================================================================
-- NIKO MOUNT - Pure Native Logic & Clean Macro
-- =========================================================================

local NIKO_VERSION = "1.1.9"
local GITHUB_URL = "github.com/NikowskyWow/NikoMount/releases"

_G["BINDING_HEADER_NIKO_MOUNT_HEADER"] = "|cff33ff99Niko Mount|r"
_G["BINDING_NAME_CLICK NikoMountCastBtn:LeftButton"] = "Cast Random Mount"

local addonName, addonTable = ...
local SM = CreateFrame("Frame")
local db

-- Typy mountov: "ground" (len zem), "fly" (len vzduch, blokovany v no-fly mestach),
-- "both" (hybrid - lieta v otvorenej oblasti, chodi po zemi aj v Dalarane/WG boji)

-- HYBRID SEED: mounty summonovatelne aj v no-fly mestach A zaroven lietajuce.
-- Kontroluje sa AKO PRVE (ma prednost pred fly keywordmi nizsie).
local BOTH_KEYWORDS = {
    "Netherwing",        -- vsetky farby Netherwing Drake
    "Nether Ray",        -- Riding Nether Ray (Skyguard/Netherwing)
    "Invincible",
    "Horseman",          -- Headless Horseman's Mount
    "X%-53",             -- X-53 Touring Rocket ('-' escapovany pre string.find)
    "Rocket",            -- holiday rakety (Big Love / Nether-Rocket)
}

-- FLY SEED: klasicke lietajuce mounty (blokovane v no-fly mestach)
local FLY_KEYWORDS = {
    "Drake", "Gryphon", "Wyvern", "Hippogryph", "Ray", "Nether",
    "Phoenix", "Helicopter", "Carpet", "Proto", "Bat", "Dragon",
    "Mimiron", "Headless", "Machine", "Broom",
    "Celestial", "Guardian", "Aspect", "Fey", "Reaver", "Nightmare",
    "Windsteed", "Seeker", "Crow", "Wind Rider",
    "Al'ar", "Wyrm", "Vanquisher", "Winged",
}

local defaults = { minimapPos = 45, minimapShown = true, mounts = {} }

-- Odhad typu podla mena (pouzije sa iba raz pre kazdy mount, klik hraca ma vzdy prednost)
local function GuessMountType(name)
    for _, word in ipairs(BOTH_KEYWORDS) do
        if string.find(name, word) then return "both" end
    end
    for _, word in ipairs(FLY_KEYWORDS) do
        if string.find(name, word) then return "fly" end
    end
    return "ground"
end

local function RefreshMountDB()
    local numMounts = GetNumCompanions("MOUNT")
    for i = 1, numMounts do
        local creatureID, creatureName, spellID, icon, active = GetCompanionInfo("MOUNT", i)

        local entry = db.mounts[spellID]
        if not entry then
            db.mounts[spellID] = {
                enabled  = true,
                airType  = GuessMountType(creatureName),
                name     = creatureName,
                icon     = icon,
            }
        else
            entry.name = creatureName
            entry.icon = icon
            -- Migracia zo stareho boolean isAir -> novy airType (iba ak este nema airType)
            if not entry.airType then
                if entry.isAir then
                    -- Stare "fly" mohlo byt v skutocnosti hybrid - preto odhadneme znova
                    entry.airType = GuessMountType(creatureName)
                else
                    entry.airType = "ground"
                end
                entry.isAir = nil -- staru hodnotu uz nepotrebujeme
            end
        end
    end
end

-- =========================================================================
-- 🚀 THE SECURE MACRO BUTTON (Clean 1-Cast Engine)
-- =========================================================================

local CastBtn = CreateFrame("Button", "NikoMountCastBtn", UIParent, "SecureActionButtonTemplate")
CastBtn:SetAttribute("type", "macro")

CastBtn:SetScript("PreClick", function(self)
    if InCombatLockdown() then
        UIErrorsFrame:AddMessage("|cff33ff99[Niko Mount]|r Cannot mount in combat!", 1.0, 0.0, 0.0)
        self:SetAttribute("macrotext", "")
        return 
    end

    RefreshMountDB()

    -- IsFlyableArea() reaguje dynamicky - vratane Wintergrasp pocas boja (false)
    -- a Dalaranu (false). Preto sa spolahame vylucne na nu, ziadne hard-code zony.
    local canFly = IsFlyableArea()

    -- Rozdelime povolene mounty podla toho, co je v aktualnej oblasti summonovatelne.
    -- Flyable oblast  -> vsetko co lieta:  fly + both
    -- No-fly oblast   -> vsetko co chodi:  ground + both (nikdy cisty fly - blokovany)
    local primary = {}   -- preferovany pool
    local fallback = {}  -- zaloha (opacna kategoria, ak preferovana je prazdna)
    local numMounts = GetNumCompanions("MOUNT")

    for i = 1, numMounts do
        local _, _, spellID = GetCompanionInfo("MOUNT", i)
        local data = db.mounts[spellID]
        if data and data.enabled then
            local t = data.airType or "ground"
            if canFly then
                if t == "fly" or t == "both" then
                    table.insert(primary, i)      -- lieta -> preferuj
                elseif t == "ground" then
                    table.insert(fallback, i)     -- zaloha ak nemame lietajuceho
                end
            else
                -- No-fly: cisty "fly" sa NIKDY nepridava (hra ho blokuje)
                if t == "ground" or t == "both" then
                    table.insert(primary, i)
                end
            end
        end
    end

    -- Vyber poolu: primarny; ak prazdny, skusime zalohu
    local pool = primary
    if #pool == 0 then pool = fallback end

    local mountSpellName = nil
    if #pool > 0 then
        local index = pool[math.random(1, #pool)]
        local _, _, spellID = GetCompanionInfo("MOUNT", index)
        mountSpellName = GetSpellInfo(spellID)
    end

    if not mountSpellName then
        UIErrorsFrame:AddMessage("|cff33ff99[Niko Mount]|r No matching mounts found! Check Manager.", 1.0, 0.0, 0.0)
        self:SetAttribute("macrotext", "")
        return
    end

    -- Dynamicky vygenerujeme čisté, nekonfliktné makro
    local macroString = "/dismount [mounted]\n/cancelform\n/cast " .. mountSpellName
    self:SetAttribute("macrotext", macroString)
end)

-- =========================================================================
-- 🎨 NIKO UI - MAIN FRAME
-- =========================================================================

-- Predbezne deklaracie (funkcie/frame definovane nizsie, ale referencovane skorej)
local RefreshMinimapCB, ApplyMinimapShown, UpdateMinimapButton

local MainFrame = CreateFrame("Frame", "NikoMountMainFrame", UIParent)
MainFrame:SetSize(400, 500)
MainFrame:SetPoint("CENTER")
MainFrame:SetMovable(true)
MainFrame:EnableMouse(true)
MainFrame:RegisterForDrag("LeftButton")
MainFrame:SetScript("OnDragStart", MainFrame.StartMoving)
MainFrame:SetScript("OnDragStop", MainFrame.StopMovingOrSizing)
MainFrame:Hide()

MainFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
})

local CloseBtn = CreateFrame("Button", nil, MainFrame, "UIPanelCloseButton")
CloseBtn:SetPoint("TOPRIGHT", -5, -5)

local HeaderTexture = MainFrame:CreateTexture(nil, "ARTWORK")
HeaderTexture:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
HeaderTexture:SetWidth(250)
HeaderTexture:SetHeight(64)
HeaderTexture:SetPoint("TOP", 0, 12)

local HeaderText = MainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
HeaderText:SetPoint("TOP", HeaderTexture, "TOP", 0, -14)
HeaderText:SetText("Niko Mount")

local Footer = MainFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
Footer:SetPoint("BOTTOM", 0, 15)
Footer:SetText("by Nikowsky")

local VersionText = MainFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
VersionText:SetPoint("BOTTOMLEFT", 20, 15)
VersionText:SetText("v" .. NIKO_VERSION)

-- =========================================================================
-- ⌨️ IN-ADDON KEYBIND PICKER
-- =========================================================================
-- Akcia, na ktoru sa viaze klavesa (rovnaka ako v Bindings.xml)
local BIND_ACTION = "CLICK NikoMountCastBtn:LeftButton"
local listeningForKey = false  -- rezim cakania na klavesu

-- Poskladaj modifikatorovy prefix (SHIFT-/CTRL-/ALT-)
local function ModPrefix()
    local mod = ""
    if IsShiftKeyDown() then mod = mod .. "SHIFT-" end
    if IsControlKeyDown() then mod = mod .. "CTRL-" end
    if IsAltKeyDown() then mod = mod .. "ALT-" end
    return mod
end

-- Aplikuje ulozenu klavesu (vola sa pri nacitani aj pri zmene)
local function ApplyKeybind()
    if InCombatLockdown() then return end
    -- Najprv odstranime vsetky klavesy viazane na nasu akciu (cistka orphanov)
    local k1, k2 = GetBindingKey(BIND_ACTION)
    if k1 then SetBinding(k1) end
    if k2 then SetBinding(k2) end
    -- Nastavime novu, ak je ulozena
    if db and db.keybind then
        SetBinding(db.keybind, BIND_ACTION)
    end
    SaveBindings(GetCurrentBindingSet())
end

local function GetKeybindLabel()
    if db and db.keybind then
        return "Keybind: |cff33ff99" .. db.keybind .. "|r"
    end
    return "Keybind: |cffff5555<none>|r"
end

-- Predbezna deklaracia (tlacidla su vytvorene nizsie vo footeri)
local KeybindBtn, ClearBtn
local function RefreshKeybindUI()
    if KeybindBtn then KeybindBtn:SetText(GetKeybindLabel()) end
end

-- Ukoncenie rezimu pocuvania a nastavenie klavesy
local function FinishKeybind(keyString)
    listeningForKey = false
    MainFrame:EnableKeyboard(false)

    if keyString then
        -- Kontrola konfliktu s inou akciou
        local existing = GetBindingAction(keyString)
        if existing and existing ~= "" and existing ~= BIND_ACTION then
            DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99[Niko Mount]|r |cffFFD100" .. keyString ..
                "|r was bound to |cffffffff" .. existing .. "|r - reassigned to Niko Mount.", 1, 0.8, 0)
        end
        db.keybind = keyString
        ApplyKeybind()
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99[Niko Mount]|r Keybind set to |cff33ff99" .. keyString .. "|r.", 0.3, 1, 0.3)
    end
    RefreshKeybindUI()
end

-- Zachytenie klaves priamo na MainFrame (spolahlivo funguje v 3.3.5a)
MainFrame:SetScript("OnKeyDown", function(self, key)
    if not listeningForKey then return end

    if key == "ESCAPE" then
        FinishKeybind(nil) -- zrusenie
        return
    end
    -- Samotny modifikator nie je platna klavesa
    if key == "LSHIFT" or key == "RSHIFT"
    or key == "LCTRL" or key == "RCTRL"
    or key == "LALT" or key == "RALT" then
        return
    end

    FinishKeybind(ModPrefix() .. key)
end)

-- Zachytenie bocnych myssich tlacidiel (Button4/Button5) v rezime pocuvania
MainFrame:SetScript("OnMouseDown", function(self, button)
    if not listeningForKey then return end
    if button == "Button4" or button == "Button5" then
        -- Binding string vyzaduje velke pismena (BUTTON4, BUTTON5)
        FinishKeybind(ModPrefix() .. string.upper(button))
    end
end)

local GitFrame = CreateFrame("Frame", "NikoMountGitFrame", UIParent)
GitFrame:SetSize(350, 120)
GitFrame:SetPoint("CENTER")
GitFrame:SetFrameStrata("DIALOG")
GitFrame:Hide()

GitFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
})

local GitClose = CreateFrame("Button", nil, GitFrame, "UIPanelCloseButton")
GitClose:SetPoint("TOPRIGHT", -5, -5)

local GitHeader = GitFrame:CreateTexture(nil, "ARTWORK")
GitHeader:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
GitHeader:SetWidth(200)
GitHeader:SetHeight(64)
GitHeader:SetPoint("TOP", 0, 12)

local GitTitle = GitFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
GitTitle:SetPoint("TOP", GitHeader, "TOP", 0, -14)
GitTitle:SetText("Update Link")

local GitBox = CreateFrame("EditBox", nil, GitFrame, "InputBoxTemplate")
GitBox:SetSize(280, 20)
GitBox:SetPoint("CENTER", 0, -10)
GitBox:SetAutoFocus(false)
GitBox:SetText(GITHUB_URL)
GitBox:SetCursorPosition(0)
GitBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
GitBox:SetScript("OnEscapePressed", function(self) GitFrame:Hide() end)
GitBox:SetScript("OnMouseUp", function(self) self:HighlightText() end)

local GitInst = GitFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
GitInst:SetPoint("BOTTOM", GitBox, "TOP", 0, 5)
GitInst:SetText("Press CTRL+C to copy:")

-- =========================================================================
-- 🎛️ OVLADACIE TLACIDLA
-- =========================================================================
-- Check Updates - pravy dolny roh
local UpdateBtn = CreateFrame("Button", nil, MainFrame, "UIPanelButtonTemplate")
UpdateBtn:SetSize(110, 24)
UpdateBtn:SetPoint("BOTTOMRIGHT", -15, 12)
UpdateBtn:SetText("Check Updates")
UpdateBtn:SetScript("OnClick", function()
    GitFrame:Show()
    GitBox:SetFocus()
    GitBox:HighlightText()
end)

-- Keybind + Clear - vycentrovana dvojica, mierne vyssie nad footerom
-- Sirka dvojice: 150 + 5 + 55 = 210 -> lavy okraj od stredu = -105
KeybindBtn = CreateFrame("Button", nil, MainFrame, "UIPanelButtonTemplate")
KeybindBtn:SetSize(150, 24)
KeybindBtn:SetPoint("BOTTOM", MainFrame, "BOTTOM", -30, 46)

ClearBtn = CreateFrame("Button", nil, MainFrame, "UIPanelButtonTemplate")
ClearBtn:SetSize(55, 24)
ClearBtn:SetPoint("LEFT", KeybindBtn, "RIGHT", 5, 0)
ClearBtn:SetText("Clear")

-- Spustenie rezimu "cakania na klavesu"
KeybindBtn:SetScript("OnClick", function()
    if InCombatLockdown() then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99[Niko Mount]|r Cannot change keybind in combat.", 1, 0.3, 0.3)
        return
    end
    listeningForKey = true
    MainFrame:EnableKeyboard(true)
    KeybindBtn:SetText("|cffFFD100Press a key...|r")
end)

-- Tooltip namiesto velkeho hint textu
KeybindBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Set Cast Keybind")
    GameTooltip:AddLine("Click, then press any key or", 1, 1, 1)
    GameTooltip:AddLine("SHIFT/CTRL/ALT + key (or mouse Button4/5).", 1, 1, 1)
    GameTooltip:AddLine("ESC cancels.", 0.7, 0.7, 0.7)
    GameTooltip:Show()
end)
KeybindBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

ClearBtn:SetScript("OnClick", function()
    if InCombatLockdown() then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99[Niko Mount]|r Cannot change keybind in combat.", 1, 0.3, 0.3)
        return
    end
    db.keybind = nil
    ApplyKeybind()
    RefreshKeybindUI()
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99[Niko Mount]|r Keybind cleared.", 0.3, 1, 0.3)
end)

local function CreateDarkPanel(parent)
    local box = CreateFrame("Frame", nil, parent)
    box:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    box:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    box:SetBackdropBorderColor(0, 0.7, 1, 1)
    return box
end

local ListBox = CreateDarkPanel(MainFrame)
ListBox:SetPoint("TOPLEFT", 20, -58) -- priestor pre "Show Minimap Button" checkbox
ListBox:SetPoint("BOTTOMRIGHT", -20, 78) -- ponechany priestor pre control row + footer

local ScrollFrame = CreateFrame("ScrollFrame", "NikoMountScrollFrame", ListBox, "FauxScrollFrameTemplate")
ScrollFrame:SetPoint("TOPLEFT", 0, -5)
ScrollFrame:SetPoint("BOTTOMRIGHT", -30, 5)

local ROW_HEIGHT = 35
local MAX_ROWS = 10
local rows = {}

-- Farby a popisky pre 3-stavovy typ mountu
local TYPE_INFO = {
    ground = { label = "Ground", r = 0.8, g = 0.8, b = 0.8 },
    fly    = { label = "Fly",    r = 0.3, g = 1.0, b = 0.3 },
    both   = { label = "Both",   r = 1.0, g = 0.82, b = 0.0 },
}
-- Poradie cyklovania pri kliknuti na typ
local TYPE_CYCLE = { ground = "fly", fly = "both", both = "ground" }

local function CreateRow(index)
    local row = CreateFrame("Frame", nil, ListBox)
    row:SetSize(330, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 10, -((index - 1) * ROW_HEIGHT) - 12)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(28, 28)
    row.icon:SetPoint("LEFT", 5, 0)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 10, 0)
    row.name:SetWidth(150)
    row.name:SetJustifyH("LEFT")

    -- Klikatelny typovy tag (Ground / Fly / Both)
    row.typeBtn = CreateFrame("Button", nil, row)
    row.typeBtn:SetSize(52, 20)
    row.typeBtn:SetPoint("LEFT", row.name, "RIGHT", 4, 0)
    row.typeBtn.text = row.typeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.typeBtn.text:SetPoint("CENTER")
    row.typeBtn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

    row.cbEnable = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    row.cbEnable:SetSize(24, 24)
    row.cbEnable:SetPoint("RIGHT", -20, 0)
    row.cbEnable.text = row.cbEnable:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.cbEnable.text:SetPoint("BOTTOM", row.cbEnable, "TOP", 0, 0)
    row.cbEnable.text:SetText("Enable")

    return row
end

for i = 1, MAX_ROWS do rows[i] = CreateRow(i) end

local function UpdateScrollList()
    RefreshMountDB()
    local mountList = {}
    local numMounts = GetNumCompanions("MOUNT")
    for i = 1, numMounts do
        local _, _, spellID = GetCompanionInfo("MOUNT", i)
        table.insert(mountList, { index = i, spellID = spellID })
    end
    
    FauxScrollFrame_Update(ScrollFrame, #mountList, MAX_ROWS, ROW_HEIGHT)
    local offset = FauxScrollFrame_GetOffset(ScrollFrame)
    
    for i = 1, MAX_ROWS do
        local idx = offset + i
        local row = rows[i]
        if idx <= #mountList then
            local mountInfo = mountList[idx]
            local dbData = db.mounts[mountInfo.spellID]
            
            row:Show()
            row.icon:SetTexture(dbData.icon)
            row.name:SetText(dbData.name)

            -- Typovy tag (Ground / Fly / Both) - klikatelny, cykluje typ
            local t = dbData.airType or "ground"
            local info = TYPE_INFO[t] or TYPE_INFO.ground
            row.typeBtn.text:SetText(info.label)
            row.typeBtn.text:SetTextColor(info.r, info.g, info.b)
            row.typeBtn:SetScript("OnClick", function()
                local cur = db.mounts[mountInfo.spellID].airType or "ground"
                db.mounts[mountInfo.spellID].airType = TYPE_CYCLE[cur] or "ground"
                UpdateScrollList() -- prekresli riadok s novym typom
            end)

            row.cbEnable:SetChecked(dbData.enabled)
            row.cbEnable:SetScript("OnClick", function(self) db.mounts[mountInfo.spellID].enabled = self:GetChecked() end)
        else
            row:Hide()
        end
    end
end

ScrollFrame:SetScript("OnVerticalScroll", function(self, offset)
    FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, UpdateScrollList) 
end)

MainFrame:SetScript("OnShow", function()
    UpdateScrollList()
    RefreshKeybindUI()
    RefreshMinimapCB()
end)

local MinimapBtn = CreateFrame("Button", "NikoMountMinimapButton", Minimap)
MinimapBtn:SetSize(32, 32)
MinimapBtn:SetFrameLevel(8)
MinimapBtn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local icon = MinimapBtn:CreateTexture(nil, "BACKGROUND")
icon:SetTexture("Interface\\Icons\\Inv_Misc_Food_54")
icon:SetSize(20, 20)
icon:SetPoint("CENTER")

local border = MinimapBtn:CreateTexture(nil, "OVERLAY")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
border:SetSize(52, 52)
border:SetPoint("TOPLEFT")

UpdateMinimapButton = function()
    local angle = math.rad(db.minimapPos or 45)
    local x = math.cos(angle) * 80
    local y = math.sin(angle) * 80
    MinimapBtn:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

-- Zobrazi/skryje minimap ikonu podla nastavenia
ApplyMinimapShown = function()
    if db.minimapShown == false then
        MinimapBtn:Hide()
    else
        MinimapBtn:Show()
    end
end

-- Checkbox "Show Minimap Button" v hornej casti okna (nad zoznamom)
local MinimapCB = CreateFrame("CheckButton", nil, MainFrame, "UICheckButtonTemplate")
MinimapCB:SetSize(22, 22)
MinimapCB:SetPoint("TOPLEFT", 18, -30)
MinimapCB.text = MinimapCB:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
MinimapCB.text:SetPoint("LEFT", MinimapCB, "RIGHT", 2, 0)
MinimapCB.text:SetText("Show Minimap Button")
MinimapCB:SetScript("OnClick", function(self)
    db.minimapShown = self:GetChecked() and true or false
    ApplyMinimapShown()
end)

RefreshMinimapCB = function()
    MinimapCB:SetChecked(db.minimapShown ~= false)
end

MinimapBtn:RegisterForDrag("RightButton")
MinimapBtn:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function(self)
        local xpos, ypos = GetCursorPosition()
        local xmin, ymin = Minimap:GetLeft(), Minimap:GetBottom()
        xpos = xpos / Minimap:GetEffectiveScale() - xmin - 70
        ypos = ypos / Minimap:GetEffectiveScale() - ymin - 70
        local angle = math.deg(math.atan2(ypos, xpos))
        db.minimapPos = angle
        UpdateMinimapButton()
    end)
end)

MinimapBtn:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)

MinimapBtn:SetScript("OnClick", function(self, button)
    if button == "LeftButton" then
        if MainFrame:IsShown() then MainFrame:Hide() else MainFrame:Show() end
    end
end)

MinimapBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Niko Mount Manager")
    GameTooltip:AddLine("Left-Click: Configure Mounts", 1, 1, 1)
    GameTooltip:AddLine("Right-Click: Move Icon", 0.7, 0.7, 0.7)
    GameTooltip:Show()
end)
MinimapBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

SM:RegisterEvent("ADDON_LOADED")
SM:RegisterEvent("PLAYER_LOGIN")
SM:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "NikoMount" then
        -- Jednorazová migrácia zo starého SausageMount na NikoMount (zachová nastavenia)
        if not NikoMountDB and SausageMountDB then
            NikoMountDB = SausageMountDB
            SausageMountDB = nil
        end

        if not NikoMountDB then NikoMountDB = defaults end
        db = NikoMountDB
        if not db.mounts then db.mounts = {} end

        UpdateMinimapButton()
        ApplyMinimapShown()
        RefreshMinimapCB()
        RefreshKeybindUI()

        SLASH_NIKOMOUNT1 = "/nikomount"
        SlashCmdList["NIKOMOUNT"] = function(msg)
            MainFrame:Show()
        end

        self:UnregisterEvent("ADDON_LOADED")

    elseif event == "PLAYER_LOGIN" then
        -- Bindingy su plne pripravene az tu - aplikujeme ulozenu klavesu
        if InCombatLockdown() then
            -- Login pocas boja: aplikujeme az po skonceni boja
            self:RegisterEvent("PLAYER_REGEN_ENABLED")
        else
            ApplyKeybind()
        end
        self:UnregisterEvent("PLAYER_LOGIN")

    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Docorucenie keybindu, ak login prebehol v boji
        ApplyKeybind()
        self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    end
end)