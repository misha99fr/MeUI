local core = require("TabletOSCore")
local graphics = require("TabletOSGraphics")
local computer = require("computer")

local function devMode()
    return core.settings.developerMode == true
end

local function perfModeOn()
    return core.settings.superPerformanceMode == true
end

local function disablePerfMode(silent)
    core.settings.superPerformanceMode = false
    if not silent then
        graphics.drawInfo("Super Performance Mode", {"Режим выключен.", "Энергосбережение и анимации", "работают в обычном режиме."})
    end
end

local function enablePerfMode()
    -- Предупреждение перед включением - режим заметно увеличивает
    -- энергопотребление и нагрузку на процессор, отключает все
    -- ограничения энергосбережения и держит интерфейс на максимальной
    -- частоте обновления вне зависимости от уровня заряда или нагрева.
    graphics.drawWarning("Super Performance Mode", {
        "Этот режим разгоняет интерфейс до",
        "максимума, отключая энергосбережение.",
        "Энергопотребление и нагрузка на",
        "процессор значительно вырастут,",
        "заряд будет расходоваться быстрее,",
        "устройство может сильнее нагреваться.",
    })
    local confirmScreen = {
        name = function() return "Super Performance Mode" end,
        {type="Label", name=function() return "Включить, понимая риски?" end},
        {type="Separator"},
        {type="Button", name=function() return "Включить" end, onClick=function(event)
            if event.action ~= "UP" then return end
            core.settings.superPerformanceMode = true
            graphics.drawInfo("Super Performance Mode", {"Режим включён.", "Анимации форсированы, энергосбережение", "отключено до тех пор, пока вы не", "выключите режим вручную."})
            computer.pushSignal("ESS")
        end},
        {type="Button", name=function() return "Отмена" end, onClick=function(event)
            if event.action ~= "UP" then return end
            computer.pushSignal("ESS")
        end},
    }
    setContentView(confirmScreen)
end

local mainScreen = {
    name = function() return "Для разработчиков" end,
    {type="Label", name=function() return "Настройки для разработчиков" end},
    {type="Separator"},
    {type="Label", name=function()
        return "Super Performance Mode: " .. (perfModeOn() and "ВКЛЮЧЕН" or "выключен")
    end},
    {type="Button",
        name=function()
            return perfModeOn() and "Выключить Super Performance Mode" or "Включить Super Performance Mode"
        end,
        onClick=function(event)
            if event.action ~= "UP" then return end
            if perfModeOn() then
                disablePerfMode()
                computer.pushSignal("REDRAW_ALL")
            else
                enablePerfMode()
            end
        end,
    },
    {type="Label+", name=function()
        return "Максимальная производительность интерфейса"
    end},
    {type="Label+", name=function()
        return "ценой энергопотребления и нагрузки на ЦП."
    end},
    {type="Separator"},
    {type="Button", name=function() return "Тестовое предупреждение (10% заряда)" end,
        onClick=function(event)
            if event.action ~= "UP" then return end
            -- Демонстрация API предупреждений (core.newWarning / graphics.drawWarning):
            -- модальное окно с "!" поверх интерфейса, показывается всегда,
            -- даже если обычные уведомления отключены в Настройках.
            graphics.drawWarning("Низкий заряд", {"У вас осталось 10% заряда."})
            computer.pushSignal("REDRAW_ALL")
        end,
    },
    {type="Separator"},
    {type="Button", name=function() return "Выключить режим разработчика" end, onClick=function(event)
        if event.action ~= "UP" then return end
        -- При выходе из режима разработчика принудительно отключаем
        -- Super Performance Mode, чтобы не оставить устройство в
        -- энергозатратном режиме без доступа к переключателю.
        if perfModeOn() then disablePerfMode(true) end
        core.settings.developerMode = false
        if _G.refreshMainScreen then _G.refreshMainScreen() end
        graphics.drawInfo("Для разработчиков", {"Режим разработчика выключен."})
        computer.pushSignal("ESS")
    end},
}

return {
    name = function() return "Для разработчиков" end,
    hidden = function() return not devMode() end,
    onClick = function()
        setContentView(mainScreen)
    end,
    section = function() return "9" end,
}
