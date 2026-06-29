local core = require("TabletOSCore")
local graphics = require("TabletOSGraphics")
local computer = require("computer")

-- Версия MeUI
local MEUI_VERSION = "MeUI Stable 1.0"

local mainScreen = {
    name = function() return "О системе" end,
    {type="Label", name=function() return "MeUI" end},
    {type="Separator"},
    {type="Label+", name=function() return MEUI_VERSION end},
    {type="Label", name=function() return "OpenComputers TabletOS" end},
    {type="Separator"},
    {type="Label", name=function() return "Сборка: Stable" end},
    {type="Label", name=function() return "Ядро: TabletOSCore" end},
    {type="Separator"},
    {type="Label", name=function()
        if core.settings.bootloaderUnlocked then
            return "Загрузчик: РАЗБЛОКИРОВАН"
        else
            return "Загрузчик: ЗАБЛОКИРОВАН"
        end
    end},
}

return {
    name = function() return "О системе" end,
    onClick = function()
        setContentView(mainScreen)
    end,
    section = function() return "9" end,
}
