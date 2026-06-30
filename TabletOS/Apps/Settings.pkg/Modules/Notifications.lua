local core = require("TabletOSCore")
local graphics = require("TabletOSGraphics")
local computer = require("computer")

local function enabled()
    return core.notificationsEnabled()
end

local mainScreen = {
    name = function() return "Уведомления" end,
    {type="Label", name=function()
        return "Уведомления: " .. (enabled() and "включены" or "отключены")
    end},
    {type="Separator"},
    {type="Button",
        name=function()
            local prefix = enabled() and "● " or "○ "
            return prefix .. "Включить уведомления"
        end,
        onClick=function(event)
            if event.action ~= "UP" then return end
            core.settings.notificationsEnabled = true
            graphics.drawInfo("Уведомления", {"Уведомления включены."})
            computer.pushSignal("REDRAW_ALL")
        end,
    },
    {type="Button",
        name=function()
            local prefix = (not enabled()) and "● " or "○ "
            return prefix .. "Отключить уведомления"
        end,
        onClick=function(event)
            if event.action ~= "UP" then return end
            core.settings.notificationsEnabled = false
            graphics.drawInfo("Уведомления", {"Уведомления отключены.", "Системные приложения и игры", "больше не будут показывать", "всплывающие уведомления."})
            computer.pushSignal("REDRAW_ALL")
        end,
    },
    {type="Separator"},
    {type="Label", name=function()
        return "Важные предупреждения (например, низкий"
    end},
    {type="Label+", name=function()
        return "заряд) всё равно показываются поверх"
    end},
    {type="Label+", name=function()
        return "интерфейса, даже при отключённых уведомлениях."
    end},
}

return {
    name = function() return "Уведомления" end,
    onClick = function()
        setContentView(mainScreen)
    end,
    section = function() return "4" end,
}
