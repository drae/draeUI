--[[


--]]
local DraeUI = select(2, ...)

local IB = DraeUI:GetModule("Infobar")
local COIN = IB:NewModule("Coin", "AceEvent-3.0")

local plugin = IB:Register("Coin", { order = 40 })

--
local mfloor, format, pairs, mabs = math.floor, string.format, pairs, math.abs
local GetMoney, IsShiftKeyDown, ToggleAllBags, C_CurrencyInfo = GetMoney, IsShiftKeyDown, ToggleAllBags, C_CurrencyInfo
local COPPER_PER_SILVER, SILVER_PER_GOLD = COPPER_PER_SILVER, SILVER_PER_GOLD
local CURRENCY = CURRENCY
local L = DraeUI.L

--
local profit, loss = 0, 0

--[[

]]
local IntToGold = function(coins, showIcons)
	local g = mfloor(coins / (COPPER_PER_SILVER * SILVER_PER_GOLD))
	local s = mfloor((coins - (g * COPPER_PER_SILVER * SILVER_PER_GOLD)) / COPPER_PER_SILVER)
	local c = coins % COPPER_PER_SILVER

	local gText = showIcons and format("\124TInterface\\MoneyFrame\\UI-GoldIcon:%d:%d:1:0\124t", 12, 12)
		or "|cffffd700g|r"
	local sText = showIcons and format("\124TInterface\\MoneyFrame\\UI-SilverIcon:%d:%d:1:0\124t", 12, 12)
		or "|cffc7c7cfs|r"
	local cText = showIcons and format("\124TInterface\\MoneyFrame\\UI-CopperIcon:%d:%d:1:0\124t", 12, 12)
		or "|cffeda55fc|r"

	if g then
		return ("%d%s %d%s %d%s"):format(g or 0, gText, s or 0, sText, c or 0, cText)
	elseif s then
		return ("%d%s %d%s"):format(s or 0, sText, c or 0, cText)
	else
		return ("%d%s"):format(c or 0, cText)
	end
end

COIN.UpdateCoin = function()
	DraeUI.dbGlobal.gold = DraeUI.dbGlobal.gold or {}
	DraeUI.dbGlobal.gold[DraeUI.playerRealm] = DraeUI.dbGlobal.gold[DraeUI.playerRealm] or {}
	local db = DraeUI.dbGlobal.gold

	local curMoney = GetMoney()
	local oldMoney = db[DraeUI.playerRealm][DraeUI.playerName] or curMoney
	local diffMoney = curMoney - oldMoney

	if oldMoney > curMoney then -- Lost Money
		loss = loss - diffMoney
	else -- Gained Moeny
		profit = profit + diffMoney
	end

	db[DraeUI.playerRealm][DraeUI.playerName] = curMoney

	plugin:SetText(IntToGold(curMoney, false))

	plugin:RefreshTooltip()
end

plugin.OnTooltip = function(tooltip)
	DraeUI.dbGlobal.gold = DraeUI.dbGlobal.gold or {}
	DraeUI.dbGlobal.gold[DraeUI.playerRealm] = DraeUI.dbGlobal.gold[DraeUI.playerRealm] or {}
	local db = DraeUI.dbGlobal.gold

	tooltip:AddLine(L["INFOBAR_THIS_SESSION"])

	tooltip:AddDoubleLine(L["INFOBAR_EARNED"], IntToGold(profit, true), 1, 1, 1, 1, 1, 1)
	tooltip:AddDoubleLine(L["INFOBAR_SPENT"], IntToGold(loss, true), 1, 1, 1, 1, 1, 1)

	if profit < loss then
		tooltip:AddDoubleLine(L["INFOBAR_LOSS"], IntToGold(mabs(profit - loss), true), 1, 0, 0, 1, 1, 1)
	elseif (profit - loss) > 0 then
		tooltip:AddDoubleLine(L["INFOBAR_PROFIT"], IntToGold(profit - loss, true), 0, 1, 0, 1, 1, 1)
	end

	tooltip:AddLine(" ")

	local totalGold = 0
	tooltip:AddLine(L["INFOBAR_THIS_REALM"])

	for k, _ in pairs(db[DraeUI.playerRealm]) do
		if db[DraeUI.playerRealm][k] then
			tooltip:AddDoubleLine(k, IntToGold(db[DraeUI.playerRealm][k], true), 1, 1, 1, 1, 1, 1)

			totalGold = totalGold + db[DraeUI.playerRealm][k]
		end
	end

	tooltip:AddLine(" ")
	tooltip:AddDoubleLine(L["INFOBAR_TOTAL"], IntToGold(totalGold, true), 1, 1, 1, 1, 1, 1)

	local info
	for i = 1, 6 do
		info = C_CurrencyInfo.GetBackpackCurrencyInfo(i)
		if info ~= nil and info.name then
			if i == 1 then
				tooltip:AddLine(" ")
				tooltip:AddLine(CURRENCY)
			end

			if info.quantity then
				tooltip:AddDoubleLine(info.name, info.quantity, 1, 1, 1)
			end
		end
	end

	tooltip:AddLine(" ")
	tooltip:AddLine(L["INFOBAR_RESET_SESSION"])
	tooltip:AddLine(L["INFOBAR_RESET_REALM"])
end

plugin.OnClick = function(_, btn)
	if IsShiftKeyDown() then
		if btn == "LeftButton" then
			profit, loss = 0, 0
		else
			DraeUI.dbGlobal.gold = {}
		end

		--[[
			Redraw rather than hide. The cursor is still on the plugin, so the
			old GameTooltip:Hide() left the framework thinking this plugin owned
			a tooltip that wasn't on screen - and you couldn't see that the
			reset had taken until you moved away and came back.
		--]]
		plugin:RefreshTooltip()
	else
		ToggleAllBags()
	end
end

COIN.PlayerEnteringWorld = function(self)
	self:UnregisterEvent("PLAYER_ENTERING_WORLD", "PlayerEnteringWorld")

	self:UpdateCoin()
end

COIN.OnInitialize = function(self)
	self:RegisterEvent("PLAYER_MONEY", "UpdateCoin")
	self:RegisterEvent("SEND_MAIL_MONEY_CHANGED", "UpdateCoin")
	self:RegisterEvent("SEND_MAIL_COD_CHANGED", "UpdateCoin")
	self:RegisterEvent("PLAYER_TRADE_MONEY", "UpdateCoin")
	self:RegisterEvent("TRADE_MONEY_CHANGED", "UpdateCoin")
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "PlayerEnteringWorld")
end
