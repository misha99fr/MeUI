local core = require("TabletOSCore")
local graphics = require("TabletOSGraphics")
local computer = require("computer")

-- Версия MeUI
local MEUI_VERSION = "MeUI Stable 1.0"

local tapCount = 0
local function onBuildTap(event)
    if event.action ~= "UP" then return end
    if core.settings.developerMode then return end
    tapCount = tapCount + 1
    if tapCount >= 7 then
        core.settings.developerMode = true
        tapCount = 0
        if _G.refreshMainScreen then _G.refreshMainScreen() end
        graphics.drawInfo("Режим разработчика", {"Теперь вы разработчик!", "Настройки → Для разработчиков."})
    elseif tapCount >= 4 then
        graphics.drawInfo("Сборка", {"Осталось нажатий: " .. tostring(7 - tapCount)})
    end
end

local mainScreen = {
    name = function() return "О системе" end,
    {type="Label", name=function() return "MeUI" end},
    {type="Separator"},
    {type="Label+", name=function() return MEUI_VERSION end},
    {type="Label", name=function() return "OpenComputers TabletOS" end},
    {type="Separator"},
    {type="Label", name=function()
        local name = core.settings.deviceName
        return "Устройство: " .. ((name and name ~= "") and name or "Не задано")
    end},
    {type="Label", name=function()
        local model = core.settings.deviceModel
        return "Модель: " .. ((model and model ~= "") and model or "Неизвестно")
    end},
    {type="Separator"},
    {type="Button", name=function() return "Сборка: Stable" end, onClick=onBuildTap},
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
