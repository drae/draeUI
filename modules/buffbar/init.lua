--[[


--]]
local DraeUI = select(2, ...)

local BuffBar = DraeUI:NewModule("BuffBar", "AceEvent-3.0")

--
local strmatch = string.match

--[[



--]]
local SetTooltip = function(button)
    if button:GetAttribute('index') then
        --		GameTooltip:SetUnitBuffByAuraInstanceID(button.header:GetAttribute('unit'), button.auraInstanceID)

        GameTooltip:SetUnitAura(button.header:GetAttribute('unit'), button:GetID(), button.filter)

        if (issecretvalue and not issecretvalue(button.caster) and UnitExists(button.caster)) then
            local color

            if (UnitIsPlayer(button.caster)) then
                if (RAID_CLASS_COLORS[select(2, UnitClass(button.caster))]) then
                    color = RAID_CLASS_COLORS[select(2, UnitClass(button.caster))]
                end
            else
                color = FACTION_BAR_COLORS[UnitReaction(button.caster, "player")]
            end

            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(
                ("Cast by %s%s|r"):format(DraeUI.Hex(color.r, color.g, color.b), UnitName(button.caster)))
        end

        GameTooltip:Show()
    elseif button:GetAttribute('target-slot') then
        GameTooltip:SetInventoryItem('player', button:GetID())
    end
end

local Button_OnLeave = function()
    GameTooltip:Hide()
end

local Button_OnEnter = function(self)
    GameTooltip:SetOwner(self, 'ANCHOR_BOTTOMLEFT', -5, -5)

    self.elapsed = 1 -- let the tooltip update next frame
end

local Button_OnShow = function(self)
    if self.enchantIndex then
        self.header.enchants[self.enchantIndex] = self
        self.header.elapsedEnchants = 1 -- let the enchant update next frame
    end
end

local Button_OnHide = function(self)
    if self.enchantIndex then
        self.header.enchants[self.enchantIndex] = nil
    else
        self.instant = true
    end
end

local Button_OnUpdate = function(self, elapsed)
    if self.elapsed and self.elapsed > 0.1 then
        if GameTooltip:IsOwned(self) then
            SetTooltip(self)
        end

        self.elapsed = 0
    else
        self.elapsed = (self.elapsed or 0) + elapsed
    end
end

local UpdateAura = function(button, index)
    local aura = C_UnitAuras.GetAuraDataByIndex(button.header:GetAttribute("unit"), index, button.filter)

    if not aura then
        return
    end

    button.caster = aura.sourceUnit
    button.Count:SetText((aura.charges == nil and "") or (aura.charges and aura.charges <= 1 and "") or aura.charges)
    button.Icon:SetTexture(aura.icon)

    local duration = C_UnitAuras.GetAuraDuration(button.header:GetAttribute("unit"), aura.auraInstanceID)
    if duration then
        button.Cooldown:SetCooldownFromDurationObject(duration)
    end
end

local UpdateTempEnchant = function(button, index, expiration)
    if expiration then
        button.Icon:SetTexture(GetInventoryItemTexture("player", index))

        local r, g, b
        local quality = GetInventoryItemQuality("player", index)

        if quality and quality > 1 then
            r, g, b = GetItemQualityColor(quality)
        else
            r, g, b = 0, 0, 0
        end

        button:SetBackdropBorderColor(r, g, b)

        local remaining = (expiration * 0.001) or 0
        button.Cooldown:SetCooldown(GetTime(), remaining)
    end
end

local Button_OnAttributeChanged = function(self, attr, value)
    if attr == 'index' then
        if self.instant then
            UpdateAura(self, value)
            self.instant = nil
        elseif self.header.spells[self] ~= value then
            self.header.spells[self] = value
        end
    elseif attr == 'target-slot' and self.enchantIndex and self.header.enchants[self.enchantIndex] ~= self then
        self.header.enchants[self.enchantIndex] = self
        self.header.elapsedEnchants = 0 -- reset the timer so we can wait for the data to be ready
    end
end

local Header_OnEvent = function(self, event)
    if event == 'WEAPON_ENCHANT_CHANGED' then
        local header = self.frame

        for enchantIndex, button in next, header.enchantButtons do
            if header.enchants[enchantIndex] ~= button then
                header.enchants[enchantIndex] = button
                header.elapsedEnchants = 0 -- reset the timer so we can wait for the data to be ready
            end
        end
    end
end

local Header_OnUpdate = function(self, elapsed)
    local header = self.frame

    if header.elapsedSpells and header.elapsedSpells > 0.1 then
        local button, value = next(header.spells)

        while button do
            UpdateAura(button, value)

            header.spells[button] = nil
            button, value = next(header.spells)
        end

        header.elapsedSpells = 0
    else
        header.elapsedSpells = (header.elapsedSpells or 0) + elapsed
    end

    if header.elapsedEnchants and header.elapsedEnchants > 0.5 then
        local index, enchant = next(header.enchants)

        if index then
            local _, main, _, _, _, offhand, _, _, _, ranged = GetWeaponEnchantInfo()

            while enchant do
                UpdateTempEnchant(enchant, enchant:GetID(),
                    (index == 1 and main) or (index == 2 and offhand) or (index == 3 and ranged))

                header.enchants[index] = nil
                index, enchant = next(header.enchants)
            end
        end

        header.elapsedEnchants = 0
    else
        header.elapsedEnchants = (header.elapsedEnchants or 0) + elapsed
    end
end

BuffBar.CreateAuraButton = function(_, button)
    button.header = button:GetParent()
    button.name = button:GetName()

    button.auraType = "HELPFUL"
    button.filter = button.header.filter

    button.enchantIndex = tonumber(strmatch(button.name, 'TempEnchant(%d)$'))
    if button.enchantIndex then
        button.header['enchant' .. button.enchantIndex] = button
        button.header.enchantButtons[button.enchantIndex] = button
    else
        button.instant = true -- let update on attribute change
    end

    local border = CreateFrame("Frame", nil, button, BackdropTemplateMixin and "BackdropTemplate")
    border:SetPoint("TOPLEFT", button, -3, 3)
    border:SetPoint("BOTTOMRIGHT", button, 3, -3)
    border:SetFrameStrata("BACKGROUND")
    border:SetBackdrop {
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false,
        edgeSize = 3
    }
    border:SetBackdropBorderColor(0, 0, 0)
    button.Border = border

    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetTexCoord(unpack(DraeUI.config["general"].texcoords))
    icon:SetAllPoints(button)
    button.Icon = icon

    local overlay = button:CreateTexture(nil, "OVERLAY")
    button.Overlay = overlay

    local cd = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    cd:SetReverse(true)
    cd:SetAllPoints(button)
    button.Cooldown = cd

    local count = button:CreateFontString(nil)
    count:SetFont(DraeUI.media.font, DraeUI.config["general"].fontsize3, "THINOUTLINE")
    count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 7, -6)
    button.Count = count

    button:SetScript('OnHide', Button_OnHide)
    button:SetScript('OnShow', Button_OnShow)
    button:SetScript("OnEnter", Button_OnEnter)
    button:SetScript("OnLeave", Button_OnLeave)
    button:SetScript("OnUpdate", Button_OnUpdate)
    button:SetScript('OnAttributeChanged', Button_OnAttributeChanged)
    --    button:RegisterForClicks('RightButtonUp', 'RightButtonDown')
end

local UpdateHeader = function(header)
    header:SetAttribute("template", "DraeUIAuraTemplate")
    header:SetAttribute("weaponTemplate", "DraeUIAuraTemplate")

    header:SetAttribute("unit", "player")
    header:SetAttribute("filter", "HELPFUL")
    header:SetAttribute("separateOwn", true)
    header:SetAttribute("consolidateDuration", -1)
    header:SetAttribute("includeWeapons", 1)
    header:SetAttribute("separateOwn", 1)
    header:SetAttribute("sortMethod", "TIME")
    header:SetAttribute("sortDirection", "+")
    header:SetAttribute("maxWraps", 2)
    header:SetAttribute("wrapAfter", 16)
    header:SetAttribute("point", "BOTTOMRIGHT")
    header:SetAttribute("minWidth", 30)
    header:SetAttribute("minHeight", 30)
    header:SetAttribute("xOffset", -34)
    header:SetAttribute("yOffset", 0)
    header:SetAttribute("wrapXOffset", 0)
    header:SetAttribute("wrapYOffset", 34)

    local index = 1
    local child = select(index, header:GetChildren())
    while child do
        child.auraType = header.auraType -- used to update cooldown text

        -- Blizzard bug fix, icons arent being hidden when you reduce the amount of maximum buttons
        if index > 16 and child:IsShown() then
            child:Hide()
        end

        index = index + 1
        child = select(index, header:GetChildren())
    end
end

-- Totally stolen from ElvUI because I"m lazy ... well, with some changes based on oUF
local CreateBuffBarHeader = function()
    local name = "DraeUIBuffBar"
    local auraType = "buffs"
    local filter = "HELPFUL"

    local header = CreateFrame('Frame', name, UIParent, 'SecureAuraHeaderTemplate')
    header:SetClampedToScreen(true)
    header:UnregisterEvent('UNIT_AURA') -- we only need to watch player and vehicle
    header:RegisterUnitEvent('UNIT_AURA', 'player', 'vehicle')
    header:SetAttribute('unit', 'player')
    header:SetAttribute('filter', filter)
    header.enchantButtons = {}
    header.enchants = {}
    header.spells = {}

    header.visibility = CreateFrame('Frame', nil, UIParent, 'SecureHandlerStateTemplate')
    header.visibility:SetScript('OnUpdate', Header_OnUpdate) -- dont put this on the main frame
    header.visibility:SetScript('OnEvent', Header_OnEvent)   -- dont put this on the main frame
    header.visibility.frame = header
    header.auraType = auraType
    header.filter = filter
    header.name = name

    header.visibility:RegisterEvent('WEAPON_ENCHANT_CHANGED')

    RegisterAttributeDriver(header, 'unit', '[vehicleui] vehicle; player')
    SecureHandlerSetFrameRef(header.visibility, 'AuraHeader', header)
    RegisterStateDriver(header.visibility, 'customVisibility', '[petbattle] 0;1')

    header.visibility:SetAttribute('_onstate-customVisibility', [[
		local header = self:GetFrameRef('AuraHeader')
		local hide, shown = newstate == 0, header:IsShown()
		if hide and shown then header:Hide() elseif not hide and not shown then header:Show() end
	]]) -- use custom script that will only call hide when it needs to, this prevents spam to `SecureAuraHeader_Update`

    header:SetAttribute('consolidateDuration', -1)
    header:SetAttribute('includeWeapons', 1)

    UpdateHeader(header)
    header:Show()

    return header
end

BuffBar.PlayerEnteringWorld = function(self)
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
end

BuffBar.OnInitialize = function(self)
    -- Do things when we enter the world
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "PlayerEnteringWorld")
end

BuffBar.OnEnable = function(self)
    self.BuffFrame = CreateBuffBarHeader()

    self.BuffFrame:SetPoint("BOTTOMRIGHT", _G.UIParent, "BOTTOMRIGHT", -20, 20)
end
