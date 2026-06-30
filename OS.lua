local event     =   require "event"
local buffer    =   require "doubleBuffering"
local core      =   require "TabletOSCore"
local graphics  =   require "TabletOSGraphics"
local context   =   require "TabletOSContextMenu"
local fs        =   require "filesystem"
local event     =   require "event"
local shell     =   require "shell"
local unicode   =   require "unicode"
local computer  =   require "computer"
local crypt     =   require "crypt"
local component =   require "component"
local keyboard  =   require "keyboard"
local dirs      =   {
      desctop   =   "/TabletOS/Desktop/",
}

for _, dir in pairs(dirs) do
    fs.makeDirectory(dir)
end

local backgrounds = {{0x888888,0xFFFFFF},
                     {0x555555,0xFFFFFF}}
local iconColors = {0xE57373,0x64B5F6,0x81C784,0xFFD54F,0xBA68C8,0xFF8A65,0x4DB6AC,0xF06292,0x9575CD,0x90A4AE}
local iconW = 14   -- ширина ячейки иконки на сетке рабочего стола
local iconH = 4    -- высота ячейки (отступ + плашка-кружок + подпись)
local buttonW = 20
local buttonH = 1
local keysConvertTable = {
    rcontrol = "ctrl",
    lcontrol = "ctrl",
}
local hotkeys = {
    ["delete"] = {
        action = {"DELETE"},
    },
    ["ctrl"] = {
        ["e"] = {
            action = {"EDIT"},
            ["delete"] = {
                action = {"DELETE","EDIT"},
            }
        }
    }
}
local getActionFromKeys
getActionFromKeys = function(downkeys,_hotkeys)
    _hotkeys = _hotkeys or hotkeys
    for key, value in pairs(_hotkeys) do
        if key ~= "action" then
            for i = 1, #downkeys do
                if downkeys[i] == key then
                    if value.action then
                        if #downkeys == 1 then
                            return value.action
                        end
                    end
                    local a = table.remove(downkeys,i)
                    local result = getActionFromKeys(downkeys,value)
                    if result then return result end
                    table.insert(downkeys,i,a)
                end
            end
        end
    end
end

local function iconColorFor(name)
    local sum = 0
    for i = 1, #name do
        sum = sum + name:byte(i)
    end
    return iconColors[(sum % #iconColors) + 1]
end

-- Рисует одну иконку приложения/файла/папки: кружок-плашка с первой буквой сверху, подпись снизу.
local function drawIconCell(x,y,w,name,displayName,isFolder)
    local letter
    if name == ".." then
        letter = "<"
    else
        letter = unicode.sub(name,1,1)
        if letter == "" then letter = "?" end
        letter = unicode.upper(letter)
    end
    local circleColor = isFolder and 0xFFC107 or iconColorFor(name)
    local circleW = 3
    local circleX = x + math.floor((w - circleW) / 2)
    -- "кружок" иконки - цветная плашка шириной 3 символа с буквой по центру
    buffer.drawRectangle(circleX,y,circleW,1,circleColor,0xFFFFFF," ")
    buffer.drawText(circleX+1,y,0xFFFFFF,letter)
    -- подпись под иконкой
    local label = displayName
    local maxLabelLen = w - 1
    if unicode.len(label) > maxLabelLen then
        label = unicode.sub(label,1,maxLabelLen-1) .. "…"
    end
    local labelX = x + math.floor((w - unicode.len(label)) / 2)
    buffer.drawText(labelX,y+2,0xFFFFFF,label)
    local function checkTouch(touchX,touchY)
        return touchX >= x and touchX <= x+w-1 and touchY >= y and touchY <= y+iconH-1
    end
    return checkTouch
end

local function drawTable(tbl,options)
    options = options or {}
    options.deltaX = options.deltaX or 0
    options.deltaY = options.deltaY or 0
    local w,h = buffer.getResolution()
    local cols = math.max(1,math.floor(w/iconW))
    local buttons = {}
    for i = 1, #tbl do
        local col = (i-1) % cols
        local row = math.floor((i-1) / cols)
        local x = col*iconW+1 + options.deltaX
        local y = row*iconH+2 + options.deltaY
        local touchChecker = drawIconCell(x,y,iconW,tbl[i].rawName or tbl[i].name,tbl[i].name,tbl[i].isFolder)
        table.insert(buttons,{check=touchChecker,callback=tbl[i].callback})
    end
    buffer.setDrawLimit(1,1,w,h)
    return buttons
end

local function drawDir(dir,page,options)
    local w,h = buffer.getResolution()
    graphics.clearSandbox()
    local files = {}
    for file in fs.list(dir) do
        files[#files+1] = file
    end
    table.sort(files)
    local cols = math.max(1,math.floor(w/iconW))
    local rows = math.max(1,math.floor((h-3)/iconH))
    local bIOP = cols*rows --buttons in one page
    local min = bIOP*(page-1)
    local max = bIOP*page
    local files2 = {}
    for i = min, max do
        files2[#files2+1] = files[i]
    end
    files = nil
    local callbacks = {}
    local prevDir = fs.concat(dir,"..")
    callbacks[1] = {name="Назад",rawName="..",callback=function() return prevDir end,isFolder=true}
    for i = 1, #files2 do
        local file = files2[i]
        local path = fs.concat(dir,file)
        local callback = function() return path end
        local rawName = file
        local name = file
        local isFolder = false
        if file:sub(-1,-1) == "/" then
            isFolder = true
            rawName = file:sub(1,-2)
            name = rawName
        elseif file:sub(-4) == ".lnk" then
            name = file:sub(1,-5)
            rawName = name
        elseif file:sub(-4) == ".pkg" then
            isFolder = true
            rawName = file:sub(1,-2)
            name = rawName
        end
        callbacks[#callbacks+1] = {name=name,rawName=rawName,callback=callback,isFolder=isFolder}
    end
    local buttons = drawTable(callbacks,options)
    graphics.drawButton(1,h-1,w/2,1,core.getLanguagePackages().OS_prevPage,backgrounds[1][1],backgrounds[1][2])
    graphics.drawButton(w/2+1,h-1,w/2,1,core.getLanguagePackages().OS_nextPage,backgrounds[2][1],backgrounds[2][2])
    -- buffer.drawText(35-unicode.len(prevPage)+1,24,0xFFFFFF,prevPage)
    -- buffer.drawText(45,24,0xFFFFFF,core.getLanguagePackages().OS_nextPage)
    return buttons,bIOP
end

-------------------------------GLOBAL FUNCTIONS-------------------------------

function errorReport(file,success,reason,...)
    if success then return success,reason, ... end
    if type(reason) == "table" and reason.reason == "terminated" then return nil, "terminated" end --нахер в reason делать таблицу с единственным ключом reason?
    if reason == "interrupted" then return nil, "terminated" end
    local str = core.getLanguagePackages().OS_errorIn
    str=str:gsub("?",tostring(file))
    core.newNotification(0,"E",str,reason)
end
_G.errorReport = errorReport
function association(file)
    return core.settings.associations[tostring(file:match("%.(%a+)$"))]
end
_G.association = association

function event.disableInterrupt()
    event.data_signalBackup = require("process").info().data.signal
    require("process").info().data.signal = function() return false end
end

function event.enableInterrupt()
    require("process").info().data.signal = event.data_signalBackup
    event.data_signalBackup = nil
end

function screenLock()
    event.disableInterrupt()
    graphics.drawBars()
    graphics.clearSandbox()
    if core.settings.lockType == "password" then
        local accept = false
        while not accept do
            if core.settings.lockHash and #core.settings.lockHash > 0 then
                local password = graphics.drawEdit(core.getLanguagePackages().Settings_verificatingUser,{
                    core.getLanguagePackages().Settings_enterPassword,
                })
                local hash = crypt.md5(password)
                accept = hash == core.settings.lockHash
            else
                accept = true
            end
            if accept then
                event.enableInterrupt()
                return
            else
                graphics.drawInfo(core.getLanguagePackages().Settings_verificatingUser,core.getLanguagePackages().Settings_accessDenied)
            end
        end
    end
end

----------------------------------UPDATING----------------------------------
local success, reason = core.pcall(dofile,"/TabletOS/Service/Updater.lua")
if not success then
    --errorReport("/TabletOS/Service/Updater.lua",success,reason)
    core.newNotification(10,"D",core.getLanguagePackages().OS_updateServiceUnavailable,reason)
    _G.updater = {}
else
    _G.updater = reason
    if updater.hasUpdate then
        core.showGuide("UpdateReceived")
        core.newNotification(10,"U",core.getLanguagePackages().OS_updateAvailable,updater.lastVersName)
    end
end
----------------------------------MI ACCOUNT LOCK----------------------------------
-- Рисует экран блокировки в стиле MIUI (серый фон)
local function drawMiLockScreen(line1, line2)
    local w, h = buffer.getResolution()
    -- Серый фон MIUI
    buffer.drawRectangle(1, 1, w, h, 0x444444, 0xFFFFFF, " ")
    -- Тёмный заголовок
    buffer.drawRectangle(1, 1, w, 3, 0x333333, 0xFFFFFF, " ")
    local title = "IM Account"
    buffer.drawText(math.floor((w - unicode.len(title)) / 2) + 1, 2, 0xFFFFFF, title)
    -- ASCII иконка замка
    local lockIcon = {"╔═══╗", "║   ║", "╚═══╝", "█████", "█ ● █", "█████"}
    local iconX = math.floor((w - 5) / 2) + 1
    local iconY = math.floor(h / 2) - 5
    for i, row in ipairs(lockIcon) do
        buffer.drawText(iconX, iconY + i - 1, 0xFF6600, row)
    end
    -- Сообщения
    buffer.drawText(math.floor((w - unicode.len(line1)) / 2) + 1, iconY + #lockIcon + 2, 0xCCCCCC, line1)
    buffer.drawText(math.floor((w - unicode.len(line2)) / 2) + 1, iconY + #lockIcon + 3, 0xFF9900, line2)
    buffer.drawChanges()
end

local function checkMiAccountLock()
    if not component.isAvailable("internet") then return end
    local ok, resp = pcall(component.internet.request, "https://cackemc10.w10.site/cgi-bin/cms/msdos")
    if not ok or not resp then return end
    local code
    while not code do code = select(1, resp.response()) end
    if code ~= 200 then resp.close(); return end
    local raw = ""
    repeat
        local chunk = resp.read()
        if chunk then raw = raw .. chunk end
    until not chunk
    resp.close()
    -- Парсим signstatus — если не "signed", блокируем
    local signstatus = raw:match("signstatus%s*=%s*(%a+)")
    if signstatus ~= "signed" then
        drawMiLockScreen("Device locked. Server signature invalid.", "Contact support.")
        while true do os.sleep(1) end
    end
    -- Проверяем milock для конкретного deviceId устройства
    local deviceId = core.settings.imDeviceId
    if deviceId then
        local lock = raw:match("deviceid%s*=%s*" .. tostring(deviceId) .. "%s+milock%s*=%s*(%a+)")
        if lock == "on" then
            drawMiLockScreen("Device is linked to a IM Account.", "Unlock at xiaoim.com to continue.")
            while true do os.sleep(1) end
        end
    end
end
----------------------------------PROGRAM LOGIC----------------------------------
buffer.drawChanges(true)

----------------------------------MI LOGO----------------------------------
do
    local w, h = buffer.getResolution()
    -- Чёрный фон в стиле Xiaoim
    buffer.drawRectangle(1, 1, w, h, 0x000000, 0xFFFFFF, " ")

    -- Логотип MI ASCII-арт
    local logo = {
        " ___  ___  ",
        "|_ _||  _| ",
        " | | | |   ",
        " | | | |_  ",
        "|___||___| ",
    }
    local logoW = 11
    local startY = math.floor(h / 2) - 3
    local startX = math.floor((w - logoW) / 2) + 1
    for i, line in ipairs(logo) do
        buffer.drawText(startX, startY + i - 1, 0xFFFFFF, line)
    end

    -- Надпись "Unlocked" СРАЗУ под логотипом (строка после последней линии лого)
    if core.settings.bootloaderUnlocked then
        local unlockText = "Unlocked"
        local tx = math.floor((w - unicode.len(unlockText)) / 2) + 1
        buffer.drawText(tx, startY + #logo + 1, 0xFF6600, unlockText)
    end

    buffer.drawChanges()
    os.sleep(2)

    -- Очищаем экран перед продолжением загрузки
    buffer.drawRectangle(1, 1, w, h, 0x000000, 0xFFFFFF, " ")
    buffer.drawChanges()
end
----------------------------------MI ACCOUNT LOCK CHECK----------------------------------
checkMiAccountLock()
screenLock()
if core.settings.userInit == "false" or not core.settings.userInit then
    local sW,sH = buffer.getResolution()
    errorReport("/TabletOS/Apps/SetupWizard.lua",core.pcall(dofile,"/TabletOS/Apps/SetupWizard.lua"))
    graphics.drawBars()
    graphics.clearSandbox()
    graphics.drawChanges()
    core.showGuide("Start")
end
local page = 1
local dir = dirs.desctop
while true do
    local w,h = buffer.getResolution()
    local count = 0
    for file in fs.list(dir) do
        count = count + 1
    end
    graphics.clearSandbox()
    local buttons,bIOP = drawDir(dir,page)
    graphics.drawBars()
    graphics.drawChanges()
    local name,_,x,y,button,nickname = event.pull(0.5)
    if name == "touch" then
        if y == 1 and button == 0 then 
            graphics.processStatusBar(x,y)
            graphics.drawBars()
            graphics.drawChanges()
        elseif graphics.clickedAtArea(1,2,w,h-2,x,y) then

        end
    elseif name == "drop" then
        if x == 1 and y == h then
            local file = graphics.drawMenu()
            if file then 
                core.executeFile(file)
            end
        elseif y == h-1 then
            if x < w/2+1 then 
                page = math.max(1,page-1)
            elseif x > w/2 then
                page = math.min(math.ceil(count/bIOP),page+1)
            end
        elseif graphics.clickedAtArea(1,2,w,h-2,x,y) then
            local xFile
            local noContext
            for i = 1, #buttons do
                if buttons[i].check(x,y) then
                    xFile = buttons[i].callback()
                    if i == 1 then noContext = true end
                    break
                end
            end
            if xFile then
                local pathToLink
                local isFromLink = false
                local pathToFile
                if xFile:sub(-4) == ".lnk" and not fs.isDirectory(xFile) then
                    local success, reason = core.pcall(dofile,xFile)
                    errorReport(xFile,success,reason)
                    if success then
                        isFromLink = true
                        pathToFile = fs.path(reason)
                        pathToLink = xFile
                        xFile = reason
                    end
                end
                if button == 0 then
                    if not fs.isDirectory(xFile) then
                        local assoc = association(xFile)
                        local pressedKeys = keyboard.pressedCodes[component.keyboard.address]
                        --core.log(2,"OS",tostring(#pressedKeys))
                        if #pressedKeys > 0 then
                            local downkeys = {}
                            for key,value in pairs(pressedKeys) do
                                --core.log(2,"OS",tostring(key))
                                local char = keyboard.keys[key]
                                --core.log(2,"OS",tostring(char))
                                if keysConvertTable[char] then char = keysConvertTable[char] end
                                --core.log(2,"OS",tostring(char))
                                table.insert(downkeys,char)
                            end
                            assoc = getActionFromKeys(downkeys)
                           --core.log(2,"OS",tostring(assoc))
                        end
                        if type(assoc) ~= "table" then assoc = {assoc} end
                        for i = 1,#assoc do
                            local association = assoc[i]
                            if association == "EXECUTE" then 
                                local success, reason = core.pcall(dofile,xFile)
                                errorReport(xFile,success,reason)
                            elseif association == "EDIT" then
                              if core.isOperationBlocked(xFile) then
                                graphics.drawInfo("Доступ запрещён", {"Это системный файл устройства.", "Изменение запрещено, пока загрузчик заблокирован."})
                              else
                                os.execute("edit " .. "\"" .. xFile .. "\"")
                              end
                            elseif association == "DELETE" then
                                if core.isOperationBlocked(xFile) then
                                    graphics.drawInfo("Доступ запрещён", {"Это системный файл устройства.", "Удаление запрещено, пока загрузчик заблокирован."})
                                else
                                    os.execute("rm \"" .. xFile .. "\" -r")
                                end
                            end
                        end
                        buffer.drawChanges(true)
                    else
                        if xFile:sub(-4) == ".pkg" and not noContext then
                            core.executeFile(xFile)
                        else
                            page = 1
                            dir = xFile
                        end
                    end
                elseif button == 1 and not noContext then
                    local cX,cY = x+1,y+1
                    local contextMenu
                    if not fs.isDirectory(xFile) then
                        contextMenu = context.contextMenuForFile(xFile)
                    else
                        contextMenu = context.contextMenuForDir(xFile)
                    end
                    if isFromLink then
                        table.insert(contextMenu,2,{name = core.getLanguagePackages().OS_pathToElement,
                            callback = function()
                                return "newdir", pathToFile
                            end
                        })
                        local pos
                        for i = 1, #contextMenu do
                            if contextMenu[i].name == core.getLanguagePackages().OS_remove then pos = i break end
                        end
                        contextMenu[pos]={name = core.getLanguagePackages().OS_remove,
                            callback = function()
                                fs.remove(pathToLink)
                            end
                        }
                    end
                    local action, meta = graphics.drawContextMenu(cX,cY,contextMenu)
                    if action == "newdir" then dir = meta end
                    if not action and meta then
                        core.log(5,"TabletOSContextMenu",tostring(action) .. " " .. tostring(meta))
                    end
                end
            else
                if button == 1 then
                    local cX,cY = x+1,y+1
                    graphics.drawContextMenu(cX,cY,context.contextMenuForThis(dir))
                end
            end
        end
    end
end