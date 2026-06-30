local core = require("TabletOSCore")
local graphics = require("TabletOSGraphics")
local computer = require("computer")

local deviceModels = {
    "XiaoIM Pad 4",
    "XiaoIM Pad 4 Pro",
    "RedIM Pad 1 Lite",
}

local function currentName()
    local name = core.settings.deviceName
    if name and name ~= "" then return name end
    return "MeUI Device"
end

local function currentModel()
    local model = core.settings.deviceModel
    if model and model ~= "" then return model end
    return "Неизвестно"
end

local modelSelect = {
    name = function() return "Выберите модель" end,
    {type="Label", name=function() return "Модель устройства" end},
    {type="Separator"},
}
for _, model in pairs(deviceModels) do
    table.insert(modelSelect, {
        type = "Button",
        name = function() return model end,
        onClick = function(event)
            if event.action ~= "UP" then return end
            core.settings.deviceModel = model
            computer.pushSignal("ESS")
        end,
    })
end

local mainScreen = {
    name = function() return "Об устройстве" end,
    {type="Label", name=function() return "Имя: " .. currentName() end},
    {type="Label", name=function() return "Модель: " .. currentModel() end},
    {type="Separator"},
    {type="Button", name=function() return "Изменить имя устройства" end,
    onClick=function(event)
        if event.action ~= "UP" then return end
        local newName = graphics.drawEdit("Имя устройства", {"Текущее: " .. currentName(), "Новое имя устройства:"}, currentName())
        if newName and newName ~= "" then
            core.settings.deviceName = newName
            graphics.drawInfo("Имя устройства", {"Имя устройства изменено.", newName})
        end
        computer.pushSignal("REDRAW_ALL")
    end},
    {type="Button", name=function() return "Изменить модель устройства" end,
    onClick=function(event)
        if event.action ~= "UP" then return end
        setContentView(modelSelect)
    end},
}

return {
    name = function() return "Об устройстве" end,
    onClick = function()
        setContentView(mainScreen)
    end,
    section = function() return "1" end,
}
