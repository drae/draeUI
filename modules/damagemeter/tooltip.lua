--[[
	The per-row spell breakdown tooltip.

	Blizzard's session getters refuse a secret GUID as an argument, so mid-combat
	only your own row has a breakdown at all.
--]]
local DraeUI = select(2, ...)

local Meter = DraeUI:GetModule("DamageMeter")

local Tooltip = Meter:NewModule("Tooltip")

-- Localise a bunch of functions
local _G = _G
local C_Spell = C_Spell
local ipairs, pcall = ipairs, pcall

local L = DraeUI.L

local CanAccessValue = DraeUI.CanAccessValue

-- Not config: past this the tooltip is taller than the window it came from
local SPELL_LIMIT = 8

--[[
	A spell's name with its icon in front, or nil when it can't be assembled.

	The getters take a secret spell ID, but what comes back out is secret too,
	and this concatenates the icon escape onto the name. Check both halves
	before joining them.
--]]
local SpellText = function(spellID)
	local ok, name = pcall(C_Spell.GetSpellName, spellID)

	if not ok or not CanAccessValue(name) then
		return nil
	end

	local hasIcon, icon = pcall(C_Spell.GetSpellTexture, spellID)

	if hasIcon and CanAccessValue(icon) then
		return "|T" .. icon .. ":14:14:0:0:64:64:4:60:4:60|t " .. name
	end

	return name
end

-- The body. `row.source` is nil for a row currently hidden
local Fill = function(tooltip, row)
	local window = row.window
	local source = row.source
	local Data = Meter.Data

	if not source then
		return
	end

	-- Guarded, not passed through: a FontString takes a secret, a tooltip line
	-- is not a sink with any such promise
	tooltip:AddLine(CanAccessValue(source.name) and source.name or _G["UNKNOWN"])
	tooltip:AddLine(Data:ReadoutName(window.readout), 0.6, 0.6, 0.6)

	local data = Data:Source(window, source)

	if not data or not data.combatSpells then
		tooltip:AddLine(" ")
		tooltip:AddLine(L["DAMAGEMETER_SECRET"], 0.8, 0.4, 0.4)

		return
	end

	tooltip:AddLine(" ")

	local shown = 0

	for _, spell in ipairs(data.combatSpells) do
		if shown >= SPELL_LIMIT then
			break
		end

		-- A spell with an unreadable amount is still worth listing
		local text = SpellText(spell.spellID)

		if text then
			shown = shown + 1

			local amount = CanAccessValue(spell.totalAmount) and Data:Abbreviate(spell.totalAmount) or ""

			tooltip:AddDoubleLine(text, amount, 1, 1, 1, 1, 1, 1)
		end
	end

	if shown == 0 then
		tooltip:AddLine(L["DAMAGEMETER_NO_DATA"], 0.6, 0.6, 0.6)
	end
end

-- Called once per row at creation, so the body reads row.source rather than
-- closing over a source the row will outlive
Tooltip.Attach = function(_, row)
	row:SetScript("OnEnter", function(self)
		if self.source then
			Meter.ShowTip(self, function(tooltip)
				Fill(tooltip, self)
			end)
		end
	end)

	row:SetScript("OnLeave", Meter.HideTip)
end
