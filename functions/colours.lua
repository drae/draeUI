--[[

--]]
local DraeUI = select(2, ...)
local oUF = DraeUI.oUF or oUF

--[[

--]]

oUF.colors.power["ENERGY"]      = oUF:CreateColor(255, 249, 105)
oUF.colors.power["FOCUS"]       = oUF:CreateColor(255, 128, 64)
oUF.colors.power["FURY"]        = oUF:CreateColor(201, 66, 252) --, atlas = '_DemonHunter-DemonicFuryBar)
oUF.colors.power["INSANITY"]    = oUF:CreateColor(102, 0, 204)  --, atlas = '_Priest-InsanityBar)
oUF.colors.power["LUNAR_POWER"] = oUF:CreateColor(77, 133, 230) --, atlas = '_Druid-LunarBar)
oUF.colors.power["MAELSTROM"]   = oUF:CreateColor(0, 128, 255)  --, atlas = '_Shaman-MaelstromBar)
oUF.colors.power["MANA"]        = oUF:CreateColor(46, 158, 255)
oUF.colors.power["PAIN"]        = oUF:CreateColor(255, 156, 0)  --, atlas = '_DemonHunter-DemonicPainBar)
oUF.colors.power["RAGE"]        = oUF:CreateColor(199, 64, 64)
oUF.colors.power["RUNIC_POWER"] = oUF:CreateColor(0, 204, 255)
oUF.colors.power["ALT_POWER"]   = oUF:CreateColor(51, 102, 204)

oUF.colors.reaction[2]          = oUF:CreateColor(255, 0, 0)
oUF.colors.reaction[4]          = oUF:CreateColor(255, 255, 0)
oUF.colors.reaction[5]          = oUF:CreateColor(0, 255, 0)

oUF.colors.charmed              = oUF:CreateColor(255, 0, 102)
oUF.colors.disconnected         = oUF:CreateColor(230, 230, 230)
oUF.colors.tapped               = oUF:CreateColor(153, 153, 153)

oUF.colors.debuffTypes          = {
	["Magic"] = oUF:CreateColor(51, 153, 255),
	["Curse"] = oUF:CreateColor(153, 0.0, 255),
	["Disease"] = oUF:CreateColor(153, 102, 0.0),
	["Poison"] = oUF:CreateColor(0.0, 153, 0.0)
}
