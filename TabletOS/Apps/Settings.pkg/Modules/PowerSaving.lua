local core = require("TabletOSCore")
local graphics = require("TabletOSGraphics")
local computer = require("computer")

local modes = {
    {id = "off", name = "Выключено"},
    {id = "medium", name = "Средняя экономия"},
    {id = "max", name = "Максимальная экономия"},
}

local function descriptionFor(id)
    if id == "max" then
        return "Отключены анимации и эффекты интерфейса.", "Максимальная экономия заряда устройства."
    elseif id == "medium" then
        return "Снижена частота фоновых проверок.", "Баланс между экономией и плавностью интерфейса."
    else
        return "Энергосбережение отключено.", "Интерфейс работает в обычном режиме."
    end
end

local function currentMode()
    return core.settings.powerSaveMode or "off"
end

local function currentModeName()
    for _, mode in pairs(modes) do
        if mode.id == currentMode() then return mode.name end
    end
    return "Выключено"
end

local mainScreen = {
    name = function() return "Энергосбережение" end,
    {type="Label", name=function() return "Текущий режим: " .. currentModeName() end},
    {type="Separator"},
}

for _, mode in pairs(modes) do
    table.insert(mainScreen, {
        type = "Button",
        name = function()
            local prefix = (currentMode() == mode.id) and "● " or "○ "
            return prefix .. mode.name
        end,
        onClick = function(event)
            if event.action ~= "UP" then return end
            core.settings.powerSaveMode = mode.id
            local line1, line2 = descriptionFor(mode.id)
            graphics.drawInfo("Энергосбережение", {mode.name .. " включено.", line1, line2})
            computer.pushSignal("REDRAW_ALL")
        end,
    })
end

table.insert(mainScreen, {type="Separator"})
table.insert(mainScreen, {type="Label", name=function()
    local _, line2 = descriptionFor(currentMode())
    return line2
end})

return {
    name = function() return "Энергосбережение" end,
    onClick = function()
        setContentView(mainScreen)
    end,
    section = function() return "4" end,
}
