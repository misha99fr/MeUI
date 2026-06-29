local core = require("TabletOSCore")
local graphics = require("TabletOSGraphics")
local computer = require("computer")
local component = require("component")
local crypt = require("crypt")

-- Выполнить HTTP-запрос
local function request(url)
  local success, response = pcall(component.internet.request, url)
  if not success or not response then return nil end
  local code
  while not code do code = select(1, response.response()) end
  if code ~= 200 then response.close(); return nil end
  local buf = ""
  repeat
    local data = response.read()
    if data then buf = buf .. data end
  until not data
  response.close()
  return buf
end

-- Проверить IM Account Lock через сервер Ovkisser
local function checkMiLock()
  local deviceId = core.settings.imDeviceId
  if not deviceId or deviceId == "" then return false end
  local url = "https://cackemc10.w10.site/cgi-bin/cms/msdos"
  local raw = request(url)
  if not raw then return false end
  local devLock = raw:match("deviceid%s*=%s*" .. tostring(deviceId) .. "%s+milock%s*=%s*(%a+)")
  return devLock == "on"
end

-- Экран разблокировки загрузчика
local function doUnlock()
  graphics.drawInfo(
    "Загрузчик",
    {"ВНИМАНИЕ: Разблокировка СОТРЁТ все данные!", "Это действие необратимо.", "Подтвердите паролем для продолжения."}
  )
  if core.settings.lockType == "password" and core.settings.lockHash then
    local pw = graphics.drawEdit("Подтверждение личности", {"Введите пароль"})
    if crypt.md5(pw) ~= core.settings.lockHash then
      graphics.drawInfo("Подтверждение личности", {"Доступ запрещен"})
      computer.pushSignal("REDRAW_ALL")
      return
    end
  end
  core.settings.bootloaderUnlocked = true
  -- НЕ делаем resetSettings(false) — он стирает все настройки включая bootloaderUnlocked!
  -- Просто сохраняем настройки с уже установленным флагом
  core.saveSettings()
  graphics.drawInfo("Загрузчик", {"Загрузчик разблокирован. Перезагрузка..."})
  computer.shutdown(true)
end

local function doLock()
  core.settings.bootloaderUnlocked = false
  graphics.drawInfo("Загрузчик", {"Загрузчик успешно заблокирован."})
  computer.pushSignal("REDRAW_ALL")
end

-- Главный экран модуля
local mainScreen = {
  {type="Label", name=function()
    if core.settings.bootloaderUnlocked then
      return "Статус: РАЗБЛОКИРОВАН"
    else
      return "Статус: ЗАБЛОКИРОВАН"
    end
  end},
  {type="Separator"},
  {type="Button",
    name=function()
      if core.settings.bootloaderUnlocked then
        return "Заблокировать загрузчик"
      else
        return "Разблокировать загрузчик"
      end
    end,
    onClick=function(event)
      if event.action ~= "UP" then return end
      if core.settings.bootloaderUnlocked then
        doLock()
      else
        doUnlock()
      end
    end
  },
}

return {
  name = function() return "Загрузчик" end,
  onClick = function()
    if checkMiLock() then
      graphics.drawInfo("Блокировка IM Аккаунта", {"Устройство привязано к IM Аккаунту.", "Снимите блокировку на xiaoim.com."})
      computer.pushSignal("REDRAW_ALL")
      return
    end
    setContentView(mainScreen)
  end,
  section = function() return "3" end,
}
