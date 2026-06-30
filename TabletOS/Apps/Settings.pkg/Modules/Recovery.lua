local core = require("TabletOSCore")
local graphics = require("TabletOSGraphics")
local computer = require("computer")
local fs = require("filesystem")
local buffer = require("doubleBuffering")

local RECOVERY_PATH = "/TabletOS/Recovery/Main.lua"
local FLAG_PATH = "/TabletOS/recovery.flag"

local function enterNow()
  -- Открыть recovery прямо сейчас, без перезагрузки (удобно для проверки).
  local success, reason = core.pcall(dofile, RECOVERY_PATH)
  buffer.drawChanges(true)
  if not success then
    graphics.drawInfo("MeUI Recovery", {"Не удалось запустить Recovery.", tostring(reason)})
  end
  computer.pushSignal("REDRAW_ALL")
end

local function rebootToRecovery()
  local f = io.open(FLAG_PATH, "w")
  if f then
    f:write("1")
    f:close()
  end
  graphics.drawInfo("MeUI Recovery", {"Устройство перезагрузится в Recovery..."})
  computer.shutdown(true)
end

local mainScreen = {
  name = function() return "MeUI Recovery" end,
  {type="Label", name=function() return "Режим восстановления" end},
  {type="Separator"},
  {type="Label", name=function() return "Recovery позволяет сбросить настройки," end},
  {type="Label", name=function() return "очистить кэш или установить обновление," end},
  {type="Label", name=function() return "даже если система не загружается." end},
  {type="Separator"},
  {type="Button", name=function() return "Перезагрузить в MeUI Recovery" end,
  onClick=function(event)
    if event.action ~= "UP" then return end
    rebootToRecovery()
  end},
  {type="Button", name=function() return "Открыть Recovery сейчас (тест)" end,
  onClick=function(event)
    if event.action ~= "UP" then return end
    enterNow()
  end},
}

return {
  name = function() return "MeUI Recovery" end,
  onClick = function()
    setContentView(mainScreen)
  end,
  section = function() return "3" end,
}
