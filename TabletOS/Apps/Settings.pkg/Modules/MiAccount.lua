local core = require("TabletOSCore")
local graphics = require("TabletOSGraphics")
local computer = require("computer")
local crypt = require("crypt")

local mainScreen = {
    name = function() return "IM Аккаунт" end,
    {type="Label", name=function()
        local id = core.settings.imDeviceId
        if id and id ~= "" then
            return "Device ID: " .. tostring(id)
        else
            return "Устройство не привязано"
        end
    end},
    {type="Separator"},
    -- Кнопка привязки/отвязки
    {type="Button", name=function()
        local id = core.settings.imDeviceId
        if id and id ~= "" then
            return "Отвязать устройство"
        else
            return "Привязать устройство"
        end
    end,
    onClick=function(event)
        if event.action ~= "UP" then return end
        local id = core.settings.imDeviceId
        if id and id ~= "" then
            -- Отвязка: требуем пароль
            if core.settings.lockType == "password" and core.settings.lockHash then
                local pw = graphics.drawEdit("Подтверждение личности", {"Введите пароль"})
                if crypt.md5(pw) ~= core.settings.lockHash then
                    graphics.drawInfo("IM Аккаунт", {"Доступ запрещён."})
                    computer.pushSignal("REDRAW_ALL")
                    return
                end
            end
            core.settings.imDeviceId = ""
            graphics.drawInfo("IM Аккаунт", {"Устройство успешно отвязано."})
        else
            -- Привязка: вводим Device ID
            local newId = graphics.drawEdit("IM Аккаунт", {"Введите Device ID устройства"})
            if newId and newId ~= "" then
                core.settings.imDeviceId = newId
                graphics.drawInfo("IM Аккаунт", {"Устройство привязано.", "Device ID: " .. newId})
            else
                graphics.drawInfo("IM Аккаунт", {"Отменено. Device ID не задан."})
            end
        end
        computer.pushSignal("REDRAW_ALL")
    end},
    {type="Separator"},
    -- Кнопка изменить Device ID вручную
    {type="Button", name=function() return "Изменить Device ID" end,
    onClick=function(event)
        if event.action ~= "UP" then return end
        local cur = core.settings.imDeviceId or ""
        local newId = graphics.drawEdit("IM Аккаунт", {"Текущий: " .. (cur ~= "" and cur or "не задан"), "Новый Device ID:"})
        if newId and newId ~= "" then
            core.settings.imDeviceId = newId
            graphics.drawInfo("IM Аккаунт", {"Device ID обновлён.", newId})
        end
        computer.pushSignal("REDRAW_ALL")
    end},
}

return {
    name = function() return "IM Аккаунт" end,
    onClick = function()
        setContentView(mainScreen)
    end,
    section = function() return "2" end,
}
