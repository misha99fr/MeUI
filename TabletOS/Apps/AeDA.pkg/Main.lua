os.sleep(0.1) --от двойного клика
local core = require("TabletOSCore")
local computer = require("computer")
local component = require("component")
local event = require("event")
local unicode = require("unicode")
local graphics = require("TabletOSGraphics")
local buffer = require("doubleBuffering")
local w,h = buffer.getResolution()
local program = {theme={0xCCCCCC,0xFFFFFF-0xCCCCCC},actionBar={background=0xFFFFFF,foreground=0x000000,statusBarFore=0x000000}}

-- ===== Профили чипсетов по модели устройства =====
-- Какой "процессор" показывать, зависит от модели, выбранной в Setup
-- Wizard / Настройки → Об устройстве. Старшие модели линейки XiaoIM
-- идут на более производительном чипе, бюджетная RedIM Lite - на
-- более простом и энергоэффективном.
local chipsetProfiles = {
	["XiaoIM Pad 4"] = {
		name = "QualJocx Snapagon G4 UX",
		vendor = "QualJocx Technologies",
		process = "4 нм",
		cores = "8 (1x2.8 + 3x2.5 + 4x1.8 ГГц)",
		gpu = "Adreno-class GPU 730UX",
		class = "Флагманский",
	},
	["XiaoIM Pad 4 Pro"] = {
		name = "QualJocx Snapagon G4 UX",
		vendor = "QualJocx Technologies",
		process = "4 нм",
		cores = "8 (1x3.0 + 3x2.6 + 4x1.9 ГГц)",
		gpu = "Adreno-class GPU 740UX",
		class = "Флагманский (Pro-бин)",
	},
	["RedIM Pad 1 Lite"] = {
		name = "MediaKek MT6401",
		vendor = "MediaKek Inc.",
		process = "6 нм",
		cores = "8 (2x2.2 + 6x2.0 ГГц)",
		gpu = "Mali-class GPU G57 MC2",
		class = "Бюджетный",
	},
}
local defaultChipset = chipsetProfiles["RedIM Pad 1 Lite"]

local function currentChipset()
	local model = core.settings.deviceModel
	return (model and chipsetProfiles[model]) or defaultChipset
end

-- ===== Вспомогательные функции для живых данных устройства =====
local function fmtBytes(bytes)
	if not bytes then return "н/д" end
	if bytes >= 1024*1024 then
		return string.format("%.1f МБ", bytes/1024/1024)
	elseif bytes >= 1024 then
		return string.format("%.1f КБ", bytes/1024)
	else
		return tostring(bytes) .. " Б"
	end
end

local function fmtUptime(seconds)
	seconds = math.floor(seconds or 0)
	local hrs = math.floor(seconds/3600)
	local mins = math.floor((seconds%3600)/60)
	local secs = seconds%60
	return string.format("%02d:%02d:%02d", hrs, mins, secs)
end

local function memoryLoadPercent()
	local total = computer.totalMemory()
	local free = computer.freeMemory()
	if not total or total == 0 then return 0 end
	return math.floor((1 - free/total) * 100 + 0.5)
end

local function listComponents()
	local list = {}
	for address, ctype in component.list() do
		table.insert(list, ctype)
	end
	table.sort(list)
	-- свернуть дубликаты с подсчётом
	local counts = {}
	local order = {}
	for _, ctype in ipairs(list) do
		if not counts[ctype] then table.insert(order, ctype) end
		counts[ctype] = (counts[ctype] or 0) + 1
	end
	local result = {}
	for _, ctype in ipairs(order) do
		local n = counts[ctype]
		table.insert(result, ctype .. (n > 1 and (" x" .. n) or ""))
	end
	return result
end

-- ===== Простой постраничный экран "лист параметров" =====
-- rows = { {label, value}, ... } либо {type="header", text=...}
local function drawInfoScreen(title, rows, onBack)
	buffer.drawRectangle(1,2,w,h-2,program.theme[1],program.theme[2]," ")
	local backW = 9
	local backCheck = graphics.drawButton(1,4,backW,1,"< Назад",0x999999,0xFFFFFF)
	local refreshCheck = graphics.drawButton(w-10,4,11,1,"Обновить",0x555555,0xFFFFFF)
	local y = 6
	for i = 1, #rows do
		if y > h-1 then break end
		local row = rows[i]
		if row.type == "header" then
			buffer.drawRectangle(1,y,w,1,0x444444,0xFFFFFF," ")
			graphics.centerText(w/2,y,0xFFFFFF,row.text)
		else
			local label = row[1]
			local value = row[2]
			local line = label .. ": " .. tostring(value)
			if unicode.len(line) > w-2 then
				line = unicode.sub(line,1,w-3) .. "…"
			end
			buffer.drawRectangle(1,y,w,1,0xFFFFFF,0x000000," ")
			buffer.drawText(2,y,0x000000,line)
		end
		y = y + 1
	end
	graphics.drawActionBar({
		color=program.actionBar.background,
		text=title,
		textColor=program.actionBar.foreground,
		statusBarFore=program.actionBar.statusBarFore,
	})
	buffer.drawChanges()
	return backCheck, refreshCheck
end

local function runInfoScreen(title, buildRows, onBack)
	local backCheck, refreshCheck = drawInfoScreen(title, buildRows())
	while true do
		local sig = {event.pull(1)}
		if not sig[1] then
			backCheck, refreshCheck = drawInfoScreen(title, buildRows())
		elseif sig[1] == "REDRAW_ALL" then
			backCheck, refreshCheck = drawInfoScreen(title, buildRows())
		elseif sig[1] == "touch" then
			if graphics.clickedToBarButton(sig[3],sig[4]) == "HOME" then
				os.exit()
			elseif graphics.clickedToBarButton(sig[3],sig[4]) == "BACK" then
				return
			elseif sig[4] == 1 then
				graphics.processStatusBar(sig[3],sig[4])
			end
		elseif sig[1] == "drop" then
			if backCheck(sig[3],sig[4]) then
				return
			elseif refreshCheck(sig[3],sig[4]) then
				backCheck, refreshCheck = drawInfoScreen(title, buildRows())
			end
		end
	end
end

-- ===== Разделы =====
local function openCPUInfo()
	runInfoScreen("AeDA — Процессор", function()
		local chip = currentChipset()
		return {
			{type="header", text="Процессор"},
			{"Модель", chip.name},
			{"Производитель", chip.vendor},
			{"Класс", chip.class},
			{"Техпроцесс", chip.process},
			{"Ядра", chip.cores},
			{"Графика", chip.gpu},
			{type="header", text="Нагрузка"},
			{"Загрузка памяти", memoryLoadPercent() .. "%"},
			{"Время работы", fmtUptime(computer.uptime())},
		}
	end)
end

local function openMemoryInfo()
	runInfoScreen("AeDA — Память", function()
		return {
			{type="header", text="Оперативная память"},
			{"Всего", fmtBytes(computer.totalMemory())},
			{"Свободно", fmtBytes(computer.freeMemory())},
			{"Загрузка", memoryLoadPercent() .. "%"},
			{"Режим пониженной памяти", core.lowMemory and "активен" or "неактивен"},
		}
	end)
end

local function openSystemInfo()
	runInfoScreen("AeDA — Система", function()
		local chip = currentChipset()
		return {
			{type="header", text="Устройство"},
			{"Имя устройства", core.settings.deviceName or "не задано"},
			{"Модель", core.settings.deviceModel or "неизвестно"},
			{"Процессор", chip.name},
			{type="header", text="Прошивка"},
			{"ОС", "MeUI"},
			{"Сборка", "Stable"},
			{"Язык системы", core.settings.language or "eu_EN"},
			{type="header", text="Безопасность"},
			{"Блокировка экрана", (core.isLockActive and core.isLockActive()) and "включена" or "выключена"},
			{"Загрузчик", (core.settings.bootloaderUnlocked) and "разблокирован" or "заблокирован"},
			{"Режим разработчика", core.settings.developerMode and "включён" or "выключен"},
			{"Super Performance Mode", core.settings.superPerformanceMode and "включён" or "выключен"},
		}
	end)
end

local function openDisplayInfo()
	runInfoScreen("AeDA — Дисплей", function()
		local rW,rH = w,h
		local depth = "н/д"
		local ok, d = pcall(function() return component.gpu.getDepth() end)
		if ok and d then
			local maxOk, maxD = pcall(function() return component.gpu.maxDepth() end)
			depth = tostring(d) .. (maxOk and (" / макс " .. tostring(maxD)) or "")
		end
		return {
			{type="header", text="Экран"},
			{"Разрешение (текст)", rW .. "x" .. rH},
			{"Глубина цвета", depth},
		}
	end)
end

local function openComponentsInfo()
	runInfoScreen("AeDA — Компоненты", function()
		local rows = {{type="header", text="Подключённые компоненты"}}
		local comps = listComponents()
		if #comps == 0 then
			table.insert(rows, {"Компоненты", "не обнаружены"})
		else
			for i = 1, #comps do
				table.insert(rows, {"•", comps[i]})
			end
		end
		return rows
	end)
end

-- ===== Главный экран =====
local function drawMainMenu()
	buffer.drawRectangle(1,2,w,h-2,program.theme[1],program.theme[2]," ")
	local y = 5
	local buttons = {}
	local items = {
		{"Процессор", openCPUInfo},
		{"Память", openMemoryInfo},
		{"Система", openSystemInfo},
		{"Дисплей", openDisplayInfo},
		{"Компоненты", openComponentsInfo},
	}
	for i = 1, #items do
		local check = graphics.drawButton(1,y,w,1,items[i][1],program.theme[1],program.theme[2])
		table.insert(buttons,{check=check,onClick=items[i][2]})
		y = y + 1
	end
	y = y + 1
	local chip = currentChipset()
	graphics.centerText(w/2,y,0x666666,chip.name)
	graphics.drawActionBar({
		color=program.actionBar.background,
		text="AeDA",
		textColor=program.actionBar.foreground,
		statusBarFore=program.actionBar.statusBarFore,
	})
	buffer.drawChanges()
	return buttons
end

local function mainLoop()
	local buttons = drawMainMenu()
	while true do
		local sig = {event.pull(0.5)}
		if sig[1] == "REDRAW_ALL" then
			buttons = drawMainMenu()
		elseif sig[1] == "touch" then
			if graphics.clickedToBarButton(sig[3],sig[4]) == "HOME" then
				os.exit()
			elseif graphics.clickedToBarButton(sig[3],sig[4]) == "BACK" then
				os.exit()
			elseif sig[4] == 1 then
				graphics.processStatusBar(sig[3],sig[4])
			end
		elseif sig[1] == "drop" then
			for i = 1, #buttons do
				if buttons[i].check(sig[3],sig[4]) then
					buttons[i].onClick()
					buttons = drawMainMenu()
					break
				end
			end
		end
	end
end

core.pcall(mainLoop)
