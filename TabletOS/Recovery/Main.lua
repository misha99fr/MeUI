-- MeUI Recovery
-- Низкоуровневый режим восстановления, не зависит от TabletOSGraphics/doubleBuffering,
-- чтобы работать даже если графическая подсистема или настройки повреждены.

local component = require("component")
local computer = require("computer")
local event = require("event")
local fs = require("filesystem")
local term = require("term")
local keyboard = require("keyboard")
local serial = require("serialization")
local gpu = component.gpu

local crypt
do
	local ok, mod = pcall(require, "crypt")
	if ok then crypt = mod end
end

local core
do
	local ok, mod = pcall(require, "TabletOSCore")
	if ok then core = mod end
end

local w, h = gpu.getResolution()

local colors = {
	background = 0x000000,
	foreground = 0x33CC33,
	highlightBack = 0x33CC33,
	highlightFore = 0x000000,
	title = 0xFFFFFF,
	warning = 0xFF3333,
}

local function clear()
	gpu.setBackground(colors.background)
	gpu.setForeground(colors.foreground)
	gpu.fill(1, 1, w, h, " ")
end

local function centerText(y, text, color)
	gpu.setForeground(color or colors.foreground)
	gpu.setBackground(colors.background)
	local x = math.max(1, math.floor((w - #text) / 2) + 1)
	gpu.set(x, y, text)
end

local function drawHeader(subtitle)
	clear()
	centerText(2, "MeUI Recovery", colors.title)
	centerText(3, "------------------------", colors.foreground)
	if subtitle then
		centerText(4, subtitle, colors.foreground)
	end
end

-- Простое меню с навигацией вверх/вниз и выбором по Enter.
-- items = { {text=..., action=function() ... end}, ... }
local function runMenu(title, items, startY)
	startY = startY or 7
	local selected = 1
	local function draw()
		drawHeader(title)
		for i = 1, #items do
			local y = startY + (i - 1)
			local text = items[i].text
			if i == selected then
				gpu.setBackground(colors.highlightBack)
				gpu.setForeground(colors.highlightFore)
				gpu.fill(3, y, w - 4, 1, " ")
				gpu.set(4, y, "> " .. text)
			else
				gpu.setBackground(colors.background)
				gpu.setForeground(colors.foreground)
				gpu.set(4, y, "  " .. text)
			end
		end
		gpu.setBackground(colors.background)
		gpu.setForeground(colors.foreground)
		centerText(h - 2, "Вверх/Вниз - выбор, Enter - подтвердить", colors.foreground)
	end
	while true do
		draw()
		local sig = {event.pull("key_down")}
		local code = sig[4]
		if code == 200 then -- Up
			selected = selected - 1
			if selected < 1 then selected = #items end
		elseif code == 208 then -- Down
			selected = selected + 1
			if selected > #items then selected = 1 end
		elseif code == 28 then -- Enter
			local result = items[selected].action()
			if result == "exit" then return end
		elseif code == 1 then -- Esc
			return
		end
	end
end

local function waitKey(msg)
	if msg then centerText(h - 4, msg, colors.foreground) end
	event.pull("key_down")
end

-- Текстовый ввод без зависимостей от графической библиотеки ОС.
local function readLine(promptY, mask)
	gpu.setBackground(colors.background)
	gpu.setForeground(colors.foreground)
	gpu.fill(1, promptY, w, 1, " ")
	local text = ""
	while true do
		gpu.fill(1, promptY, w, 1, " ")
		local display = mask and string.rep("*", #text) or text
		gpu.set(2, promptY, "> " .. display .. "_")
		local sig = {event.pull("key_down")}
		local char = sig[3]
		local code = sig[4]
		if code == 28 then -- Enter
			return text
		elseif code == 14 then -- Backspace
			text = text:sub(1, -2)
		elseif code == 1 then -- Esc
			return nil
		elseif char and char ~= 0 and char >= 32 then
			text = text .. string.char(char)
		end
	end
end

local function confirm(question)
	drawHeader()
	centerText(7, question, colors.warning)
	centerText(9, "Введите YES для подтверждения, либо оставьте пусто для отмены:", colors.foreground)
	local answer = readLine(11)
	return answer == "YES"
end

-- Проверка пароля блокировки экрана (если он установлен).
-- Возвращает true, если доступ разрешён.
local function verifyLockPassword()
	if not core then return true end
	if not core.isLockActive or not core.isLockActive() then return true end
	if not crypt then return true end
	drawHeader("Подтверждение личности")
	centerText(7, "Устройство защищено паролем.", colors.warning)
	centerText(8, "Введите пароль для продолжения:", colors.foreground)
	local password = readLine(10, true)
	if not password then return false end
	return crypt.md5(password) == core.settings.lockHash
end

local function rebootSystem()
	drawHeader()
	centerText(7, "Перезагрузка...")
	os.sleep(1)
	computer.shutdown(true)
end

local function shutdownSystem()
	drawHeader()
	centerText(7, "Выключение...")
	os.sleep(1)
	computer.shutdown(false)
end

local function removeRecursively(path)
	if not fs.exists(path) then return end
	if fs.isDirectory(path) then
		for file in fs.list(path) do
			removeRecursively(fs.concat(path, file))
		end
	end
	fs.remove(path)
end

local function wipeCache()
	drawHeader()
	centerText(7, "Очистка кэша...")
	removeRecursively("/TabletOS/UpdateCache")
	removeRecursively("/TabletOS/logs.log")
	os.sleep(1)
	drawHeader()
	centerText(7, "Кэш очищен.", colors.foreground)
	waitKey("Нажмите любую клавишу...")
end

local function wipeData()
	if not verifyLockPassword() then
		drawHeader()
		centerText(7, "Доступ запрещён. Неверный пароль.", colors.warning)
		waitKey("Нажмите любую клавишу...")
		return
	end
	if not confirm("ВНИМАНИЕ: будут удалены ВСЕ данные и настройки!") then
		return
	end
	drawHeader()
	centerText(7, "Сброс к заводским настройкам...")
	removeRecursively("/TabletOS/db")
	removeRecursively("/TabletOS/settings.bin")
	removeRecursively("/TabletOS/Desktop")
	removeRecursively("/TabletOS/logs.log")
	removeRecursively("/TabletOS/UpdateCache")
	fs.makeDirectory("/TabletOS/Desktop")
	os.sleep(1)
	drawHeader()
	centerText(7, "Готово. Устройство будет перезагружено.", colors.foreground)
	os.sleep(2)
	computer.shutdown(true)
end

local function applyUpdate()
	drawHeader()
	local updaterBin = "/TabletOS/UpdateCache/updater-binary"
	if not fs.exists(updaterBin) then
		centerText(7, "Обновление не найдено в /TabletOS/UpdateCache", colors.warning)
		waitKey("Нажмите любую клавишу...")
		return
	end
	if not confirm("Установить найденное обновление сейчас?") then
		return
	end
	drawHeader()
	centerText(7, "Установка обновления...")
	local success, reason = pcall(dofile, updaterBin)
	if success then
		centerText(9, "Обновление установлено. Перезагрузка...", colors.foreground)
		os.sleep(2)
		computer.shutdown(true)
	else
		centerText(9, "Ошибка: " .. tostring(reason), colors.warning)
		waitKey("Нажмите любую клавишу...")
	end
end

local function disableLock()
	if not core then return end
	if not verifyLockPassword() then
		drawHeader()
		centerText(7, "Доступ запрещён. Неверный пароль.", colors.warning)
		waitKey("Нажмите любую клавишу...")
		return
	end
	core.settings.lockType = nil
	core.settings.lockHash = nil
	drawHeader()
	centerText(7, "Блокировка экрана снята.", colors.foreground)
	waitKey("Нажмите любую клавишу...")
end

local function showInfo()
	drawHeader("Информация об устройстве")
	local y = 7
	local lines = {}
	if core then
		table.insert(lines, "Имя: " .. tostring(core.settings.deviceName or "не задано"))
		table.insert(lines, "Модель: " .. tostring(core.settings.deviceModel or "неизвестно"))
		table.insert(lines, "Блокировка экрана: " .. ((core.isLockActive and core.isLockActive()) and "включена" or "выключена"))
		table.insert(lines, "Загрузчик: " .. (core.settings.bootloaderUnlocked and "разблокирован" or "заблокирован"))
	else
		table.insert(lines, "TabletOSCore недоступен (повреждены настройки?)")
	end
	table.insert(lines, "Свободно памяти: " .. tostring(computer.freeMemory()) .. " байт")
	for i, line in ipairs(lines) do
		centerText(y + i - 1, line)
	end
	waitKey("Нажмите любую клавишу для возврата...")
end

local function advancedMenu()
	runMenu("Дополнительно", {
		{text = "Информация об устройстве", action = function() showInfo() end},
		{text = "Снять блокировку экрана (требует пароль)", action = function() disableLock() end},
		{text = "Назад", action = function() return "exit" end},
	})
end

local function mainMenu()
	runMenu(nil, {
		{text = "Reboot system now", action = function() rebootSystem() end},
		{text = "Apply update from UpdateCache", action = function() applyUpdate() end},
		{text = "Wipe cache", action = function() wipeCache() end},
		{text = "Wipe data / Factory reset", action = function() wipeData() end},
		{text = "Advanced", action = function() advancedMenu() end},
		{text = "Power off", action = function() shutdownSystem() end},
	})
end

mainMenu()
-- Если пользователь вышел из меню (Esc) - просто перезагружаемся в обычную ОС.
rebootSystem()
